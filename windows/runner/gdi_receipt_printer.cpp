#include "gdi_receipt_printer.h"

#include <windows.h>

#include <gdiplus.h>
#include <objbase.h>
#include <objidl.h>

#include <algorithm>
#include <cmath>
#include <map>
#include <memory>
#include <sstream>
#include <vector>

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return L"";
  int len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                                static_cast<int>(str.length()), nullptr, 0);
  std::wstring result(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.length()),
                      &result[0], len);
  return result;
}

const EncodableValue* Find(const EncodableMap& map, const std::string& key) {
  auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

std::string GetStr(const EncodableMap& map, const std::string& key,
                   const std::string& fallback = "") {
  auto* value = Find(map, key);
  if (!value) return fallback;
  if (auto* s = std::get_if<std::string>(value)) return *s;
  return fallback;
}

double GetNum(const EncodableMap& map, const std::string& key,
             double fallback = 0.0) {
  auto* value = Find(map, key);
  if (!value) return fallback;
  if (auto* d = std::get_if<double>(value)) return *d;
  if (auto* i = std::get_if<int32_t>(value)) return static_cast<double>(*i);
  if (auto* i = std::get_if<int64_t>(value)) return static_cast<double>(*i);
  return fallback;
}

bool GetBool(const EncodableMap& map, const std::string& key,
            bool fallback = false) {
  auto* value = Find(map, key);
  if (!value) return fallback;
  if (auto* b = std::get_if<bool>(value)) return *b;
  return fallback;
}

const EncodableList* GetList(const EncodableMap& map, const std::string& key) {
  auto* value = Find(map, key);
  if (!value) return nullptr;
  return std::get_if<EncodableList>(value);
}

const std::vector<uint8_t>* GetBytes(const EncodableMap& map,
                                     const std::string& key) {
  auto* value = Find(map, key);
  if (!value) return nullptr;
  return std::get_if<std::vector<uint8_t>>(value);
}

const EncodableMap* AsMap(const EncodableValue& value) {
  return std::get_if<EncodableMap>(&value);
}

// GDI+ ning standart `MeasureString`/`DrawString`i satr atrofiga qo'shimcha
// "nafas olish" bo'shlig'i qo'shadi — bu o'lchash/chizishdagi kichik
// nomuvofiqliklarni oldini olish uchun aniqroq (typographic) formatga
// o'tkaziladi. Ruchli oʻralish (word-wrap) o'zimizda qilingani uchun bu
// yerda GDI+ning avtomatik o'ralishi ham o'chiriladi.
Gdiplus::StringFormat& TightFormat() {
  static Gdiplus::StringFormat* format = [] {
    auto* f = new Gdiplus::StringFormat(Gdiplus::StringFormat::GenericTypographic());
    f->SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap |
                      Gdiplus::StringFormatFlagsNoClip);
    f->SetTrimming(Gdiplus::StringTrimmingNone);
    return f;
  }();
  return *format;
}

// `Gdiplus::Font` nusxalash konstruktori yo'q (`private`) — shuning uchun
// qiymat bo'yicha emas, `unique_ptr` orqali qaytariladi.
std::unique_ptr<Gdiplus::Font> MakeFont(float sizePt, bool bold) {
  return std::make_unique<Gdiplus::Font>(
      L"Arial", sizePt <= 0 ? 1.0f : sizePt,
      bold ? Gdiplus::FontStyleBold : Gdiplus::FontStyleRegular,
      Gdiplus::UnitPoint);
}

float MeasureWidth(Gdiplus::Graphics& g, Gdiplus::Font& font,
                   const std::wstring& text) {
  if (text.empty()) return 0;
  Gdiplus::RectF bounds;
  g.MeasureString(text.c_str(), -1, &font, Gdiplus::PointF(0, 0),
                  &TightFormat(), &bounds);
  return bounds.Width;
}

// `letterSpacing > 0` bo'lganda har bir belgi orasiga qo'shimcha bo'shliq
// qo'shib o'lchaydi (GDI+ da to'g'ridan-to'g'ri letter-spacing yo'q).
float MeasureLineWidth(Gdiplus::Graphics& g, Gdiplus::Font& font,
                       const std::wstring& line, float letterSpacing) {
  if (letterSpacing <= 0) return MeasureWidth(g, font, line);
  float total = 0;
  for (size_t i = 0; i < line.size(); i++) {
    total += MeasureWidth(g, font, line.substr(i, 1));
    if (i + 1 < line.size()) total += letterSpacing;
  }
  return total;
}

void DrawLine(Gdiplus::Graphics& g, Gdiplus::SolidBrush& brush,
             Gdiplus::Font& font, const std::wstring& line, float x, float y,
             float letterSpacing) {
  if (letterSpacing <= 0) {
    g.DrawString(line.c_str(), -1, &font, Gdiplus::PointF(x, y), &TightFormat(),
                &brush);
    return;
  }
  float cursorX = x;
  for (size_t i = 0; i < line.size(); i++) {
    std::wstring ch = line.substr(i, 1);
    g.DrawString(ch.c_str(), -1, &font, Gdiplus::PointF(cursorX, y),
                &TightFormat(), &brush);
    cursorX += MeasureWidth(g, font, ch) + letterSpacing;
  }
}

// `\n` bilan ajratilgan paragraflarga, so'ng har bir paragrafni so'zma-so'z
// berilgan kenglikka ("greedy word-wrap") bo'ladi. `firstLineMaxWidth` —
// (masalan header qatorida qalin sarlavhadan keyin qolgan joy uchun)
// birinchi qatorning boshqalaridan tor bo'lishi kerak bo'lganda ishlatiladi.
std::vector<std::wstring> WrapParagraph(Gdiplus::Graphics& g,
                                        Gdiplus::Font& font,
                                        const std::wstring& text,
                                        float maxWidth,
                                        float firstLineMaxWidth = -1) {
  std::vector<std::wstring> lines;
  if (firstLineMaxWidth < 0) firstLineMaxWidth = maxWidth;

  std::wistringstream words(text);
  std::wstring word;
  std::wstring current;
  bool firstLine = true;

  while (words >> word) {
    float limit = firstLine ? firstLineMaxWidth : maxWidth;
    std::wstring candidate = current.empty() ? word : current + L" " + word;
    float width = MeasureWidth(g, font, candidate);
    if (width > limit && !current.empty()) {
      lines.push_back(current);
      firstLine = false;
      current = word;
    } else {
      current = candidate;
    }
  }
  lines.push_back(current);
  return lines;
}

// Bo'sh qatorlar (`\n\n`) ham saqlanishi uchun paragraflarga ajratadi.
std::vector<std::wstring> SplitParagraphs(const std::wstring& text) {
  std::vector<std::wstring> paragraphs;
  std::wstring current;
  for (wchar_t ch : text) {
    if (ch == L'\n') {
      paragraphs.push_back(current);
      current.clear();
    } else {
      current += ch;
    }
  }
  paragraphs.push_back(current);
  return paragraphs;
}

// Ko'p qatorli, ixtiyoriy tekislash (`left`/`center`/`right`) va
// letter-spacing bilan matn chizadi (yoki `actuallyDraw=false` bo'lsa,
// faqat egallaydigan balandlikni hisoblaydi — masalan status ramkasining
// o'lchamini oldindan bilish uchun). Qaytadigan qiymat — egallangan
// balandlik (pt).
float DrawOrMeasureParagraph(Gdiplus::Graphics& g, Gdiplus::SolidBrush& brush,
                             Gdiplus::Font& font, const std::wstring& text,
                             float x, float y, float maxWidth,
                             const std::string& align, float letterSpacing,
                             bool actuallyDraw, float lineGap = 0.0f) {
  // `lineGap` — header itemlaridagi bo'shliq bilan bir xil naqsh: shrift
  // balandligining o'ziga tegilmaydi, faqat qatorlar orasiga qo'shimcha
  // bo'shliq qo'shiladi, compact rejimda bu `zeroInCompact(...)` orqali
  // nolga tushadi (`receipt_gdi_blocks.dart`).
  float lineHeight = font.GetHeight(&g) + lineGap;
  float cursorY = y;

  for (const auto& paragraph : SplitParagraphs(text)) {
    auto lines = WrapParagraph(g, font, paragraph, maxWidth);
    for (const auto& line : lines) {
      if (actuallyDraw) {
        float lineWidth = MeasureLineWidth(g, font, line, letterSpacing);
        float lineX = x;
        if (align == "center") {
          lineX = x + (maxWidth - lineWidth) / 2;
        } else if (align == "right") {
          lineX = x + (maxWidth - lineWidth);
        }
        DrawLine(g, brush, font, line, lineX, cursorY, letterSpacing);
      }
      cursorY += lineHeight;
    }
  }
  return cursorY - y;
}

// GDI+ ning `Bitmap::FromStream`i ba'zi formatlarda piksel ma'lumotini
// "dangasa" (lazy) o'qishi mumkin — shuning uchun orqadagi `IStream` bitmap
// bilan bir xil umr ko'rishi kerak (avval chizib bo'lgach, keyin ikkalasi
// birga bo'shatiladi). Shu sababli oddiy `Bitmap*` emas, bu ikkalasini
// birga ushlab turadigan struktura qaytariladi.
struct DecodedImage {
  std::unique_ptr<Gdiplus::Bitmap> bitmap;
  IStream* stream = nullptr;

  ~DecodedImage() {
    bitmap.reset();
    if (stream) stream->Release();
  }
};

std::unique_ptr<DecodedImage> DecodeImage(const std::vector<uint8_t>& bytes) {
  HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes.size());
  if (!hMem) return nullptr;
  void* buffer = GlobalLock(hMem);
  memcpy(buffer, bytes.data(), bytes.size());
  GlobalUnlock(hMem);

  IStream* stream = nullptr;
  if (CreateStreamOnHGlobal(hMem, TRUE, &stream) != S_OK) {
    GlobalFree(hMem);
    return nullptr;
  }

  auto* bitmap = Gdiplus::Bitmap::FromStream(stream);
  if (!bitmap || bitmap->GetLastStatus() != Gdiplus::Ok) {
    delete bitmap;
    stream->Release();
    return nullptr;
  }

  auto decoded = std::make_unique<DecodedImage>();
  decoded->bitmap.reset(bitmap);
  decoded->stream = stream;
  return decoded;
}

// Bitta chek "bloki"ni chizadi va joriy `cursorY`ni oshiradi. Har bir blok
// turi Dart tomonidagi `receipt_gdi_blocks.dart`dagi mos joylashuv qoidasiga
// bevosita mos keladi — bu yerda uslub qarorlari qabul qilinmaydi, faqat
// tayyor qiymatlar ijro etiladi.
void DrawBlock(Gdiplus::Graphics& g, Gdiplus::SolidBrush& blackBrush,
               const EncodableMap& block, float contentWidth, float& cursorY) {
  std::string type = GetStr(block, "type");

  if (type == "spacer") {
    cursorY += static_cast<float>(GetNum(block, "height"));
    return;
  }

  if (type == "text") {
    float fontSize = static_cast<float>(GetNum(block, "fontSize", 9));
    bool bold = GetBool(block, "bold");
    std::string align = GetStr(block, "align", "left");
    float letterSpacing = static_cast<float>(GetNum(block, "letterSpacing"));
    float lineGap = static_cast<float>(GetNum(block, "lineGap"));
    auto fontOwner = MakeFont(fontSize, bold);
    auto& font = *fontOwner;
    auto text = Utf8ToWide(GetStr(block, "text"));
    cursorY += DrawOrMeasureParagraph(g, blackBrush, font, text, 0, cursorY,
                                      contentWidth, align, letterSpacing, true,
                                      lineGap);
    return;
  }

  if (type == "row") {
    float fontSize = static_cast<float>(GetNum(block, "fontSize", 9));
    bool leftBold = GetBool(block, "leftBold");
    bool rightBold = GetBool(block, "rightBold");
    auto leftFontOwner = MakeFont(fontSize, leftBold);
    auto& leftFont = *leftFontOwner;
    auto rightFontOwner = MakeFont(fontSize, rightBold);
    auto& rightFont = *rightFontOwner;
    auto rightText = Utf8ToWide(GetStr(block, "right"));
    auto leftText = Utf8ToWide(GetStr(block, "left"));

    float rightWidth = MeasureWidth(g, rightFont, rightText);
    float rightX = contentWidth - rightWidth;
    float leftMaxWidth = rightText.empty() ? contentWidth : std::max(0.0f, rightX);

    float leftHeight = DrawOrMeasureParagraph(
        g, blackBrush, leftFont, leftText, 0, cursorY, leftMaxWidth, "left",
        0, true);
    if (!rightText.empty()) {
      DrawLine(g, blackBrush, rightFont, rightText, rightX, cursorY, 0);
    }
    float rightHeight = rightFont.GetHeight(&g);
    cursorY += std::max(leftHeight, rightHeight);
    return;
  }

  if (type == "headerRich") {
    float fontSize = static_cast<float>(GetNum(block, "fontSize", 9));
    auto boldFontOwner = MakeFont(fontSize, true);
    auto& boldFont = *boldFontOwner;
    auto regularFontOwner = MakeFont(fontSize, false);
    auto& regularFont = *regularFontOwner;
    auto titlePrefix = Utf8ToWide(GetStr(block, "title") + ": ");
    auto val = Utf8ToWide(GetStr(block, "val"));

    float titleWidth = MeasureWidth(g, boldFont, titlePrefix);
    float firstLineMaxWidth = std::max(0.0f, contentWidth - titleWidth);
    float lineHeight = regularFont.GetHeight(&g);

    DrawLine(g, blackBrush, boldFont, titlePrefix, 0, cursorY, 0);

    auto lines = WrapParagraph(g, regularFont, val, contentWidth,
                               firstLineMaxWidth);
    for (size_t i = 0; i < lines.size(); i++) {
      float x = i == 0 ? titleWidth : 0;
      DrawLine(g, blackBrush, regularFont, lines[i], x, cursorY, 0);
      cursorY += lineHeight;
    }
    return;
  }

  if (type == "statusBox") {
    float fontSize = static_cast<float>(GetNum(block, "fontSize", 12));
    float padding = static_cast<float>(GetNum(block, "padding"));
    float borderWidth = static_cast<float>(GetNum(block, "borderWidth", 2));
    auto fontOwner = MakeFont(fontSize, true);
    auto& font = *fontOwner;
    auto text = Utf8ToWide(GetStr(block, "text"));

    float innerWidth = contentWidth - 2 * (padding + borderWidth);
    float textHeight = DrawOrMeasureParagraph(g, blackBrush, font, text, 0, 0,
                                              innerWidth, "center", 0, false);
    float boxHeight = textHeight + 2 * (padding + borderWidth);

    Gdiplus::Pen pen(Gdiplus::Color(255, 0, 0, 0), borderWidth);
    g.DrawRectangle(&pen, 0.0f, cursorY, contentWidth, boxHeight);

    DrawOrMeasureParagraph(g, blackBrush, font, text, padding + borderWidth,
                           cursorY + padding + borderWidth, innerWidth,
                           "center", 0, true);
    cursorY += boxHeight;
    return;
  }

  if (type == "divider") {
    float margin = static_cast<float>(GetNum(block, "margin"));
    float thickness = static_cast<float>(GetNum(block, "thickness", 0.375));
    cursorY += margin;
    Gdiplus::Pen pen(Gdiplus::Color(255, 0, 0, 0), thickness);
    g.DrawLine(&pen, 0.0f, cursorY, contentWidth, cursorY);
    cursorY += thickness + margin;
    return;
  }

  if (type == "image") {
    auto* bytes = GetBytes(block, "bytes");
    float height = static_cast<float>(GetNum(block, "height"));
    if (!bytes || bytes->empty() || height <= 0) return;
    auto decoded = DecodeImage(*bytes);
    if (!decoded) return;
    auto* bitmap = decoded->bitmap.get();

    float naturalW = static_cast<float>(bitmap->GetWidth());
    float naturalH = static_cast<float>(bitmap->GetHeight());
    float width = naturalH > 0 ? height * (naturalW / naturalH) : height;

    // C#dagi `DrawLogoFromUrl` bilan bir xil "ikkala tomondan cheklash"
    // mantiqi: aspekt nisbati saqlanib, `maxWidth` (agar berilgan bo'lsa)
    // dan oshsa, kenglik bo'yicha qayta hisoblanadi.
    float maxWidth = static_cast<float>(GetNum(block, "maxWidth", -1));
    if (maxWidth > 0 && width > maxWidth) {
      width = maxWidth;
      height = naturalW > 0 ? maxWidth * (naturalH / naturalW) : height;
    }
    float x = (contentWidth - width) / 2;

    // C#dagi kabi: dithering yo'q, faqat yuqori sifatli interpolyatsiya —
    // qattiq qora/oq dithering sinalgan edi (2026-09-16), lekin logotipni
    // "shovqinli" qilib yomonlashtirdi (aslida muammo kichik o'lcham edi,
    // yuqoridagi `height`/`maxWidth` C#ga mos kattalashtirildi).
    auto oldInterp = g.GetInterpolationMode();
    auto oldSmoothing = g.GetSmoothingMode();
    g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    g.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);
    g.DrawImage(bitmap, Gdiplus::RectF(x, cursorY, width, height));
    g.SetInterpolationMode(oldInterp);
    g.SetSmoothingMode(oldSmoothing);

    cursorY += height;
    return;
  }

  if (type == "barcodeBars") {
    float totalWidth = static_cast<float>(GetNum(block, "totalWidth"));
    float totalHeight = static_cast<float>(GetNum(block, "totalHeight"));
    auto* bars = GetList(block, "bars");
    float offsetX = (contentWidth - totalWidth) / 2;
    if (bars) {
      for (const auto& barValue : *bars) {
        auto* bar = AsMap(barValue);
        if (!bar) continue;
        float left = static_cast<float>(GetNum(*bar, "left"));
        float top = static_cast<float>(GetNum(*bar, "top"));
        float width = static_cast<float>(GetNum(*bar, "width"));
        float barHeight = static_cast<float>(GetNum(*bar, "height"));
        g.FillRectangle(&blackBrush, offsetX + left, cursorY + top, width,
                        barHeight);
      }
    }
    cursorY += totalHeight;
    return;
  }

  if (type == "socialRow") {
    auto* items = GetList(block, "items");
    if (!items) return;
    float spacing = static_cast<float>(GetNum(block, "spacing"));
    float runSpacing = static_cast<float>(GetNum(block, "runSpacing"));
    float iconGap = static_cast<float>(GetNum(block, "iconGap"));

    float cursorX = 0;
    float rowHeight = 0;
    float rowY = cursorY;

    for (const auto& itemValue : *items) {
      auto* item = AsMap(itemValue);
      if (!item) continue;

      float iconSize = static_cast<float>(GetNum(*item, "iconSize"));
      float fontSize = static_cast<float>(GetNum(*item, "fontSize", 9));
      auto fontOwner = MakeFont(fontSize, false);
      auto& font = *fontOwner;
      auto title = Utf8ToWide(GetStr(*item, "title"));
      float labelWidth = MeasureWidth(g, font, title);
      float labelHeight = font.GetHeight(&g);
      float itemHeight = std::max(iconSize, labelHeight);
      float itemWidth = iconSize + iconGap + labelWidth;

      if (cursorX > 0 && cursorX + itemWidth > contentWidth) {
        rowY += rowHeight + runSpacing;
        cursorX = 0;
        rowHeight = 0;
      }

      auto* iconBytes = GetBytes(*item, "iconBytes");
      if (iconBytes && !iconBytes->empty() && iconSize > 0) {
        auto decoded = DecodeImage(*iconBytes);
        if (decoded) {
          // Ikonka ham Dart tomonida qattiq qora/shaffof qilib
          // tayyorlangan (`_rasterizeSvgIcon`) — silliqlashtirish uni
          // qayta xiralashtiradi, shuning uchun `NearestNeighbor`.
          auto oldInterp = g.GetInterpolationMode();
          g.SetInterpolationMode(Gdiplus::InterpolationModeNearestNeighbor);
          g.DrawImage(decoded->bitmap.get(),
                      Gdiplus::RectF(cursorX, rowY + (itemHeight - iconSize) / 2,
                                    iconSize, iconSize));
          g.SetInterpolationMode(oldInterp);
        }
      }
      DrawLine(g, blackBrush, font, title, cursorX + iconSize + iconGap,
              rowY + (itemHeight - labelHeight) / 2, 0);

      rowHeight = std::max(rowHeight, itemHeight);
      cursorX += itemWidth + spacing;
    }

    cursorY = rowY + rowHeight;
    return;
  }
}

}  // namespace

bool PrintReceiptBlocks(const std::wstring& printer_name,
                        const std::wstring& document_name,
                        double content_width_pt,
                        const EncodableList& blocks, std::string& error_out) {
  HDC hDC = CreateDC(L"WINSPOOL", printer_name.c_str(), nullptr, nullptr);
  if (!hDC) {
    error_out = "CreateDC muvaffaqiyatsiz tugadi";
    return false;
  }

  DOCINFO docInfo = {};
  docInfo.cbSize = sizeof(docInfo);
  docInfo.lpszDocName = document_name.c_str();

  if (StartDoc(hDC, &docInfo) <= 0) {
    DeleteDC(hDC);
    error_out = "StartDoc muvaffaqiyatsiz tugadi";
    return false;
  }
  if (StartPage(hDC) <= 0) {
    AbortDoc(hDC);
    DeleteDC(hDC);
    error_out = "StartPage muvaffaqiyatsiz tugadi";
    return false;
  }

  {
    // C#dagi `Graphics`dan farqli sozlamalar ataylab qo'yilmaydi —
    // GDI+ning printer DC uchun standart (hint'siz) matn/chiziq rejimi
    // aynan C# ilova ishlatgan bi-level, aniq natijani beradi.
    Gdiplus::Graphics graphics(hDC);
    graphics.SetPageUnit(Gdiplus::UnitPoint);

    Gdiplus::SolidBrush blackBrush(Gdiplus::Color(255, 0, 0, 0));
    float cursorY = 0;
    float contentWidth = static_cast<float>(content_width_pt);

    for (const auto& blockValue : blocks) {
      auto* block = AsMap(blockValue);
      if (!block) continue;
      DrawBlock(graphics, blackBrush, *block, contentWidth, cursorY);
    }
    // `graphics` shu blokdan chiqishda destruktor orqali flush bo'ladi —
    // GDI+ning printer DC'ga chizishlarni oxirigacha yetkazishi uchun bu
    // `EndPage`dan OLDIN sodir bo'lishi shart.
  }

  EndPage(hDC);
  EndDoc(hDC);
  DeleteDC(hDC);
  return true;
}

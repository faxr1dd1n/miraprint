import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../model/receipt/header_item.dart';
import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_date_format.dart';
import '../../model/receipt/receipt_settings.dart';
import 'social_icon_assets.dart';

// `receipt_gdi_printer.dart` orqali Windows'da GDI+ ga yuboriladigan
// "chizish bloklari"ni quradi — uslub qoidalari (shrift o'lchamlari,
// bo'shliqlar, compact rejim) aynan avvalgi `receipt_pdf_builder.dart`
// (endi o'chirilgan) bilan bir xil, faqat oxirgi bosqich PDF/PDFium o'rniga
// to'g'ridan-to'g'ri printer drayveriga (`GDI+`) chizadigan native kodga
// almashtirilgan — chek matnining xira chiqishi aynan PDF rasterlash
// bosqichida edi (`PLAN.md`dagi tahlilga qarang).
//
// message.txt'dagi qoidalar (px) — 12px/16px/20px, PUNKT (pt)ga
// o'girilgan: 96 CSS-px/dyum va 72pt/dyum, ya'ni `1px = 0.75pt`.
const _pxToPt = 0.75;
double pt(double px) => px * _pxToPt;

const _baseFontSize = 12.0 * _pxToPt; // mahsulot nomi, oddiy totals
// Header sarlavha/qiymat va ijtimoiy tarmoq matni — saytdagidan farqli
// o'laroq, foydalanuvchi tasdiqlagan holda 12px emas, 14px (2026-09-16).
const _labelFontSize = 12.0 * _pxToPt;
const _totalBigFontSize = 16.0 * _pxToPt; // Итого
const _statusFontSize = 16.0 * _pxToPt;
const _footerFontSize = 12.0 * _pxToPt;

// 80mm rulon qog'oz kengligi, punktda (72pt/dyum, 1dyum=25.4mm) — avvalgi
// `PdfPageFormat.roll80.width` bilan bir xil qiymat, endi `pdf` paketiga
// bog'liq bo'lmasdan.
const _mmToPt = 72 / 25.4;
const contentWidthPt = 80 * _mmToPt;

Future<Map<String, Object?>> buildReceiptGdiPayload(
  ReceiptData receipt, {
  ReceiptSettings? settings,
}) async {
  final isCompact = settings?.spacing == 'compact';
  double zeroInCompact(double px) => isCompact ? 0 : pt(px);
  double halveInCompact(double px) => pt(isCompact ? px / 2 : px);

  final dateFormat = settings?.layout.dateFormat ?? 'date';
  final isCentered = isCenteredDateFormat(dateFormat);

  HeaderItem? statusHeader;
  HeaderItem? dateHeader;
  for (final header in receipt.headers) {
    if (header.key == 'status') statusHeader = header;
    if (header.key == 'receipt_date') dateHeader = header;
  }
  final remainingHeaders = receipt.headers.where((header) {
    if (header.key == 'status') return false;
    if (isCentered && header.key == 'receipt_date') return false;
    return true;
  }).toList();

  final blocks = <Map<String, Object?>>[];

  if (receipt.logo.isNotEmpty) {
    final logoBytes = await _downloadBytes(receipt.logo);
    if (logoBytes != null) {
      // C#dagi `DrawLogoFromUrl` (`MainForm.cs`) bilan bir xil: hech qanday
      // oldindan qayta ishlash (dithering) yo'q — asl bayt, native tomonda
      // `HighQualityBicubic` bilan chiziladi. Dithering (2026-09-16)
      // sinalgan edi, lekin logotipni "shovqinli" qilib yomonlashtirdi —
      // asl muammo dithering emas, balki o'lcham juda kichik bo'lgani edi
      // (pastga qarang, C#dagi haqiqiy maksimal o'lchamlarga moslandi).
      blocks
        ..add({
          'type': 'image',
          'bytes': logoBytes,
          // C#: logoMaxHeight=140 (1/100in) = 1.4in, logoMaxWidth=260
          // (1/100in) = 2.6in — aspekt nisbati saqlanib, ikkalasidan
          // qaysi biri avval cheklasa o'shanga moslanadi (native
          // tomonda amalga oshiriladi).
          'height': 1.4 * 72,
          'maxWidth': 2.6 * 72,
        })
        ..add(_spacer(halveInCompact(8)));
    }
  }

  if (isCentered && dateHeader != null) {
    blocks
      ..add(
        _text(
          formatReceiptDate(dateHeader.val, dateFormat),
          fontSize: _baseFontSize,
          align: 'center',
        ),
      )
      ..add(_spacer(halveInCompact(8)));
  }

  // Receipt.vue: `.receipt-status` — ramka (2px), katta harflar, qalin.
  if (statusHeader != null && statusHeader.val.isNotEmpty) {
    blocks
      ..add({
        'type': 'statusBox',
        'text': statusHeader.val.toUpperCase(),
        'fontSize': _statusFontSize,
        'padding': pt(8),
        'borderWidth': pt(2),
      })
      ..add(_spacer(halveInCompact(12)));
  }

  if (receipt.currentNumber.isNotEmpty) {
    blocks
      ..add(_spacer(halveInCompact(10)))
      ..add(
        _text(
          receipt.currentNumber,
          fontSize: pt(32),
          bold: true,
          align: 'center',
        ),
      )
      ..add(_spacer(halveInCompact(20)));
  }

  // Receipt.vue: `<strong>{{ title }}:</strong><span>{{ val }}</span>`.
  for (final header in remainingHeaders) {
    if (settings?.layout.fieldsLayout == 'space-between') {
      blocks.add({
        'type': 'row',
        'left': header.title,
        'right': header.val,
        'leftBold': true,
        'rightBold': false,
        'fontSize': _labelFontSize,
      });
    } else {
      blocks.add({
        'type': 'headerRich',
        'title': header.title,
        'val': header.val,
        'fontSize': _labelFontSize,
      });
    }
    blocks.add(_spacer(zeroInCompact(4)));
  }

  blocks.add(_divider(halveInCompact(6)));

  for (final item in receipt.items) {
    blocks
      ..add(_text(item.name, fontSize: _baseFontSize, bold: true))
      ..add(_spacer(zeroInCompact(6)))
      ..add({
        'type': 'row',
        'left': '${item.qty}шт x ${item.price}',
        'right': item.totalPrice,
        'leftBold': false,
        'rightBold': true,
        'fontSize': _baseFontSize,
      })
      ..add(_spacer(zeroInCompact(4)));

    if (item.discountText != null && item.discountPrice != null) {
      blocks
        ..add({
          'type': 'row',
          'left': item.discountText!,
          'right': item.discountPrice!,
          'leftBold': false,
          'rightBold': true,
          'fontSize': _baseFontSize,
        })
        ..add(_spacer(zeroInCompact(4)));
    }

    blocks.add(_divider(halveInCompact(6)));
  }

  // Receipt.vue: `.total { font-weight: bold }` — BARCHA totals qatori
  // qalin, `big` faqat shriftni kattalashtiradi.
  for (final total in receipt.totals) {
    blocks
      ..add({
        'type': 'row',
        'left': total.title,
        'right': total.val,
        'leftBold': true,
        'rightBold': true,
        'fontSize': total.big ? _totalBigFontSize : _baseFontSize,
      })
      ..add(_spacer(zeroInCompact(total.big ? 10 : 4)));
  }

  if (receipt.socials.isNotEmpty) {
    blocks.add(_spacer(halveInCompact(8)));
    final items = <Map<String, Object?>>[];
    for (final social in receipt.socials) {
      Uint8List iconBytes;
      try {
        iconBytes = await _rasterizeSvgIcon(
          socialIconAssetPath(social.icon),
          pt(16),
        );
      } catch (_) {
        iconBytes = Uint8List(0);
      }
      items.add({
        'iconBytes': iconBytes,
        'iconSize': pt(16),
        'title': social.title,
        'fontSize': _labelFontSize,
      });
    }
    blocks.add({
      'type': 'socialRow',
      'items': items,
      'spacing': pt(10),
      'runSpacing': pt(8),
      'iconGap': pt(4),
    });
  }

  if (receipt.barcode.isNotEmpty) {
    blocks
      ..add(_spacer(pt(10)))
      ..add({
        'type': 'barcodeBars',
        // Receipt.vue: `JsBarcode(..., { displayValue: false })` — barcode
        // ostida raqamli matn KO'RSATILMAYDI.
        'bars': Barcode.code128()
            .make(receipt.barcode, width: pt(120), height: pt(80))
            .whereType<BarcodeBar>()
            .where((bar) => bar.black)
            .map(
              (bar) => {
                'left': bar.left,
                'top': bar.top,
                'width': bar.width,
                'height': bar.height,
              },
            )
            .toList(),
        'totalWidth': pt(120),
        'totalHeight': pt(80),
      })
      ..add(_spacer(pt(8)));
  }

  // Receipt.vue `.thanks`: markazlashgan, letter-spacing:1px.
  final footerNotice = settings?.texts.footerNotice;
  if (footerNotice != null && footerNotice.isNotEmpty) {
    blocks
      ..add(_spacer(halveInCompact(12)))
      ..add(_divider(0))
      ..add(_spacer(halveInCompact(12)))
      ..add(
        _text(
          footerNotice,
          fontSize: _footerFontSize,
          align: 'center',
          letterSpacing: pt(1),
          // Header itemlaridagi bilan bir xil naqsh (`zeroInCompact(4)`) —
          // compact rejimda footer matnining ichki qatorlari orasidagi
          // qo'shimcha bo'shliq ham nolga tushadi.
          lineGap: zeroInCompact(4),
        ),
      );
  }

  return {'contentWidthPt': contentWidthPt, 'blocks': blocks};
}

Map<String, Object?> _text(
  String text, {
  required double fontSize,
  bool bold = false,
  String align = 'left',
  double letterSpacing = 0,
  double lineGap = 0,
}) => {
  'type': 'text',
  'text': text,
  'fontSize': fontSize,
  'bold': bold,
  'align': align,
  'letterSpacing': letterSpacing,
  'lineGap': lineGap,
};

Map<String, Object?> _spacer(double height) => {
  'type': 'spacer',
  'height': height,
};

/// `verticalMargin` — chiziqdan oldin/keyingi bo'shliq (ikkalasi ham teng).
Map<String, Object?> _divider(double verticalMargin) => {
  'type': 'divider',
  'margin': verticalMargin,
  'thickness': pt(1),
};

/// Eski C# ilovadagi `DownloadLogoAsync` bilan bir xil: har qanday xatoda
/// (tarmoq, timeout, buzilgan rasm) jim `null` qaytaradi.
Future<Uint8List?> _downloadBytes(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}

/// Ijtimoiy tarmoq ikonkasi SVG'sini kichik PNG rastriga aylantiradi (GDI+
/// SVG'ni to'g'ridan-to'g'ri chiza olmaydi) — `receipt_canvas_renderer.dart`
/// dagi bilan bir xil `vg.loadPicture` texnikasi.
Future<Uint8List> _rasterizeSvgIcon(String assetPath, double sizePt) async {
  final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);
  // Ikonka kichik bo'lgani uchun (odatda ~35px), yumshoq (anti-aliased)
  // qirralar termal printerda dithering orqali "erib" ketib, xira
  // ko'rinardi — shuning uchun yuqori zichlikda rastrga aylantirilib,
  // keyin pastda alpha kanali qattiq threshold qilinadi (aniq qora/shaffof,
  // yarim-shaffof piksel yo'q).
  const scale = 4.0;
  final pixelSize = (sizePt * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(
    pixelSize / pictureInfo.size.width,
    pixelSize / pictureInfo.size.height,
  );
  canvas.drawPicture(pictureInfo.picture);
  final picture = recorder.endRecording();

  final uiImage = await picture.toImage(pixelSize, pixelSize);
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = byteData!.buffer.asUint8List();

  final image = img.Image.fromBytes(
    width: uiImage.width,
    height: uiImage.height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  for (final pixel in image) {
    if (pixel.a >= 128) {
      pixel
        ..r = 0
        ..g = 0
        ..b = 0
        ..a = 255;
    } else {
      pixel.a = 0;
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

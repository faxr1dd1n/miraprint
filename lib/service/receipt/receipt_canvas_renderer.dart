import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import '../../model/receipt/header_item.dart';
import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_date_format.dart';
import '../../model/receipt/receipt_settings.dart';
import '../../model/receipt/social_link.dart';
import 'social_icon_assets.dart';

const double _printWidth = 576;

/// Har bir `SocialLink` uchun SVG'ni oldindan yuklab, chizish uchun
/// tayyorlaydi. `_renderContent` ikki marta (o'lchash va chizish uchun)
/// chaqirilgani sababli, yuklashni undan tashqarida, bir marta qilamiz.
Future<List<(SocialLink, ui.Picture, Size)>> _loadSocialIcons(
  List<SocialLink> socials,
) async {
  final loaded = <(SocialLink, ui.Picture, Size)>[];
  for (final social in socials) {
    final pictureInfo = await vg.loadPicture(
      SvgAssetLoader(socialIconAssetPath(social.icon)),
      null,
    );
    loaded.add((social, pictureInfo.picture, pictureInfo.size));
  }
  return loaded;
}

double _spacingMultiplier(String spacing) {
  switch (spacing) {
    // Receipt.vue: `.receipt--spacing-compact` klassidagi barcha margin
    // qiymatlari normal holatiga nisbatan aniq yarmiga teng
    // (masalan `hr` 0.5rem -> 0.25rem, `.receipt-header` 20px -> 10px).
    case 'compact':
      return 0.5;
    default:
      return 1.0;
  }
}

double _renderContent(
  Canvas? canvas,
  ReceiptData receipt, {
  ReceiptSettings? settings,
  List<(SocialLink, ui.Picture, Size)>? socialIcons,
}) {
  double y = 0;
  final spacing = _spacingMultiplier(settings?.spacing ?? 'normal');
  final isCompact = settings?.spacing == 'compact';
  final spaceBetweenLayout = settings?.layout.fieldsLayout == 'space-between';
  final dateFormat = settings?.layout.dateFormat ?? 'date';

  double paintRow(
    String left,
    String right, {
    required double fontSize,
    bool boldLeft = false,
    bool boldRight = false,
  }) {
    TextStyle style(bool bold) => TextStyle(
      color: const Color(0xFF000000),
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    final leftPainter = TextPainter(
      text: TextSpan(text: left, style: style(boldLeft)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth * 0.65);
    final rightPainter = TextPainter(
      text: TextSpan(text: right, style: style(boldRight)),
      textDirection: TextDirection.ltr,
    )..layout();

    final rowHeight = leftPainter.height > rightPainter.height
        ? leftPainter.height
        : rightPainter.height;

    if (canvas != null) {
      leftPainter.paint(canvas, Offset(0, y));
      rightPainter.paint(canvas, Offset(_printWidth - rightPainter.width, y));
    }
    return rowHeight;
  }

  void hr({double before = 6, double after = 10}) {
    y += before * spacing;
    canvas?.drawRect(
      Rect.fromLTWH(0, y, _printWidth, 2),
      Paint()..color = const Color(0xFF000000),
    );
    y += 2 + after * spacing;
  }

  // `header.key == 'receipt_date'` — sana HEADER ELEMENTINING kaliti;
  // `layout.date_format` esa sozlamalardagi FORMAT nomi — ikkisi boshqa-
  // boshqa narsa, avval bittasi ikkinchisi bilan aralashtirilgan edi.
  HeaderItem? dateHeader;
  for (final header in receipt.headers) {
    if (header.key == 'receipt_date') {
      dateHeader = header;
      break;
    }
  }

  final isCenteredDate = isCenteredDateFormat(dateFormat);

  if (isCenteredDate && dateHeader != null) {
    final painter = TextPainter(
      text: TextSpan(
        text: formatReceiptDate(dateHeader.val, dateFormat),
        style: const TextStyle(color: Color(0xFF000000), fontSize: 22),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth);
    if (canvas != null) {
      painter.paint(canvas, Offset((_printWidth - painter.width) / 2, y));
    }
    y += painter.height + 8 * spacing;
  }

  // Receipt.vue: `statusLabel` header ro'yxatidan ajratib olinadi va
  // logotip/sanadan keyin, header maydonlaridan OLDIN, alohida ramkali
  // blok (`.receipt-status`) sifatida chiqariladi — umumiy header
  // qatorida qaytarilmaydi (pastdagi asosiy tsiklda `key == 'status'`
  // o'tkazib yuboriladi).
  HeaderItem? statusHeader;
  for (final header in receipt.headers) {
    if (header.key == 'status') {
      statusHeader = header;
      break;
    }
  }

  if (statusHeader != null && statusHeader.val.isNotEmpty) {
    const statusFontSize = 24.0;
    const statusPadding = 12.0;
    const statusBorderWidth = 3.0;
    final painter = TextPainter(
      text: TextSpan(
        text: statusHeader.val.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: statusFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth - (statusPadding + statusBorderWidth) * 2);

    final boxWidth = painter.width + (statusPadding + statusBorderWidth) * 2;
    final boxHeight = painter.height + (statusPadding + statusBorderWidth) * 2;
    final boxLeft = (_printWidth - boxWidth) / 2;

    if (canvas != null) {
      canvas.drawRect(
        Rect.fromLTWH(boxLeft, y, boxWidth, boxHeight),
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = statusBorderWidth,
      );
      painter.paint(
        canvas,
        Offset(
          boxLeft + statusPadding + statusBorderWidth,
          y + statusPadding + statusBorderWidth,
        ),
      );
    }
    y += boxHeight + 12 * spacing;
  }

  if (receipt.currentNumber.isNotEmpty) {
    final painter = TextPainter(
      text: TextSpan(
        text: receipt.currentNumber,
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 64,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth);
    if (canvas != null) {
      painter.paint(canvas, Offset((_printWidth - painter.width) / 2, y));
    }
    y += painter.height + 12 * spacing;
  }

  for (final header in receipt.headers) {
    if (header.key == 'status') continue;
    if (isCenteredDate && header.key == 'receipt_date') continue;

    final displayVal = header.key == 'receipt_date'
        ? formatReceiptDate(header.val, dateFormat)
        : header.val;

    // Receipt.vue: `.receipt-block--header > p { margin-bottom: 0.25rem }`,
    // compact holatda esa `.receipt--spacing-compact ... { margin-bottom: 0 }`
    // — bu yerda proporsional emas, aniq nolga tushadi.
    final headerRowGap = isCompact ? 0.0 : 4 * spacing;

    if (spaceBetweenLayout) {
      y += paintRow(header.title, displayVal, fontSize: 24, boldLeft: true);
      y += headerRowGap;
    } else {
      // Receipt.vue: <strong>{{ title }}:</strong><span>{{ val }}</span>
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${header.title}: ',
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: displayVal,
              style: const TextStyle(color: Color(0xFF000000), fontSize: 24),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _printWidth);
      if (canvas != null) painter.paint(canvas, Offset(0, y));
      y += painter.height + headerRowGap;
    }
  }

  hr();

  // Receipt.vue: `.receipt--spacing-compact .line-item * { margin-bottom: 0 }`
  // — bitta item ichidagi nom/miqdor-narx/chegirma qatorlari orasidagi
  // bo'shliq ham (header qatorlari kabi) proporsional emas, aniq nolga
  // tushadi. Totals ham `.line-item` klassiga ega, shu bilan bir xil.
  final rowGap = isCompact ? 0.0 : 1.0;

  for (final item in receipt.items) {
    final namePainter = TextPainter(
      text: TextSpan(
        text: item.name,
        style: const TextStyle(
          color: Color(0xFF000000),
          // message.txt: `.item-name` alohida font-size bermaydi, shuning
          // uchun `.line-item{font-size:12px}`ni meros oladi — header bilan
          // bir xil (bizda ×2 masshtab: 12×2=24, headerga teng).
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth);
    if (canvas != null) namePainter.paint(canvas, Offset(0, y));
    y += namePainter.height + 6 * spacing * rowGap;

    y += paintRow(
      '${item.qty}шт x ${item.price}',
      item.totalPrice,
      fontSize: 24,
      boldRight: true,
    );
    y += 4 * spacing * rowGap;

    if (item.discountText != null && item.discountPrice != null) {
      // Receipt.vue: `.item-discount` oddiy, `.item-price-without-discount`
      // esa `font-weight-bold` klassiga ega — chegirmadan keyingi yakuniy
      // summa qalin bo'lishi kerak.
      y += paintRow(
        item.discountText!,
        item.discountPrice!,
        fontSize: 22,
        boldRight: true,
      );
      y += 4 * spacing * rowGap;
    }

    hr();
  }

  for (final total in receipt.totals) {
    // Receipt.vue: `.total { font-weight: bold }` — hamma totals qatori
    // qalin, `big` (`.total-xl`) faqat shriftni kattalashtiradi.
    y += paintRow(
      total.title,
      total.val,
      fontSize: total.big ? 32 : 24,
      boldLeft: true,
      boldRight: true,
    );
    y += (total.big ? 10 : 4) * spacing * rowGap;
  }

  // Receipt.vue: socialLinks totals'dan keyin, barcode'dan OLDIN chiqadi —
  // har bir element ikonka + nom yonma-yon (`d-flex align-items-center`),
  // qatorga sig'masa keyingisiga o'tadi (`d-inline-block` oqimi).
  if (socialIcons != null && socialIcons.isNotEmpty) {
    y += _paintSocialIcons(canvas, y, socialIcons) + 12 * spacing;
  }

  return y;
}

/// `SocialLink`larni ikonka + nom yonma-yon (`d-flex align-items-center`),
/// qatorga sig'masa keyingisiga o'tadigan (`d-inline-block` oqimi) tarzda
/// `startY`dan boshlab chizadi. Qaytadigan qiymat — bloк egallagan balandlik.
double _paintSocialIcons(
  Canvas? canvas,
  double startY,
  List<(SocialLink, ui.Picture, Size)> socialIcons,
) {
  const iconSize = 24.0;
  const iconGap = 6.0; // Bootstrap `mr-1`
  const itemGap = 12.0; // Bootstrap `mr-2`
  const rowGap = 8.0;

  double x = 0;
  double y = startY;
  double rowHeight = 0;

  for (final (social, picture, size) in socialIcons) {
    final label = TextPainter(
      text: TextSpan(
        text: social.title,
        style: const TextStyle(color: Color(0xFF000000), fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final itemWidth = iconSize + iconGap + label.width;
    if (x > 0 && x + itemWidth > _printWidth) {
      y += rowHeight + rowGap;
      x = 0;
      rowHeight = 0;
    }

    if (canvas != null) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(iconSize / size.width, iconSize / size.height);
      canvas.drawPicture(picture);
      canvas.restore();
      picture.dispose();
      label.paint(
        canvas,
        Offset(x + iconSize + iconGap, y + (iconSize - label.height) / 2),
      );
    }

    rowHeight = [
      rowHeight,
      iconSize,
      label.height,
    ].reduce((a, b) => a > b ? a : b);
    x += itemWidth + itemGap;
  }

  return y + rowHeight - startY;
}

/// Oq fonli, berilgan balandlikdagi bo'sh canvas ustiga `draw` chizadi va
/// natijani `img.Image`ga aylantiradi. Kirill matn kerak bo'lgan har qanday
/// blok (asosiy kontent, footer) shu orqali rasm sifatida chiqariladi —
/// sabab: bu printerda ESC/POS matn rejimida kirill buziladi (`PLAN.md`,
/// Bosqich 5).
Future<img.Image> _rasterize(
  double height,
  void Function(Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _printWidth, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  draw(canvas);

  final picture = recorder.endRecording();
  final uiImage = await picture.toImage(_printWidth.ceil(), height.ceil());
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = byteData!.buffer.asUint8List();

  return img.Image.fromBytes(
    width: uiImage.width,
    height: uiImage.height,
    bytes: bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
}

Future<img.Image> renderReceiptTextImage(
  ReceiptData receipt, {
  ReceiptSettings? settings,
}) async {
  final socialIcons = receipt.socials.isNotEmpty
      ? await _loadSocialIcons(receipt.socials)
      : null;

  final totalHeight = _renderContent(
    null,
    receipt,
    settings: settings,
    socialIcons: socialIcons,
  );
  return _rasterize(
    totalHeight,
    (canvas) => _renderContent(
      canvas,
      receipt,
      settings: settings,
      socialIcons: socialIcons,
    ),
  );
}

/// Barcode'dan keyin chiqadigan chiziq + `texts.footer_notice` matni.
/// Matn bo'lmasa (`null`/bo'sh) `null` qaytadi — hech narsa chizilmaydi.
Future<img.Image?> renderFooterImage(ReceiptSettings? settings) async {
  final footerNotice = settings?.texts.footerNotice;
  if (footerNotice == null || footerNotice.isEmpty) return null;

  final isCompact = settings?.spacing == 'compact';
  final spacing = _spacingMultiplier(settings?.spacing ?? 'normal');
  final gap = 10 * spacing;
  // Receipt.vue `.thanks` klassidan: letter-spacing: 1px; padding-bottom: 5px.
  const bottomPadding = 5.0;

  final painter = TextPainter(
    text: TextSpan(
      text: footerNotice,
      style: TextStyle(
        color: const Color(0xFF000000),
        fontSize: 20,
        letterSpacing: 1,
        // Receipt.vue: `.receipt--spacing-compact .thanks { line-height: 16px }`
        // — ko'p qatorli (`\n`) footer matni compact holatda zichroq bo'lishi
        // kerak; normalda brauzer standart qator oralig'i ishlatiladi.
        height: isCompact ? 0.8 : null,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _printWidth);

  final totalHeight = gap + 2 + gap + painter.height + bottomPadding;

  return _rasterize(totalHeight, (canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, gap, _printWidth, 2),
      Paint()..color = const Color(0xFF000000),
    );
    painter.paint(
      canvas,
      Offset((_printWidth - painter.width) / 2, gap + 2 + gap),
    );
  });
}


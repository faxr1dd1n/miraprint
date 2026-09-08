import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../model/receipt/header_item.dart';
import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';

const double _printWidth = 576;

double _spacingMultiplier(String spacing) {
  switch (spacing) {
    case 'compact':
      return 0.6;
    case 'spacious':
      return 1.5;
    default:
      return 1.0;
  }
}

/// `key == "date_format"` header'ining qiymati serverdan tayyor matn
/// ("08.09.2026, 12:02:38", ya'ni "dd.MM.yyyy, HH:mm:ss") sifatida keladi —
/// shu matnni `layout.date_format`ga qarab qisqartiramiz (Receipt.vue'dagi
/// `moment(...)` formatlariga mos):
/// - 'date' -> faqat sana ("08.09.2026")
/// - 'short' -> sana va vaqt, vergul bilan, soniyasiz ("08.09.2026, 12:02")
/// - 'cashier' -> sana va vaqt, vergulsiz, probel bilan ("08.09.2026 12:02")
String _formatDateValue(String raw, String dateFormat) {
  final parts = raw.split(',');
  final datePart = parts.first.trim();
  if (dateFormat == 'date') return datePart;

  if (parts.length < 2) return raw;
  final timeSegments = parts[1].trim().split(':');
  final shortTime = timeSegments.length >= 2
      ? '${timeSegments[0]}:${timeSegments[1]}'
      : parts[1].trim();
  return dateFormat == 'cashier' ? '$datePart $shortTime' : '$datePart, $shortTime';
}

double _renderContent(
  Canvas? canvas,
  ReceiptData receipt, {
  ReceiptSettings? settings,
}) {
  double y = 0;
  final spacing = _spacingMultiplier(settings?.spacing ?? 'normal');
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

  HeaderItem? dateHeader;
  for (final header in receipt.headers) {
    if (header.key == 'date_format') {
      dateHeader = header;
      break;
    }
  }

  if (dateFormat == 'cashier' && dateHeader != null) {
    final painter = TextPainter(
      text: TextSpan(
        text: _formatDateValue(dateHeader.val, dateFormat),
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
    if (dateFormat == 'cashier' && header.key == 'date_format') continue;

    final displayVal = header.key == 'date_format'
        ? _formatDateValue(header.val, dateFormat)
        : header.val;

    if (spaceBetweenLayout) {
      y += paintRow(header.title, displayVal, fontSize: 24, boldLeft: true);
      y += 4 * spacing;
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
      y += painter.height + 4 * spacing;
    }
  }

  hr();

  for (final item in receipt.items) {
    final namePainter = TextPainter(
      text: TextSpan(
        text: item.name,
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth);
    if (canvas != null) namePainter.paint(canvas, Offset(0, y));
    y += namePainter.height + 6 * spacing;

    y += paintRow(
      '${item.qty}шт x ${item.price}',
      item.totalPrice,
      fontSize: 24,
      boldRight: true,
    );
    y += 4 * spacing;

    if (item.discountText != null && item.discountPrice != null) {
      y += paintRow(item.discountText!, item.discountPrice!, fontSize: 22);
      y += 4 * spacing;
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
    y += (total.big ? 10 : 4) * spacing;
  }

  return y;
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
}) {
  final totalHeight = _renderContent(null, receipt, settings: settings);
  return _rasterize(
    totalHeight,
    (canvas) => _renderContent(canvas, receipt, settings: settings),
  );
}

/// Barcode'dan keyin chiqadigan chiziq + `texts.footer_notice` matni.
/// Matn bo'lmasa (`null`/bo'sh) `null` qaytadi — hech narsa chizilmaydi.
Future<img.Image?> renderFooterImage(ReceiptSettings? settings) async {
  final footerNotice = settings?.texts.footerNotice;
  if (footerNotice == null || footerNotice.isEmpty) return null;

  final spacing = _spacingMultiplier(settings?.spacing ?? 'normal');
  final gap = 10 * spacing;
  // Receipt.vue `.thanks` klassidan: letter-spacing: 1px; padding-bottom: 5px.
  const bottomPadding = 5.0;

  final painter = TextPainter(
    text: TextSpan(
      text: footerNotice,
      style: const TextStyle(
        color: Color(0xFF000000),
        fontSize: 20,
        letterSpacing: 1,
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
    painter.paint(canvas, Offset((_printWidth - painter.width) / 2, gap + 2 + gap));
  });
}

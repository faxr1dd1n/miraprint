import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../model/receipt/receipt_data.dart';

const double _printWidth = 576;

double _renderContent(Canvas? canvas, ReceiptData receipt) {
  double y = 0;

  double paintRow(
    String left,
    String right, {
    required double fontSize,
    bool bold = false,
  }) {
    final style = TextStyle(
      color: const Color(0xFF000000),
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    final leftPainter = TextPainter(
      text: TextSpan(text: left, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth * 0.65);
    final rightPainter = TextPainter(
      text: TextSpan(text: right, style: style),
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
    y += before;
    canvas?.drawRect(
      Rect.fromLTWH(0, y, _printWidth, 2),
      Paint()..color = const Color(0xFF000000),
    );
    y += 2 + after;
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
    y += painter.height + 12;
  }

  for (final header in receipt.headers) {
    final painter = TextPainter(
      text: TextSpan(
        text: '${header.title}: ${header.val}',
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: 24,
          fontWeight: header.title == 'Компания'
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _printWidth);
    if (canvas != null) painter.paint(canvas, Offset(0, y));
    y += painter.height + 4;
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
    y += namePainter.height + 6;

    y += paintRow(
      '${item.qty}шт x ${item.price}',
      item.totalPrice,
      fontSize: 24,
    );
    y += 4;

    if (item.discountText != null && item.discountPrice != null) {
      y += paintRow(item.discountText!, item.discountPrice!, fontSize: 22);
      y += 4;
    }

    hr();
  }

  for (final total in receipt.totals) {
    y += paintRow(
      total.title,
      total.val,
      fontSize: total.big ? 32 : 24,
      bold: total.big,
    );
    y += total.big ? 10 : 4;
  }

  return y;
}

Future<img.Image> renderReceiptTextImage(ReceiptData receipt) async {
  final totalHeight = _renderContent(null, receipt);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _printWidth, totalHeight),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  _renderContent(canvas, receipt);

  final picture = recorder.endRecording();
  final uiImage = await picture.toImage(_printWidth.ceil(), totalHeight.ceil());
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

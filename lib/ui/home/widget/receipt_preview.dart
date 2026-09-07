import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';

import '../../../model/receipt/receipt_data.dart';

class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.receipt});

  final ReceiptData receipt;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: Colors.black,
  );
  static const _divider = Text(
    '--------------------------------',
    style: _mono,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (receipt.logo.isNotEmpty) ...[
            Center(
              child: Image.network(
                receipt.logo,
                height: 80,
                errorBuilder: (context, error, stackTrace) => const Text(
                  '(logo yuklanmadi)',
                  style: _mono,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (receipt.currentNumber.isNotEmpty)
            Center(
              child: Text(
                receipt.currentNumber,
                style: _mono.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          for (final header in receipt.headers)
            Text(
              '${header.title}: ${header.val}',
              style: _mono.copyWith(
                fontWeight: header.title == 'Компания'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          _divider,
          for (final item in receipt.items) ...[
            Text(
              item.name,
              style: _mono.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            _priceRow(
              '${item.qty}шт x ${item.price}',
              item.totalPrice,
              bold: true,
            ),
            if (item.discountText != null && item.discountPrice != null)
              _priceRow(item.discountText!, item.discountPrice!),
            _divider,
          ],
          for (final total in receipt.totals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _priceRow(
                total.title,
                total.val,
                bold: total.big,
                fontSize: total.big ? 16 : 13,
              ),
            ),
          if (receipt.barcode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  _BarcodeView(data: receipt.barcode),
                  const SizedBox(height: 4),
                  Text(receipt.barcode, style: _mono),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _priceRow(
    String left,
    String right, {
    bool bold = false,
    double fontSize = 13,
  }) {
    final style = _mono.copyWith(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: fontSize,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(right, style: style),
      ],
    );
  }
}

class _BarcodeView extends StatelessWidget {
  const _BarcodeView({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 60),
      painter: _BarcodePainter(data),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final barcode = bc.Barcode.code128();
    final paint = Paint()..color = Colors.black;

    for (final element in barcode.make(
      data,
      width: size.width,
      height: size.height,
    )) {
      if (element is bc.BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.data != data;
}

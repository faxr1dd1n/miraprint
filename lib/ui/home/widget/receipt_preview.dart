import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../model/receipt/header_item.dart';
import '../../../model/receipt/receipt_data.dart';
import '../../../model/receipt/receipt_date_format.dart';
import '../../../model/receipt/receipt_settings.dart';
import '../../../service/receipt/social_icon_assets.dart';

/// Ilova ichidagi "oxirgi chek" preview'i — `Receipt.vue` (sayt) bilan bir
/// xil stil (o'lcham, qalinlik, bo'shliq) beradigan, oddiy Flutter
/// widget'lardan tuzilgan versiya. Haqiqiy chop etish uchun ishlatiladigan
/// past darajali canvas kodi (`receipt_canvas_renderer.dart`) bilan
/// alohida — u yerda xuddi shu qoidalar `TextPainter`/`Canvas` orqali
/// qo'lda joylashtiriladi.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.receipt, this.settings});

  final ReceiptData receipt;
  final ReceiptSettings? settings;

  // message.txt'dagi aniq qoidalar: `.line-item{font-size:12px}` (header,
  // item nomi — `.item-name`ning o'zi alohida size bermaydi, shu 12pxni
  // meros oladi — qty/price/discount ham shu), `.total-xl{*{font-size:16px}}`,
  // `.receipt-status{font-size:20px}`, `.thanks{font-size:14px}`.
  static const _baseFontSize = 12.0;
  static const _totalBigFontSize = 16.0;
  static const _statusFontSize = 20.0;
  static const _footerFontSize = 14.0;

  static const _mono = TextStyle(fontFamily: 'monospace', color: Colors.black);

  bool get _isCompact => settings?.spacing == 'compact';

  /// Receipt.vue: `.receipt--spacing-compact .line-item *` va
  /// `.receipt-block--header > p` uchun `margin-bottom: 0` — bu qatorlar
  /// orasidagi bo'shliq compact'da proporsional emas, aniq nolga tushadi.
  double _zeroInCompact(double normal) => _isCompact ? 0 : normal;

  /// Receipt.vue: `hr`, `.receipt-header`, `.receipt-ordering-number`,
  /// `.receipt-status` kabi elementlarning margin'lari compact'da aniq
  /// yarmiga tushadi (`0.5rem -> 0.25rem`, `20px -> 10px` va h.k.).
  double _halveInCompact(double normal) => _isCompact ? normal / 2 : normal;

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);

    final dateFormat = settings?.layout.dateFormat ?? 'date';
    final isCenteredDate = isCenteredDateFormat(dateFormat);

    // `header.key == 'receipt_date'` — sana HEADER ELEMENTINING kaliti;
    // `layout.date_format` sozlamalardagi FORMAT nomi, ikkisi boshqa narsa.
    HeaderItem? statusHeader;
    HeaderItem? dateHeader;
    for (final header in receipt.headers) {
      if (header.key == 'status') statusHeader = header;
      if (header.key == 'receipt_date') dateHeader = header;
    }
    final remainingHeaders = receipt.headers.where((header) {
      if (header.key == 'status') return false;
      if (isCenteredDate && header.key == 'receipt_date') return false;
      return true;
    }).toList();

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
                errorBuilder: (context, error, stackTrace) => Text(
                  translate('receipt_preview.logo_not_loaded'),
                  style: _mono,
                ),
              ),
            ),
            SizedBox(height: _halveInCompact(8)),
          ],

          if (isCenteredDate && dateHeader != null) ...[
            Center(
              child: Text(
                formatReceiptDate(dateHeader.val, dateFormat),
                style: _mono.copyWith(fontSize: _baseFontSize),
              ),
            ),
            SizedBox(height: _halveInCompact(8)),
          ],

          // Receipt.vue: `.receipt-status` — ramka, katta harflar, qalin.
          if (statusHeader != null && statusHeader.val.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                statusHeader.val.toUpperCase(),
                textAlign: TextAlign.center,
                style: _mono.copyWith(
                  fontSize: _statusFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: _halveInCompact(12)),
          ],

          if (receipt.currentNumber.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(
                top: _halveInCompact(10),
                bottom: _halveInCompact(20),
              ),
              child: Center(
                child: Text(
                  receipt.currentNumber,
                  style: _mono.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          // Receipt.vue: `<strong>{{ title }}:</strong><span>{{ val }}</span>`
          // — har doim title qalin, val oddiy (avvalgi kodda faqat
          // "Компания" bo'lsa qalin bo'lardi, bu xato edi).
          for (final header in remainingHeaders) ...[
            _headerRow(header),
            SizedBox(height: _zeroInCompact(4)),
          ],

          _divider(),

          for (final item in receipt.items) ...[
            Text(
              item.name,
              style: _mono.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: _baseFontSize,
              ),
            ),
            SizedBox(height: _zeroInCompact(6)),
            _priceRow(
              '${item.qty}шт x ${item.price}',
              item.totalPrice,
              boldRight: true,
            ),
            SizedBox(height: _zeroInCompact(4)),
            if (item.discountText != null && item.discountPrice != null) ...[
              // Receipt.vue: `.item-discount` oddiy,
              // `.item-price-without-discount` qalin.
              _priceRow(
                item.discountText!,
                item.discountPrice!,
                boldRight: true,
              ),
              SizedBox(height: _zeroInCompact(4)),
            ],
            _divider(),
          ],

          // Receipt.vue: `.total { font-weight: bold }` — BARCHA totals
          // qatori qalin (avvalgi kodda faqat `big` bo'lsa qalin bo'lardi,
          // bu ham xato edi), `big` faqat shriftni kattalashtiradi.
          for (final total in receipt.totals) ...[
            _priceRow(
              total.title,
              total.val,
              boldLeft: true,
              boldRight: true,
              fontSize: total.big ? _totalBigFontSize : _baseFontSize,
            ),
            SizedBox(height: _zeroInCompact(total.big ? 10 : 4)),
          ],

          if (receipt.socials.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: _halveInCompact(8)),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final social in receipt.socials)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          socialIconAssetPath(social.icon),
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          social.title,
                          style: _mono.copyWith(fontSize: _baseFontSize),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],

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

          // Receipt.vue `.thanks`: markazlashgan, letter-spacing:1px,
          // compact'da qator oralig'i (`line-height:16px`) toraytiriladi.
          if ((settings?.texts.footerNotice ?? '').isNotEmpty) ...[
            SizedBox(height: _halveInCompact(10)),
            _divider(),
            SizedBox(height: _halveInCompact(10)),
            Text(
              settings!.texts.footerNotice!,
              textAlign: TextAlign.center,
              style: _mono.copyWith(
                fontSize: _footerFontSize,
                letterSpacing: 1,
                height: _isCompact ? 0.8 : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(HeaderItem header) {
    final titleStyle = _mono.copyWith(
      fontSize: _baseFontSize,
      fontWeight: FontWeight.bold,
    );
    final valueStyle = _mono.copyWith(fontSize: _baseFontSize);

    if (settings?.layout.fieldsLayout == 'space-between') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(header.title, style: titleStyle),
          Text(header.val, style: valueStyle),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${header.title}: ', style: titleStyle),
          TextSpan(text: header.val, style: valueStyle),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _halveInCompact(6)),
      child: const Text('--------------------------------', style: _mono),
    );
  }

  static Widget _priceRow(
    String left,
    String right, {
    bool boldLeft = false,
    bool boldRight = false,
    double fontSize = _baseFontSize,
  }) {
    TextStyle style(bool bold) => _mono.copyWith(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(left, style: style(boldLeft))),
        Text(right, style: style(boldRight)),
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

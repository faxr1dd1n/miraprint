import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../../model/receipt/header_item.dart';
import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_date_format.dart';
import '../../model/receipt/receipt_settings.dart';
import '../../model/receipt/social_link.dart';
import 'social_icon_assets.dart';

// message.txt'dagi aniq qoidalar — `receipt_preview.dart` bilan bir xil
// (Receipt.vue): header/item qatori/totals 12px, Итого 16px, status 20px,
// footer (`.thanks`) 14px.
const _baseFontSize = 12.0;
const _totalBigFontSize = 16.0;
const _statusFontSize = 20.0;
const _footerFontSize = 14.0;

/// Windows uchun: chekni PDF sifatida quradi, so'ng `Printing.directPrintPdf`
/// orqali OS print-spooleri/drayveriga yuboriladi (`PLAN.md`, Bosqich 12,
/// 2026-09-15 qayta ochilgan qism). `receipt_preview.dart` bilan bir xil
/// stil qoidalarini ishlatadi — faqat Flutter `Text`/`Row` o'rniga `pdf`
/// paketining declarative widget'lari orqali.
Future<Uint8List> buildReceiptPdf(
  ReceiptData receipt, {
  ReceiptSettings? settings,
}) async {
  final regularFont = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  final logoBytes = receipt.logo.isNotEmpty
      ? await _downloadBytes(receipt.logo)
      : null;

  final socialSvgs = <SocialLink, String>{};
  for (final social in receipt.socials) {
    socialSvgs[social] = await rootBundle.loadString(
      socialIconAssetPath(social.icon),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: _buildContent(receipt, settings, logoBytes, socialSvgs),
      ),
    ),
  );

  return doc.save();
}

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

List<pw.Widget> _buildContent(
  ReceiptData receipt,
  ReceiptSettings? settings,
  Uint8List? logoBytes,
  Map<SocialLink, String> socialSvgs,
) {
  final isCompact = settings?.spacing == 'compact';
  double zeroInCompact(double normal) => isCompact ? 0 : normal;
  double halveInCompact(double normal) => isCompact ? normal / 2 : normal;

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

  final widgets = <pw.Widget>[];

  if (logoBytes != null) {
    widgets
      ..add(pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), height: 60)))
      ..add(pw.SizedBox(height: halveInCompact(8)));
  }

  if (isCentered && dateHeader != null) {
    widgets
      ..add(
        pw.Center(
          child: pw.Text(
            formatReceiptDate(dateHeader.val, dateFormat),
            style: const pw.TextStyle(fontSize: _baseFontSize),
          ),
        ),
      )
      ..add(pw.SizedBox(height: halveInCompact(8)));
  }

  // Receipt.vue: `.receipt-status` — ramka, katta harflar, qalin.
  if (statusHeader != null && statusHeader.val.isNotEmpty) {
    widgets
      ..add(
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            statusHeader.val.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: _statusFontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      )
      ..add(pw.SizedBox(height: halveInCompact(12)));
  }

  if (receipt.currentNumber.isNotEmpty) {
    widgets.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          top: halveInCompact(10),
          bottom: halveInCompact(20),
        ),
        child: pw.Center(
          child: pw.Text(
            receipt.currentNumber,
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Receipt.vue: `<strong>{{ title }}:</strong><span>{{ val }}</span>`.
  for (final header in remainingHeaders) {
    widgets
      ..add(_headerRow(header, settings))
      ..add(pw.SizedBox(height: zeroInCompact(4)));
  }

  widgets.add(_divider(halveInCompact(6)));

  for (final item in receipt.items) {
    widgets
      ..add(
        pw.Text(
          item.name,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: _baseFontSize,
          ),
        ),
      )
      ..add(pw.SizedBox(height: zeroInCompact(6)))
      ..add(
        _priceRow(
          '${item.qty}шт x ${item.price}',
          item.totalPrice,
          boldRight: true,
        ),
      )
      ..add(pw.SizedBox(height: zeroInCompact(4)));

    if (item.discountText != null && item.discountPrice != null) {
      // Receipt.vue: `.item-discount` oddiy, `.item-price-without-discount`
      // qalin.
      widgets
        ..add(
          _priceRow(item.discountText!, item.discountPrice!, boldRight: true),
        )
        ..add(pw.SizedBox(height: zeroInCompact(4)));
    }

    widgets.add(_divider(halveInCompact(6)));
  }

  // Receipt.vue: `.total { font-weight: bold }` — BARCHA totals qatori
  // qalin, `big` faqat shriftni kattalashtiradi.
  for (final total in receipt.totals) {
    widgets
      ..add(
        _priceRow(
          total.title,
          total.val,
          boldLeft: true,
          boldRight: true,
          fontSize: total.big ? _totalBigFontSize : _baseFontSize,
        ),
      )
      ..add(pw.SizedBox(height: zeroInCompact(total.big ? 10 : 4)));
  }

  if (receipt.socials.isNotEmpty) {
    widgets.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(top: halveInCompact(8)),
        child: pw.Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final social in receipt.socials)
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (socialSvgs[social] != null)
                    pw.SvgImage(
                      svg: socialSvgs[social]!,
                      width: 12,
                      height: 12,
                    ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    social.title,
                    style: const pw.TextStyle(fontSize: _baseFontSize),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  if (receipt.barcode.isNotEmpty) {
    widgets
      ..add(pw.SizedBox(height: 12))
      ..add(
        pw.Center(
          child: pw.BarcodeWidget(
            data: receipt.barcode,
            barcode: pw.Barcode.code128(),
            drawText: true,
            width: 200,
            height: 60,
          ),
        ),
      );
  }

  // Receipt.vue `.thanks`: markazlashgan, letter-spacing:1px.
  final footerNotice = settings?.texts.footerNotice;
  if (footerNotice != null && footerNotice.isNotEmpty) {
    widgets
      ..add(pw.SizedBox(height: halveInCompact(10)))
      ..add(_divider(0))
      ..add(pw.SizedBox(height: halveInCompact(10)))
      ..add(
        pw.Text(
          footerNotice,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: _footerFontSize, letterSpacing: 1),
        ),
      );
  }

  return widgets;
}

pw.Widget _headerRow(HeaderItem header, ReceiptSettings? settings) {
  final titleStyle = pw.TextStyle(
    fontSize: _baseFontSize,
    fontWeight: pw.FontWeight.bold,
  );
  final valueStyle = pw.TextStyle(fontSize: _baseFontSize);

  if (settings?.layout.fieldsLayout == 'space-between') {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(header.title, style: titleStyle),
        pw.Text(header.val, style: valueStyle),
      ],
    );
  }

  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: '${header.title}: ', style: titleStyle),
        pw.TextSpan(text: header.val, style: valueStyle),
      ],
    ),
  );
}

pw.Widget _priceRow(
  String left,
  String right, {
  bool boldLeft = false,
  bool boldRight = false,
  double fontSize = _baseFontSize,
}) {
  pw.TextStyle style(bool bold) => pw.TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Flexible(child: pw.Text(left, style: style(boldLeft))),
      pw.Text(right, style: style(boldRight)),
    ],
  );
}

pw.Widget _divider(double verticalMargin) {
  return pw.Divider(
    height: verticalMargin * 2 + 1,
    thickness: 1,
    color: PdfColors.black,
  );
}

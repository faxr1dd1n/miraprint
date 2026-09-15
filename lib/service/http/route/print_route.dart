import 'dart:convert';
import 'dart:io';

import 'package:miraprint/model/printer/print_request.dart';
import 'package:miraprint/model/printer/print_response.dart';
import 'package:miraprint/service/printer/printer_connection.dart';
import 'package:miraprint/service/printer/windows_cut_sender.dart';
import 'package:miraprint/service/receipt/last_receipt_notifier.dart';
import 'package:miraprint/service/receipt/receipt_builder.dart';
import 'package:miraprint/service/receipt/receipt_pdf_builder.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shelf/shelf.dart';

Future<Response> handlePostPrint(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final printRequest = PrintRequest.fromJson(json);
    lastReceiptNotifier.value = LastReceipt(
      check: printRequest.check,
      settings: printRequest.receiptSettings,
    );

    await _sendToPrinter(printRequest);

    final response = PrintResponse(success: true, message: "Chek chop etildi");
    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    final response = PrintResponse(success: false, message: e.toString());
    return Response(
      400,
      body: jsonEncode(response.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Windows'da OS print-spooleri/drayveri orqali (PDF), boshqa
/// platformalarda (hozircha faqat macOS — dasturchi test muhiti) xom
/// ESC/POS bayt orqali chop etadi.
///
/// Sabab (`PLAN.md`, Bosqich 12, 2026-09-15): RAW bayt oqimida printer/USB
/// ulanishi hali "uyg'onmagan" paytda, reset'dan keyin eng birinchi
/// yuborilgan rasm tasodifiy buzilib qolishi mumkin edi — OS drayveri bu
/// vaqtlashuvni o'z ichida hal qiladi. Lekin bu qurilma uchun haqiqiy
/// drayver faqat Windows'da mavjud (macOS'da faqat generic/noto'g'ri
/// drayver bor edi — Bosqich 12'da tasdiqlangan), shuning uchun bu yo'l
/// faqat Windows'da ishlatiladi.
Future<void> _sendToPrinter(PrintRequest printRequest) async {
  if (Platform.isWindows) {
    final printers = await Printing.listPrinters();
    final printer = printers.firstWhere(
      (p) => p.name == printRequest.printer.name,
      orElse: () => throw Exception(
        'Printer OS drayver ro\'yxatida topilmadi: ${printRequest.printer.name}',
      ),
    );

    final pdfBytes = await buildReceiptPdf(
      printRequest.check,
      settings: printRequest.receiptSettings,
    );
    final success = await Printing.directPrintPdf(
      printer: printer,
      format: PdfPageFormat.roll80,
      onLayout: (_) async => pdfBytes,
    );
    if (!success) {
      throw Exception('Chop etib bo\'lmadi: ${printRequest.printer.name}');
    }
    await sendWindowsCutCommand(printRequest.printer.name);
    return;
  }

  final bytes = await buildReceiptBytes(
    printRequest.check,
    settings: printRequest.receiptSettings,
  );
  final connection = PrinterConnection.forPlatform(printRequest.printer.name);
  await connection.sendRaw(bytes);
}

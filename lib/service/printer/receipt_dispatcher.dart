import 'dart:io';

import 'package:printing/printing.dart';

import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';
import '../receipt/receipt_builder.dart';
import 'gdi_receipt_printer.dart';
import 'printer_connection.dart';
import 'windows_cut_sender.dart';

/// `print_route.dart` (HTTP) va `printer_section.dart` (UI test print)
/// bir xil chop etish yo'lidan foydalanishi uchun umumiy qilingan —
/// avval bu mantiq faqat HTTP marshrutida edi.
Future<void> sendReceiptToPrinter({
  required String printerName,
  required ReceiptData receipt,
  ReceiptSettings? settings,
}) async {
  if (Platform.isWindows) {
    final printers = await Printing.listPrinters();
    final printerExists = printers.any((p) => p.name == printerName);
    if (!printerExists) {
      throw Exception(
        'Printer OS drayver ro\'yxatida topilmadi: $printerName',
      );
    }

    await printReceiptViaGdi(
      printerName: printerName,
      receipt: receipt,
      settings: settings,
    );
    await sendWindowsCutCommand(printerName);
    return;
  }

  final bytes = await buildReceiptBytes(receipt, settings: settings);
  final connection = PrinterConnection.forPlatform(printerName);
  await connection.sendRaw(bytes);
}

import 'package:flutter/services.dart';

import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';
import '../receipt/receipt_gdi_blocks.dart';

const _channel = MethodChannel('miraprint/gdi_print');

/// Windows uchun: chekni PDF/PDFium orqali emas, to'g'ridan-to'g'ri GDI+
/// bilan printer drayveriga chizadi (`windows/runner/gdi_receipt_printer.cpp`)
/// — C# ilova ishlatgan `PrintDocument` yo'liga mos, xiralikning sababi
/// bo'lgan PDF rasterlash bosqichi butunlay chetlab o'tiladi.
Future<void> printReceiptViaGdi({
  required String printerName,
  required ReceiptData receipt,
  ReceiptSettings? settings,
  String documentName = 'Miraprint chek',
}) async {
  final payload = await buildReceiptGdiPayload(receipt, settings: settings);
  await _channel.invokeMethod<void>('printReceipt', {
    'printerName': printerName,
    'documentName': documentName,
    'contentWidthPt': payload['contentWidthPt'],
    'blocks': payload['blocks'],
  });
}

import 'printer_info.dart';
import '../receipt/receipt_data.dart';
import '../receipt/receipt_settings.dart';

class PrintRequest {
  const PrintRequest({
    required this.printer,
    required this.check,
    this.receiptSettings,
  });

  final PrinterInfo printer;
  final ReceiptData check;
  final ReceiptSettings? receiptSettings;

  factory PrintRequest.fromJson(Map<String, dynamic> json) {
    // Sayt "checkSettings" nomi bilan yuboradi; "receipt_settings" eski
    // nom sifatida orqaga moslik uchun saqlanadi.
    final settingsJson =
        json['checkSettings'] as Map<String, dynamic>? ??
        json['receipt_settings'] as Map<String, dynamic>?;

    return PrintRequest(
      printer: PrinterInfo.fromJson(
        json['printer'] as Map<String, dynamic>? ?? {},
      ),
      check: ReceiptData.fromJson(json['check'] as Map<String, dynamic>? ?? {}),
      receiptSettings: settingsJson != null
          ? ReceiptSettings.fromJson(settingsJson)
          : null,
    );
  }
}

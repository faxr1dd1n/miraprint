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
    return PrintRequest(
      printer: PrinterInfo.fromJson(
        json['printer'] as Map<String, dynamic>? ?? {},
      ),
      check: ReceiptData.fromJson(json['check'] as Map<String, dynamic>? ?? {}),
      receiptSettings: json['receipt_settings'] != null
          ? ReceiptSettings.fromJson(
              json['receipt_settings'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

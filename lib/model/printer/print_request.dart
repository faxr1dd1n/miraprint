import 'printer_info.dart';
import '../receipt/receipt_data.dart';

class PrintRequest {
  const PrintRequest({required this.printer, required this.check});

  final PrinterInfo printer;
  final ReceiptData check;

  factory PrintRequest.fromJson(Map<String, dynamic> json) {
    return PrintRequest(
      printer: PrinterInfo.fromJson(
        json['printer'] as Map<String, dynamic>? ?? {},
      ),
      check: ReceiptData.fromJson(json['check'] as Map<String, dynamic>? ?? {}),
    );
  }
}

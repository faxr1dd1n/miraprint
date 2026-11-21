import 'printer_info.dart';
import '../receipt/receipt_data.dart';
import '../receipt/receipt_settings.dart';

class PrintRequest {
  const PrintRequest({
    required this.printer,
    required this.check,
    required this.receiptSettings,
  });

  final PrinterInfo printer;
  final ReceiptData check;
  final ReceiptSettings receiptSettings;

  factory PrintRequest.fromJson(Map<String, dynamic> json) {
    // Chek mazmuni ham, sozlamalari ham faqat "check_settings" (yoki
    // "checkSettings") ichidan o'qiladi; `printer` alohida kalit.
    final settingsJson =
        (json['check_settings'] ?? json['checkSettings'])
            as Map<String, dynamic>?;
    if (settingsJson == null) {
      throw const FormatException('check_settings topilmadi');
    }
    return PrintRequest(
      printer: PrinterInfo.fromJson(
        json['printer'] as Map<String, dynamic>? ?? {},
      ),
      check: ReceiptData.fromJson(settingsJson),
      receiptSettings: ReceiptSettings.fromJson(settingsJson),
    );
  }
}

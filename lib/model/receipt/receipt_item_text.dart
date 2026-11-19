import 'receipt_item.dart';
import 'receipt_settings.dart';

/// Chekda chiqadigan mahsulot nomi: `show_product_numbers` yoqilgan bo'lsa
/// oldiga tartib raqami qo'yiladi ("1. Nom"), aks holda nomning o'zi.
String receiptItemName(ReceiptItem item, int index, ReceiptSettings? settings) {
  final numbered = settings?.layout.showProductNumbers ?? false;
  return numbered ? '${index + 1}. ${item.name}' : item.name;
}

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.totalPrice,
    this.discountText,
    this.discountPrice,
  });

  final String name;

  /// Miqdor: butun yoki kasr (masalan 7, 2.5, 0.25).
  final num qty;
  final String price;
  final String totalPrice;
  final String? discountText;
  final String? discountPrice;

  /// Chekda ko'rsatiladigan miqdor: butun bo'lsa "7", kasr bo'lsa "7.5"
  /// (ortiqcha nollarsiz, 3 xonagacha).
  String get qtyText {
    if (qty == qty.truncate()) return qty.truncate().toString();
    return qty.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Son, kasr son yoki matn ("2.5", "2,5") — hammasi qabul qilinadi.
  static num _parseQty(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
    return 0;
  }

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      qty: _parseQty(json['qty']),
      price: json['price'] as String? ?? '',
      totalPrice: json['total_price'] as String? ?? '',
      discountText: json['discount_text'] as String?,
      discountPrice: json['discount_price'] as String?,
    );
  }
}

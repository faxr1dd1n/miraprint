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
  final int qty;
  final String price;
  final String totalPrice;
  final String? discountText;
  final String? discountPrice;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      qty: json['qty'] as int? ?? 0,
      price: json['price'] as String? ?? '',
      totalPrice: json['total_price'] as String? ?? '',
      discountText: json['discount_text'] as String?,
      discountPrice: json['discount_price'] as String?,
    );
  }
}

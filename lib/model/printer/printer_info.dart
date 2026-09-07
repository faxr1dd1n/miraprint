class PrinterInfo {
  const PrinterInfo({
    required this.name,
    this.vendorId = '',
    this.productId = '',
    this.isDefault = false,
  });

  final String name;
  final String vendorId;
  final String productId;
  final bool isDefault;

  factory PrinterInfo.fromJson(Map<String, dynamic> json) {
    return PrinterInfo(
      name: json['name'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'vendorId': vendorId,
      'productId': productId,
      'isDefault': isDefault,
    };
  }
}

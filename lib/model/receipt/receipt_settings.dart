class ReceiptLayout {
  const ReceiptLayout({
    this.fieldsLayout = 'standard',
    this.dateFormat = 'date',
    this.showProductNumbers = false,
  });

  final String fieldsLayout;
  final String dateFormat;

  /// true bo'lsa, mahsulotlar nomi oldiga tartib raqami qo'yiladi ("1. Nom").
  final bool showProductNumbers;

  factory ReceiptLayout.fromJson(Map<String, dynamic> json) {
    return ReceiptLayout(
      fieldsLayout: json['fields_layout'] as String? ?? 'standard',
      dateFormat: json['date_format'] as String? ?? 'date',
      showProductNumbers: _asBool(json['show_product_numbers']),
    );
  }
}

bool _asBool(Object? v) =>
    v == true || v == 1 || (v is String && (v == 'true' || v == '1'));

class ReceiptTexts {
  const ReceiptTexts({this.footerNotice});

  final String? footerNotice;

  factory ReceiptTexts.fromJson(Map<String, dynamic> json) {
    return ReceiptTexts(footerNotice: json['footer_notice'] as String?);
  }
}

class ReceiptSettings {
  const ReceiptSettings({
    required this.spacing,
    required this.layout,
    required this.texts,
  });

  final String spacing;
  final ReceiptLayout layout;
  final ReceiptTexts texts;

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) {
    return ReceiptSettings(
      spacing: json['spacing'] as String? ?? 'normal',
      layout: ReceiptLayout.fromJson(
        json['layout'] as Map<String, dynamic>? ?? {},
      ),
      texts: ReceiptTexts.fromJson(
        json['texts'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

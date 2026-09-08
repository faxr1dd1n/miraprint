class ReceiptLayout {
  const ReceiptLayout({
    this.fieldsLayout = 'standard',
    this.dateFormat = 'date',
  });

  final String fieldsLayout;
  final String dateFormat;

  factory ReceiptLayout.fromJson(Map<String, dynamic> json) {
    return ReceiptLayout(
      fieldsLayout: json['fields_layout'] as String? ?? 'standard',
      dateFormat: json['date_format'] as String? ?? 'date',
    );
  }
}

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

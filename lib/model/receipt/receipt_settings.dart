/// `check_settings` ichidagi oformlenie sozlamalari (chek mazmuni
/// `ReceiptData`da, bir xil JSON'dan o'qiladi).
class ReceiptSettings {
  const ReceiptSettings({
    this.spacing = 'normal',
    this.fieldsLayout = 'standard',
    this.footerNoteText,
  });

  /// `normal` yoki `compact`.
  final String spacing;

  /// `standard` (nom va qiymat yonma-yon) yoki `space-between`.
  final String fieldsLayout;

  /// Chek tagidagi matn; kalit kelmasa/bo'sh bo'lsa chizilmaydi.
  final String? footerNoteText;

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) {
    final footer = (json['footer_note_text'] as String?)?.trim();
    return ReceiptSettings(
      spacing: json['spacing'] as String? ?? 'normal',
      fieldsLayout: json['fields_layout'] as String? ?? 'standard',
      footerNoteText: (footer == null || footer.isEmpty) ? null : footer,
    );
  }
}

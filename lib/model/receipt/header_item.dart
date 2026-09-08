class HeaderItem {
  const HeaderItem({this.key, required this.title, required this.val});

  /// Maxsus ishlov beriladigan elementni aniqlash uchun (masalan sana
  /// header'ida `key == "date"`). Boshqa headerlar uchun ahamiyati yo'q —
  /// ular kelgan tartibda, sozlanmagan holda chiziladi.
  final String? key;
  final String title;
  final String val;

  factory HeaderItem.fromJson(Map<String, dynamic> json) {
    return HeaderItem(
      key: json['key'] as String?,
      title: json['title'] as String? ?? '',
      val: json['val'] as String? ?? '',
    );
  }
}

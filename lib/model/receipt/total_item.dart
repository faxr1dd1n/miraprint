class TotalItem {
  const TotalItem({
    required this.title,
    required this.val,
    this.big = false,
    this.light = false,
  });

  final String title;
  final String val;
  final bool big;
  final bool light;

  factory TotalItem.fromJson(Map<String, dynamic> json) {
    return TotalItem(
      title: json['title'] as String? ?? '',
      val: json['val'] as String? ?? '',
      big: json['big'] as bool? ?? false,
      light: json['light'] as bool? ?? false,
    );
  }
}

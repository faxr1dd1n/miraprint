class HeaderItem {
  const HeaderItem({required this.title, required this.val});

  final String title;
  final String val;

  factory HeaderItem.fromJson(Map<String, dynamic> json) {
    return HeaderItem(
      title: json['title'] as String? ?? '',
      val: json['val'] as String? ?? '',
    );
  }
}

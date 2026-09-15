class SocialLink {
  const SocialLink({required this.title, required this.icon});

  final String title;

  /// Backenddan keladigan ikonka nomi (masalan `"telegram"`, `"youtube"`) —
  /// `assets/social_media/` papkasidagi mos SVG faylni tanlashda ishlatiladi
  /// (`receipt_canvas_renderer.dart`dagi `_socialIconAssets`ga qarang).
  final String icon;

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
    );
  }
}

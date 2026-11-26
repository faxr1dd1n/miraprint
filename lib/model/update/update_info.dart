class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
  });

  final String version;
  final String downloadUrl;

  /// O'rnatuvchining kutilgan SHA-256 hash'i (hex ko'rinishida). Yuklangan
  /// fayl ishga tushirilishidan oldin shu qiymat bilan solishtiriladi.
  final String sha256;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
    );
  }
}

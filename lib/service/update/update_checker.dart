import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/app_constants.dart';
import '../../core/app_version.dart';
import '../../model/update/update_info.dart';

/// `version.json` ikkala platforma uchun bitta faylda, alohida bo'limlarda
/// beriladi (Windows `.exe`, macOS `.dmg`/`.pkg` — fayl turi boshqa bo'lgani
/// uchun bitta umumiy `download_url` yetmaydi):
/// ```json
/// {"windows": {"version": "1.0.4", "download_url": "...exe"},
///  "macos":   {"version": "1.0.3", "download_url": "...dmg"}}
/// ```
Future<UpdateInfo?> checkForUpdate() async {
  final response = await http
      .get(Uri.parse('$kUpdateServerUrl/version.json'))
      .timeout(const Duration(seconds: 5));

  if (response.statusCode != 200) return null;

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final platformKey = Platform.isMacOS ? 'macos' : 'windows';
  final platformJson = json[platformKey] as Map<String, dynamic>?;
  if (platformJson == null) return null;

  final info = UpdateInfo.fromJson(platformJson);
  if (info.version.isEmpty || info.downloadUrl.isEmpty) return null;

  if (_isNewer(info.version, kAppVersion)) {
    return info;
  }
  return null;
}

bool _isNewer(String remote, String current) {
  final remoteParts = remote.split('.').map(int.parse).toList();
  final currentParts = current.split('.').map(int.parse).toList();

  for (var i = 0; i < remoteParts.length; i++) {
    final currentPart = i < currentParts.length ? currentParts[i] : 0;
    if (remoteParts[i] > currentPart) return true;
    if (remoteParts[i] < currentPart) return false;
  }
  return false;
}

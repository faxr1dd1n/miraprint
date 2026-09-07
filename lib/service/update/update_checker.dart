import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_constants.dart';
import '../../core/app_version.dart';
import '../../model/update/update_info.dart';

Future<UpdateInfo?> checkForUpdate() async {
  final response = await http
      .get(Uri.parse('$kUpdateServerUrl/version.json'))
      .timeout(const Duration(seconds: 5));

  if (response.statusCode != 200) return null;

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final info = UpdateInfo.fromJson(json);

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

import 'dart:io';

import 'package:http/http.dart' as http;

Future<String> downloadInstaller(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Yuklab olishda xato: ${response.statusCode}');
  }

  final fileName = url.split('/').last;
  final filePath = '${Directory.systemTemp.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(response.bodyBytes);

  return filePath;
}

Future<void> launchInstaller(String filePath) async {
  await Process.start(filePath, [], mode: ProcessStartMode.detached);
}

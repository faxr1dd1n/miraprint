import 'dart:io';

import 'package:printing/printing.dart';

Future<List<Printer>> listMacPrinters() async {
  final namesResult = await Process.run('lpstat', ['-e']);
  final names = (namesResult.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final defaultResult = await Process.run('lpstat', ['-d']);
  final defaultOutput = (defaultResult.stdout as String).trim();
  final defaultName = defaultOutput.contains(':')
      ? defaultOutput.split(':').last.trim()
      : '';

  final deviceUris = await _printerDeviceUris();
  final statuses = await _printerStatusesByUri();

  return names.map((name) {
    final uri = deviceUris[name];
    final status = uri != null ? statuses[uri] : null;
    final isAvailable = status == null || status != 'Offline';
    return Printer(
      url: name,
      name: name,
      isDefault: name == defaultName,
      isAvailable: isAvailable,
    );
  }).toList();
}

/// Har bir CUPS printer nomi uchun konfiguratsiya qilingan qurilma manzilini
/// (masalan `usb://Printer/POS-80?serial=...`) qaytaradi.
///
/// `lpstat -v` matni tizim tiliga qarab tarjima qilinadi (masalan ruscha
/// tizimda "device for X:" o'rniga "устройство для X:" chiqadi va bu
/// `LANG`/`LC_ALL` orqali ham inglizchaga majburlanmaydi), shuning uchun
/// tarjima matniga emas, faqat `nom: sxema://...` qolipiga tayanamiz.
Future<Map<String, String>> _printerDeviceUris() async {
  final result = await Process.run('lpstat', ['-v']);
  final output = result.stdout as String;
  final pattern = RegExp(r'([\w.\-]+):\s*(\w+://\S+)$');
  final uris = <String, String>{};
  for (final line in output.split('\n')) {
    final match = pattern.firstMatch(line.trim());
    if (match != null) {
      uris[match.group(1)!] = match.group(2)!;
    }
  }
  return uris;
}

/// `system_profiler SPPrintersDataType` orqali har bir qurilma manzilining
/// hozirgi holatini ("Idle", "Offline" va h.k.) o'qiydi — `lpinfo -v`'dan
/// farqli, tez ishlaydi va macOS'ning haqiqiy printer holatini aks ettiradi.
Future<Map<String, String>> _printerStatusesByUri() async {
  final result = await Process.run('system_profiler', [
    'SPPrintersDataType',
  ]);
  final output = result.stdout as String;

  final statuses = <String, String>{};
  String? currentUri;
  String? currentStatus;

  void flush() {
    if (currentUri != null && currentStatus != null) {
      statuses[currentUri!] = currentStatus!;
    }
    currentUri = null;
    currentStatus = null;
  }

  for (final rawLine in output.split('\n')) {
    final line = rawLine.trimRight();
    if (RegExp(r'^ {4}\S.*:$').hasMatch(line)) {
      flush();
      continue;
    }
    final trimmed = line.trimLeft();
    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;
    final key = trimmed.substring(0, colonIndex);
    final value = trimmed.substring(colonIndex + 1).trim();
    if (key == 'Status') {
      currentStatus = value;
    } else if (key == 'URI') {
      currentUri = value;
    }
  }
  flush();

  return statuses;
}

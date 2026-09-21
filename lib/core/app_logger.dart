import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

final Logger appLogger = Logger('Miraprint');

const int _maxLogBytes = 5 * 1024 * 1024;

File? _logFile;

/// Konsolga (dev) va fayl tizimiga (`<app support dir>/logs/miraprint.log`,
/// masalan macOS'da `~/Library/Application Support/Miraprint/logs/`) yozadi —
/// production'da do'kondagi muammoni masofadan diagnostika qilish uchun.
/// Fayl 5MB'dan oshsa, eskisi `.old.log`ga ko'chiriladi.
Future<void> setupLogging() async {
  Logger.root.level = Level.ALL;

  try {
    _logFile = await _prepareLogFile();
  } catch (_) {
    // Fayl tizimiga yozib bo'lmasa (huquq, disk va h.k.), faqat konsolga
    // chiqaramiz — loglash o'zi hech qachon ilovani cho'ktirmasligi kerak.
  }

  Logger.root.onRecord.listen((record) {
    final lines = record.message.split('\n');
    final consoleText = [
      '${_levelMarker(record.level)} ${_formatTime(record.time)}  '
          '${lines.first}',
      ...lines.skip(1),
    ].join('\n');
    // ignore: avoid_print
    print(consoleText);

    final fileLine = '${record.time} ${record.level.name}: ${record.message}';
    try {
      _logFile?.writeAsStringSync('$fileLine\n', mode: FileMode.append);
    } catch (_) {
      // xuddi shu sabab — fayl yozuvi xatosi ilovani to'xtatmasin.
    }
  });
}

String _formatTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
      '${three(time.millisecond)}';
}

String _levelMarker(Level level) {
  if (level >= Level.SEVERE) return '❌';
  if (level >= Level.WARNING) return '⚠️';
  return 'ℹ️';
}

Future<File> _prepareLogFile() async {
  final supportDir = await getApplicationSupportDirectory();
  final logsDir = Directory('${supportDir.path}/logs');
  await logsDir.create(recursive: true);

  final file = File('${logsDir.path}/miraprint.log');
  if (await file.exists() && await file.length() > _maxLogBytes) {
    final rotated = File('${logsDir.path}/miraprint.old.log');
    if (await rotated.exists()) await rotated.delete();
    await file.rename(rotated.path);
  }
  return file;
}

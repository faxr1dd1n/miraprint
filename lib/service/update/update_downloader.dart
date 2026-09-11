import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Yuklab olishni bekor qilish uchun. `cancel()` chaqirilgach, joriy
/// `downloadInstaller` chunk yozib bo'lgach to'xtaydi va yarim qolgan faylni
/// o'chiradi.
class UpdateCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class UpdateCancelledException implements Exception {
  @override
  String toString() => 'Yuklab olish bekor qilindi';
}

/// Installer'ni stream orqali yuklab oladi (butun faylni xotiraga
/// bufferlamaydi) va har chunk'da `onProgress(received, total)` chaqiradi —
/// `total` server `Content-Length` bermasa `0` bo'ladi (UI aniqmas
/// progress-bar ko'rsatishi kerak). Ulanish 15 soniya ichida boshlanmasa
/// yoki oqim 20 soniyadan ortiq to'xtab qolsa (stall), xato tashlaydi.
Future<String> downloadInstaller(
  String url, {
  void Function(int received, int total)? onProgress,
  UpdateCancelToken? cancelToken,
}) async {
  final client = http.Client();
  File? partialFile;
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Yuklab olishda xato: ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    final fileName = url.split('/').last;
    final dir = await _downloadDir();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    partialFile = file;
    final sink = file.openWrite();

    var received = 0;
    try {
      final stream = response.stream.timeout(
        const Duration(seconds: 20),
        onTimeout: (eventSink) {
          eventSink.addError(
            TimeoutException('Yuklab olish to\'xtab qoldi (tarmoq javob bermadi)'),
          );
        },
      );

      await for (final chunk in stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw UpdateCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    if (cancelToken?.isCancelled ?? false) {
      throw UpdateCancelledException();
    }

    return filePath;
  } catch (_) {
    // Yarim qolgan/buzuq faylni keyingi urinishga xalaqit bermasligi uchun
    // o'chiramiz.
    if (partialFile != null && await partialFile.exists()) {
      await partialFile.delete();
    }
    rethrow;
  } finally {
    client.close();
  }
}

Future<void> launchInstaller(String filePath) async {
  if (Platform.isMacOS) {
    // .dmg/.pkg'ni to'g'ridan-to'g'ri ishga tushirib bo'lmaydi. `open <fayl>`
    // diskni "jim" (Finder oynasisiz) mount qiladi va app sandbox `/Volumes`ni
    // ro'yxatlashga ham ruxsat bermaydi — shu sabab avtomatik mount/topish
    // o'rniga faylni **Finder'da ko'rsatamiz** (xuddi brauzerdan yuklab
    // olingandek): foydalanuvchi uni ikki marta bosib o'zi ochadi/o'rnatadi.
    final result = await Process.run('open', ['-R', filePath]);
    if (result.exitCode != 0) {
      throw Exception(
        'Faylni ko\'rsatib bo\'lmadi (open -R, kod ${result.exitCode}): ${result.stderr}',
      );
    }
    return;
  }
  await Process.start(filePath, [], mode: ProcessStartMode.detached);
}

/// macOS'da Downloads papkasiga (Finder'da tabiiy ko'rinadigan joy —
/// `com.apple.security.files.downloads.read-write` entitlement kerak),
/// boshqa platformalarda tizim temp papkasiga yuklaydi.
Future<Directory> _downloadDir() async {
  if (Platform.isMacOS) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  }
  return Directory.systemTemp;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_constants.dart';
import '../../core/app_logger.dart';
import '../../model/arca/terminal_target.dart';
import 'arca_client.dart';

/// ARCA bilan `wss://<ip>:<port>` orqali gaplashadi.
///
/// Sertifikat: terminal odatda o'zi imzolagan sertifikat ishlatadi va IP
/// bo'yicha ulanamiz, shuning uchun faqat aynan shu `ip:port` uchun
/// sertifikat xatosi e'tiborsiz qoldiriladi (boshqa hech qaysi manzil uchun emas).
/// TODO: sertifikatni ishonchli tekshirish usuli alohida hal qilinadi.
class WssArcaClient implements ArcaClient {
  Future<WebSocket> _connect(TerminalTarget t, Duration timeout) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) =>
          host == t.ip && port == t.port;
    try {
      return await WebSocket.connect(
        'wss://${t.ip}:${t.port}',
        customClient: client,
      ).timeout(timeout);
    } on TimeoutException {
      client.close(force: true);
      throw TerminalUnreachableException('Ulanish vaqti tugadi');
    } on Exception catch (e) {
      client.close(force: true);
      throw TerminalUnreachableException(e.toString());
    }
  }

  @override
  Future<bool> check(TerminalTarget target) async {
    try {
      final ws = await _connect(target, kArcaCheckTimeout);
      await ws.close();
      return true;
    } on TerminalUnreachableException catch (e) {
      appLogger.warning(
        'check: ${target.ip}:${target.port} ga ulanib bo\'lmadi: ${e.reason}',
      );
      return false;
    }
  }

  @override
  Future<String> execute(
    TerminalTarget target,
    Map<String, dynamic> request,
    Duration timeout,
  ) async {
    final ws = await _connect(target, const Duration(seconds: 10));
    final id = request['id'];
    final completer = Completer<String>();

    final sub = ws.listen(
      (data) {
        final text = data is String ? data : utf8.decode(data as List<int>);
        if (!completer.isCompleted && _isReplyTo(id, text)) {
          completer.complete(text);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(TerminalUnreachableException(e.toString()));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            TerminalUnreachableException('Terminal ulanishni yopdi'),
          );
        }
      },
    );

    try {
      ws.add(jsonEncode(request));
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TerminalTimeoutException(),
      );
    } finally {
      await sub.cancel();
      await ws.close();
    }
  }

  /// Boshqa so'rovga tegishli xabarlarni o'tkazib yuboradi.
  bool _isReplyTo(Object? id, String text) {
    if (id == null) return true;
    try {
      final json = jsonDecode(text);
      if (json is Map && json['requestId'] != null) {
        return json['requestId'] == id;
      }
    } catch (_) {}
    return true;
  }
}

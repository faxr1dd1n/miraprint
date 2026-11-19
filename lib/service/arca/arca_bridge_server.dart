import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/app_constants.dart';
import '../../core/app_logger.dart';
import '../../model/arca/terminal_target.dart';
import 'certificate_service.dart';
import 'arca_client.dart';

/// `https://127.0.0.1:17865` — Mirasoft sayti shu serverga `POST` yuboradi.
///
/// Ikki xil so'rov (`type`):
///  * `check`   — terminalga ulanish mumkinmi? -> `check_result`
///  * `execute` — `request` terminalga (ARCA, wss) yuboriladi, terminal
///                javobi o'zgarishsiz HTTP 200 JSON qilib qaytariladi.
///
/// MAXFIYLIK: so'rov/javob tanasi (login, PIN, chek) hech qachon logga yozilmaydi.
class ArcaBridgeServer {
  ArcaBridgeServer({
    this.useTls = kArcaUseTls,
    this.port = kArcaPort,
    ArcaClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? ArcaClient.wss;

  final bool useTls;
  final int port;
  final ArcaClient Function() _clientFactory;
  HttpServer? _server;
  bool _stoppingManually = false;

  /// Server o'zi (stop() chaqirilmasdan) to'xtab qolganda chaqiriladi.
  void Function()? onStopped;

  /// Qabul qilingan so'rovlar soni (UI uchun).
  final ValueNotifier<int> requestCount = ValueNotifier(0);

  /// Oxirgi marta sayt murojaat qilgan vaqt (UI uchun).
  final ValueNotifier<DateTime?> lastSeen = ValueNotifier(null);

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final HttpServer server;
    if (useTls) {
      final files = await CertificateService.ensure();
      final context = SecurityContext()
        ..useCertificateChain(files.cert.path)
        ..usePrivateKey(files.key.path);
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        port,
        context,
      );
    } else {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    }
    _server = server;
    appLogger.info(
      'Server ${useTls ? 'https' : 'http'}://127.0.0.1:$port da ishga tushdi',
    );
    server.listen(
      _onRequest,
      onError: (e) => appLogger.warning('Server: $e'), // masalan TLS handshake
      onDone: () {
        if (_stoppingManually) return;
        appLogger.severe('Arca serveri kutilmaganda to\'xtadi');
        _server = null;
        onStopped?.call();
      },
    );
  }

  Future<void> stop() async {
    _stoppingManually = true;
    await _server?.close(force: true);
    _server = null;
  }

  // ---------------------------------------------------------------- HTTP

  Future<void> _onRequest(HttpRequest request) async {
    final response = request.response;
    try {
      final origin = request.headers.value('origin');
      if (!_isOriginAllowed(origin)) {
        appLogger.warning('Ruxsat etilmagan origin rad etildi: $origin');
        response.statusCode = HttpStatus.forbidden;
        await response.close();
        return;
      }
      if (origin != null) {
        response.headers
          ..set('Access-Control-Allow-Origin', origin)
          ..set('Vary', 'Origin')
          ..set('Access-Control-Allow-Methods', 'POST, OPTIONS')
          ..set('Access-Control-Allow-Headers', 'Content-Type')
          // Chrome: ommaviy saytdan lokal manzilga (Private Network Access).
          ..set('Access-Control-Allow-Private-Network', 'true')
          ..set('Access-Control-Max-Age', '600');
      }

      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }
      if (request.method != 'POST') {
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
        return;
      }

      lastSeen.value = DateTime.now();
      requestCount.value++;
      final body = await utf8.decoder.bind(request).join();
      final result = await _handle(body);
      if (kArcaLogBodies) {
        appLogger.info(
          '[${result.status}] so\'rov: $body\n  javob: ${result.body}',
        );
      }

      response.statusCode = result.status;
      response.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      response.write(result.body);
    } catch (e) {
      appLogger.severe('So\'rovni qayta ishlashda xato: ${e.runtimeType}');
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  /// `https://*.mirasoft.io` (va `mirasoft.io`) hamda lokal ishlab chiqish
  /// uchun `localhost` / `127.0.0.1` (har qanday port).
  @visibleForTesting
  static bool isOriginAllowed(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') return true;
    final isMirasoft =
        host == kArcaAllowedOriginDomain ||
        host.endsWith('.$kArcaAllowedOriginDomain');
    return uri.scheme == 'https' && isMirasoft;
  }

  bool _isOriginAllowed(String? origin) {
    if (origin == null) return true; // brauzer bo'lmagan mijoz
    return !kArcaRestrictOrigins || isOriginAllowed(origin);
  }

  // ------------------------------------------------------------- Logic

  Future<({int status, String body})> _handle(String body) async {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return _error(
        code: 'BAD_REQUEST',
        message: 'JSON noto\'g\'ri',
        status: 400,
      );
    }
    if (json is! Map) {
      return _error(
        code: 'BAD_REQUEST',
        message: 'JSON obyekt kerak',
        status: 400,
      );
    }

    final target = TerminalTarget.tryParse(json['terminal']);
    final request = json['request'];
    // `type` ixtiyoriy: yuborilmasa request bor -> execute, yo'q -> check.
    final type = json['type'] ?? (request is Map ? 'execute' : 'check');
    final requestId = request is Map ? request['id'] : null;
    final command = request is Map ? request['command'] : null;

    if (target == null) {
      return _error(
        code: 'BAD_REQUEST',
        message: 'terminal.ip va terminal.port kerak',
        requestId: requestId,
        command: command,
        status: 400,
      );
    }

    final stopwatch = Stopwatch()..start();
    final client = _clientFactory();

    switch (type) {
      case 'check':
        final ok = await client.check(target);
        _record(
          'check',
          target,
          stopwatch,
          errorCode: ok ? null : 'UNREACHABLE',
        );
        return (
          status: 200,
          body: jsonEncode({'type': 'check_result', 'success': ok}),
        );

      case 'execute':
        if (request is! Map) {
          return _error(
            code: 'BAD_REQUEST',
            message: 'request kerak',
            status: 400,
          );
        }
        String? errorCode;
        try {
          // Terminalga FAQAT `request` ketadi, javob o'zgarishsiz qaytadi.
          final reply = await client.execute(
            target,
            Map<String, dynamic>.from(request),
            kArcaExecuteTimeout,
          );
          _record(
            'execute',
            target,
            stopwatch,
            command: command,
            requestId: requestId,
          );
          return (status: 200, body: reply);
        } on TerminalTimeoutException {
          errorCode = 'TERMINAL_TIMEOUT';
        } on TerminalUnreachableException {
          errorCode = 'TERMINAL_UNREACHABLE';
        }
        _record(
          'execute',
          target,
          stopwatch,
          command: command,
          requestId: requestId,
          errorCode: errorCode,
        );
        return _error(
          code: errorCode,
          message: errorCode == 'TERMINAL_TIMEOUT'
              ? 'Terminal javob bermadi. Natijani terminaldan tekshiring'
              : 'Terminalga ulanib bo\'lmadi',
          requestId: requestId,
          command: command,
        );

      default:
        return _error(
          code: 'BAD_REQUEST',
          message: 'Noma\'lum type',
          requestId: requestId,
          command: command,
          status: 400,
        );
    }
  }

  ({int status, String body}) _error({
    required String code,
    required String message,
    Object? requestId,
    Object? command,
    int status = 200,
  }) {
    return (
      status: status,
      body: jsonEncode({
        'type': 'bridge_error',
        'requestId': requestId,
        'command': command,
        'code': code,
        'message': message,
      }),
    );
  }

  void _record(
    String type,
    TerminalTarget target,
    Stopwatch stopwatch, {
    Object? command,
    Object? requestId,
    String? errorCode,
  }) {
    appLogger.info(
      '[$type] $target ${command ?? ''} ${requestId ?? ''} '
      '${errorCode ?? 'OK'} ${stopwatch.elapsedMilliseconds}ms',
    );
  }
}

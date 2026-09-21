import 'dart:io';

import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/service/http/route/print_route.dart';
import 'package:miraprint/service/http/route/printers_route.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/app_constants.dart';

const Map<String, String> corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': '*',
};

Middleware get corsMiddleware => (Handler innerHandler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: corsHeaders);
    }
    final response = await innerHandler(request);
    return response.change(headers: corsHeaders);
  };
};

/// Har bir so'rovni (`GET /printers`, `POST /print`) — so'rov tanasi, javob
/// tanasi, holat kodi va sarflangan vaqt bilan birga — bitta tartibli blok
/// sifatida `appLogger` orqali konsolga (va log faylga) yozadi. So'rov/javob
/// tanasi stream sifatida faqat bir marta o'qiladi — shuning uchun uni
/// o'qib olib, xuddi shu matn bilan yangi `Request`/`Response` qaytaramiz
/// (aks holda haqiqiy so'rov/javob bo'sh ketardi).
Middleware get requestLoggingMiddleware => (Handler innerHandler) {
  return (Request request) async {
    final stopwatch = Stopwatch()..start();
    final requestBody = await request.readAsString();
    final forwardedRequest = request.change(body: requestBody);

    try {
      final response = await innerHandler(forwardedRequest);
      final responseBody = await response.readAsString();
      stopwatch.stop();

      final isOk = response.statusCode < 400;
      final statusLabel = isOk
          ? '${response.statusCode} OK'
          : '⚠️ ${response.statusCode} XATO';

      appLogger.info(
        [
          '[HTTP] ${request.method} ${request.requestedUri.path} -> '
              '$statusLabel • ${stopwatch.elapsedMilliseconds}ms',
          if (requestBody.isNotEmpty) '  so\'rov: $requestBody',
          '  javob: $responseBody',
        ].join('\n'),
      );
      return response.change(body: responseBody);
    } catch (e) {
      stopwatch.stop();
      appLogger.severe(
        '[HTTP] ${request.method} ${request.requestedUri.path} -> '
        '❌ ISTISNO • ${stopwatch.elapsedMilliseconds}ms\n'
        '  xato: $e',
      );
      rethrow;
    }
  };
};

class HttpService {
  HttpServer? server;

  bool get isRunning => server != null;

  Future<void> start() async {
    if (server != null) return;
    final router = Router();
    router.get('/printers', handleGetPrinters);
    router.post('/print', handlePostPrint);
    final handler = const Pipeline()
        .addMiddleware(corsMiddleware)
        .addMiddleware(requestLoggingMiddleware)
        .addHandler(router.call);
    server = await serve(handler, InternetAddress.loopbackIPv4, kHttpPort);
  }
}

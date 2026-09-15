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

/// Har bir so'rovni (`GET /printers`, `POST /print`) va **javob tanasini**
/// (biz sayt`ga aynan nima jo'natayotganimizni) `appLogger` orqali
/// konsolga (va log faylga) yozadi. Javob tanasi stream sifatida faqat
/// bir marta o'qiladi — shuning uchun uni o'qib olib, xuddi shu matn bilan
/// yangi `Response` qaytaramiz (aks holda haqiqiy javob bo'sh ketardi).
Middleware get requestLoggingMiddleware => (Handler innerHandler) {
  return (Request request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await innerHandler(request);
      final body = await response.readAsString();
      stopwatch.stop();
      final level = response.statusCode < 400 ? 'OK' : 'XATO';
      appLogger.info(
        '${request.method} ${request.requestedUri.path} -> '
        '$level (${response.statusCode}), ${stopwatch.elapsedMilliseconds}ms\n'
        '  Javob: $body',
      );
      return response.change(body: body);
    } catch (e) {
      stopwatch.stop();
      appLogger.severe(
        '${request.method} ${request.requestedUri.path} -> '
        'ISTISNO: $e, ${stopwatch.elapsedMilliseconds}ms',
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

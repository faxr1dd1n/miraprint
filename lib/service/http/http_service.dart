import 'dart:io';

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
        .addHandler(router.call);
    server = await serve(handler, InternetAddress.loopbackIPv4, kHttpPort);
  }
}

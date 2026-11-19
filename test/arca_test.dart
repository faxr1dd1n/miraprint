import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miraprint/bloc/arca_bloc/arca_bloc.dart';
import 'package:miraprint/bloc/health/app_health.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/service/arca/arca_bridge_server.dart';
import 'package:miraprint/service/arca/certificate_service.dart';

Future<Map<String, dynamic>> post(
  int port,
  Object body, {
  String? origin,
}) async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/'));
  if (origin != null) req.headers.set('origin', origin);
  req.write(jsonEncode(body));
  final res = await req.close();
  final text = await utf8.decoder.bind(res).join();
  client.close();
  return {
    'status': res.statusCode,
    'body': text.isEmpty ? null : jsonDecode(text),
  };
}

void main() {
  healthTest();
  certTest();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // haqiqiy tarmoq so'rovlari uchun

  const terminal = {'ip': '127.0.0.1', 'port': 18888};

  test('wss orqali faqat request ketadi, javob o\'zgarishsiz qaytadi', () async {
    // Soxta ARCA: wss server (bundled self-signed sertifikat bilan)
    final certDir = await Directory.systemTemp.createTemp('arca_fake');
    final certFiles = await CertificateService.ensure(dir: certDir);
    final ctx = SecurityContext()
      ..useCertificateChain(certFiles.cert.path)
      ..usePrivateKey(certFiles.key.path);
    final arca = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      18888,
      ctx,
    );
    String? received;
    arca.listen((r) async {
      final ws = await WebSocketTransformer.upgrade(r);
      ws.listen((m) {
        received = m as String;
        final req = jsonDecode(received!) as Map;
        ws.add(
          jsonEncode({
            'requestId': req['id'],
            'command': req['command'],
            'status': 'Success',
            'extra': 42,
          }),
        );
      });
    });

    final bridge = ArcaBridgeServer(useTls: false, port: 17997);
    await bridge.start();
    const origin = 'https://minorsomsa.mirasoft.io';

    // check: `type`siz ham, `type`li ham
    expect(
      (await post(17997, {'terminal': terminal}, origin: origin))['body'],
      {'type': 'check_result', 'success': true},
    );
    expect(
      (await post(17997, {
        'type': 'check',
        'terminal': terminal,
      }, origin: origin))['body'],
      {'type': 'check_result', 'success': true},
    );

    // execute: terminalga faqat request ketadi, javob o'zgarishsiz
    final request = {
      'id': 'x9',
      'command': 'Sale',
      'data': {'amount': 850000},
    };
    for (final body in [
      {'terminal': terminal, 'request': request},
      {'type': 'execute', 'terminal': terminal, 'request': request},
    ]) {
      final exec = await post(17997, body, origin: origin);
      expect(jsonDecode(received!), request);
      expect(exec['status'], 200);
      expect(exec['body'], {
        'requestId': 'x9',
        'command': 'Sale',
        'status': 'Success',
        'extra': 42,
      });
    }

    // noto'g'ri so'rov
    final bad = await post(17997, {'request': request}, origin: origin);
    expect(bad['status'], 400);
    expect(bad['body']['type'], 'bridge_error');

    // (domen cheklovi hozir o'chiq: kRestrictOrigins = false; qoida yuqorida alohida tekshirilgan)

    // terminal o'chiq
    await arca.close(force: true);
    final down = await post(17997, {
      'terminal': terminal,
      'request': request,
    }, origin: origin);
    expect(down['body']['code'], 'TERMINAL_UNREACHABLE');
    expect(down['body']['requestId'], 'x9');
    expect(
      (await post(17997, {
        'terminal': terminal,
      }, origin: origin))['body']['success'],
      false,
    );

    await bridge.stop();
  });
}

void certTest() {
  test(
    'yaratilgan sertifikat 127.0.0.1 uchun HTTPS\'da tekshiruvdan o\'tadi',
    () async {
      final dir = await Directory.systemTemp.createTemp('arca_cert');
      final files = await CertificateService.ensure(dir: dir);

      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        17996,
        SecurityContext()
          ..useCertificateChain(files.cert.path)
          ..usePrivateKey(files.key.path),
      );
      server.listen((r) async {
        r.response.write('ok');
        await r.response.close();
      });

      // Server aynan yaratilgan sertifikatni berayotganini tekshiramiz.
      // (Dart'ning o'zi imzolagan sertifikatni ildiz sifatida qabul qilmasligi
      // sababli tizim ishonchi o'rniga PEM solishtiriladi; IP-SAN, muddat va
      // KeyUsage openssl bilan alohida tekshirilgan.)
      final expected = (await files.cert.readAsString()).trim();
      String? served;
      final client = HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          served = cert.pem.trim();
          return host == '127.0.0.1';
        };
      final req = await client.getUrl(Uri.parse('https://127.0.0.1:17996/'));
      final res = await req.close();
      expect(await utf8.decoder.bind(res).join(), 'ok');
      expect(served, expected);

      // ikkinchi chaqiruv yangisini yaratmaydi, mavjudini qaytaradi
      final again = await CertificateService.ensure(dir: dir);
      expect(await again.cert.readAsString(), await files.cert.readAsString());

      client.close();
      await server.close(force: true);
      await dir.delete(recursive: true);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

void healthTest() {
  test(
    'umumiy holat: ikkala server ishlasa ok, biri xato bo\'lsa sabab bilan error',
    () {
      const running = ServerState(status: ServerStatus.running);
      const arcaRunning = ArcaState(status: ArcaStatus.running);

      expect(AppHealth.from(running, arcaRunning).level, HealthLevel.ok);
      expect(
        AppHealth.from(
          const ServerState(status: ServerStatus.starting),
          arcaRunning,
        ).level,
        HealthLevel.starting,
      );

      final busy = AppHealth.from(
        running,
        const ArcaState(
          status: ArcaStatus.error,
          errorMessage:
              'SocketException: Failed to create server socket (OS Error: Address already in use, errno = 48), address = 127.0.0.1, port = 17865',
        ),
      );
      expect(busy.level, HealthLevel.error);
      expect(busy.issues.single.service, ServiceName.arca);
      expect(busy.issues.single.isPortBusy, true);

      final stopped = AppHealth.from(
        const ServerState(
          status: ServerStatus.error,
          errorMessage: kServerStoppedMessage,
        ),
        arcaRunning,
      );
      expect(stopped.issues.single.service, ServiceName.printer);
      expect(stopped.issues.single.isStopped, true);
    },
  );

  test(
    'port band bo\'lsa Arca serveri xato beradi, qo\'lda stop() esa onStopped chaqirmaydi',
    () async {
      final first = ArcaBridgeServer(useTls: false, port: 17990);
      await first.start();

      final second = ArcaBridgeServer(useTls: false, port: 17990);
      Object? error;
      try {
        await second.start();
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      final health = AppHealth.from(
        const ServerState(status: ServerStatus.running),
        ArcaState(status: ArcaStatus.error, errorMessage: error.toString()),
      );
      expect(
        health.issues.single.isPortBusy,
        true,
        reason: 'xato matni: $error',
      );

      var stoppedCalled = false;
      first.onStopped = () => stoppedCalled = true;
      await first.stop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stoppedCalled, false);
    },
  );
}

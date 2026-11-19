import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:basic_utils/basic_utils.dart' show CryptoUtils;
import 'package:pointycastle/export.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_logger.dart';

typedef CertFiles = ({File cert, File key});

/// `https://127.0.0.1` uchun shu kompyuterga xos o'zi imzolagan sertifikat.
///
/// Sertifikat har bir kompyuterda alohida yaratiladi (private key ilova ichida
/// emas). Windows'da installer `--generate-cert <papka>` bilan yaratib, uni
/// "Trusted Root"ga o'rnatadi; ilova keyin shu fayllarni o'qiydi.
class CertificateService {
  static const _certName = 'localhost.crt';
  static const _keyName = 'localhost.key';

  /// Ilova ishlayotganda sertifikat qidiriladigan asosiy papka.
  /// Windows: `%PROGRAMDATA%\MirasoftArca\cert` (installer shu yerga yaratadi).
  static Future<Directory> defaultDir() async {
    final programData = Platform.environment['PROGRAMDATA'];
    if (Platform.isWindows && programData != null) {
      return Directory('$programData\\MirasoftArca\\cert');
    }
    return _fallbackDir();
  }

  static Future<Directory> _fallbackDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/cert');
  }

  /// Sertifikat mavjud bo'lsa o'shani qaytaradi, yo'q bo'lsa yaratadi.
  /// [dir] berilmasa [defaultDir] ishlatiladi; unga yozib bo'lmasa (huquq),
  /// foydalanuvchi papkasiga yoziladi.
  static Future<CertFiles> ensure({Directory? dir}) async {
    final primary = dir ?? await defaultDir();
    final existing = _filesIn(primary);
    if (existing != null) return existing;

    try {
      return await _generateInto(primary, trustForUser: dir == null);
    } on FileSystemException catch (e) {
      appLogger.warning(
        'Sertifikat papkasiga yozib bo\'lmadi (${e.path}): '
        '${e.osError?.message}; foydalanuvchi papkasi ishlatiladi',
      );
      final fallback = await _fallbackDir();
      return _filesIn(fallback) ??
          await _generateInto(fallback, trustForUser: true);
    }
  }

  static CertFiles? _filesIn(Directory dir) {
    final cert = File('${dir.path}${Platform.pathSeparator}$_certName');
    final key = File('${dir.path}${Platform.pathSeparator}$_keyName');
    return cert.existsSync() && key.existsSync()
        ? (cert: cert, key: key)
        : null;
  }

  static Future<CertFiles> _generateInto(
    Directory dir, {
    required bool trustForUser,
  }) async {
    appLogger.info('Yangi sertifikat yaratilmoqda: ${dir.path}');
    // RSA kalit yaratish bir necha soniya olishi mumkin — UI qotmasligi uchun isolate.
    final pems = await Isolate.run(generatePems);
    await dir.create(recursive: true);
    final cert = File('${dir.path}${Platform.pathSeparator}$_certName');
    final key = File('${dir.path}${Platform.pathSeparator}$_keyName');
    await key.writeAsString(pems.key);
    await cert.writeAsString(pems.cert);

    if (trustForUser) await _tryTrustForCurrentUser(cert);
    return (cert: cert, key: key);
  }

  /// `127.0.0.1` (IP) va `localhost` (DNS) uchun 10 yillik sertifikat (PEM).
  ///
  /// X.509 tuzilmasi qo'lda yig'iladi: `basic_utils` generatori IP manzilni
  /// DNS sifatida yozadi (Chrome IP-SAN talab qiladi) va BoringSSL qabul
  /// qilmaydigan KeyUsage hosil qiladi.
  static ({String cert, String key}) generatePems() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final priv = pair.privateKey as RSAPrivateKey;
    final pub = pair.publicKey as RSAPublicKey;

    ASN1Object ctx(int tag, List<int> bytes) =>
        ASN1Object.preEncoded(tag, Uint8List.fromList(bytes));
    ASN1Sequence algorithm() => ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.11'))
      ..add(ASN1Null()); // sha256WithRSAEncryption
    ASN1Sequence name() => ASN1Sequence()
      ..add(
        ASN1Set()..add(
          ASN1Sequence()
            ..add(ASN1ObjectIdentifier.fromComponentString('2.5.4.10')) // O
            ..add(ASN1UTF8String('Mirasoft Arca')),
        ),
      )
      ..add(
        ASN1Set()..add(
          ASN1Sequence()
            ..add(ASN1ObjectIdentifier.fromComponentString('2.5.4.3')) // CN
            ..add(ASN1UTF8String('127.0.0.1')),
        ),
      );
    ASN1Sequence extension(
      String oid,
      ASN1Object value, {
      bool critical = false,
    }) {
      final seq = ASN1Sequence()
        ..add(ASN1ObjectIdentifier.fromComponentString(oid));
      if (critical) seq.add(ASN1Boolean(true));
      return seq..add(ASN1OctetString(value.encodedBytes));
    }

    final spki = ASN1Sequence()
      ..add(
        ASN1Sequence()
          ..add(
            ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'),
          )
          ..add(ASN1Null()),
      )
      ..add(
        ASN1BitString(
          Uint8List.fromList(
            (ASN1Sequence()
                  ..add(ASN1Integer(pub.modulus!))
                  ..add(ASN1Integer(pub.exponent!)))
                .encodedBytes,
          ),
        ),
      );

    final extensions = ASN1Sequence()
      ..add(extension('2.5.29.19', ASN1Sequence(), critical: true)) // CA:FALSE
      ..add(
        extension(
          '2.5.29.15', // digitalSignature + keyEncipherment
          ASN1BitString(Uint8List.fromList([0xA0]), unusedbits: 5),
          critical: true,
        ),
      )
      ..add(
        extension(
          '2.5.29.37', // serverAuth
          ASN1Sequence()..add(
            ASN1ObjectIdentifier.fromComponentString('1.3.6.1.5.5.7.3.1'),
          ),
        ),
      )
      ..add(
        extension(
          '2.5.29.17', // SAN: IP 127.0.0.1 + DNS localhost
          ASN1Sequence()
            ..add(ctx(0x87, [127, 0, 0, 1]))
            ..add(ctx(0x82, utf8.encode('localhost'))),
        ),
      );

    final now = DateTime.now().toUtc();
    final tbs = ASN1Sequence()
      ..add(ctx(0xA0, ASN1Integer.fromInt(2).encodedBytes)) // v3
      ..add(ASN1Integer(BigInt.from(Random.secure().nextInt(1 << 31) + 1)))
      ..add(algorithm())
      ..add(name()) // issuer
      ..add(
        ASN1Sequence()
          ..add(ASN1UtcTime(now.subtract(const Duration(days: 1))))
          ..add(ASN1UtcTime(now.add(const Duration(days: 3650)))),
      )
      ..add(name()) // subject
      ..add(spki)
      ..add(ctx(0xA3, extensions.encodedBytes));

    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(priv));
    final signature = signer.generateSignature(tbs.encodedBytes).bytes;

    final cert = ASN1Sequence()
      ..add(tbs)
      ..add(algorithm())
      ..add(ASN1BitString(signature));

    return (
      cert: _pem('CERTIFICATE', cert.encodedBytes),
      key: CryptoUtils.encodeRSAPrivateKeyToPem(priv),
    );
  }

  static String _pem(String label, List<int> der) {
    final b64 = base64.encode(der);
    final lines = [
      for (var i = 0; i < b64.length; i += 64)
        b64.substring(i, min(i + 64, b64.length)),
    ];
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }

  /// Ilova o'zi (installer'siz) sertifikat yaratganda:
  ///  * Windows — joriy foydalanuvchining Trusted Root ro'yxatiga qo'shadi
  ///    (Windows bir marta tasdiq oynasini ko'rsatadi);
  ///  * macOS/boshqa — qo'lda bajariladigan buyruq logga yoziladi.
  static Future<void> _tryTrustForCurrentUser(File cert) async {
    if (Platform.isWindows) {
      final r = await Process.run('certutil', [
        '-user',
        '-addstore',
        '-f',
        'Root',
        cert.path,
      ]);
      appLogger.info('certutil -user: exit ${r.exitCode}');
    } else if (Platform.isMacOS) {
      appLogger.warning(
        'Brauzer ishonishi uchun (bir marta) bajaring:\n'
        'security add-trusted-cert -r trustRoot -p ssl '
        '-k ~/Library/Keychains/login.keychain-db "${cert.path}"',
      );
    }
  }
}

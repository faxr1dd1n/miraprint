import 'dart:convert';
import 'package:flutter/services.dart';

class LocaleFileService {
  static Future<Map<String, String>> getLocaleFiles(
      List<String> locales, String basePath) async {
    var localizedFiles = await _getAllLocaleFiles(basePath);

    final files = new Map<String, String>();

    for (final language in locales.toSet()) {
      var file = _findLocaleFile(language, localizedFiles, basePath);

      files[language] = file;
    }

    return files;
  }

  static Future<String?> getLocaleContent(String file) async {
    final ByteData? data = await rootBundle.load(file);

    if (data == null) return null;

    return utf8.decode(data.buffer.asUint8List());
  }

  // Miraprint tuzatishi: yangi Flutter SDK'lar (3.16+) endi
  // `AssetManifest.json`ni umuman generatsiya qilmaydi — faqat binary
  // `AssetManifest.bin`. Shu sababli asl `rootBundle.loadString('AssetManifest.json')`
  // "Unable to load asset" xatosi bilan yiqiladi. O'rniga zamonaviy
  // `AssetManifest.loadFromAssetBundle` API'si ishlatiladi.
  static Future<List<String>> _getAllLocaleFiles(String basePath) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets();

    var separator = basePath.endsWith('/') ? '' : '/';

    return keys.where((x) => x.startsWith('$basePath$separator')).toList();
  }

  static String _findLocaleFile(
      String languageCode, List<String> localizedFiles, String basePath) {
    var file = _getFilepath(languageCode, basePath);

    if (!localizedFiles.contains(file)) {
      if (languageCode.contains('_')) {
        file = _getFilepath(languageCode.split('_').first, basePath);
      }
    }

    if (file == null) {
      throw new Exception(
          'The asset file for the language "$languageCode" was not found.');
    }

    return file;
  }

  static String? _getFilepath(String languageCode, String basePath) {
    var separator = basePath.endsWith('/') ? '' : '/';

    return '$basePath$separator$languageCode.json';
  }
}

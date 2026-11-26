import 'dart:io';

import 'package:flutter/services.dart';
import 'package:miraprint/core/app_logger.dart';

const String _kCaBundleAsset = 'assets/certs/cacert.pem';

/// Mozilla'ning ildiz sertifikatlarini tizimnikiga qo'shimcha ravishda
/// ishonchli ro'yxatga yuklaydi.
///
/// Sabab: Windows ba'zi ildiz sertifikatlarni faqat o'z TLS tizimi (SChannel)
/// so'raganda yuklab oladi. Dart (BoringSSL) buni qilmaydi, natijada
/// `CERTIFICATE_VERIFY_FAILED` chiqadi.
///
/// `SecurityContext.defaultContext`ga qo'shilgani uchun birinchi HTTPS
/// so'rovidan oldin chaqirilishi kerak. Sertifikat tekshiruvi o'chirilmaydi.
Future<void> loadTrustedCertificates() async {
  try {
    final data = await rootBundle.load(_kCaBundleAsset);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    appLogger.info('[TLS] Qo\'shimcha ildiz sertifikatlar yuklandi');
  } catch (e) {
    // Yuklanmasa ham ilova ishlayveradi (chek chiqarish bunga bog'liq emas),
    // faqat tizim sertifikatlariga tayanib qoladi.
    appLogger.warning('[TLS] Ildiz sertifikatlarni yuklab bo\'lmadi: $e');
  }
}

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';
import 'logo_loader.dart';
import 'receipt_canvas_renderer.dart';

Future<List<int>> buildReceiptBytes(
  ReceiptData receipt, {
  ReceiptSettings? settings,
  Future<img.Image> Function()? extraImageBuilder,
}) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  List<int> bytes = [];

  // Printer sovuq holatda (endigina yoqilgan yoki ilova birinchi marta
  // ulanayotgan) bo'lsa, oqim boshidagi baytlar yo'qolib/buzilib qolishi
  // mumkin (logo ustida "?" va bo'sh qatorlar shundan). ESC @ ni bir necha
  // marta takrorlab "isitish" bilan haqiqiy tarkib himoyalanadi — bu
  // komanda hech narsa chop etmaydi, faqat printerni reset qiladi.
  for (var i = 0; i < 5; i++) {
    bytes += generator.reset();
  }

  // Sinov bilan tasdiqlandi: buzilish logoning o'ziga emas, balki
  // reset'dan keyin ENG BIRINCHI yuboriladigan rasmga bog'liq (printer/USB
  // ulanishi hali "uyg'onmagan"). Shuning uchun logoni saytdagi tabiiy
  // o'rniga (boshiga) qaytardik — haqiqiy himoya endi ulanish darajasida,
  // `mac_raw_printer_connection.dart`dagi kutishda.
  if (receipt.logo.isNotEmpty) {
    final logoImage = await loadLogoImage(receipt.logo);
    if (logoImage != null) {
      bytes += generator.imageRaster(logoImage);
      bytes += generator.emptyLines(1);
    }
  }

  final contentImage = await renderReceiptTextImage(
    receipt,
    settings: settings,
  );
  bytes += generator.imageRaster(contentImage);

  if (receipt.barcode.isNotEmpty) {
    bytes += generator.emptyLines(1);
    bytes += generator.barcode(
      Barcode.code128(receipt.barcode.split('')),
      textPos: BarcodeText.none,
    );
  }

  final footerImage = await renderFooterImage(settings);
  if (footerImage != null) {
    bytes += generator.emptyLines(1);
    bytes += generator.imageRaster(footerImage);
  }

  if (extraImageBuilder != null) {
    final extraImage = await extraImageBuilder();
    bytes += generator.emptyLines(1);
    bytes += generator.imageRaster(extraImage);
  }

  bytes += generator.cut();

  return bytes;
}

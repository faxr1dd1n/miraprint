import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';
import 'logo_loader.dart';
import 'receipt_canvas_renderer.dart';

Future<List<int>> buildReceiptBytes(
  ReceiptData receipt, {
  ReceiptSettings? settings,
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

  bytes += generator.cut();

  return bytes;
}

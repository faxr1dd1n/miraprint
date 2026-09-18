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
  final isCompact = settings?.spacing == 'compact';
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
  // ulanishi hali "uyg'onmagan"). Logoni shuning uchun saytdagi tabiiy
  // o'rniga (boshiga) qaytardik. Bu RAW yo'l endi faqat macOS'da (dasturchi
  // test muhiti) ishlatiladi — Windows (production) endi OS drayveri
  // orqali chop etadi (`receipt_pdf_builder.dart`, `PLAN.md` Bosqich 12,
  // 2026-09-15), shu bilan bu muammo tubdan hal qilingan. Bu yerda tuzatish
  // qilinmadi — mac'da kamdan-kam holatda hamon yuz berishi mumkin, lekin
  // production emasligi uchun qabul qilingan xavf.
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
    // GDI (Windows) yo'lida bu bo'shliq compact rejimda yarmiga tushadi
    // (`receipt_gdi_blocks.dart`dagi `halveInCompact`) — ESC/POS'da faqat
    // butun qator berish mumkin, shu sabab yarim o'rniga compact'da
    // butunlay olib tashlanadi.
    if (!isCompact) bytes += generator.emptyLines(1);
    bytes += generator.barcode(
      Barcode.code128(receipt.barcode.split('')),
      textPos: BarcodeText.none,
    );
  }

  final footerImage = await renderFooterImage(settings);
  if (footerImage != null) {
    if (!isCompact) bytes += generator.emptyLines(1);
    bytes += generator.imageRaster(footerImage);
  }

  bytes += generator.cut();

  return bytes;
}

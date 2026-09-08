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

  bytes += generator.reset();

  if (receipt.logo.isNotEmpty) {
    final logoImage = await loadLogoImage(receipt.logo);
    if (logoImage != null) {
      bytes += generator.image(logoImage);
      bytes += generator.emptyLines(1);
    }
  }

  final contentImage = await renderReceiptTextImage(
    receipt,
    settings: settings,
  );
  bytes += generator.image(contentImage);

  if (receipt.barcode.isNotEmpty) {
    bytes += generator.emptyLines(1);
    bytes += generator.barcode(Barcode.code128(receipt.barcode.split('')));
  }

  final footerImage = await renderFooterImage(settings);
  if (footerImage != null) {
    bytes += generator.emptyLines(1);
    bytes += generator.image(footerImage);
  }

  bytes += generator.cut();

  return bytes;
}

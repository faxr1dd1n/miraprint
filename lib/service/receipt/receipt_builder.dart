import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../model/receipt/receipt_data.dart';
import 'logo_loader.dart';
import 'receipt_canvas_renderer.dart';

Future<List<int>> buildReceiptBytes(ReceiptData receipt) async {
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

  final contentImage = await renderReceiptTextImage(receipt);
  bytes += generator.image(contentImage);

  if (receipt.barcode.isNotEmpty) {
    bytes += generator.emptyLines(1);
    bytes += generator.barcode(Barcode.code128(receipt.barcode.split('')));
  }

  bytes += generator.cut();

  return bytes;
}

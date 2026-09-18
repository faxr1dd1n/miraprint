import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

Future<img.Image?> loadLogoImage(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final decoded = img.decodeImage(response.bodyBytes);
    if (decoded == null) return null;

    return _fitToPrintWidth(decoded);
  } catch (_) {
    return null;
  }
}

// Windows/C# tomonidagi qiymatlar bilan bir xil (`receipt_gdi_blocks.dart`
// `logoMaxHeight`/`logoMaxWidth`, C#: 1.4in/2.6in), 203dpi'ga o'girilgan
// (`_printWidth = 576px` ham shu dpi'dagi 72mm printable kenglikka mos).
img.Image _fitToPrintWidth(
  img.Image source, {
  int maxWidth = 528,
  int maxHeight = 284,
}) {
  var width = source.width;
  var height = source.height;

  if (width > maxWidth) {
    height = (height * maxWidth / width).round();
    width = maxWidth;
  }
  if (height > maxHeight) {
    width = (width * maxHeight / height).round();
    height = maxHeight;
  }

  // `esc_pos_utils_plus`ning `imageRaster()`i (`generator.dart:166-194`)
  // kengligi 8ga bo'linmaydigan tasvirlarda ichki bug'ga ega (fixed-length
  // ro'yxatga `insertAll` bilan qo'shishga urinadi, "Cannot add to a
  // fixed-length list" xatosi) — shu sabab qaysi logotip/nisbat
  // bo'lishidan qat'i nazar, final kenglik har doim eng yaqin 8ning
  // karraliga tushiriladi.
  width -= width % 8;
  if (width <= 0) width = 8;

  return img.copyResize(source, width: width, height: height);
}

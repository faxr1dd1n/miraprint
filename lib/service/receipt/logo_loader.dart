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
// (`_printWidth = 576px` ham shu dpi'dagi 72mm printable kenglikka mos) —
// ilgari mustaqil ravishda kichikroq (200px) tanlangan edi, shu sabab
// balandlik bo'yicha cheklangan logotiplar Mac'da Windows'dan kichikroq
// chiqardi.
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

  return img.copyResize(source, width: width, height: height);
}

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

img.Image _fitToPrintWidth(
  img.Image source, {
  int maxWidth = 520,
  int maxHeight = 200,
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

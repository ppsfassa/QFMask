import 'package:image/image.dart' as img;

//加工ロジック

img.Image applyCustomEffect(img.Image src) {
  // 元の画像と同じサイズの新しい画像を作成
  final width = src.width;
  final height = src.height;
  final dst = img.Image(width: width, height: height, numChannels: 4);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = src.getPixel(x, y);

      // Pythonのロジックを再現
      // R: ネガポジ + 上下反転
      final rPixel = src.getPixel(x, height - 1 - y);
      final r = 255 - rPixel.r.toInt();

      // G: ネガポジ
      final g = 255 - pixel.g.toInt();

      // B: ネガポジ + 左右反転
      final bPixel = src.getPixel(width - 1 - x, y);
      final b = 255 - bPixel.b.toInt();

      dst.setPixel(x, y, img.ColorRgba8(r, g, b, pixel.a.toInt()));
    }
  }
  return dst;
}


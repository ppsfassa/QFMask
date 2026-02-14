import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb; // これが重要
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Uint8List encodeByExtension(img.Image image, String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg') {
      return Uint8List.fromList(img.encodeJpg(image));
    } else {
      return Uint8List.fromList(img.encodePng(image));
    }
  }

  static Future<void> saveToGallery(img.Image image, String fileName) async {
  final bytes = encodeByExtension(image, fileName);

  if (kIsWeb) {
    // Webの実装（Blobなど）
  } else {
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) throw Exception("ギャラリーへのアクセス権限がありません");
    }

    // 2. 一時ファイルの作成
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final file = File(tempPath);
    await file.writeAsBytes(bytes);

    try {
      // 保存処理の直前に追加
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            //print("権限が拒否されました");
            return; 
          }
        }
      }
      // 3. ギャラリーへ保存
      await Gal.putImage(file.path);
      
      // 4. 保存後は一時ファイルを削除
      if (await file.exists()) {
        await file.delete();
      }
    } on GalException catch (e) {
      throw Exception("ギャラリー保存エラー: ${e.type}");
    }
  }
}

  static bool isSupportedImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.bmp'].contains(ext);
  }
}
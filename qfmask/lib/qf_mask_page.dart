import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'apply_custom_effect.dart';
import 'image_utils.dart';
import 'roi_editor.dart';

//メイン画面UI

class QFMaskPage extends StatefulWidget {
  const QFMaskPage({super.key});
  @override
  State<QFMaskPage> createState() => _QFMaskPageState();
}

class _QFMaskPageState extends State<QFMaskPage> {
  double _progress = 0;

  // インプットと同じ形式で一括保存
  Future<void> runBatchProcess() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir == null) return;

    final dir = Directory(selectedDir);
    final files = (await dir.list().toList())
        .whereType<File>()
        .where((f) => ImageUtils.isSupportedImage(f.path))
        .toList();

    if (files.isEmpty) return;

    final outputDir = Directory(p.join(selectedDir, 'output'));
    if (!await outputDir.exists()) await outputDir.create();

    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        final processed = applyCustomEffect(image);
        final outPath = p.join(outputDir.path, p.basename(files[i].path));
        await File(outPath).writeAsBytes(ImageUtils.encodeByExtension(processed, files[i].path));
      }
      setState(() => _progress = (i + 1) / files.length);
    }
    _showSnackBar("一括処理が完了しました");
  }

  Future<void> _saveImage(img.Image processed, String originalFileName) async {
  final bytes = ImageUtils.encodeByExtension(processed, originalFileName);

  if (Platform.isWindows) {
    // Windows: 保存先を選択させる
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '保存先を選択してください',
      fileName: 'processed_$originalFileName',
      type: FileType.image,
    );

    if (outputFile == null) return; // キャンセル時

    await File(outputFile).writeAsBytes(bytes);
    _showSnackBar("保存しました: $outputFile");
    
  } else {
    // モバイル: gal を使用してギャラリーに保存
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'processed_$originalFileName'));
    await tempFile.writeAsBytes(bytes);

    try {
      await Gal.putImage(tempFile.path);
      _showSnackBar("ギャラリーに保存しました");
    } catch (e) {
      _showSnackBar("保存に失敗しました: $e");
    }
  }
}

  // 1枚のみ全体加工（インプットと同じ形式）
  Future<void> processSingleImage() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result == null) return;

  final File file = File(result.files.single.path!);
  final img.Image? decodedImage = img.decodeImage(await file.readAsBytes());

  if (decodedImage != null) {
    final processed = applyCustomEffect(decodedImage);
    // 共通保存メソッドを呼び出し
    await _saveImage(processed, p.basename(file.path));
  }
}

// 部分加工
Future<void> openPartialEditor() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result == null) return;

  final File file = File(result.files.single.path!);
  final img.Image? decodedImage = img.decodeImage(await file.readAsBytes());

  if (decodedImage != null && mounted) {
    final img.Image? processedResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ROIEditor(sourceImage: decodedImage)),
    );

    if (processedResult != null) {
      // 共通保存メソッドを呼び出し
      await _saveImage(processedResult, p.basename(file.path));
    }
  }
}

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QF-MASK")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("QF-MASK 操作パネル"),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: runBatchProcess, icon: const Icon(Icons.folder_copy), label: const Text("一括処理")),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: processSingleImage, icon: const Icon(Icons.image), label: const Text("1枚全体加工")),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: openPartialEditor, icon: const Icon(Icons.crop), label: const Text("部分加工")),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: LinearProgressIndicator(value: _progress),
            ),
          ],
        ),
      ),
    );
  }
}
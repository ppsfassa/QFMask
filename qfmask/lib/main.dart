import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'apply_custom_effect.dart';
import 'dart:typed_data';

void main() {
  runApp(const QFMaskApp());
}

class QFMaskApp extends StatelessWidget {
  const QFMaskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QF-MASK',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const QFMaskPage(),
    );
  }
}

class QFMaskPage extends StatefulWidget {
  const QFMaskPage({super.key});
  @override
  State<QFMaskPage> createState() => _QFMaskPageState();
}

class _QFMaskPageState extends State<QFMaskPage> {
  bool _invertAlpha = false;
  String _format = "PNG";
  double _progress = 0;

  // 一括処理
  Future<void> runBatchProcess() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final dir = Directory(selectedDirectory);
    final List<File> files = (await dir.list().toList())
        .whereType<File>()
        .where((f) => ['.png', '.jpg', '.jpeg', '.bmp'].contains(p.extension(f.path).toLowerCase()))
        .toList();

    if (files.isEmpty) return;

    final outputDir = Directory(p.join(selectedDirectory, 'output'));
    if (!await outputDir.exists()) await outputDir.create();

    setState(() => _progress = 0);

    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        final processed = applyCustomEffect(image, invertAlpha: _invertAlpha);
        String outPath = p.join(outputDir.path, "${p.basenameWithoutExtension(files[i].path)}.$_format".toLowerCase());
        await File(outPath).writeAsBytes(_format == "PNG" ? img.encodePng(processed) : img.encodeJpg(processed));
      }
      setState(() => _progress = (i + 1) / files.length);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("一括処理が完了しました")));
  }

  // 画像1枚を全体加工して保存する機能
  Future<void> processSingleImage() async {
    // 1. 画像ファイルを選択
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    final File file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    img.Image? decodedImage = img.decodeImage(bytes);

    if (decodedImage != null) {
      setState(() => _progress = 0.5); // 処理中っぽく見せる

      // 2. 加工適用 (全体)
      final processed = applyCustomEffect(decodedImage, invertAlpha: _invertAlpha);

      // 3. 保存先を選択
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存先を選択してください',
        fileName: 'processed_${p.basename(file.path)}',
      );

      if (savePath != null) {
        // 形式に合わせて保存 (一括処理と同じロジック)
        if (_format == "PNG") {
          await File(savePath).writeAsBytes(img.encodePng(processed));
        } else {
          await File(savePath).writeAsBytes(img.encodeJpg(processed));
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("画像を保存しました")));
      }
      setState(() => _progress = 1.0);
    }
  }

  // 部分加工：画像を選択してエディタを開く
  Future<void> openPartialEditor() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    final File file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    final img.Image? decodedImage = img.decodeImage(bytes);

    if (decodedImage != null && mounted) {
      // 編集画面へ遷移
      final img.Image? processedResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ROIEditor(sourceImage: decodedImage, invertAlpha: _invertAlpha),
        ),
      );

      if (processedResult != null) {
        // 加工後の画像を保存
        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存先を選択してください',
          fileName: 'partial_processed.png',
        );
        if (savePath != null) {
          await File(savePath).writeAsBytes(img.encodePng(processedResult));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("保存完了しました")));
        }
      }
    }
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
            // 一括処理ボタン
            ElevatedButton.icon(
              onPressed: runBatchProcess,
              icon: const Icon(Icons.folder_copy),
              label: const Text("フォルダを一括処理"),
            ),
            const SizedBox(height: 10),
            // ★追加：1枚のみ全体処理ボタン
            ElevatedButton.icon(
              onPressed: processSingleImage,
              icon: const Icon(Icons.image),
              label: const Text("1枚のみ全体加工"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50]),
            ),
            const SizedBox(height: 10),
            // 部分加工ボタン
            ElevatedButton.icon(
              onPressed: openPartialEditor,
              icon: const Icon(Icons.crop),
              label: const Text("画像を選択して部分加工"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen[100]),
            ),
            const Divider(height: 40),
            CheckboxListTile(
              title: const Text("アルファチャンネルを反転"),
              value: _invertAlpha,
              onChanged: (v) => setState(() => _invertAlpha = v!),
            ),
            LinearProgressIndicator(value: _progress),
          ],
        ),
      ),
    );
  }
}

// --- 部分加工用のエディタ画面 ---
// --- 部分加工用のエディタ画面 ---
class ROIEditor extends StatefulWidget {
  final img.Image sourceImage;
  final bool invertAlpha;
  const ROIEditor({super.key, required this.sourceImage, required this.invertAlpha});

  @override
  State<ROIEditor> createState() => _ROIEditorState();
}

class _ROIEditorState extends State<ROIEditor> {
  Offset? startPoint;
  Offset? endPoint;
  final GlobalKey _imageKey = GlobalKey();
  
  // 追加：表示用のバイトデータを保持する変数
  late Uint8List _displayImageData;

  @override
  void initState() {
    super.initState();
    // 画面が開いた時に一度だけエンコードする
    _displayImageData = Uint8List.fromList(img.encodePng(widget.sourceImage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("範囲を選択して✓ボタン"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (startPoint != null && endPoint != null) {
                final processed = _applyPartialEffect();
                Navigator.pop(context, processed);
              }
            },
          )
        ],
      ),
      body: Center(
        child: GestureDetector(
          onPanStart: (details) => setState(() => startPoint = details.localPosition),
          onPanUpdate: (details) => setState(() => endPoint = details.localPosition),
          child: Stack(
            alignment: Alignment.center, // 子要素を中央に配置
            children: [
              Image.memory(
                _displayImageData, // 事前に作ったデータを使用
                key: _imageKey,
                fit: BoxFit.contain,
              ),
              if (startPoint != null && endPoint != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: RectPainter(startPoint!, endPoint!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  img.Image _applyPartialEffect() {
    // 1. 画像が画面上で実際に表示されているサイズを取得
    final RenderBox renderBox = _imageKey.currentContext!.findRenderObject() as RenderBox;
    final double displayW = renderBox.size.width;
    final double displayH = renderBox.size.height;

    // 2. 本来の画像サイズ
    final double realW = widget.sourceImage.width.toDouble();
    final double realH = widget.sourceImage.height.toDouble();

    // 3. 表示サイズと実サイズの比率(スケール)を計算
    final double scaleX = realW / displayW;
    final double scaleY = realH / displayH;

    // 4. 画面上の座標を画像上の座標に変換
    int x1 = (startPoint!.dx * scaleX).toInt().clamp(0, realW.toInt());
    int y1 = (startPoint!.dy * scaleY).toInt().clamp(0, realH.toInt());
    int x2 = (endPoint!.dx * scaleX).toInt().clamp(0, realW.toInt());
    int y2 = (endPoint!.dy * scaleY).toInt().clamp(0, realH.toInt());

    // 5. 範囲を計算
    final int left = x1 < x2 ? x1 : x2;
    final int top = y1 < y2 ? y1 : y2;
    final int width = (x1 - x2).abs();
    final int height = (y1 - y2).abs();

    if (width <= 0 || height <= 0) return widget.sourceImage;

    // 6. 加工（切り抜き -> エフェクト適用 -> 合成）
    final cropped = img.copyCrop(widget.sourceImage, x: left, y: top, width: width, height: height);
    final processedCropped = applyCustomEffect(cropped, invertAlpha: widget.invertAlpha);
    
    final resultImage = img.Image.from(widget.sourceImage);
    img.compositeImage(resultImage, processedCropped, dstX: left, dstY: top);

    return resultImage;
  }
}
class RectPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  RectPainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromPoints(start, end), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import '../apply_custom_effect.dart';

//部分加工エディタ

class ROIEditor extends StatefulWidget {
  final img.Image sourceImage;
  const ROIEditor({super.key, required this.sourceImage});

  @override
  State<ROIEditor> createState() => _ROIEditorState();
}

class _ROIEditorState extends State<ROIEditor> {
  Offset? startPoint;
  Offset? endPoint;
  final GlobalKey _imageKey = GlobalKey();
  late Uint8List _displayImageData;

  @override
  void initState() {
    super.initState();
    _displayImageData = Uint8List.fromList(img.encodePng(widget.sourceImage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("範囲を選択して✓"),
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
            alignment: Alignment.center,
            children: [
              Image.memory(_displayImageData, key: _imageKey, fit: BoxFit.contain),
              if (startPoint != null && endPoint != null)
                Positioned.fill(
                  child: CustomPaint(painter: RectPainter(startPoint!, endPoint!)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  img.Image _applyPartialEffect() {
    final RenderBox renderBox = _imageKey.currentContext!.findRenderObject() as RenderBox;
    final double scaleX = widget.sourceImage.width / renderBox.size.width;
    final double scaleY = widget.sourceImage.height / renderBox.size.height;

    int x1 = (startPoint!.dx * scaleX).toInt().clamp(0, widget.sourceImage.width);
    int y1 = (startPoint!.dy * scaleY).toInt().clamp(0, widget.sourceImage.height);
    int x2 = (endPoint!.dx * scaleX).toInt().clamp(0, widget.sourceImage.width);
    int y2 = (endPoint!.dy * scaleY).toInt().clamp(0, widget.sourceImage.height);

    final int left = x1 < x2 ? x1 : x2;
    final int top = y1 < y2 ? y1 : y2;
    final int width = (x1 - x2).abs();
    final int height = (y1 - y2).abs();

    if (width <= 0 || height <= 0) return widget.sourceImage;

    final cropped = img.copyCrop(widget.sourceImage, x: left, y: top, width: width, height: height);
    final processedCropped = applyCustomEffect(cropped);
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
    final paint = Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromPoints(start, end), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
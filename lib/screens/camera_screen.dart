// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

const Map<String, Color> namedColors = {
  "Red": Color(0xFFFF0000),
  "Green": Color(0xFF00FF00),
  "Blue": Color(0xFF0000FF),
  "Yellow": Color(0xFFFFFF00),
  "Cyan": Color(0xFF00FFFF),
  "Magenta": Color(0xFFFF00FF),
  "Orange": Color(0xFFFFA500),
  "Pink": Color(0xFFFFC0CB),
  "Purple": Color(0xFF800080),
  "Brown": Color(0xFFA52A2A),
  "Black": Color(0xFF000000),
  "Gray": Color(0xFF808080),
  "White": Color(0xFFFFFFFF),
  "Lime": Color(0xFF00FF00),
  "Maroon": Color(0xFF800000),
  "Navy": Color(0xFF000080),
  "Olive": Color(0xFF808000),
  "Teal": Color(0xFF008080),
  "Silver": Color(0xFFC0C0C0),
  "Gold": Color(0xFFFFD700),
  "Beige": Color(0xFFF5F5DC),
  "Coral": Color(0xFFFF7F50),
  "Indigo": Color(0xFF4B0082),
  "SkyBlue": Color(0xFF87CEEB),
  "Violet": Color(0xFFEE82EE),
  "Turquoise": Color(0xFF40E0D0),
  "Salmon": Color(0xFFFA8072),
  "Khaki": Color(0xFFF0E68C),
  "Plum": Color(0xFFDDA0DD),
  "Chocolate": Color(0xFFD2691E),
  "FireBrick": Color(0xFFB22222),
  "Peru": Color(0xFFCD853F),
  "SeaGreen": Color(0xFF2E8B57),
  "SlateBlue": Color(0xFF6A5ACD),
  "Tomato": Color(0xFFFF6347),
  "Wheat": Color(0xFFF5DEB3),
  "Azure": Color(0xFFF0FFFF),
  "Lavender": Color(0xFFE6E6FA),
  "MintCream": Color(0xFFF5FFFA),
  "OldLace": Color(0xFFFDF5E6),
  "Ivory": Color(0xFFFFFFF0),
  "HoneyDew": Color(0xFFF0FFF0),
  "AliceBlue": Color(0xFFF0F8FF),
  "SlateGray": Color(0xFF708090),
};

String getClosestColorName(Color color) {
  String closestName = "Unknown";
  double minDist = double.infinity;
  for (final entry in namedColors.entries) {
    final c = entry.value;
    final dist = pow(color.red - c.red, 2) +
        pow(color.green - c.green, 2) +
        pow(color.blue - c.blue, 2);
    if (dist < minDist) {
      minDist = dist.toDouble();
      closestName = entry.key;
    }
  }
  return closestName;
}

/// Overlay utility that expects [center] in pixel coordinates of the captured image!
Future<File> overlayPlusAndName({
  required File imageFile,
  required String colorName,
  required Color color,
  required Offset center,
  double boxSize = 180,
}) async {
  final bytes = await imageFile.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final uiImage = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  final width = uiImage.width.toDouble();
  final height = uiImage.height.toDouble();

  // Draw original image
  canvas.drawImage(uiImage, Offset.zero, paint);

  // Draw plus sign centered at [center]
  final double plusLength = boxSize * 0.3;
  final double plusStroke = boxSize * 0.07;
  final plusPaint = Paint()
    ..color = color
    ..strokeWidth = plusStroke
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Vertical line
  canvas.drawLine(
    Offset(center.dx, center.dy - plusLength / 2),
    Offset(center.dx, center.dy + plusLength / 2),
    plusPaint,
  );
  // Horizontal line
  canvas.drawLine(
    Offset(center.dx - plusLength / 2, center.dy),
    Offset(center.dx + plusLength / 2, center.dy),
    plusPaint,
  );

  // Draw color name text (above the plus sign)
  final textPainter = TextPainter(
    text: TextSpan(
      text: colorName,
      style: TextStyle(
        fontSize: boxSize * 0.22,
        fontWeight: FontWeight.bold,
        color: color,
        shadows: [const Shadow(color: Colors.black, blurRadius: 2)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  const double verticalSpace = 28;
  final textOffset = Offset(
    center.dx - textPainter.width / 2,
    center.dy - plusLength / 2 - verticalSpace - textPainter.height,
  );
  textPainter.paint(canvas, textOffset);

  final pic = recorder.endRecording();
  final uiImg = await pic.toImage(uiImage.width, uiImage.height);
  final pngBytes = await uiImg.toByteData(format: ui.ImageByteFormat.png);

  final tempDir = await getTemporaryDirectory();
  final newFile = File('${tempDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.png');
  await newFile.writeAsBytes(pngBytes!.buffer.asUint8List());
  return newFile;
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  Color? _focusColor;
  String? _focusColorName;
  bool _gettingColor = false;
  bool _isSaving = false;

  Size? _previewSize; // Aspect ratio of camera sensor

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;
    setState(() {
      _isCameraInitialized = true;
      _previewSize = _controller.value.previewSize != null
          ? Size(
              _controller.value.previewSize!.height,
              _controller.value.previewSize!.width,
            )
          : null;
    });
    _startColorDetection();
  }

  void _startColorDetection() {
    _controller.startImageStream((CameraImage image) async {
      if (_gettingColor) return;
      _gettingColor = true;
      final int centerX = image.width ~/ 2;
      final int centerY = image.height ~/ 2;
      final color = _getPixelColor(image, centerX, centerY);
      final name = getClosestColorName(color);
      setState(() {
        _focusColor = color;
        _focusColorName = name;
      });
      _gettingColor = false;
    });
  }

  Color _getPixelColor(CameraImage image, int x, int y) {
    if (image.format.group != ImageFormatGroup.yuv420) return Colors.grey;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    int yp = y * image.planes[0].bytesPerRow + x;
    int up = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
    int vp = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

    int yVal = image.planes[0].bytes[yp];
    int uVal = image.planes[1].bytes[up];
    int vVal = image.planes[2].bytes[vp];

    double yF = yVal.toDouble();
    double uF = uVal.toDouble() - 128.0;
    double vF = vVal.toDouble() - 128.0;
    int r = (yF + 1.370705 * vF).round().clamp(0, 255);
    int g = (yF - 0.337633 * uF - 0.698001 * vF).round().clamp(0, 255);
    int b = (yF + 1.732446 * uF).round().clamp(0, 255);

    return Color.fromARGB(255, r, g, b);
  }

  Future<void> _capturePhotoAndSave() async {
    if (_focusColor == null || _focusColorName == null || _isSaving) return;
    setState(() => _isSaving = true);
    await _initializeControllerFuture;
    try {
      await _controller.stopImageStream();
    } catch (_) {}
    final XFile file = await _controller.takePicture();

    // Map preview's center to image coordinates
    // Get image and preview dimensions
    final imageBytes = await File(file.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    final double imgW = uiImage.width.toDouble();
    final double imgH = uiImage.height.toDouble();

    // Get screen size (for preview widget)
    // ignore: use_build_context_synchronously
    final renderBox = context.findRenderObject() as RenderBox;
    final double screenW = renderBox.size.width;
    final double screenH = renderBox.size.height;

    // Camera sensor aspect ratio (width/height)
    final previewSize = _controller.value.previewSize!;
    final double previewAspect = previewSize.width / previewSize.height;
    final double screenAspect = screenW / screenH;

    // For BoxFit.cover, the image fills the screen and may be cropped
    double scale, offsetX = 0, offsetY = 0;
    if (screenAspect > previewAspect) {
      // Wider screen, vertical crop
      scale = screenW / previewSize.width;
      double fittedHeight = previewSize.height * scale;
      offsetY = (screenH - fittedHeight) / 2;
    } else {
      // Taller screen, horizontal crop
      scale = screenH / previewSize.height;
      double fittedWidth = previewSize.width * scale;
      offsetX = (screenW - fittedWidth) / 2;
    }

    // The overlay "+" is at (screenW/2, screenH/2) in screen coords.
    // Map that point back to sensor/image coordinates:
    double px = (screenW / 2 - offsetX) / scale;
    double py = (screenH / 2 - offsetY) / scale;
    // Now, px/py are in preview coordinates (width/height = previewSize)
    // Map to captured image coordinates (may differ if image is rotated or different ratio)
    double imgCenterX = px * (imgW / previewSize.width);
    double imgCenterY = py * (imgH / previewSize.height);

    File overlaid = await overlayPlusAndName(
      imageFile: File(file.path),
      colorName: _focusColorName!,
      color: _focusColor!,
      boxSize: 180,
      center: Offset(imgCenterX, imgCenterY),
    );

    // Save to device using photo_manager
    await PhotoManager.editor.saveImageWithPath(overlaid.path);

    // Clean up temp files
    try {
      await File(file.path).delete();
      await overlaid.delete();
    } catch (_) {}

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pushReplacementNamed('/gallery');
    }
  }

  Widget _buildPlusOverlay(BuildContext context) {
    if (_focusColor == null || _focusColorName == null) return const SizedBox();
    final double boxSize = 180;
    return IgnorePointer(
      child: Center(
        child: CustomPaint(
          size: Size(boxSize, boxSize),
          painter: _PlusAndTextPainter(
            color: _focusColor!,
            colorName: _focusColorName!,
            boxSize: boxSize,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget previewWidget;
    if (_isCameraInitialized && _previewSize != null) {
      previewWidget = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller),
          _buildPlusOverlay(context),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            top: 24,
            left: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 34),
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _capturePhotoAndSave,
                child: const Icon(Icons.camera_alt, size: 32),
              ),
            ),
          ),
        ],
      );
    } else {
      previewWidget = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: previewWidget,
    );
  }
}

class _PlusAndTextPainter extends CustomPainter {
  final Color color;
  final String colorName;
  final double boxSize;
  _PlusAndTextPainter({
    required this.color,
    required this.colorName,
    required this.boxSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double plusLength = boxSize * 0.3;
    final double plusStroke = boxSize * 0.07;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint plusPaint = Paint()
      ..color = color
      ..strokeWidth = plusStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - plusLength / 2),
      Offset(center.dx, center.dy + plusLength / 2),
      plusPaint,
    );
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - plusLength / 2, center.dy),
      Offset(center.dx + plusLength / 2, center.dy),
      plusPaint,
    );

    // Draw color name text (above the plus sign)
    final textPainter = TextPainter(
      text: TextSpan(
        text: colorName,
        style: TextStyle(
          fontSize: boxSize * 0.22,
          fontWeight: FontWeight.bold,
          color: color,
          shadows: [const Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double verticalSpace = 28;
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - plusLength / 2 - verticalSpace - textPainter.height,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _PlusAndTextPainter oldDelegate) =>
      color != oldDelegate.color || colorName != oldDelegate.colorName;
}
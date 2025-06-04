// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'dart:math' as math; // Use 'as math' to avoid conflict with dart:ui's pow
import 'dart:ui' as ui; // Needed for ui.instantiateImageCodec, ui.PictureRecorder, ui.ImageByteFormat
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for permission handling
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts for consistent typography

// --- Color Utility Functions (Duplicated for self-containment, can be moved to a shared file) ---
const Map<String, Color> namedColors = {
  "Red": Color(0xFFFF0000), "Green": Color(0xFF00FF00), "Blue": Color(0xFF0000FF),
  "Yellow": Color(0xFFFF0000), "Cyan": Color(0xFF00FFFF), "Magenta": Color(0xFFFF00FF),
  "Orange": Color(0xFFFFA500), "Pink": Color(0xFFFFC0CB), "Purple": Color(0xFF800080),
  "Brown": Color(0xFFA52A2A), "Black": Color(0xFF000000), "Gray": Color(0xFF808080),
  "White": Color(0xFFFFFFFF), "Lime": Color(0xFF00FF00), "Maroon": Color(0xFF800000),
  "Navy": Color(0xFF000080), "Olive": Color(0xFF808000), "Teal": Color(0xFF008080),
  "Silver": Color(0xFFC0C0C0), "Gold": Color(0xFFFFD700),
  "Coral": Color(0xFFFF7F50), "Indigo": Color(0xFF4B0082), "SkyBlue": Color(0xFF87CEEB),
  "Violet": Color(0xFFEE82EE), "Turquoise": Color(0xFF40E0D0), "Salmon": Color(0xFFFA8072),
  "Khaki": Color(0xFFF0E68C), "Plum": Color(0xFFDDA0DD), "Chocolate": Color(0xFFD2691E),
  "FireBrick": Color(0xFFB22222), "Peru": Color(0xFFCD853F), "SeaGreen": Color(0xFF2E8B57),
  "SlateBlue": Color(0xFF6A5ACD), "Wheat": Color(0xFFF5DEB3),
  "Azure": Color(0xFFF0FFFF), "Lavender": Color(0xFFE6E6FA), "MintCream": Color(0xFFF5FFFA),
  "OldLace": Color(0xFFFDF5E6), "Ivory": Color(0xFFFFFFF0), "HoneyDew": Color(0xFFF0FFF0),
  "AliceBlue": Color(0xFFF0F8FF), "SlateGray": Color(0xFF708090),
};

String getClosestColorName(Color color) {
  String closestName = "Unknown";
  double minDist = double.infinity;
  for (final entry in namedColors.entries) {
    final c = entry.value;
    final dist = math.pow(color.red - c.red, 2) +
        math.pow(color.green - c.green, 2) +
        math.pow(color.blue - c.blue, 2);
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
      style: GoogleFonts.inter( // Use GoogleFonts for consistency
        fontSize: boxSize * 0.22,
        fontWeight: FontWeight.bold,
        color: color,
        shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
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

// Renamed from CameraScreen to ColorIdentificationCameraScreen
class ColorIdentificationCameraScreen extends StatefulWidget {
  final void Function(String imagePath) onImageCaptured;

  const ColorIdentificationCameraScreen({super.key, required this.onImageCaptured});

  @override
  State<ColorIdentificationCameraScreen> createState() => _ColorIdentificationCameraScreenState();
}

class _ColorIdentificationCameraScreenState extends State<ColorIdentificationCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  Color? _focusColor;
  String? _focusColorName;
  bool _gettingColor = false;
  bool _isSaving = false;

  Size? _previewSize; // Aspect ratio of camera sensor
  int _selectedCameraIdx = 0; // Index of the currently selected camera
  List<CameraDescription>? _cameras; // List of available cameras

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Dispose existing controller if any
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    // Request camera permission
    var status = await Permission.camera.request();
    if (status.isDenied) {
      print("Camera permission denied");
      _showPermissionDeniedDialog();
      return;
    }
    if (status.isPermanentlyDenied) {
      print("Camera permission permanently denied. Please enable from settings.");
      _showPermissionDeniedDialog(isPermanent: true);
      return;
    }

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      print("No cameras found");
      _showErrorDialog("Camera Error", "No cameras found on this device.");
      return;
    }

    // Ensure _selectedCameraIdx is within bounds
    if (_selectedCameraIdx >= _cameras!.length) {
      _selectedCameraIdx = 0; // Reset to first camera if index is out of bounds
    }

    _controller = CameraController(
      _cameras![_selectedCameraIdx], // Use the selected camera
      ResolutionPreset.high, // Keeping high resolution for color identification
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Optimal for Android
    );

    _initializeControllerFuture = _controller!.initialize();
    await _initializeControllerFuture;

    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
      // Note: Camera preview size might be rotated compared to screen orientation.
      // Using previewSize.height and previewSize.width directly for AspectRatio
      // to maintain correct aspect, as CameraPreview handles rotation.
      _previewSize = _controller!.value.previewSize;
    });
    _startColorDetection();
  }

  // Function to toggle between front and back cameras
  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      print("Only one camera available, cannot toggle.");
      return;
    }

    setState(() {
      _isCameraInitialized = false; // Set to false to show loading indicator
      _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length; // Cycle through cameras
    });

    await _initCamera(); // Re-initialize camera with the new selection
  }

  void _startColorDetection() {
    _controller!.startImageStream((CameraImage image) async {
      if (_gettingColor) return;
      _gettingColor = true;

      // Ensure the image is in the correct format before processing
      if (image.format.group != ImageFormatGroup.yuv420) {
        print("Color detection: Unsupported image format ${image.format.group}");
        _gettingColor = false;
        return;
      }

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
    // This YUV to RGB conversion is critical for accurate color picking
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

    // Standard YUV to RGB conversion formulas
    int r = (yF + 1.370705 * vF).round().clamp(0, 255);
    int g = (yF - 0.337633 * uF - 0.698001 * vF).round().clamp(0, 255);
    int b = (yF + 1.732446 * uF).round().clamp(0, 255);

    return Color.fromARGB(255, r, g, b);
  }

  void _showPermissionDeniedDialog({bool isPermanent = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Permission Denied", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(isPermanent
            ? "Camera access is permanently denied. Please go to app settings to enable it."
            : "Camera access is required to use this feature.",
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isPermanent) {
                openAppSettings();
              } else {
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: Text("OK", style: GoogleFonts.inter(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text("OK", style: GoogleFonts.inter(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhotoAndSave() async {
    if (_focusColor == null || _focusColorName == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _initializeControllerFuture;
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      final XFile file = await _controller!.takePicture();

      // Get image and preview dimensions for accurate overlay placement
      final imageBytes = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;
      final double imgW = uiImage.width.toDouble();
      final double imgH = uiImage.height.toDouble();

      // Get screen size (for preview widget)
      if (!mounted) return; // Check mounted before using context
      final renderBox = context.findRenderObject() as RenderBox;
      final double screenW = renderBox.size.width;
      final double screenH = renderBox.size.height;

      // Camera sensor aspect ratio (width/height)
      final previewSize = _controller!.value.previewSize!;
      final double previewAspect = previewSize.width / previewSize.height;
      final double screenAspect = screenW / screenH;

      // Calculate scaling and offsets for BoxFit.cover
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

      if (mounted) {
        setState(() => _isSaving = false);
        // Pass the path back via the callback
        widget.onImageCaptured(overlaid.path);
      }
    } catch (e) {
      print("Error during photo capture and save: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorDialog("Photo Capture Error", "Failed to capture photo: $e");
      }
    } finally {
      // Restart image stream if controller is still initialized
      if (_controller != null && _controller!.value.isInitialized && !_controller!.value.isStreamingImages) {
        _startColorDetection();
      }
    }
  }

  Widget _buildPlusOverlay(BuildContext context) {
    if (_focusColor == null || _focusColorName == null) return const SizedBox();
    final double plusSignSize = 80; // Define a consistent size for the plus sign area
    final double plusLength = plusSignSize * 0.4; // Adjust length relative to its container
    final double plusStroke = plusSignSize * 0.1; // Adjust stroke relative to its container

    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use min to wrap content
          children: [
            // Color name text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: _focusColor?.withOpacity(0.8) ?? Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _focusColorName!,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20), // Space between text and plus sign
            // Plus sign (CustomPainter)
            CustomPaint(
              size: Size(plusSignSize, plusSignSize), // Size for the CustomPainter
              painter: _PlusPainter(
                color: _focusColor!,
                plusLength: plusLength,
                plusStroke: plusStroke,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose(); // Use null-safe operator
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget previewWidget;
    if (_isCameraInitialized && _previewSize != null) {
      previewWidget = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!), // Use ! as we check _isCameraInitialized
          _buildPlusOverlay(context),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    const SizedBox(height: 16),
                    Text(
                      'Saving photo...',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else {
      previewWidget = Scaffold(
        appBar: AppBar(
          title: Text('Camera Loading', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)),
              SizedBox(height: 20),
              Text("Initializing camera...", style: TextStyle(fontSize: 18, color: Colors.black54)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: previewWidget,
      appBar: AppBar(
        title: Text('Center Pixel Color Identification', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)), // Title for this screen
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Camera toggle button for front/back camera
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: _toggleCamera,
              tooltip: 'Toggle Camera',
            ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _capturePhotoAndSave, // Disable button while saving
        heroTag: 'capturePhotoColorId', // Unique tag
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Rounded corners
        elevation: 6, // More prominent shadow
        child: const Icon(Icons.camera_alt, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Centered at the bottom
    );
  }
}

// Separate CustomPainter for just the plus sign
class _PlusPainter extends CustomPainter {
  final Color color;
  final double plusLength;
  final double plusStroke;

  _PlusPainter({
    required this.color,
    required this.plusLength,
    required this.plusStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) =>
      color != oldDelegate.color ||
      plusLength != oldDelegate.plusLength ||
      plusStroke != oldDelegate.plusStroke;
}

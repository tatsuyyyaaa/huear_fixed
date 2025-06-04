// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
// Removed: import 'dart:typed_data'; // Explicitly import Uint8List - no longer needed as Uint8List is from services.dart
import 'dart:ui' as ui; // Import for ui.Image, ui.PictureRecorder etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MethodChannel, PlatformException, SystemChannels, and Uint8List
import 'package:path_provider/path_provider.dart'; // For temporary file storage
import 'package:photo_manager/photo_manager.dart'; // For saving images to gallery
import 'package:camera/camera.dart'; // Using the camera package directly
import 'package:permission_handler/permission_handler.dart'; // For permission handling
import 'package:google_fonts/google_fonts.dart'; // For consistent typography

// --- Color Utility Functions ---
const Map<String, Color> namedColors = {
  "Red": Color(0xFFFF0000), "Green": Color(0xFF00FF00), "Blue": Color(0xFF0000FF),
  "Yellow": Color(0xFFFF0000), "Cyan": Color(0xFF00FFFF), "Magenta": Color(0xFFFF00FF),
  "Orange": Color(0xFFFFA500), "Pink": Color(0xFFFFC0CB), "Purple": Color(0xFF800080),
  "Brown": Color(0xFFA52A2A), "Black": Color(0xFF000000), "Gray": Color(0xFF808080),
  "White": Color(0xFFFFFFFF), "Lime": Color(0xFF00FF00), "Maroon": Color(0xFF800000),
  "Navy": Color(0xFF000080), "Olive": Color(0xFF808000), "Teal": Color(0xFF008080),
  "Silver": Color(0xFFC0C0C0), "Gold": Color(0xFFFFD700), "Beige": Color(0xFFF5F5DC),
  "Coral": Color(0xFFFA8072), "Indigo": Color(0xFF4B0082), "SkyBlue": Color(0xFF87CEEB),
  "Violet": Color(0xFFEE82EE), "Turquoise": Color(0xFF40E0D0), "Salmon": Color(0xFFFA8072),
  "Khaki": Color(0xFFF0E68C), "Plum": Color(0xFFDDA0DD), "Chocolate": Color(0xFFD2691E),
  "FireBrick": Color(0xFFB22222), "Peru": Color(0xFFCD853F), "SeaGreen": Color(0xFF2E8B57),
  "SlateBlue": Color(0xFF6A5ACD), "Tomato": Color(0xFFFF6347), "Wheat": Color(0xFFF5DEB3),
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

// Class to represent a detected object with its bounding box, label, and confidence.
class DetectedObject {
  final RectF boundingBox;
  final String label;
  final double confidence;
  final Color? color; // Added for color detection result

  DetectedObject({
    required this.boundingBox,
    required this.label,
    required this.confidence,
    this.color,
  });

  @override
  String toString() {
    return 'DetectedObject(label: $label, confidence: ${confidence.toStringAsFixed(2)}, boundingBox: $boundingBox, color: $color)';
  }
}

// Helper class to represent a rectangle (used for object detection bounding boxes).
class RectF {
  final double left;
  final double top;
  final double right;
  final double bottom;

  RectF(this.left, this.top, this.right, this.bottom);

  @override
  String toString() {
    return 'RectF(left: ${left.toStringAsFixed(2)}, top: ${top.toStringAsFixed(2)}, right: ${right.toStringAsFixed(2)}, bottom: ${bottom.toStringAsFixed(2)})';
  }
}

// --- ARColorDetectorScreen Widget (Camera Screen with Overlays) ---
class ARColorDetectorScreen extends StatefulWidget {
  final void Function(String imagePath) onImageCaptured;

  const ARColorDetectorScreen({super.key, required this.onImageCaptured});

  @override
  State<ARColorDetectorScreen> createState() => _ARColorDetectorScreenState();
}

class _ARColorDetectorScreenState extends State<ARColorDetectorScreen> {
  static const platform = MethodChannel('com.example.huear_fixed/object_detection');

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0; // Index of the currently selected camera
  bool _isCameraInitialized = false;
  bool _isDetecting = false; // Flag to prevent multiple detections on the same frame
  bool _isCapturing = false; // New state variable for loading indicator

  final List<DetectedObject> _currentDetections = []; // Store all detected objects
  Color? _detectedColorAverage; // Average color of the primary detected object
  String? _primaryDetectedObjectName; // Label of the primary detected object

  // Removed performance metrics fields as they are no longer displayed in the UI.
  // String _inferenceTime = "N/A";
  // String _totalPredictionTime = "N/A";
  // String _preProcessingTime = "N/A";
  // String _frameDimensions = "N/A";

  // Confidence threshold for displaying detections
  static const double _confidenceThreshold = 0.0; 

  // Current resolution preset, defaulting to low
  ResolutionPreset _currentResolutionPreset = ResolutionPreset.low;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Dispose existing controller if any
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
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

    // Initialize camera controller with the current resolution preset and selected camera
    _cameraController = CameraController(
      _cameras![_selectedCameraIdx], // Use the selected camera
      _currentResolutionPreset, // Use the selected resolution preset
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Optimal for ML Kit on Android
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        // Removed _frameDimensions update as it's no longer used in UI
        // _frameDimensions = "${_cameraController!.value.previewSize!.width.toInt()} x ${_cameraController!.value.previewSize!.height.toInt()}";
      });
      // Start image stream for continuous processing of frames
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isDetecting) {
          _isDetecting = true;
          _processCameraImage(image);
        }
      });
    } on CameraException catch (e) {
      print("Error initializing camera: $e");
      _showErrorDialog("Camera Error", "Failed to initialize camera: ${e.description}");
      if (mounted) Navigator.of(context).pop();
    }
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

    await _initializeCamera(); // Re-initialize camera with the new selection
  }

  // Converts CameraImage to RGBA bytes and sends to native for detection
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    final Uint8List? rgbaBytes = convertYUV400toRGBA(cameraImage);
    if (rgbaBytes == null) {
      _isDetecting = false;
      return;
    }

    final int width = cameraImage.width;
    final int height = cameraImage.height;

    await _detectObjects(rgbaBytes, width, height);
    _isDetecting = false;
  }

  // Converts CameraImage (YUV420_888) to an RGBA Uint8List.
  Uint8List? convertYUV400toRGBA(CameraImage cameraImage) {
    if (cameraImage.format.group != ImageFormatGroup.yuv420) {
      print("Unsupported image format: ${cameraImage.format.group}");
      return null;
    }

    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;

    final Uint8List rgbaBytes = Uint8List(width * height * 4); // Allocate RGBA buffer

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int Y = yPlane[y * width + x];
        final int U = uPlane[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];
        final int V = vPlane[(y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride];

        // YUV to RGB conversion (simplified)
        int R = (Y + V * 1.402).round().clamp(0, 255);
        int G = (Y - U * 0.344136 - V * 0.714136).round().clamp(0, 255);
        int B = (Y + U * 1.772).round().clamp(0, 255);

        final int rgbaIndex = (y * width + x) * 4;
        rgbaBytes[rgbaIndex] = R;
        rgbaBytes[rgbaIndex + 1] = G;
        rgbaBytes[rgbaIndex + 2] = B;
        rgbaBytes[rgbaIndex + 3] = 255; // Alpha channel
      }
    }
    return rgbaBytes;
  }

  void _showPermissionDeniedDialog({bool isPermanent = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Denied"),
        content: Text(isPermanent
            ? "Camera access is permanently denied. Please go to app settings to enable it."
            : "Camera access is required to use this feature."),
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
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _detectObjects(List<int> bytes, int width, int height) async {
    // Removed stopwatch as performance metrics are no longer displayed.
    // final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final Map<Object?, Object?>? rawResult = await platform.invokeMethod('detectObjects', {
        'bytes': bytes,
        'width': width,
        'height': height,
      });

      final Map<String, dynamic>? result = rawResult?.cast<String, dynamic>();

      // print("Flutter: Received raw result from Kotlin: $rawResult"); // Log raw result
      // print("Flutter: Casted result: $result"); // Log casted result

      // Removed stopwatch.stop();

      setState(() {
        _currentDetections.clear();
        _primaryDetectedObjectName = null;
        _detectedColorAverage = null;

        if (result != null && result['objects'] != null) {
          final List<dynamic> objects = result['objects'] as List<dynamic>;
          // print("Flutter: Number of objects received: ${objects.length}"); // Log number of objects

          List<DetectedObject> highConfidenceDetections = [];
          DetectedObject? mostConfidentObject;
          double maxConfidence = -1.0;

          for (var obj in objects) {
            final Map<String, dynamic> objMap = obj.cast<String, dynamic>();
            final RectF rect = RectF(
              objMap['left'] as double,
              objMap['top'] as double,
              objMap['right'] as double,
              objMap['bottom'] as double,
            );
            final double confidence = objMap['confidence'] ?? 0.0;
            final String label = objMap['label'] ?? 'Unknown';

            // print("Flutter: Raw detected object: Label='$label', Confidence='$confidence', BoundingBox='${rect}'");

            if (confidence >= _confidenceThreshold) {
              final detectedObj = DetectedObject(
                boundingBox: rect,
                label: label,
                confidence: confidence,
              );
              highConfidenceDetections.add(detectedObj);
              // print("Flutter: Added high confidence object: $detectedObj");

              if (confidence > maxConfidence) {
                maxConfidence = confidence;
                mostConfidentObject = detectedObj;
              }
            }
          }

          _currentDetections.addAll(highConfidenceDetections); // Only add high confidence detections

          if (mostConfidentObject != null) {
            _primaryDetectedObjectName = mostConfidentObject.label;
            _analyzeColorOfObject(bytes, width, height, mostConfidentObject.boundingBox, mostConfidentObject.label);
          }
        } else {
          // print("Flutter: No objects key or result is null.");
        }

        // Removed performance metrics updates
        // _inferenceTime = "${result?['inferenceTimeMs']?.toStringAsFixed(0) ?? 'N/A'} ms";
        // _totalPredictionTime = "${stopwatch.elapsedMilliseconds} ms";
        // _preProcessingTime = "${result?['preProcessingTimeMs']?.toStringAsFixed(0) ?? 'N/A'} ms";
      });
    } on PlatformException catch (e) {
      print("Error during object detection: '${e.message}'");
      _showErrorDialog("Detection Error", "Failed to detect objects: ${e.message}");
    } catch (e) {
      print("Unexpected error during object detection: $e");
      _showErrorDialog("Error", "An unexpected error occurred: $e");
    }
  }

  Future<void> _analyzeColorOfObject(List<int> imageBytes, int width, int height, RectF detectionRect, String objectName) async {
    int r = 0, g = 0, b = 0;
    int pixelCount = 0;

    int left = (detectionRect.left * width).toInt().clamp(0, width - 1);
    int top = (detectionRect.top * height).toInt().clamp(0, height - 1);
    int right = (detectionRect.right * width).toInt().clamp(0, width - 1);
    int bottom = (detectionRect.bottom * height).toInt().clamp(0, height - 1);

    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        int offset = (y * width + x) * 4;
        if (offset + 3 < imageBytes.length) {
          r += imageBytes[offset];
          g += imageBytes[offset + 1];
          b += imageBytes[offset + 2];
          pixelCount++;
        }
      }
    }

    Color averageColor = Colors.grey;
    if (pixelCount > 0) {
      averageColor = Color.fromRGBO(r ~/ pixelCount, g ~/ pixelCount, b ~/ pixelCount, 1.0);
    }

    setState(() {
      _detectedColorAverage = averageColor;
    });
    // print("Flutter: Analyzed color for '$objectName': $averageColor (${getClosestColorName(averageColor)})");
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera not initialized for photo capture.");
      _showErrorDialog("Capture Error", "Camera is not ready to capture photo.");
      return;
    }

    setState(() {
      _isCapturing = true; // Show loading indicator
    });

    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final rawBytes = await imageFile.readAsBytes(); // Read raw bytes from XFile

      // Decode raw bytes to ui.Image to get proper dimensions and potentially handle orientation
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final ui.Image uiImage = frame.image;

      // Encode ui.Image back to PNG bytes. This re-bakes the image.
      final pngBytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      
      final tempDir = await getTemporaryDirectory();
      final newFile = File('${tempDir.path}/detected_photo_${DateTime.now().millisecondsSinceEpoch}.png');
      await newFile.writeAsBytes(pngBytes!.buffer.asUint8List()); // Save the re-encoded PNG bytes
      await PhotoManager.editor.saveImageWithPath(newFile.path);
      widget.onImageCaptured(newFile.path);

    } catch (e) {
      print("Error during photo capture: $e");
      _showErrorDialog("Photo Capture Error", "Failed to capture photo: $e");
    } finally {
      setState(() {
        _isCapturing = false; // Hide loading indicator
      });
      if (_cameraController != null && _cameraController!.value.isInitialized && !_cameraController!.value.isStreamingImages) {
        _cameraController!.startImageStream((CameraImage image) {
          if (!_isDetecting) {
            _isDetecting = true;
            _processCameraImage(image);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
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

    // Determine the appropriate aspect ratio for CameraPreview
    final cameraAspectRatio = _cameraController!.value.aspectRatio;

    return Scaffold(
      appBar: AppBar(
        title: Text('Object & Color Detector', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Dropdown for selecting camera resolution
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ResolutionPreset>(
                value: _currentResolutionPreset,
                dropdownColor: Colors.black87,
                icon: const Icon(Icons.settings_overscan, color: Colors.white),
                onChanged: (ResolutionPreset? newValue) {
                  if (newValue != null && newValue != _currentResolutionPreset) {
                    setState(() {
                      _currentResolutionPreset = newValue;
                      _isCameraInitialized = false; // Re-initialize camera
                    });
                    _initializeCamera(); // Re-initialize camera with new resolution
                  }
                },
                items: ResolutionPreset.values.map<DropdownMenuItem<ResolutionPreset>>((ResolutionPreset value) {
                  return DropdownMenuItem<ResolutionPreset>(
                    value: value,
                    child: Text(
                      value.toString().split('.').last, // e.g., "low", "medium"
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Camera toggle button moved to AppBar actions
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: _toggleCamera,
              tooltip: 'Toggle Camera',
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: cameraAspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ObjectDetectionPainter(
                detections: _currentDetections,
                cameraPreviewSize: _cameraController!.value.previewSize!,
              ),
            ),
          ),
          // Primary Detected Object Name and Color Overlay
          if (_primaryDetectedObjectName != null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: _detectedColorAverage?.withOpacity(0.8) ?? Colors.black.withOpacity(0.8),
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
                    'Detected: $_primaryDetectedObjectName (${getClosestColorName(_detectedColorAverage!)})',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          else
            // Message when no objects are detected
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    'No objects detected',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 18),
                  ),
                ),
              ),
            ),
          // Loading indicator overlay for photo capture
          if (_isCapturing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Capturing photo...',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCapturing ? null : _capturePhoto, // Disable button while capturing
        heroTag: 'capturePhoto', // Unique tag
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Rounded corners
        elevation: 6, // More prominent shadow
        child: const Icon(Icons.camera_alt, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Centered at the bottom
    );
  }
}

// CustomPainter to draw bounding boxes and labels on the camera preview
class ObjectDetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final Size cameraPreviewSize;

  ObjectDetectionPainter({required this.detections, required this.cameraPreviewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent; // Bounding box color

    for (var detection in detections) {
      // Scale bounding box coordinates from normalized (0-1) to screen pixels
      final double x = detection.boundingBox.left * size.width;
      final double y = detection.boundingBox.top * size.height;
      final double width = (detection.boundingBox.right - detection.boundingBox.left) * size.width;
      final double height = (detection.boundingBox.bottom - detection.boundingBox.top) * size.height;
      
      final Rect rect = Rect.fromLTWH(x, y, width, height);
      canvas.drawRect(rect, paint);

      // Draw text background
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.inter( // Use GoogleFonts for consistency
            color: Colors.black,
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final Rect textBgRect = Rect.fromLTWH(
        x,
        y - textPainter.height - 5, // Position text above the bounding box
        textPainter.width + 10,
        textPainter.height + 5,
      );
      canvas.drawRect(textBgRect, Paint()..color = Colors.greenAccent);

      textPainter.paint(canvas, Offset(x + 5, y - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant ObjectDetectionPainter oldDelegate) {
    // Only repaint if detections or camera preview size changes
    return oldDelegate.detections != detections ||
           oldDelegate.cameraPreviewSize != cameraPreviewSize;
  }
}

// Extension to provide firstWhereOrNull for older Dart versions if needed
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

package com.example.huear_fixed

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.Bitmap
import android.util.Log
import java.nio.ByteBuffer
import java.util.ArrayList
import java.util.HashMap // Explicitly import HashMap

// Import necessary Google ML Kit classes
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.ObjectDetector
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.huear_fixed/object_detection"
    private lateinit var objectDetector: ObjectDetector

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val options = ObjectDetectorOptions.Builder()
            .setDetectorMode(ObjectDetectorOptions.STREAM_MODE)
            .enableMultipleObjects()
            .enableClassification()
            .build()
        objectDetector = ObjectDetection.getClient(options)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "detectObjects") {
                val bytes = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")

                Log.d("ObjectDetection", "Kotlin: Received bytes length: ${bytes?.size}")
                Log.d("ObjectDetection", "Kotlin: Received width: $width, height: $height")

                if (bytes != null && width != null && height != null) {
                    detectObjects(bytes, width, height, result)
                } else {
                    result.error("UNAVAILABLE", "Image data was null or dimensions missing.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun detectObjects(@NonNull bytes: ByteArray, @NonNull width: Int, @NonNull height: Int, @NonNull result: MethodChannel.Result) {
        val preProcessingStopwatch = System.currentTimeMillis()

        val bitmap: Bitmap?
        try {
            val buffer = ByteBuffer.wrap(bytes)
            Log.d("ObjectDetection", "Kotlin: ByteBuffer capacity: ${buffer.capacity()}")
            Log.d("ObjectDetection", "Kotlin: Expected Bitmap size (width*height*4): ${width * height * 4}")

            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.copyPixelsFromBuffer(buffer)
        } catch (e: Exception) {
            Log.e("ObjectDetection", "Error creating bitmap or copying pixels: ${e.localizedMessage}", e)
            result.error("BITMAP_CONVERSION_FAILED", "Error converting image buffer to bitmap: ${e.localizedMessage}", null)
            return
        }

        if (bitmap == null) {
            result.error("BITMAP_NULL", "Bitmap creation failed.", null)
            return
        }

        val preProcessingTimeMs = System.currentTimeMillis() - preProcessingStopwatch
        val inferenceStopwatch = System.currentTimeMillis()

        val image = InputImage.fromBitmap(bitmap, 0)

        objectDetector.process(image)
            .addOnSuccessListener { detectedObjects ->
                val inferenceTimeMs = System.currentTimeMillis() - inferenceStopwatch

                Log.d("ObjectDetection", "Kotlin: ML Kit detected ${detectedObjects.size} objects.")
                val objectResults = ArrayList<HashMap<String, Any>>()
                for (i in detectedObjects.indices) {
                    val obj = detectedObjects[i]
                    val boundingBox = obj.boundingBox
                    val detection = HashMap<String, Any>()

                    detection["left"] = boundingBox.left.toDouble() / width
                    detection["top"] = boundingBox.top.toDouble() / height
                    detection["right"] = boundingBox.right.toDouble() / width
                    detection["bottom"] = boundingBox.bottom.toDouble() / height

                    if (obj.labels.isNotEmpty()) {
                        val label = obj.labels[0]
                        detection["label"] = label.text
                        detection["confidence"] = label.confidence.toDouble()
                        Log.d("ObjectDetection", "Kotlin: Detected object ${i+1}: Label='${label.text}', Confidence='${label.confidence}', BoundingBox='${boundingBox}'")
                    } else {
                        detection["label"] = "unknown"
                        detection["confidence"] = 0.0
                        Log.d("ObjectDetection", "Kotlin: Detected object ${i+1}: Label='unknown', Confidence='0.0', BoundingBox='${boundingBox}'")
                    }
                    objectResults.add(detection)
                }
                val resultMap: Map<String, Any> = mapOf(
                    "objects" to objectResults,
                    "inferenceTimeMs" to inferenceTimeMs,
                    "preProcessingTimeMs" to preProcessingTimeMs
                )
                result.success(resultMap)
            }
            .addOnFailureListener { e ->
                Log.e("ObjectDetection", "ML Kit object detection failed: ${e.message}", e)
                result.error("DETECTION_FAILED", "ML Kit object detection failed: ${e.message}", null)
            }
            .addOnCompleteListener {
                // For STREAM_MODE, the detector is typically kept open.
                // It is closed in onDestroy.
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        objectDetector.close()
    }
}

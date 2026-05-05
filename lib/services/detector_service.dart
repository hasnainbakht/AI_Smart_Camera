import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectionResult {
  final String label;
  final double confidence;
  final double top, left, bottom, right; // normalized 0.0–1.0

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });

  // Center of bounding box (normalized)
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

class DetectorService {
  static const int INPUT_SIZE = 300;
  static const int NUM_RESULTS = 10;
  static const double CONFIDENCE_THRESHOLD = 0.5;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    await _loadModel();
    await _loadLabels();
    _isInitialized = true;
  }

  Future<void> _loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/ssd_mobilenet_v2_coco_quant.tflite',
        options: options,
      );
    } catch (e) {
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  Future<void> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/coco_labels.txt');
    _labels = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Run inference on a raw camera image (JPEG/PNG bytes)
  Future<List<DetectionResult>> detect(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) return [];

    // Decode and resize to 300x300
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return [];

    final resized = img.copyResize(decoded,
        width: INPUT_SIZE, height: INPUT_SIZE);

    // Build input tensor [1, 300, 300, 3] as Uint8
    final inputBytes = Uint8List(1 * INPUT_SIZE * INPUT_SIZE * 3);
    int idx = 0;
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = resized.getPixel(x, y);
        inputBytes[idx++] = pixel.r.toInt();
        inputBytes[idx++] = pixel.g.toInt();
        inputBytes[idx++] = pixel.b.toInt();
      }
    }

    final input = inputBytes.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);

    // Output tensors
    // [0] boxes:   [1, 10, 4]
    // [1] classes: [1, 10]
    // [2] scores:  [1, 10]
    // [3] count:   [1]
    final boxes =
        List.generate(1, (_) => List.generate(NUM_RESULTS, (_) => List.filled(4, 0.0)));
    final classes =
        List.generate(1, (_) => List.filled(NUM_RESULTS, 0.0));
    final scores =
        List.generate(1, (_) => List.filled(NUM_RESULTS, 0.0));
    final count = List.filled(1, 0.0);

    final outputs = {
      0: boxes,
      1: classes,
      2: scores,
      3: count,
    };

    _interpreter!.runForMultipleInputs([input], outputs);

    // Parse results
    final results = <DetectionResult>[];
    final numDetected = count[0].toInt().clamp(0, NUM_RESULTS);

    for (int i = 0; i < numDetected; i++) {
      final score = scores[0][i];
      if (score < CONFIDENCE_THRESHOLD) continue;

      final classIndex = classes[0][i].toInt();
      final label = (classIndex < _labels.length)
          ? _labels[classIndex]
          : 'Unknown';

      results.add(DetectionResult(
        label: label,
        confidence: score,
        top: boxes[0][i][0],
        left: boxes[0][i][1],
        bottom: boxes[0][i][2],
        right: boxes[0][i][3],
      ));
    }

    return results;
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────
// IMAGE ANALYSIS ENGINE (pure pixel math)
// ─────────────────────────────────────────────

/// Reads image bytes from [file], decodes, and computes 5 real scores.
/// All values are normalised to [0.0 – 1.0].
Future<Map<String, double>> analyzeImage(File file) async {
  final bytes = await file.readAsBytes();

  // Decode to RGBA pixel grid (scales down for speed if very large)
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Could not decode image.');

  // Downscale large images so analysis stays fast on-device
  if (decoded.width > 800 || decoded.height > 800) {
    decoded = img.copyResize(decoded, width: 800);
  }

  final int w = decoded.width;
  final int h = decoded.height;
  final int total = w * h;

  // ── collect per-pixel luminance (0.0–1.0) ──────────────────────────────
  final List<double> luma = List<double>.filled(total, 0);
  final List<double> rList = List<double>.filled(total, 0);
  final List<double> gList = List<double>.filled(total, 0);
  final List<double> bList = List<double>.filled(total, 0);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pixel = decoded.getPixel(x, y);
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;
      final idx = y * w + x;
      rList[idx] = r;
      gList[idx] = g;
      bList[idx] = b;
      // ITU-R BT.601 luminance
      luma[idx] = 0.299 * r + 0.587 * g + 0.114 * b;
    }
  }

  // ── 1. LIGHTING: average luminance, penalise extremes ──────────────────
  final double avgLuma = luma.reduce((a, b) => a + b) / total;
  // Peak score ~0.45 luma (natural, well-exposed); drops toward 0 or 1
  final double lightingScore = 1.0 - (2.0 * (avgLuma - 0.45).abs()).clamp(0.0, 1.0);

  // ── 2. CONTRAST: standard deviation of luminance ──────────────────────
  final double lumaMean = avgLuma;
  double variance = 0;
  for (final l in luma) {
    variance += (l - lumaMean) * (l - lumaMean);
  }
  variance /= total;
  final double stdDev = sqrt(variance); // theoretical max ~0.5
  final double contrastScore = (stdDev / 0.35).clamp(0.0, 1.0);

  // ── 3. SHARPNESS: Laplacian-like edge energy ───────────────────────────
  double edgeEnergy = 0;
  int edgeSamples = 0;
  // Traverse interior pixels only (skip border)
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final c = luma[y * w + x];
      final l = luma[y * w + (x - 1)];
      final r = luma[y * w + (x + 1)];
      final u = luma[(y - 1) * w + x];
      final d = luma[(y + 1) * w + x];
      // Discrete Laplacian: |4c - l - r - u - d|
      final lap = (4 * c - l - r - u - d).abs();
      edgeEnergy += lap;
      edgeSamples++;
    }
  }
  final double avgEdge = edgeSamples > 0 ? edgeEnergy / edgeSamples : 0;
  // Sharp images typically score 0.04–0.15; normalise to 0.15 ceiling
  final double sharpnessScore = (avgEdge / 0.12).clamp(0.0, 1.0);

  // ── 4. COLOR ACCURACY: RGB balance + saturation spread ────────────────
  final double avgR = rList.reduce((a, b) => a + b) / total;
  final double avgG = gList.reduce((a, b) => a + b) / total;
  final double avgB = bList.reduce((a, b) => a + b) / total;
  // Max imbalance if one channel dominates → distance from neutral grey
  final double channelMean = (avgR + avgG + avgB) / 3.0;
  final double imbalance = ((avgR - channelMean).abs() +
          (avgG - channelMean).abs() +
          (avgB - channelMean).abs()) /
      3.0;
  // Also reward colour variety (std dev across channels of per-pixel max-min)
  double satSum = 0;
  for (int i = 0; i < total; i++) {
    final mx = max(rList[i], max(gList[i], bList[i]));
    final mn = min(rList[i], min(gList[i], bList[i]));
    satSum += (mx - mn);
  }
  final double avgSat = satSum / total; // 0–1
  // Balance: low imbalance is good; saturation variety is good
  final double balanceScore = 1.0 - (imbalance * 4.0).clamp(0.0, 1.0);
  final double colorScore = ((balanceScore * 0.5) + (avgSat * 0.5)).clamp(0.0, 1.0);

  // ── 5. COMPOSITION: centre-weight + rule-of-thirds energy ─────────────
  // a) Saliency mass in the centre third vs full frame
  double centreSum = 0, totalEdgeSum = 0;
  final int x1 = w ~/ 3, x2 = 2 * w ~/ 3;
  final int y1 = h ~/ 3, y2 = 2 * h ~/ 3;
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final lap = (4 * luma[y * w + x] -
              luma[y * w + (x - 1)] -
              luma[y * w + (x + 1)] -
              luma[(y - 1) * w + x] -
              luma[(y + 1) * w + x])
          .abs();
      totalEdgeSum += lap;
      if (x >= x1 && x <= x2 && y >= y1 && y <= y2) centreSum += lap;
    }
  }
  // Rule-of-thirds intersection hotspot energy
  double roiSum = 0;
  final List<int> roiXs = [w ~/ 3, 2 * w ~/ 3];
  final List<int> roiYs = [h ~/ 3, 2 * h ~/ 3];
  const int roiRadius = 30;
  for (final rx in roiXs) {
    for (final ry in roiYs) {
      for (int dy = -roiRadius; dy <= roiRadius; dy++) {
        for (int dx = -roiRadius; dx <= roiRadius; dx++) {
          final nx = rx + dx;
          final ny = ry + dy;
          if (nx >= 1 && nx < w - 1 && ny >= 1 && ny < h - 1) {
            roiSum += (4 * luma[ny * w + nx] -
                    luma[ny * w + (nx - 1)] -
                    luma[ny * w + (nx + 1)] -
                    luma[(ny - 1) * w + nx] -
                    luma[(ny + 1) * w + nx])
                .abs();
          }
        }
      }
    }
  }
  final double roiArea = (4 * (2 * roiRadius + 1) * (2 * roiRadius + 1)).toDouble();
  final double roiAvg = roiArea > 0 ? roiSum / roiArea : 0;
  final double totalAvgEdge =
      (edgeSamples > 0 ? totalEdgeSum / edgeSamples : 0.001);
  // Combine: rule-of-thirds energy relative to overall + aspect ratio bonus
  final double roiBonus = (roiAvg / (totalAvgEdge + 1e-9)).clamp(0.0, 2.0) / 2.0;
  final double aspectRatio = w / h.toDouble();
  // Classic compositions: portrait ~0.67, square 1.0, landscape ~1.33 or 1.78
  double aspectBonus = 0.5;
  if ((aspectRatio - 1.78).abs() < 0.15 ||
      (aspectRatio - 1.33).abs() < 0.12 ||
      (aspectRatio - 0.75).abs() < 0.12 ||
      (aspectRatio - 1.0).abs() < 0.08) {
    aspectBonus = 1.0;
  }
  final double compositionScore =
      ((roiBonus * 0.6) + (aspectBonus * 0.4)).clamp(0.0, 1.0);

  return {
    'Composition': _round(compositionScore),
    'Lighting': _round(lightingScore),
    'Sharpness': _round(sharpnessScore),
    'Color Accuracy': _round(colorScore),
    'Contrast': _round(contrastScore),
  };
}

double _round(double v) => double.parse(v.clamp(0.0, 1.0).toStringAsFixed(3));

// ─────────────────────────────────────────────
// RATING SCREEN
// ─────────────────────────────────────────────

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  File? _imageFile;
  Map<String, double>? _scores;
  bool _isAnalyzing = false;
  String? _errorMessage;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result == null) return;

    final file = File(result.path);
    setState(() {
      _imageFile = file;
      _scores = null;
      _errorMessage = null;
      _isAnalyzing = true;
    });

    try {
      final scores = await analyzeImage(file);
      if (mounted) {
        setState(() {
          _scores = scores;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Analysis failed: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  Widget _ratingBar(String label, double value) {
    final pct = (value * 100).toInt();
    final Color barColor = _scoreColor(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600)),
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 13,
                      color: barColor,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: constraints.maxWidth * value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor.withOpacity(0.7), barColor],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double v) {
    if (v >= 0.75) return const Color(0xFF4DFFA0);
    if (v >= 0.5) return const Color(0xFFFFD04D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
        ),
        title: const Text(
          'AI Image Rating',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── IMAGE PREVIEW ──────────────────────────────────────────
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _imageFile!,
                  height: 230,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 230,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: Colors.white38, size: 48),
                        SizedBox(height: 10),
                        Text('Tap to Upload Image',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── LOADING ────────────────────────────────────────────────
            if (_isAnalyzing)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 14),
                      Text('Analysing pixels…',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),

            // ── ERROR ──────────────────────────────────────────────────
            if (_errorMessage != null && !_isAnalyzing)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ── RESULTS ────────────────────────────────────────────────
            if (_scores != null && !_isAnalyzing)
              Expanded(
                child: ListView(
                  children: [
                    const Text('Analysis Results',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),

                    ..._scores!.entries
                        .map((e) => _ratingBar(e.key, e.value)),

                    const SizedBox(height: 20),

                    // OVERALL SCORE
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Text('Overall Score',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text(
                            '${(_scores!.values.reduce((a, b) => a + b) / _scores!.length * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 40,
                              color: _scoreColor(_scores!.values
                                      .reduce((a, b) => a + b) /
                                  _scores!.length),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ACTION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: pickImage,
                            child: const Text('Retake',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              // TODO: implement save
                            },
                            child: const Text('Save',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
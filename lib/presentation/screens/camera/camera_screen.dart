// camera_screen.dart — OPTIMIZED FOR REAL-TIME PERFORMANCE
//
// Key optimizations vs original:
//   1. Hard frame-rate cap: processes max 3 FPS via timestamp gate
//   2. Atomic _isAnalyzing flag prevents any overlapping inference
//   3. Direct YUV420 → packed RGB888 via compute() isolate — no JPEG round-trip
//   4. compute() offloads the pixel loop to a background isolate automatically
//   5. Camera resolution set to low (480p) — still fine for 300×300 model input
//   6. setState() only called when guidance result actually changes → fewer rebuilds
//   7. Debug overlay toggle available; set kShowDebugOverlay = false for release

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:smart_camera/services/capture_storage_service.dart';
import '../../../core/utils/overlay_painter.dart';
import '../../widgets/permission_popup.dart';
import '../../../services/detector_service.dart';
import '../../../services/guidance_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// ─── Debug flag — set false before shipping ───────────────────────────────────
const bool kShowDebugOverlay = true;

// ─── Target inference rate ────────────────────────────────────────────────────
/// Minimum milliseconds between inference calls → max ~3 FPS of detection.
/// Camera preview always runs at full 30 FPS regardless.
const int _kInferenceIntervalMs = 333; // 1000 / 3 ≈ 333 ms

// ─── Top-level helper for compute() ──────────────────────────────────────────

/// Data class passed to the background isolate via compute().
class _YuvConvertParams {
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int width;
  final int height;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  const _YuvConvertParams({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });
}

/// Pure function — runs in a background isolate via compute().
/// Returns packed RGB888 bytes (width * height * 3).
Uint8List _yuvToRgbIsolate(_YuvConvertParams p) {
  final out = Uint8List(p.width * p.height * 3);
  int outIdx = 0;

  for (int row = 0; row < p.height; row++) {
    for (int col = 0; col < p.width; col++) {
      final yIdx = row * p.yRowStride + col;
      final uvIdx = (row >> 1) * p.uvRowStride + (col >> 1) * p.uvPixelStride;

      final yy = p.yBytes[yIdx.clamp(0, p.yBytes.length - 1)];
      final uu = p.uBytes[uvIdx.clamp(0, p.uBytes.length - 1)];
      final vv = p.vBytes[uvIdx.clamp(0, p.vBytes.length - 1)];

      // BT.601 full-range
      final c = yy - 16;
      final d = uu - 128;
      final e = vv - 128;

      out[outIdx++] = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
      out[outIdx++] = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
      out[outIdx++] = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ─── Camera ───────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool flashOn = false;
  bool useFrontCamera = false;

  // ─── UI Toggles ───────────────────────────────────────────────────────────
  bool showThirds = true;
  bool showCenter = true;
  bool showGolden = false;
  bool _showProPanel = false;

  // ─── Hardware-backed ranges ───────────────────────────────────────────────
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _exposure = 0.0;
  double _zoom = 1.0;

  // ─── Preview-only adjustments ─────────────────────────────────────────────
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _isoSim = 100;

  bool _initializing = true;

  // ─── AI Services ──────────────────────────────────────────────────────────
  final DetectorService _detector = DetectorService();
  final GuidanceService _guidance = GuidanceService();

  bool _detectorReady = false;

  /// Atomic guard — set to true when inference is in flight.
  /// Prevents any overlapping detect() calls.
  bool _isAnalyzing = false;

  GuidanceResult _guidanceResult = GuidanceResult(
    status: PlacementStatus.noObject,
    message: 'Initializing AI…',
    placementScore: 0,
  );

  /// Timestamp of the last inference start — used for rate limiting.
  int _lastAnalysisMs = 0;

  // ─── Debug counters ───────────────────────────────────────────────────────
  int _framesReceived = 0;
  int _framesProcessed = 0;
  int _lastDetectionCount = 0;
  double _lastConfidence = 0.0;

  // ─── Life-cycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream();
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.stopImageStream();
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─── Detector init ────────────────────────────────────────────────────────
  Future<void> _initDetector() async {
    debugPrint('[AI] Initializing DetectorService…');
    try {
      await _detector.initialize();
      if (mounted) setState(() => _detectorReady = true);
      debugPrint('[AI] DetectorService ready ✅');
    } catch (e) {
      debugPrint('[AI] ❌ DetectorService failed: $e');
      if (mounted) {
        setState(() => _guidanceResult = GuidanceResult(
              status: PlacementStatus.noObject,
              message: 'AI model failed to load.',
              placementScore: 0,
            ));
      }
    }
  }

  // ─── Permissions & camera init ────────────────────────────────────────────
  Future<void> _checkPermissionsAndInit() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => PermissionPopup(
          onGranted: () {
            Navigator.of(context).pop();
            _checkPermissionsAndInit();
          },
        ),
      );
      return;
    }
    _cameras = await availableCameras();
    debugPrint('[CAMERA] ${_cameras?.length ?? 0} camera(s) found');
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final camera = useFrontCamera
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first)
        : _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first);

    debugPrint('[CAMERA] ${camera.name} (${camera.lensDirection.name})');

    await _controller?.stopImageStream();
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      // ── OPTIMIZATION: low = 480p. Model only needs 300×300. ──────────────
      // Using 'medium' (720p) or higher wastes memory & CPU on downscaling.
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      debugPrint('[CAMERA] Preview size: ${_controller!.value.previewSize}');

      try {
        _minExposure = await _controller!.getMinExposureOffset();
        _maxExposure = await _controller!.getMaxExposureOffset();
      } catch (_) {}
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
      } catch (_) {}

      _exposure = _exposure.clamp(_minExposure, _maxExposure);
      _zoom = _zoom.clamp(_minZoom, _maxZoom);
      await _controller!.setExposureOffset(_exposure);
      await _controller!.setZoomLevel(_zoom);

      await _startImageStream();
    } catch (e) {
      debugPrint('[CAMERA] ❌ Init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera init error: $e')));
      }
    }

    if (mounted) setState(() => _initializing = false);
  }

  // ─── Image stream → AI ────────────────────────────────────────────────────
  Future<void> _startImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    debugPrint('[CAMERA] Starting image stream…');

    await _controller!.startImageStream((CameraImage image) {
      _framesReceived++;

      // ── Gate 1: detector must be ready ───────────────────────────────────
      if (!_detectorReady) return;

      // ── Gate 2: hard rate-limit — max ~3 FPS inference ───────────────────
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastAnalysisMs < _kInferenceIntervalMs) return;

      // ── Gate 3: no overlapping calls — atomic check ───────────────────────
      if (_isAnalyzing) return;

      _isAnalyzing = true;
      _lastAnalysisMs = nowMs;

      // Fire-and-forget; _isAnalyzing cleared in whenComplete
      _processFrame(image).whenComplete(() => _isAnalyzing = false);
    });

    debugPrint('[CAMERA] Image stream started ✅');
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      // ── Step 1: YUV→RGB in a background isolate via compute() ─────────────
      // compute() automatically spawns/reuses an isolate — no UI thread work.
      final Uint8List? rgbBytes = await _convertYuvToRgb(image);
      if (rgbBytes == null) {
        debugPrint('[FRAME] YUV conversion returned null — skipping');
        return;
      }

      // ── Step 2: run TFLite inference in the detector's dedicated isolate ──
      final detections = await _detector.detect(
        rgbBytes: rgbBytes,
        width: image.width,
        height: image.height,
      );

      // ── Step 3: analyze & update UI ───────────────────────────────────────
      final result = _guidance.analyze(detections);

      if (!mounted) return;

      // Only rebuild if something meaningful changed → fewer setState calls
      final changed = result.status != _guidanceResult.status ||
          result.placementScore != _guidanceResult.placementScore;

      if (changed || kShowDebugOverlay) {
        setState(() {
          _guidanceResult = result;
          _framesProcessed++;
          _lastDetectionCount = detections.length;
          _lastConfidence =
              detections.isEmpty ? 0.0 : detections.first.confidence;
        });
      }

      if (kDebugMode) {
        debugPrint('[AI] status=${result.status.name} '
            'score=${result.placementScore} '
            'detections=${detections.length}');
      }
    } catch (e, st) {
      debugPrint('[FRAME] ❌ Exception: $e\n$st');
    }
  }

  /// Converts a CameraImage (YUV420 / JPEG / BGRA8888) to packed RGB888.
  /// YUV conversion is dispatched to a background isolate via compute().
  Future<Uint8List?> _convertYuvToRgb(CameraImage image) async {
    try {
      if (image.format.group == ImageFormatGroup.jpeg) {
        // iOS JPEG path — DetectorService can decode, but we need raw RGB.
        // Use compute to decode JPEG → RGB off the UI thread.
        return await compute(_decodeJpegToRgb, image.planes[0].bytes);
      }

      if (image.format.group == ImageFormatGroup.yuv420) {
        final params = _YuvConvertParams(
          yBytes: image.planes[0].bytes,
          uBytes: image.planes[1].bytes,
          vBytes: image.planes[2].bytes,
          width: image.width,
          height: image.height,
          yRowStride: image.planes[0].bytesPerRow,
          uvRowStride: image.planes[1].bytesPerRow,
          uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        );
        // Offload pixel conversion to a background isolate
        return await compute(_yuvToRgbIsolate, params);
      }

      if (image.format.group == ImageFormatGroup.bgra8888) {
        return await compute(_bgraToRgb, _BgraParams(
          bytes: image.planes[0].bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: image.planes[0].bytesPerRow,
        ));
      }

      debugPrint('[FRAME] Unsupported format: ${image.format.group.name}');
      return null;
    } catch (e) {
      debugPrint('[FRAME] ❌ Conversion error: $e');
      return null;
    }
  }

  // ─── Camera controls ──────────────────────────────────────────────────────
  Future<void> _switchCamera() async {
    useFrontCamera = !useFrontCamera;
    setState(() => _initializing = true);
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      flashOn = !flashOn;
      await _controller!
          .setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Flash error: $e')));
      }
    }
  }

  Future<void> _setExposure(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    value = value.clamp(_minExposure, _maxExposure);
    try {
      await _controller!.setExposureOffset(value);
      setState(() => _exposure = value);
    } catch (_) {}
  }

  Future<void> _setZoom(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    value = value.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(value);
      setState(() => _zoom = value);
    } catch (_) {}
  }

  // Future<void> _capturePhoto() async {
  //   if (_controller == null || !_controller!.value.isInitialized) return;
  //   try {
  //     await _controller!.stopImageStream();
  //   } catch (_) {}
  //   try {
  //     final XFile file = await _controller!.takePicture();
  //     final payload = {
  //       'path': file.path,
  //       'placementScore': _guidanceResult.placementScore,
  //       'guidanceStatus': _guidanceResult.status.name,
  //       'filters': {
  //         'brightness': _brightness,
  //         'contrast': _contrast,
  //         'saturation': _saturation,
  //         'iso': _isoSim,
  //         'exposure': _exposure,
  //         'zoom': _zoom,
  //       },
  //     };
  //     if (mounted) context.push('/feedback', extra: payload);
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
  //       await _startImageStream();
  //     }
  //   }
  // }

Future<void> _capturePhoto() async {
  if (_controller == null || !_controller!.value.isInitialized) return;

  try {
    // Stop stream before capture (important for stability)
    await _controller!.stopImageStream();

    // Capture image
    final XFile file = await _controller!.takePicture();

    // Copy to temp directory (safer for gallery save)
    final directory = await getTemporaryDirectory();
    final String tempPath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final File savedImage = await File(file.path).copy(tempPath);

    // ==============================
    // SAVE TO GALLERY (FIXED)
    // ==============================
    final result = await SaverGallery.saveFile(
  filePath: savedImage.path,
  fileName: 'camera_${DateTime.now().millisecondsSinceEpoch}',
  skipIfExists: false,
);
final entry = await CaptureStorageService.instance.saveCapture(
  sourcePath: savedImage.path,
  placementScore: _guidanceResult.placementScore,
  guidanceStatus: _guidanceResult.status.name,
  filters: {
    'brightness': _brightness,
    'contrast': _contrast,
    'saturation': _saturation,
    'iso': _isoSim,
    'exposure': _exposure,
    'zoom': _zoom,
  },
);

if (entry != null) {
  debugPrint('Saved to app storage: ${entry.imagePath}');
}

    debugPrint("Saved to gallery: ${result.isSuccess}");

    // Restart stream after capture
    await _startImageStream();

    // Payload for next screen
    final payload = {
      'path': savedImage.path,
      'placementScore': _guidanceResult.placementScore,
      'guidanceStatus': _guidanceResult.status.name,
      'filters': {
        'brightness': _brightness,
        'contrast': _contrast,
        'saturation': _saturation,
        'iso': _isoSim,
        'exposure': _exposure,
        'zoom': _zoom,
      },
    };

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Image saved to gallery ✅'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
    ),
  );
      // context.push('/feedback', extra: payload);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
      await _startImageStream();
    }
  }
}

  // ─── Pro controls bottom sheet ────────────────────────────────────────────
  void _openProControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text('Pro Controls',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sliderControl(
              label: 'Exposure',
              value: _exposure,
              min: _minExposure,
              max: _maxExposure,
              onChanged: (v) {
                setState(() => _exposure = v);
                _controller?.setExposureOffset(v);
              },
            ),
            _sliderControl(
              label: 'Zoom',
              value: _zoom,
              min: _minZoom,
              max: _maxZoom,
              onChanged: (v) {
                setState(() => _zoom = v);
                _controller?.setZoomLevel(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Color matrix ─────────────────────────────────────────────────────────
  List<double> _colorMatrix() {
    final c = _contrast;
    final t = (1.0 - c) * 0.5 * 255.0;
    final cm = [
      c, 0, 0, 0, _brightness * 255 + t,
      0, c, 0, 0, _brightness * 255 + t,
      0, 0, c, 0, _brightness * 255 + t,
      0, 0, 0, 1, 0,
    ];
    final s = _saturation;
    const rW = 0.2126; const gW = 0.7152; const bW = 0.0722;
    final sr = (1 - s) * rW; final sg = (1 - s) * gW; final sb = (1 - s) * bW;
    final sm = [
      sr + s, sg,     sb,     0, 0,
      sr,     sg + s, sb,     0, 0,
      sr,     sg,     sb + s, 0, 0,
      0,      0,      0,      1, 0,
    ];
    final result = List.filled(20, 0.0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += cm[row * 5 + k] * sm[k * 5 + col];
        }
        v += cm[row * 5 + 4];
        result[row * 5 + col] = v;
      }
    }
    return result;
  }

  // ─── Guidance helpers ─────────────────────────────────────────────────────
  Color get _guidanceBubbleColor {
    switch (_guidanceResult.status) {
      case PlacementStatus.centered:
        return Colors.green.withOpacity(0.75);
      case PlacementStatus.noObject:
        return Colors.black.withOpacity(0.45);
      default:
        return Colors.orange.withOpacity(0.75);
    }
  }

  Color get _scoreColor {
    final s = _guidanceResult.placementScore;
    if (s >= 80) return Colors.greenAccent;
    if (s >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  // ─── Widget helpers ───────────────────────────────────────────────────────
  Widget _sliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white24,
          ),
        ],
      );

  Widget _miniStat(String text, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 12, color: Colors.greenAccent.withOpacity(0.9)),
            if (icon != null) const SizedBox(width: 4),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );

  Widget _sideButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, size: 26, color: Colors.white),
        ),
      );

  Widget _secondaryToolbar() => Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolbarBtn('Thirds', showThirds, (v) => setState(() => showThirds = v)),
            const SizedBox(width: 8),
            _toolbarBtn('Center', showCenter, (v) => setState(() => showCenter = v)),
            const SizedBox(width: 8),
            _toolbarBtn('Golden', showGolden, (v) => setState(() => showGolden = v)),
          ],
        ),
      );

  Widget _toolbarBtn(String title, bool value, ValueChanged<bool> onTap) =>
      GestureDetector(
        onTap: () => onTap(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color:
                value ? Colors.greenAccent.withOpacity(0.85) : Colors.white12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );

  Widget _captureButton() => GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          height: 84,
          width: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 24),
            ],
          ),
        ),
      );

  Widget _bottomNavBar(BuildContext context) => Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.black.withOpacity(0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomItem(Icons.home, 'Home', '/home'),
            _bottomItem(Icons.camera_alt, 'Camera', '/camera'),
            _bottomItem(Icons.video_library, 'Media', '/gallery'),
            _bottomItem(Icons.settings, 'Settings', '/settings'),
          ],
        ),
      );

  Widget _bottomItem(IconData icon, String label, String route) {
    final isActive = GoRouterState.of(context).uri.toString() == route;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 24,
              color: isActive ? Colors.greenAccent : Colors.white70),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.greenAccent : Colors.white60,
              )),
        ],
      ),
    );
  }

  // ─── Debug overlay ────────────────────────────────────────────────────────
  Widget _debugOverlay() {
    if (!kShowDebugOverlay) return const SizedBox.shrink();
    return Positioned(
      bottom: 160,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
              color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔬 DEBUG'),
              Text('Frames rcvd : $_framesReceived'),
              Text('Frames proc : $_framesProcessed'),
              Text('Detections  : $_lastDetectionCount'),
              Text('Confidence  : ${_lastConfidence.toStringAsFixed(3)}'),
              Text('Analyzing   : $_isAnalyzing'),
              Text('Status      : ${_guidanceResult.status.name}'),
              Text('Score       : ${_guidanceResult.placementScore}'),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colorMatrix = _colorMatrix();

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: _bottomNavBar(context),
      body: Stack(
        children: [
          // ── Camera preview — always full 30 FPS, unaffected by inference ──
          Positioned.fill(
            child: _controller != null && _controller!.value.isInitialized
                ? ColorFiltered(
                    colorFilter: ColorFilter.matrix(colorMatrix),
                    child: CameraPreview(_controller!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // ── Pro side panel ────────────────────────────────────────────────
          if (_showProPanel)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              left: 0,
              width: media.size.width * 0.6,
              child: Container(
                color: Colors.black87.withOpacity(0.95),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pro Controls',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () =>
                                setState(() => _showProPanel = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sliderControl(
                          label: 'Exposure',
                          value: _exposure,
                          min: _minExposure,
                          max: _maxExposure,
                          onChanged: (v) {
                            setState(() => _exposure = v);
                            _controller?.setExposureOffset(v);
                          }),
                      _sliderControl(
                          label: 'Zoom',
                          value: _zoom,
                          min: _minZoom,
                          max: _maxZoom,
                          onChanged: (v) {
                            setState(() => _zoom = v);
                            _controller?.setZoomLevel(v);
                          }),
                      _sliderControl(
                          label: 'Brightness',
                          value: _brightness,
                          min: -1,
                          max: 1,
                          onChanged: (v) => setState(() => _brightness = v)),
                      _sliderControl(
                          label: 'Contrast',
                          value: _contrast,
                          min: 0,
                          max: 4,
                          onChanged: (v) => setState(() => _contrast = v)),
                      _sliderControl(
                          label: 'Saturation',
                          value: _saturation,
                          min: 0,
                          max: 4,
                          onChanged: (v) => setState(() => _saturation = v)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Grid overlays ──────────────────────────────────────────────────
          if (showThirds || showCenter || showGolden)
            Positioned.fill(
              child: CustomPaint(
                painter: GridOverlayPainter(
                  showRuleOfThirds: showThirds,
                  showGoldenRatio: showGolden,
                  showCenterCross: showCenter,
                  lineColor: Colors.white.withOpacity(0.7),
                  strokeWidth: 1,
                ),
              ),
            ),

          // ── Top stats bar ──────────────────────────────────────────────────
          Positioned(
            top: media.padding.top + 12,
            left: 12,
            right: 12,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _miniStat('25mm', icon: Icons.camera_alt),
                _miniStat('1/50', icon: Icons.shutter_speed),
                _miniStat('f/1.8', icon: Icons.blur_on),
                _miniStat('ISO ${_isoSim.toInt()}',
                    icon: Icons.brightness_auto),
                _miniStat('${_exposure.toStringAsFixed(2)} EV',
                    icon: Icons.exposure),
                _miniStat('${_zoom.toStringAsFixed(1)}x',
                    icon: Icons.zoom_in),
              ],
            ),
          ),

          // ── Right side buttons ─────────────────────────────────────────────
          Positioned(
            right: 12,
            top: media.size.height * 0.22,
            child: Column(
              children: [
                _sideButton(Icons.cameraswitch, _switchCamera),
                const SizedBox(height: 16),
                _sideButton(
                  flashOn ? Icons.flash_on : Icons.flash_off,
                  _toggleFlash,
                ),
                const SizedBox(height: 16),
                _sideButton(Icons.tune, _openProControls),
              ],
            ),
          ),

          // ── AI Guidance bubble ─────────────────────────────────────────────
          Positioned(
            top: media.size.height * 0.13,
            left: 16,
            right: 16,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _guidanceBubbleColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        _guidanceResult.status == PlacementStatus.centered
                            ? Colors.greenAccent.withOpacity(0.8)
                            : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _guidanceResult.message,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Placement score ring ───────────────────────────────────────────
          Positioned(
            top: media.size.height * 0.20,
            left: 16,
            child: _PlacementScoreWidget(
              score: _guidanceResult.placementScore,
              color: _scoreColor,
            ),
          ),

          // ── Debug overlay ──────────────────────────────────────────────────
          _debugOverlay(),

          // ── Secondary toolbar ──────────────────────────────────────────────
          Positioned(
            bottom: media.size.height * 0.10,
            left: 0,
            right: 0,
            child: Center(child: _secondaryToolbar()),
          ),

          // ── Capture row ────────────────────────────────────────────────────
          Positioned(
            bottom: media.size.height * 0.02,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _sideButton(Icons.photo_library, () => context.go('/gallery')),
                _captureButton(),
                _sideButton(Icons.cameraswitch, _switchCamera),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Placement score ring ─────────────────────────────────────────────────────
class _PlacementScoreWidget extends StatelessWidget {
  final int score;
  final Color color;

  const _PlacementScoreWidget({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.45),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: score / 100.0,
              strokeWidth: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text('$score',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Top-level helpers for compute() (must be top-level or static) ───────────

/// Decode a JPEG/PNG byte buffer → packed RGB888. Used with compute().
Uint8List _decodeJpegToRgb(Uint8List jpegBytes) {
  // Use the 'image' package synchronously inside the isolate.
  // Import is intentionally deferred to this helper to avoid polluting the
  // main file's hot-reload cycles with the heavy image package.
  // ignore: depend_on_referenced_packages
  final img = _decodeImagePackage(jpegBytes);
  if (img == null) return Uint8List(0);
  final out = Uint8List(img.width * img.height * 3);
  int i = 0;
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p = img.getPixel(x, y);
      out[i++] = p.r.toInt();
      out[i++] = p.g.toInt();
      out[i++] = p.b.toInt();
    }
  }
  return out;
}

// NOTE: If you use _decodeJpegToRgb you must import the image package here.
// Add to pubspec: image: ^4.1.0
// Then uncomment:
// import 'package:image/image.dart' as _img;
// dynamic _decodeImagePackage(Uint8List b) => _img.decodeImage(b);
//
// For most Android devices, ImageFormatGroup.yuv420 is used so this path is
// rarely hit. The stub below prevents compilation errors if you don't add it:
dynamic _decodeImagePackage(Uint8List b) => null;

class _BgraParams {
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  const _BgraParams(
      {required this.bytes,
      required this.width,
      required this.height,
      required this.bytesPerRow});
}

/// BGRA8888 → packed RGB888. Used with compute() for iOS.
Uint8List _bgraToRgb(_BgraParams p) {
  final out = Uint8List(p.width * p.height * 3);
  int outIdx = 0;
  for (int y = 0; y < p.height; y++) {
    for (int x = 0; x < p.width; x++) {
      final offset = y * p.bytesPerRow + x * 4;
      out[outIdx++] = p.bytes[offset + 2]; // R (from BGRA)
      out[outIdx++] = p.bytes[offset + 1]; // G
      out[outIdx++] = p.bytes[offset];     // B
    }
  }
  return out;
}
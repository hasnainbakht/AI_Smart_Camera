// camera_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/overlay_painter.dart';
import '../../widgets/permission_popup.dart';
import '../../../services/detector_service.dart';
import '../../../services/guidance_service.dart';

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
  bool _panelFromLeft = true;

  // ─── Hardware-backed ranges ───────────────────────────────────────────────
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;

  // ─── Live hardware values ─────────────────────────────────────────────────
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
  bool _isAnalyzing = false;

  // Current guidance result (shown in AI bubble)
  GuidanceResult _guidanceResult = GuidanceResult(
    status: PlacementStatus.noObject,
    message: 'Initializing AI…',
    placementScore: 0,
  );

  // Throttle: analyze at most once every 500 ms
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

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
    try {
      await _detector.initialize();
      if (mounted) setState(() => _detectorReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guidanceResult = GuidanceResult(
            status: PlacementStatus.noObject,
            message: 'AI model failed to load.',
            placementScore: 0,
          );
        });
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
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final camera = useFrontCamera
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first,
          )
        : _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first,
          );

    await _controller?.stopImageStream();
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();

      // Query hardware ranges
      try {
        _minExposure = await _controller!.getMinExposureOffset();
        _maxExposure = await _controller!.getMaxExposureOffset();
      } catch (_) {
        _minExposure = -2.0;
        _maxExposure = 2.0;
      }
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 8.0;
      }

      _exposure = _exposure.clamp(_minExposure, _maxExposure);
      _zoom = _zoom.clamp(_minZoom, _maxZoom);
      await _controller!.setExposureOffset(_exposure);
      await _controller!.setZoomLevel(_zoom);

      // Start image stream for AI analysis
      await _startImageStream();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera init error: $e')));
      }
    }

    if (!mounted) return;
    setState(() => _initializing = false);
  }

  // ─── Image stream → AI ────────────────────────────────────────────────────
  Future<void> _startImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    await _controller!.startImageStream((CameraImage image) async {
      if (!_detectorReady || _isAnalyzing) return;

      final now = DateTime.now();
      if (now.difference(_lastAnalysis).inMilliseconds < 500) return;
      _lastAnalysis = now;

      _isAnalyzing = true;
      try {
        // Convert CameraImage planes → JPEG-like Uint8List
        // CameraImage with ImageFormatGroup.jpeg has a single plane
        final Uint8List bytes = _cameraImageToBytes(image);
        if (bytes.isEmpty) return;

        final detections = await _detector.detect(bytes);
        final result = _guidance.analyze(detections);

        if (mounted) setState(() => _guidanceResult = result);
      } catch (_) {
        // silently ignore per-frame errors
      } finally {
        _isAnalyzing = false;
      }
    });
  }

  /// Extract raw bytes from a CameraImage.
  /// Handles both JPEG (single plane) and YUV420 (multi-plane) formats.
  Uint8List _cameraImageToBytes(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.jpeg) {
        // JPEG: single plane, already encoded
        return image.planes[0].bytes;
      }

      // YUV420 → concatenate all plane bytes (DetectorService decodes via image pkg)
      // We build a minimal JPEG-compatible buffer: just pass the Y plane as a
      // greyscale stand-in if we can't encode properly here.  The image package
      // inside DetectorService will handle decoding.
      final WriteBuffer buffer = WriteBuffer();
      for (final Plane plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      return buffer.done().buffer.asUint8List();
    } catch (_) {
      return Uint8List(0);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Exposure error: $e')));
      }
    }
  }

  Future<void> _setZoom(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    value = value.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(value);
      setState(() => _zoom = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Zoom error: $e')));
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Pause stream while capturing to avoid race condition
    try {
      await _controller!.stopImageStream();
    } catch (_) {}

    try {
      final XFile file = await _controller!.takePicture();

      final payload = {
        'path': file.path,
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

      if (mounted) context.push('/feedback', extra: payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
        // Restart stream if capture fails
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
            const Text(
              "Pro Controls",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _sliderControl(
              label: "Exposure",
              value: _exposure,
              min: _minExposure,
              max: _maxExposure,
              onChanged: (v) {
                setState(() => _exposure = v);
                _controller?.setExposureOffset(v);
              },
            ),
            _sliderControl(
              label: "Zoom",
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
  List<double> _colorMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    final c = contrast;
    final t = (1.0 - c) * 0.5 * 255.0;
    final cm = [
      c, 0, 0, 0, brightness * 255 + t,
      0, c, 0, 0, brightness * 255 + t,
      0, 0, c, 0, brightness * 255 + t,
      0, 0, 0, 1, 0,
    ];
    final rW = 0.2126, gW = 0.7152, bW = 0.0722;
    final s = saturation;
    final sr = (1 - s) * rW, sg = (1 - s) * gW, sb = (1 - s) * bW;
    final sm = [
      sr + s, sg,     sb,     0, 0,
      sr,     sg + s, sb,     0, 0,
      sr,     sg,     sb + s, 0, 0,
      0,      0,      0,      1, 0,
    ];
    List<double> result = List.filled(20, 0);
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

  // ─── Guidance bubble helpers ──────────────────────────────────────────────
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
    final score = _guidanceResult.placementScore;
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  // ─── Widget helpers ───────────────────────────────────────────────────────
  Widget _sliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
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
  }

  Widget _miniStat(String text, {IconData? icon}) {
    return Container(
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
          if (icon != null) const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

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

  Widget _secondaryToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolbarButton(
              "Thirds", showThirds, (v) => setState(() => showThirds = v)),
          const SizedBox(width: 8),
          _toolbarButton(
              "Center", showCenter, (v) => setState(() => showCenter = v)),
          const SizedBox(width: 8),
          _toolbarButton(
              "Golden", showGolden, (v) => setState(() => showGolden = v)),
        ],
      ),
    );
  }

  Widget _toolbarButton(
      String title, bool value, ValueChanged<bool> onTap) {
    return GestureDetector(
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
  }

  Widget _captureButton() => GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          height: 84,
          width: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [
              BoxShadow(
                  color: Colors.white.withOpacity(0.08), blurRadius: 24),
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
            _bottomItem(Icons.home, "Home", "/home"),
            _bottomItem(Icons.camera_alt, "Camera", "/camera"),
            _bottomItem(Icons.video_library, "Media", "/gallery"),
            _bottomItem(Icons.settings, "Settings", "/settings"),
          ],
        ),
      );

  Widget _bottomItem(IconData icon, String label, String route) {
    final isActive =
        GoRouterState.of(context).uri.toString() == route;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 24,
              color: isActive ? Colors.greenAccent : Colors.white70),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? Colors.greenAccent : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelWithValue(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70))),
            Text(value, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final colorMatrix = _colorMatrix(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: _bottomNavBar(context),
      body: Stack(
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          Positioned.fill(
            child: _controller != null && _controller!.value.isInitialized
                ? ColorFiltered(
                    colorFilter: ColorFilter.matrix(colorMatrix),
                    child: CameraPreview(_controller!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // ── Pro side panel ──────────────────────────────────────────────
          if (_showProPanel)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              left: _panelFromLeft ? 0 : null,
              right: !_panelFromLeft ? 0 : null,
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
                          const Text(
                            "Pro Controls",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white),
                            onPressed: () =>
                                setState(() => _showProPanel = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sliderControl(
                        label: "Exposure",
                        value: _exposure,
                        min: _minExposure,
                        max: _maxExposure,
                        onChanged: (v) {
                          setState(() => _exposure = v);
                          _controller?.setExposureOffset(v);
                        },
                      ),
                      _sliderControl(
                        label: "Zoom",
                        value: _zoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: (v) {
                          setState(() => _zoom = v);
                          _controller?.setZoomLevel(v);
                        },
                      ),
                      _sliderControl(
                        label: "Brightness",
                        value: _brightness,
                        min: -1,
                        max: 1,
                        onChanged: (v) => setState(() => _brightness = v),
                      ),
                      _sliderControl(
                        label: "Contrast",
                        value: _contrast,
                        min: 0,
                        max: 4,
                        onChanged: (v) => setState(() => _contrast = v),
                      ),
                      _sliderControl(
                        label: "Saturation",
                        value: _saturation,
                        min: 0,
                        max: 4,
                        onChanged: (v) => setState(() => _saturation = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Grid overlays ────────────────────────────────────────────────
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

          // ── Top stats bar ─────────────────────────────────────────────────
          Positioned(
            top: media.padding.top + 12,
            left: 12,
            right: 12,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _miniStat("25mm", icon: Icons.camera_alt),
                _miniStat("1/50", icon: Icons.shutter_speed),
                _miniStat("f/1.8", icon: Icons.blur_on),
                _miniStat("ISO ${_isoSim.toInt()}",
                    icon: Icons.brightness_auto),
                _miniStat("${_exposure.toStringAsFixed(2)} EV",
                    icon: Icons.exposure),
                _miniStat("${_zoom.toStringAsFixed(1)}x",
                    icon: Icons.zoom_in),
              ],
            ),
          ),

          // ── Right side buttons ────────────────────────────────────────────
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

          // ── AI Guidance bubble ────────────────────────────────────────────
          Positioned(
            top: media.size.height * 0.13,
            left: 16,
            right: 16,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _guidanceBubbleColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _guidanceResult.status == PlacementStatus.centered
                        ? Colors.greenAccent.withOpacity(0.8)
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AI icon
                    const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    // Message
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

          // ── Placement score ring ──────────────────────────────────────────
          Positioned(
            top: media.size.height * 0.20,
            left: 16,
            child: _PlacementScoreWidget(
              score: _guidanceResult.placementScore,
              color: _scoreColor,
            ),
          ),

          // ── Secondary toolbar (overlay toggles) ───────────────────────────
          Positioned(
            bottom: media.size.height * 0.10,
            left: 0,
            right: 0,
            child: Center(child: _secondaryToolbar()),
          ),

          // ── Capture row ───────────────────────────────────────────────────
          Positioned(
            bottom: media.size.height * 0.02,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _sideButton(
                    Icons.photo_library, () => context.go('/gallery')),
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

// ─── Placement score ring widget ─────────────────────────────────────────────
class _PlacementScoreWidget extends StatelessWidget {
  final int score;
  final Color color;

  const _PlacementScoreWidget({
    required this.score,
    required this.color,
  });

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
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
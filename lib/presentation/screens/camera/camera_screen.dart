// camera_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/overlay_painter.dart';
import '../../widgets/permission_popup.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  // hardware-backed
  bool flashOn = false;
  bool useFrontCamera = false;

  // UI toggles
  bool showThirds = true;
  bool showCenter = true;
  bool showGolden = false;

  // hardware-supported ranges (populated after init)
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;

  // live values bound to UI (and hardware where supported)
  double _exposure = 0.0; // real: maps to setExposureOffset
  double _zoom = 1.0; // real: maps to setZoomLevel

  // preview-only adjustments (visual preview filters)
  double _brightness = 0.0; // -1.0 -> +1.0
  double _contrast = 1.0; // 0.0 -> 4.0
  double _saturation = 1.0; // 0.0 -> 4.0
  double _isoSim = 100; // simulated ISO (informational only)

  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

void _openProControls() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black87,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
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
            const Text("Pro Controls",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sliderControl(label: "Exposure", value: _exposure, min: -2.0, max: 2.0, onChanged: (v) {
              setState(() => _exposure = v);
              _controller?.setExposureOffset(v);
            }),
            _sliderControl(label: "Zoom", value: _zoom, min: 1.0, max: 8.0, onChanged: (v) {
              setState(() => _zoom = v);
              _controller?.setZoomLevel(v);
            }),
          ],
        ),
      );
    },
  );
}




  Future<void> _checkPermissionsAndInit() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => PermissionPopup(onGranted: () {
          Navigator.of(context).pop();
          _checkPermissionsAndInit();
        }),
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

    // dispose existing controller (if any)
    await _controller?.dispose();

    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);

    try {
      await _controller!.initialize();

      // query hardware-supported ranges where available
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

      // clamp current values into ranges
      _exposure = _exposure.clamp(_minExposure, _maxExposure);
      _zoom = _zoom.clamp(_minZoom, _maxZoom);

      // apply current values to controller (safe to await)
      await _controller!.setExposureOffset(_exposure);
      await _controller!.setZoomLevel(_zoom);
    } catch (e) {
      // initialization error (device may not support)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera init error: $e')));
      }
    }

    if (!mounted) return;
    setState(() {
      _initializing = false;
    });
  }

  Future<void> _switchCamera() async {
    useFrontCamera = !useFrontCamera;
    setState(() => _initializing = true);
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      flashOn = !flashOn;
      await _controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Flash error: $e')));
    }
  }

  Future<void> _setExposure(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    value = value.clamp(_minExposure, _maxExposure);
    try {
      await _controller!.setExposureOffset(value);
      setState(() => _exposure = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exposure error: $e')));
    }
  }

  Future<void> _setZoom(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    value = value.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(value);
      setState(() => _zoom = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zoom error: $e')));
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();

      // Pass filters/values with the route extra so feedback/saving screen can apply them
      final payload = {
        'path': file.path,
        'filters': {
          'brightness': _brightness,
          'contrast': _contrast,
          'saturation': _saturation,
          'iso': _isoSim,
          'exposure': _exposure,
          'zoom': _zoom,
        }
      };

      context.push('/feedback', extra: payload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    }
  }

  // Build a color matrix for contrast/brightness/saturation adjustments to preview.
  // Contrast: 1.0 = normal. Brightness: 0 = normal. Saturation: 1 = normal.
  List<double> _colorMatrix({required double brightness, required double contrast, required double saturation}) {
    // contrast matrix
    final c = contrast;
    final t = (1.0 - c) * 0.5 * 255.0;
    final cm = [
      c, 0, 0, 0, brightness * 255 + t,
      0, c, 0, 0, brightness * 255 + t,
      0, 0, c, 0, brightness * 255 + t,
      0, 0, 0, 1, 0,
    ];

    // saturation matrix
    final rWeight = 0.2126;
    final gWeight = 0.7152;
    final bWeight = 0.0722;
    final s = saturation;
    final sr = (1 - s) * rWeight;
    final sg = (1 - s) * gWeight;
    final sb = (1 - s) * bWeight;
    final sm = [
      sr + s, sg, sb, 0, 0,
      sr, sg + s, sb, 0, 0,
      sr, sg, sb + s, 0, 0,
      0, 0, 0, 1, 0,
    ];

    // multiply sm * cm (5x4 matrices represented as 4x5 here) - approximate by applying saturation then contrast/brightness
    // For simplicity, first apply saturation then contrast/brightness by combining matrices manually:
    // Result = cm * sm
    List<double> result = List.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += cm[row * 5 + k] * sm[k * 5 + col];
        }
        v += cm[row * 5 + 4]; // bias
        result[row * 5 + col] = v;
      }
    }
    return result;
  }
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
      Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
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

  // Widget _buildManualControls(BuildContext ctx) {
  //   final mq = MediaQuery.of(ctx);
  //   final width = mq.size.width * 0.88;

  //   return Container(
  //     width: width,
  //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  //     decoration: BoxDecoration(
  //       color: Colors.black.withOpacity(0.45),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: Colors.white24),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         // Exposure (hardware-backed)
  //         _labelWithValue("Exposure", "${_exposure.toStringAsFixed(2)}"),
  //         Slider(
  //           value: _exposure,
  //           min: _minExposure,
  //           max: _maxExposure,
  //           onChanged: (v) => _setExposure(v),
  //           activeColor: Colors.greenAccent,
  //           inactiveColor: Colors.white12,
  //         ),
  //         // Zoom (hardware-backed)
  //         _labelWithValue("Zoom", "${_zoom.toStringAsFixed(2)}x"),
  //         Slider(
  //           value: _zoom,
  //           min: _minZoom,
  //           max: _maxZoom,
  //           onChanged: (v) => _setZoom(v),
  //           activeColor: Colors.greenAccent,
  //           inactiveColor: Colors.white12,
  //         ),
  //         // Brightness (preview only)
  //         _labelWithValue("Brightness (preview)", _brightness.toStringAsFixed(2)),
  //         Slider(
  //           value: _brightness,
  //           min: -0.8,
  //           max: 0.8,
  //           onChanged: (v) => setState(() => _brightness = v),
  //           activeColor: Colors.blueAccent,
  //           inactiveColor: Colors.white12,
  //         ),
  //         // Contrast (preview only)
  //         _labelWithValue("Contrast (preview)", _contrast.toStringAsFixed(2)),
  //         Slider(
  //           value: _contrast,
  //           min: 0.2,
  //           max: 3.0,
  //           onChanged: (v) => setState(() => _contrast = v),
  //           activeColor: Colors.purpleAccent,
  //           inactiveColor: Colors.white12,
  //         ),
  //         // Saturation (preview only)
  //         _labelWithValue("Saturation (preview)", _saturation.toStringAsFixed(2)),
  //         Slider(
  //           value: _saturation,
  //           min: 0.0,
  //           max: 2.0,
  //           onChanged: (v) => setState(() => _saturation = v),
  //           activeColor: Colors.orangeAccent,
  //           inactiveColor: Colors.white12,
  //         ),
  //         // ISO simulated (informational)
  //         _labelWithValue("ISO (simulated)", _isoSim.toInt().toString()),
  //         Slider(
  //           value: _isoSim,
  //           min: 50,
  //           max: 3200,
  //           onChanged: (v) => setState(() => _isoSim = v),
  //           activeColor: Colors.amber,
  //           inactiveColor: Colors.white12,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _labelWithValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // UI pieces
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
          if (icon != null) Icon(icon, size: 12, color: Colors.greenAccent.withOpacity(0.9)),
          if (icon != null) const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
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
          _toolbarButton("Thirds", showThirds, (v) => setState(() => showThirds = v)),
          const SizedBox(width: 8),
          _toolbarButton("Center", showCenter, (v) => setState(() => showCenter = v)),
          const SizedBox(width: 8),
          _toolbarButton("Golden", showGolden, (v) => setState(() => showGolden = v)),
        ],
      ),
    );
  }

  Widget _toolbarButton(String title, bool value, ValueChanged<bool> onTap) {
    return GestureDetector(
      onTap: () => onTap(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: value ? Colors.greenAccent.withOpacity(0.85) : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 24)],
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
    final isActive = GoRouterState.of(context).uri.toString() == route;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: isActive ? Colors.greenAccent : Colors.white70),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.greenAccent : Colors.white60)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;

    // build color filter matrix for preview
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
          // camera preview
          Positioned.fill(
            child: _controller != null && _controller!.value.isInitialized
                ? ColorFiltered(
                    colorFilter: ColorFilter.matrix(colorMatrix),
                    child: CameraPreview(_controller!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // overlays: grid
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

          // top stats (wrap)
          Positioned(
            top: media.padding.top + 12,
            left: 12,
            right: 12,
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _miniStat("25mm", icon: Icons.camera_alt),
              _miniStat("1/50", icon: Icons.shutter_speed),
              _miniStat("f/1.8", icon: Icons.blur_on),
              _miniStat("ISO ${_isoSim.toInt()}", icon: Icons.brightness_auto),
              _miniStat("${(_exposure).toStringAsFixed(2)} EV", icon: Icons.exposure),
              _miniStat("${_zoom.toStringAsFixed(1)}x", icon: Icons.zoom_in),
            ]),
          ),

          // right side simple controls
          Positioned(
            right: 12,
            top: media.size.height * 0.22,
            child: Column(
              children: [
                _sideButton(Icons.cameraswitch, _switchCamera),
                const SizedBox(height: 16),
                _sideButton(flashOn ? Icons.flash_on : Icons.flash_off, _toggleFlash),
                const SizedBox(height: 16),
                _sideButton(Icons.tune, _openProControls),
              ],
            ),
          ),

          // AI bubble
          Positioned(
            top: media.size.height * 0.14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text("AI Tip: Center the product", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),

          // manual controls (center-bottom)
          // Positioned(
          //   bottom: media.size.height * 0.22,
          //   left: 0,
          //   right: 0,
          //   child: Center(child: _buildManualControls(context)),
          // ),

          // secondary toolbar (above bottom)
          Positioned(
            bottom: media.size.height * 0.10,
            left: 0,
            right: 0,
            child: Center(child: _secondaryToolbar()),
          ),

          // capture
          Positioned(
            bottom: media.size.height * 0.02,
            left: 0,
            right: 0,
            child: Center(child: _captureButton()),
          ),
        ],
      ),
    );
  }
}

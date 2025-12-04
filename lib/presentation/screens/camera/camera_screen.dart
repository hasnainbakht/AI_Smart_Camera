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

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool flashOn = false;
  bool useFrontCamera = false;
  bool showThirds = true;
  bool showCenter = true;
  bool showGolden = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final status = await Permission.camera.request();
    if (status.isDenied) {
      showDialog(
        context: context,
        builder: (_) => PermissionPopup(onGranted: () {}),
      );
    } else {
      // Load available cameras
      cameras = await availableCameras();
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final camera = useFrontCamera
        ? cameras!.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front)
        : cameras!.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);

    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _switchCamera() async {
    useFrontCamera = !useFrontCamera;
    await _initCamera();
  }

  void _toggleFlash() async {
    if (_controller != null && _controller!.value.isInitialized) {
      flashOn = !flashOn;
      await _controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    }
  }

  void _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      XFile file = await _controller!.takePicture();
      // Navigate to feedback screen with the captured image path
      context.push("/feedback", extra: file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error capturing photo: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: _bottomNavBar(context),
      body: Stack(
        children: [
          // ---------------- CAMERA PREVIEW ----------------
       // Replace your Positioned widgets with responsive ones like this:

// CAMERA PREVIEW
Positioned.fill(
  child: _controller != null && _controller!.value.isInitialized
      ? CameraPreview(_controller!)
      : const Center(child: CircularProgressIndicator()),
),

// GRID OVERLAY
Positioned.fill(
  child: CustomPaint(
    painter: GridOverlayPainter(
      showRuleOfThirds: showThirds,
      showGoldenRatio: showGolden,
      showCenterCross: showCenter,
      lineColor: Colors.white.withOpacity(0.8),
      strokeWidth: 2,
    ),
  ),
),

// TOP PRO CAMERA BAR
Positioned(
  top: MediaQuery.of(context).padding.top + 10,
  left: 12,
  right: 12,
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: _proCameraBar(),
  ),
),

// AI GUIDANCE
Positioned(
  top: MediaQuery.of(context).size.height * 0.15,
  left: 0,
  right: 0,
  child: Center(child: _aiBubble("Center the product")),
),

// HISTOGRAM
Positioned(
  bottom: MediaQuery.of(context).size.height * 0.25,
  right: 12,
  child: _histogram(),
),

// RIGHT SIDE BUTTONS
Positioned(
  top: MediaQuery.of(context).size.height * 0.2,
  right: 12,
  child: _rightSideButtons(),
),

// SECONDARY TOOLBAR
Positioned(
  bottom: MediaQuery.of(context).size.height * 0.02,
  left: 0,
  right: 0,
  child: Center(child: _secondaryToolbar()),
),

// CAPTURE BUTTON
Positioned(
  bottom: MediaQuery.of(context).size.height * 0.1,
  left: 0,
  right: 0,
  child: Center(child: _captureButton()),
),

// FLASH INDICATOR
if (flashOn)
  Positioned(
    top: MediaQuery.of(context).size.height * 0.2,
    right: 12,
    child: Icon(Icons.flash_on, color: Colors.yellowAccent.withOpacity(0.9), size: 32),
  ),
 ],
      ),
    );
  }

  // =================== PRO CAMERA TOP BAR ===================
  Widget _proCameraBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniStat("25mm", icon: Icons.camera_alt),
            const SizedBox(width: 6),
            _miniStat("1/50", icon: Icons.shutter_speed),
            const SizedBox(width: 6),
            _miniStat("f/1.8", icon: Icons.blur_on),
            const SizedBox(width: 6),
            _miniStat("ISO 560", icon: Icons.brightness_medium),
            const SizedBox(width: 6),
            _miniStat("4K 16:9", icon: Icons.high_quality),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _miniStat("WB 3600K", icon: Icons.wb_sunny),
            const SizedBox(width: 6),
            _miniStat("+0.3 EV", icon: Icons.exposure),
            const SizedBox(width: 6),
            _miniStat("BATT 85%", icon: Icons.battery_full),
            const SizedBox(width: 6),
            _miniStat("SHOTS 120", icon: Icons.sd_card),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: Colors.greenAccent.withOpacity(0.9)),
          if (icon != null) const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= RIGHT SIDE BUTTONS =================
  Widget _rightSideButtons() => Column(
        children: [
          _sideButton(Icons.cameraswitch, _switchCamera),
          const SizedBox(height: 20),
          _sideButton(flashOn ? Icons.flash_on : Icons.flash_off, _toggleFlash),
        ],
      );

  Widget _sideButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
      );

  // ================= SECONDARY TOOLBAR =================
  Widget _secondaryToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _toolbarButton("Thirds", showThirds, (v) => setState(() => showThirds = v)),
          const SizedBox(width: 12),
          _toolbarButton("Center", showCenter, (v) => setState(() => showCenter = v)),
          const SizedBox(width: 12),
          _toolbarButton("Golden", showGolden, (v) => setState(() => showGolden = v)),
        ],
      ),
    );
  }

  Widget _toolbarButton(String title, bool value, ValueChanged<bool> onTap) {
    return GestureDetector(
      onTap: () => onTap(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: value ? Colors.greenAccent.withOpacity(0.9) : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(title, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  // ================= CAPTURE BUTTON =================
  Widget _captureButton() => GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20)],
          ),
        ),
      );

  // ================= AI BUBBLE =================
  Widget _aiBubble(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white30),
          boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      );

  // ================= HISTOGRAM =================
  Widget _histogram() => Container(
        height: 70,
        width: 110,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: Image.asset("assets/histogram_mock.png", fit: BoxFit.cover),
      );

  // ================= BOTTOM NAVIGATION =================
  Widget _bottomNavBar(BuildContext context) => Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.black.withOpacity(0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomItem(Icons.home, "Home", "/home", context),
            _bottomItem(Icons.camera_alt, "Camera", "/camera", context),
            _bottomItem(Icons.video_library, "Media", "/gallery", context),
            _bottomItem(Icons.settings, "Settings", "/settings", context),
          ],
        ),
      );

  Widget _bottomItem(IconData icon, String label, String route, BuildContext context) {
    bool isActive = GoRouterState.of(context).uri.toString() == route;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isActive ? Colors.greenAccent : Colors.white70),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.greenAccent : Colors.white60)),
        ],
      ),
    );
  }
}

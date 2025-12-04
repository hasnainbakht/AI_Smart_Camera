import 'package:flutter/material.dart';
import '../../../core/utils/overlay_painter.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/permission_popup.dart';
import 'package:permission_handler/permission_handler.dart';
// Uncomment for real camera
// import 'package:camera/camera.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool flashOn = false;
  bool useFrontCamera = false;

  bool showThirds = true;
  bool showCenter = true;
  bool showGolden = false;

  // Uncomment for real camera
  // late CameraController _controller;
  // List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    checkPermissions();

    // Uncomment for real camera
    // initCamera();
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
    }
  }

  // Uncomment for real camera
  // Future<void> initCamera() async {
  //   cameras = await availableCameras();
  //   _controller = CameraController(
  //     useFrontCamera ? cameras.last : cameras.first,
  //     ResolutionPreset.max,
  //     enableAudio: false,
  //   );
  //   await _controller.initialize();
  //   if (!mounted) return;
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: _bottomNavBar(context),
      body: Stack(
        children: [
          // ------------------------------
          // CAMERA PREVIEW / EMULATOR IMAGE
          // ------------------------------
          Positioned.fill(
            child:
                // Uncomment for real device
                // _controller.value.isInitialized
                //     ? CameraPreview(_controller)
                //     :
                Image.asset(
              "assets/fake_camera.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // ------------------------------
          // OVERLAY GRID / GUIDES
          // ------------------------------
          CustomPaint(
            painter: GridOverlayPainter(
              showRuleOfThirds: showThirds,
              showGoldenRatio: showGolden,
              showCenterCross: showCenter,
              lineColor: Colors.white.withOpacity(0.35),
              strokeWidth: 1,
            ),
          ),

          // ------------------------------
          // TOP CINEMA STATUS BAR
          // ------------------------------
          Positioned(
            top: 30,
            left: 12,
            right: 12,
            child: _cinemaStatusBar(),
          ),

          // ------------------------------
          // AI GUIDANCE BUBBLE
          // ------------------------------
          Positioned(
            top: 95,
            left: 0,
            right: 0,
            child: Center(child: _aiBubble("Center the product")),
          ),

          // ------------------------------
          // HISTOGRAM
          // ------------------------------
          Positioned(
            bottom: 180,
            right: 12,
            child: _histogram(),
          ),

          // ------------------------------
          // RIGHT SIDE ACTION BUTTONS
          // ------------------------------
          Positioned(
            right: 12,
            top: 160,
            child: _rightSideButtons(),
          ),

          // ------------------------------
          // CAPTURE BUTTON
          // ------------------------------
          Positioned(
            bottom: 105,
            left: 0,
            right: 0,
            child: Center(child: _captureButton()),
          ),

          // ------------------------------
          // OPTIONAL: FLASH STATUS
          // ------------------------------
          if (flashOn)
            Positioned(
              top: 120,
              right: 12,
              child: Icon(Icons.flash_on,
                  color: Colors.yellowAccent.withOpacity(0.8), size: 32),
            ),
        ],
      ),
    );
  }

  // ==============================
  // TOP CINEMA STATUS BAR
  // ==============================
  Widget _cinemaStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topPill("25mm"),
          _topPill("24 FPS"),
          _topPill("1/50"),
          _topPill("f/1.8"),
          _topPill("ISO 560"),
          _topPill("WB 3600K"),
          _topPill("4K 16:9"),
        ],
      ),
    );
  }

  Widget _topPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white.withOpacity(0.15),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  // ==============================
  // RIGHT SIDE BUTTONS
  // ==============================
  Widget _rightSideButtons() => Column(
        children: [
          _sideButton(Icons.cameraswitch, () {
            setState(() => useFrontCamera = !useFrontCamera);
            // Uncomment for real camera
            // initCamera();
          }),
          const SizedBox(height: 20),
          _sideButton(flashOn ? Icons.flash_on : Icons.flash_off, () {
            setState(() => flashOn = !flashOn);
          }),
          const SizedBox(height: 20),
          _sideButton(Icons.photo_library, () => context.go("/gallery")),
          const SizedBox(height: 20),
          _sideButton(Icons.settings, () => context.go("/settings")),
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
            boxShadow: [
              BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
      );

  // ==============================
  // HISTOGRAM
  // ==============================
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

  // ==============================
  // CAPTURE BUTTON
  // ==============================
  Widget _captureButton() => GestureDetector(
        onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Capture Clicked (Mocked)"))),
        child: Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20)
            ],
          ),
        ),
      );

  // ==============================
  // AI GUIDANCE BUBBLE
  // ==============================
  Widget _aiBubble(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white30),
          boxShadow: [
            BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      );

  // ==============================
  // BOTTOM NAVIGATION
  // ==============================
  Widget _bottomNavBar(BuildContext context) => Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        color: Colors.black.withOpacity(0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomItem(Icons.camera_alt, "Camera", "/camera", context),
            _bottomItem(Icons.video_library, "Media", "/gallery", context),
            _bottomItem(Icons.chat_bubble_outline, "Chat", "/chat", context),
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
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: isActive ? Colors.greenAccent : Colors.white60)),
        ],
      ),
    );
  }
}

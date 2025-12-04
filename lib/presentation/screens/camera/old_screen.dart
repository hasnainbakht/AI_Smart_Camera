// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:camera/camera.dart';
// import 'package:smart_camera/presentation/screens/camera/overlay_selector.dart';
// import '../../../core/utils/overlay_painter.dart';

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});

//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   CameraController? controller;
//   OverlayOptions selectedOverlay = const OverlayOptions(
//     showRuleOfThirds: true,
//     showGoldenRatio: false,
//     showCenterCross: false,
//     opacity: 0.8,
//     strokeWidth: 1.0,
//   );

//   @override
//   void initState() {
//     super.initState();
// checkPermissions();
//     initCamera();
//   }

//   Future<void> initCamera() async {
//     final cameras = await availableCameras();
//     controller = CameraController(
//       cameras.first,
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );
//     await controller!.initialize();
//     if (mounted) setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (controller == null || !controller!.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       body: Stack(
//         children: [
//           CameraPreview(controller!),

//           // Rule of Thirds Overlay
//           CustomPaint(
//             painter: GridOverlayPainter(
//               showRuleOfThirds: selectedOverlay.showRuleOfThirds,
//               showGoldenRatio: selectedOverlay.showGoldenRatio,
//               showCenterCross: selectedOverlay.showCenterCross,
//               strokeWidth: selectedOverlay.strokeWidth,
//               lineColor: Colors.white.withOpacity(selectedOverlay.opacity),
//             ),
//             child: Container(),
//           ),
//           Positioned(
//             top: 40,
//             right: 10,
//             child: OverlaySelector(
//               initial: selectedOverlay,
//               onChanged: (opts) {
//                 setState(() {
//                   selectedOverlay = opts;
//                 });
//               },
//             ),
//           ),

//           Positioned(
//             bottom: 30,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: FloatingActionButton(
//                 onPressed: () async {
//                   final file = await controller!.takePicture();
//                   context.go('/feedback', extra: file.path);
//                 },
//                 child: const Icon(Icons.camera_alt),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

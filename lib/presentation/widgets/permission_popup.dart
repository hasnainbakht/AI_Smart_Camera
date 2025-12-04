import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPopup extends StatelessWidget {
  final VoidCallback onGranted;

  const PermissionPopup({super.key, required this.onGranted});

  Future<void> _requestPermissions(BuildContext context) async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();

    if (cameraStatus.isGranted && storageStatus.isGranted) {
      onGranted();
      Navigator.pop(context); // close popup
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 50, color: Colors.white),
            const SizedBox(height: 15),
            const Text(
              "Camera Permissions Required",
              style: TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "To use Smart AI Camera, allow access to the camera and storage.",
              style: TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _requestPermissions(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text("Allow Permissions"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

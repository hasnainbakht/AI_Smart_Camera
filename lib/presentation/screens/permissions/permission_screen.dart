import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';


class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> requestPermissions(BuildContext context) async {
    await Permission.camera.request();
    await Permission.storage.request();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: const Text("Grant Permissions"),
          onPressed: () => requestPermissions(context),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _openSystemGallery();
    });
  }

  Future<void> _openSystemGallery() async {
    final status = await Permission.photos.request();

    if (!status.isGranted) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      // User cancelled gallery -> go back
      if (mounted) context.go("/home");
      return;
    }

    // Open editor with selected image
    if (mounted) {
      context.go('/editor', extra: image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: Text(
          "Opening Gallery...",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}

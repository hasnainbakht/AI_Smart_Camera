import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gallery")),
      body: const Center(
        child: Text("Gallery will be added soon"),
      ),
    );
  }
}

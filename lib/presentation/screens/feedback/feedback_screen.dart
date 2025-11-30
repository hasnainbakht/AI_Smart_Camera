import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeedbackScreen extends StatelessWidget {
  final String imagePath;
  const FeedbackScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Photo Feedback")),
      body: Column(
        children: [
          Image.file(File(imagePath)),
          const SizedBox(height: 20),
          const Text("Composition Score: 85%", style: TextStyle(fontSize: 20)),
          const Text("Lighting Score: Good"),
          const Text("Sharpness: OK"),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () {
              // save logic later
            },
          )
        ],
      ),
    );
  }
}

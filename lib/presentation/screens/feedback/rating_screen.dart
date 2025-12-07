import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  bool _showResults = false;

  // Fake Scores
  final Map<String, dynamic> _scores = {
    "Composition": 0.82,
    "Lighting": 0.74,
    "Focus & Sharpness": 0.91,
    "Color Accuracy": 0.67,
    "Creativity": 0.79,
  };

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);

    if (result != null) {
      setState(() {
        _imageFile = File(result.path);
        _showResults = true;
      });
    }
  }

  Widget ratingBar(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              height: 10,
              width: 250 * value,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.9),
                    Colors.purpleAccent.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
   appBar: AppBar(
  backgroundColor: Colors.black,
  elevation: 0,
  leading: GestureDetector(
    onTap: () => context.go('/home'),
    child: Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
    ),
  ),
  title: const Text("AI Image Rating",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),

   
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---------------- IMAGE PREVIEW ----------------
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _imageFile!,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            if (_imageFile == null)
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 230,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text(
                      "Tap to Upload Image",
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ------------------- SCORE RESULTS -------------------
            if (_showResults)
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      "AI Ratings",
                      style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ..._scores.entries
                        .map((e) => ratingBar(e.key, e.value))
                        .toList(),

                    const SizedBox(height: 20),

                    // FINAL SCORE
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text("Overall Score",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text(
                            "${(_scores.values.reduce((a, b) => a + b) / _scores.length * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ACTION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => pickImage(),
                            child: const Text("Retake",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {},
                            child: const Text("Save",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

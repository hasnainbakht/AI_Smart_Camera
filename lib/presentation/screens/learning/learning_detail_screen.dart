import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningDetailScreen extends StatelessWidget {
  final String level;

  const LearningDetailScreen({super.key, required this.level});

  List<Map<String, String>> _getVideos() {
    switch (level) {
      case "beginner":
        return [
          {
            "title": "Photography Basics",
            "url": "https://www.youtube.com/watch?v=7ZVyNjKSr0M"
          },
          {
            "title": "Camera Settings Explained",
            "url": "https://www.youtube.com/watch?v=sh7K8p5vsLw"
          },
        ];

      case "intermediate":
        return [
          {
            "title": "Mastering Exposure",
            "url": "https://www.youtube.com/watch?v=gBr29N1dVZI"
          },
          {
            "title": "Composition Techniques",
            "url": "https://www.youtube.com/watch?v=FJg02Q_SnHk"
          },
        ];

      case "advance":
        return [
          {
            "title": "Advanced Photography Tips",
            "url": "https://www.youtube.com/watch?v=Gp8j5Z6bp6k"
          },
          {
            "title": "Understanding Dynamic Range",
            "url": "https://www.youtube.com/watch?v=_oH1d1GfLmg"
          },
        ];

      default:
        return [];
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _getVideos();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => context.go('/home'),
  ),
        title: Text(
          "$level Learning",
          style: const TextStyle(color: Colors.white),
        ),
      ),

  

      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return GestureDetector(
            onTap: () => _openUrl(video["url"]!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 35),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      video["title"]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

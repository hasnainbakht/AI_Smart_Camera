import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class LearningDetailScreen extends StatefulWidget {
  final String level;

  const LearningDetailScreen({super.key, required this.level});

  @override
  State<LearningDetailScreen> createState() => _LearningDetailScreenState();
}

class _LearningDetailScreenState extends State<LearningDetailScreen> {
  YoutubePlayerController? _controller;
  String? selectedVideoTitle;

  List<Map<String, String>> _getVideos() {
    switch (widget.level) {
      case "beginner":
        return [
          {
            "title": "Photography Basics",
            "url": "https://www.youtube.com/watch?v=7ZVyNjKSr0M",
          },
          {
            "title": "Camera Settings Explained",
            "url": "https://www.youtube.com/watch?v=3eCQ4tJ4Y7Q",
          },
        ];
      case "intermediate":
        return [
          {
            "title": "Mastering Exposure",
            "url": "https://www.youtube.com/watch?v=F8T94sdiNjg",
          },
          {
            "title": "Composition Techniques",
            "url": "https://www.youtube.com/watch?v=O8H4sO3xQGc",
          },
        ];
      case "advance":
        return [
          {
            "title": "Advanced Photography Tips",
            "url": "https://www.youtube.com/watch?v=4ZGq6F9rG8E",
          },
          {
            "title": "Understanding Dynamic Range",
            "url": "https://www.youtube.com/watch?v=uh6FQ1Ao6S8",
          },
        ];

      default:
        return [];
    }
  }

  void _playVideo(String url, String title) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) return;

    // Dispose old controller before creating new one
    _controller?.dispose();

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );

    setState(() {
      selectedVideoTitle = title;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _getVideos();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => context.go('/home'),
        ),
        title: Text("${widget.level} Learning"),
      ),
      body: Column(
        children: [
          // Show video player only if controller is initialized
          if (_controller != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
                onReady: () {
                  // Controller is now ready
                  print("YouTube Controller is ready!");
                },
              ),
            ),
          if (selectedVideoTitle != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                selectedVideoTitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Video list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isSelected = selectedVideoTitle == video["title"];

                return GestureDetector(
                  onTap: () => _playVideo(video["url"]!, video["title"]!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.white12,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill,
                          color: isSelected ? Colors.blueAccent : Colors.white,
                          size: 40,
                        ),
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
          ),
        ],
      ),
    );
  }
}

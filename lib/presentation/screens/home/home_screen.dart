import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // ---------------------- BORDER ANIMATION ----------------------
  late AnimationController _controller;
  late Animation<Color?> _borderColorAnim;

  final List<Color> borderColors = [
    Colors.purpleAccent,
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.greenAccent
  ];
  int _currentColorIndex = 0;

  // ---------------------- TIPS ROTATION ----------------------
  final List<String> _tips = [
    "Rule of Thirds",
    "Leading Lines",
    "Golden Hour Photography",
    "Portrait Lighting Tips",
    "Symmetry Shot Technique",
  ];

  int _currentTipIndex = 0;

  void _cycleTips() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;

      setState(() {
        _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
      });

      _cycleTips();
    });
  }

  @override
  void initState() {
    super.initState();

    // Border Color Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _borderColorAnim = ColorTween(
      begin: borderColors[_currentColorIndex],
      end: borderColors[(_currentColorIndex + 1) % borderColors.length],
    ).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColorIndex = (_currentColorIndex + 1) % borderColors.length;
        _borderColorAnim = ColorTween(
          begin: borderColors[_currentColorIndex],
          end: borderColors[(_currentColorIndex + 1) % borderColors.length],
        ).animate(_controller);
        _controller.forward(from: 0);
      }
    });

    _controller.forward();

    // Start tips rotation
    _cycleTips();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------- MENU OPTIONS ----------------------
  final List<Map<String, dynamic>> options = [
    {'icon': Icons.edit, 'title': 'Edit Pictures', 'route': '/editor'},
    {'icon': Icons.star, 'title': 'Image Rating', 'route': '/rating'},
    {'icon': Icons.history, 'title': 'History', 'route': '/history'},
    {'icon': Icons.photo_library, 'title': 'Gallery', 'route': '/gallery'},
    {'icon': Icons.person, 'title': 'Learn', 'route': '/learning'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ------------------- TOP BAR -------------------
             Row(
  children: [
    // LEFT TITLE
    Expanded(
      child: Text(
        "AI Camera",
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    // RIGHT ACTION BUTTONS
    Row(
      children: [
        // LOGIN BUTTON (FIRST)
        GestureDetector(
          onTap: () => context.go('/auth'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),

        // UPGRADE BUTTON
        GestureDetector(
          onTap: () => context.go('/pricing'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEE0979), Color(0xFFFF6A00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              "Upgrade",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // SETTINGS BUTTON
        GestureDetector(
          onTap: () => context.go('/settings'),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings, color: Colors.white),
          ),
        ),
      ],
    ),
  ],
),


              // ------------------- TODAY TIP CARD -------------------
              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _borderColorAnim,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: () {
                      final tip = _tips[_currentTipIndex];
                      final url = "https://www.google.com/search?q=${Uri.encodeComponent(tip)}";
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _borderColorAnim.value ?? Colors.purpleAccent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Tip",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              _tips[_currentTipIndex],
                              key: ValueKey(_tips[_currentTipIndex]),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // ------------------- GRID OPTIONS -------------------
              Expanded(
                child: GridView.builder(
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return GestureDetector(
                      onTap: () => context.go(option['route']),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(31, 71, 71, 71).withOpacity(0.4),
                              const Color.fromARGB(31, 59, 59, 59).withOpacity(0.4)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(option['icon'], color: Colors.white, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              option['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ------------------- CAMERA BUTTON -------------------
              GestureDetector(
                onTap: () => context.go('/camera'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orangeAccent, Colors.pinkAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "Open Camera",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

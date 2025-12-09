import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
   appBar: AppBar(
  backgroundColor: Colors.black,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => context.go('/home'),
  ),
  title: const Text(
    "Learning",
    style: TextStyle(color: Colors.white),
  ),
  elevation: 0,
),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildLearningCard(
              context,
              title: "Beginner",
              subtitle: "Start from zero, learn basics easily.",
              gradient: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
              route: "/learning/beginner",
            ),
            const SizedBox(height: 16),

            _buildLearningCard(
              context,
              title: "Intermediate",
              subtitle: "Improve your skills & shoot better photos.",
              gradient: const [Color(0xFFFF512F), Color(0xFFF09819)],
              route: "/learning/intermediate",
            ),
            const SizedBox(height: 16),

            _buildLearningCard(
              context,
              title: "Advance",
              subtitle: "Not pro, but solid level for noobs leveling up.",
              gradient: const [Color(0xFFAA076B), Color(0xFF61045F)],
              route: "/learning/advance",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required List<Color> gradient,
        required String route,
      }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.school, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

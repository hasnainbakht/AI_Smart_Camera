import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Camera")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => context.go('/camera'),
            child: const Text("Open Camera"),
          ),
          ElevatedButton(
            onPressed: () => context.go('/gallery'),
            child: const Text("Gallery"),
          ),
          ElevatedButton(
            onPressed: () => context.go('/settings'),
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }
}

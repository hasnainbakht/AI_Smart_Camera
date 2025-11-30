import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/permissions/permission_screen.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/permissions', builder: (_, __) => const PermissionScreen()),
  ],
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      title: 'Smart AI Camera',
    );
  }
}

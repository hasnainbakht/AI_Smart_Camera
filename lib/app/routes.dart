import 'package:go_router/go_router.dart';
import 'package:smart_camera/presentation/screens/pricing/pricing_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/feedback/feedback_screen.dart';
import '../presentation/screens/feedback/rating_screen.dart';
import '../presentation/screens/camera/camera_screen.dart';
import '../presentation/screens/gallery/gallery_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/edit_picture/edit_picture_screen.dart';
import '../presentation/screens/learning/learning_screen.dart';
import '../presentation/screens/learning/learning_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
    GoRoute(path: '/pricing', builder: (context, state) => const PricingScreen()),
    GoRoute(path: '/rating', builder: (context, state) => const RatingScreen()),
    GoRoute(path: '/gallery', builder: (context, state) => const GalleryScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
  GoRoute(
  path: '/editor',
  builder: (context, state) {
    final imagePath = state.extra as String? ?? 'assets/fake_camera.jpg'; // fallback to dummy image
    return EditImageScreen(imagePath: imagePath);
  },
),
GoRoute(
  path: '/learning',
  builder: (context, state) => const LearningScreen(),
),
GoRoute(
  path: '/learning/:level',
  builder: (context, state) =>
      LearningDetailScreen(level: state.pathParameters['level']!),
),




    GoRoute(
  path: '/feedback',
  builder: (context, state) {
    final imagePath = state.extra as String?;
    return FeedbackScreen(imagePath: imagePath ?? '');
  },
),
    GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

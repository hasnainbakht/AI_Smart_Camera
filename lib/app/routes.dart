import 'package:go_router/go_router.dart';
import 'package:smart_camera/presentation/screens/pricing/pricing_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/feedback/feedback_screen.dart';
import '../presentation/screens/feedback/rating_screen.dart';
import '../presentation/screens/camera/camera_screen.dart';
import '../presentation/screens/gallery/gallery_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
    GoRoute(path: '/pricing', builder: (context, state) => const PricingScreen()),
    GoRoute(path: '/rating', builder: (context, state) => const RatingScreen()),

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

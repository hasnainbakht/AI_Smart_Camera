import 'package:go_router/go_router.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/permissions/permission_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/feedback/feedback_screen.dart';
import '../presentation/screens/camera/camera_screen.dart';
import '../presentation/screens/gallery/gallery_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';




final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/permissions', builder: (_, __) => const PermissionScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
    GoRoute(path: '/feedback', builder: (_, __) => const FeedbackScreen(imagePath: '',)),
    GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

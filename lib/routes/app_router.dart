import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/email_auth_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/mentor/mentor_chat_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'route_paths.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.emailAuth,
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: RoutePaths.app,
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: RoutePaths.mentor,
        builder: (context, state) => const MentorChatScreen(),
      ),
    ],
  );
}


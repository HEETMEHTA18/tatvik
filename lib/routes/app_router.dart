import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/email_auth_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/mentor/mentor_chat_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'route_paths.dart';

import '../providers/app_state.dart';

// Routes that require authentication
const _protectedRoutes = {RoutePaths.app, RoutePaths.mentor};
// Routes only for guests (non-authenticated)
const _guestOnlyRoutes = {
  RoutePaths.splash,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.emailAuth,
};

GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: appState,
    // Use a stable navigator key so the navigator tree is never torn down on rebuilds
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    redirect: (context, state) {
      // 1. Wait for preferences to be loaded from storage
      if (!appState.isPreferencesLoaded) {
        return null; // Stay put until prefs are loaded
      }

      final isLoggedIn = appState.token != null && appState.token!.isNotEmpty;
      final matchedLocation = state.matchedLocation;

      // 2. Logged-in user on a guest-only page → send to dashboard
      if (isLoggedIn && _guestOnlyRoutes.contains(matchedLocation)) {
        return RoutePaths.app;
      }

      // 3. Guest user on a protected page → send to onboarding
      if (!isLoggedIn && _protectedRoutes.contains(matchedLocation)) {
        return RoutePaths.onboarding;
      }

      return null; // No redirect needed
    },
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
        builder: (context, state) {
          // Only use the tab query param for the INITIAL build.
          // After that, the MainNavigationScreen manages its own tab state
          // via a stable ValueKey so it is never rebuilt from scratch.
          final tabName = state.uri.queryParameters['tab'];
          final tabIndex = RoutePaths.tabIndexFromName(tabName);
          return MainNavigationScreen(
            key: const ValueKey('main_nav'),
            initialTabIndex: tabIndex,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.mentor,
        builder: (context, state) => const MentorChatScreen(),
      ),
    ],
  );
}

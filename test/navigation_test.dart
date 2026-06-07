import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:devmentor/providers/app_state.dart';
import 'package:devmentor/screens/main_navigation_screen.dart';

void main() {
  testWidgets('Navigation tab switching test', (WidgetTester tester) async {
    final appState = AppState();
    
    final router = GoRouter(
      initialLocation: '/app',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) => const MainNavigationScreen(initialTabIndex: 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    
    // Expect Home screen to render
    expect(find.text('Dashboard'), findsOneWidget);
    
    // Tap EXPLORE
    final exploreTab = find.text('EXPLORE');
    expect(exploreTab, findsOneWidget);
    await tester.tap(exploreTab);
    await tester.pump(const Duration(seconds: 1));
    
    // Tap PROMPTS
    final promptsTab = find.text('PROMPTS');
    expect(promptsTab, findsOneWidget);
    await tester.tap(promptsTab);
    await tester.pump(const Duration(seconds: 1));
  });
}

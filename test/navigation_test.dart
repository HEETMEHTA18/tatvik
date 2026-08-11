import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatvik/providers/app_state.dart';
import 'package:tatvik/routes/route_paths.dart';
import 'package:tatvik/screens/main_navigation_screen.dart';

void main() {
  testWidgets('Navigation tab switching test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_completed_walkthrough': true});
    final appState = AppState();
    
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final tabName = state.uri.queryParameters['tab'];
            final tabIndex = RoutePaths.tabIndexFromName(tabName);
            return MainNavigationScreen(
              key: const ValueKey('main_nav'),
              initialTabIndex: tabIndex,
            );
          },
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

    // Initial load: Wait 1 second for dependencies and initial frame
    await tester.pump(const Duration(seconds: 1));
    
    // Expect Home screen to render (Dashboard)
    expect(find.text('Dashboard'), findsOneWidget);
    
    // Tap EXPLORE
    final exploreTab = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Explore' && widget.style?.fontSize == 10,
    );
    expect(exploreTab, findsOneWidget);
    await tester.tap(exploreTab);
    
    // Wait for 120ms delayed tab switch and transition to finish
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    
    // Tap PROMPTS
    final promptsTab = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Prompts' && widget.style?.fontSize == 10,
    );
    expect(promptsTab, findsOneWidget);
    await tester.tap(promptsTab);
    
    // Wait for 120ms delayed tab switch and transition to finish
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // Verify that the prompts screen is now showing
    expect(find.text('Prompt repo sources'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('Navigation tab query renders prompts tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_walkthrough': true});
    final appState = AppState();

    final router = GoRouter(
      initialLocation: '/app?tab=prompts',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) {
            final tabName = state.uri.queryParameters['tab'];
            final tabIndex = RoutePaths.tabIndexFromName(tabName);
            return MainNavigationScreen(
              key: const ValueKey('main_nav'),
              initialTabIndex: tabIndex,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    debugPrint(
      'IndexedStack size in test: ${tester.getSize(find.byType(IndexedStack).first)}',
    );

    expect(find.byType(IndexedStack), findsWidgets);
    final promptsTab = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Prompts' && widget.style?.fontSize == 10,
    );
    expect(promptsTab, findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify that the prompts route mapping shows the prompts screen.
    expect(find.text('Prompt repo sources'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });
}

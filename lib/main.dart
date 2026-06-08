import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state.dart';
import 'routes/app_router.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      child: p.ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const DevMentorApp(),
      ),
    ),
  );
}

class DevMentorApp extends StatefulWidget {
  const DevMentorApp({super.key});

  @override
  State<DevMentorApp> createState() => _DevMentorAppState();
}

class _DevMentorAppState extends State<DevMentorApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final appState = p.Provider.of<AppState>(context, listen: false);
    _router = createAppRouter(appState);
  }

  @override
  Widget build(BuildContext context) {
    final appState = p.Provider.of<AppState>(context);
    AppTheme.isDark = appState.isDarkTheme;

    return MaterialApp.router(
      title: 'DevMentor',
      debugShowCheckedModeBanner: false,
      theme: appState.isDarkTheme ? AppTheme.darkTheme : AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}

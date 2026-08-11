import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state.dart';
import 'routes/app_router.dart';
import 'services/push_notification_service.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      child: p.ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const TatvikApp(),
      ),
    ),
  );
}

class TatvikApp extends StatefulWidget {
  const TatvikApp({super.key});

  @override
  State<TatvikApp> createState() => _TatvikAppState();
}

class _TatvikAppState extends State<TatvikApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final appState = p.Provider.of<AppState>(context, listen: false);
    _router = createAppRouter(appState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.bootstrap(appState);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = p.Provider.of<AppState>(context);
    AppTheme.isDark = appState.isDarkTheme;

    return MaterialApp.router(
      title: 'Tatvik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}

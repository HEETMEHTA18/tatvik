import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../providers/app_state.dart';

FirebaseOptions? _readFirebaseOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      messagingSenderId.isEmpty ||
      projectId.isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    measurementId: measurementId.isEmpty ? null : measurementId,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final options = _readFirebaseOptions();
    if (options != null) {
      await Firebase.initializeApp(options: options);
    }
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> bootstrap(AppState appState) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _initializeLocalNotifications();

    if (!appState.pushNotifications) {
      return;
    }

    final initialized = await _initializeFirebaseSafe();
    if (!initialized) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened from background: ${message.messageId}');
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Notification launched app: ${initialMessage.messageId}');
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerDeviceToken(token: token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _registerDeviceToken(token: token);
    });
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(initSettings);
  }

  static Future<bool> _initializeFirebaseSafe() async {
    try {
      final options = _readFirebaseOptions();
      if (Firebase.apps.isNotEmpty) {
        return true;
      }

      if (options != null) {
        await Firebase.initializeApp(options: options);
        return true;
      }

      if (!kIsWeb) {
        await Firebase.initializeApp();
        return true;
      }
    } catch (e) {
      debugPrint('Firebase push initialization skipped: $e');
    }
    return false;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'tatvik_push',
      'Tatvik Notifications',
      channelDescription:
          'Push notifications for Tatvik background and foreground events.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Tatvik',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _registerDeviceToken({required String token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/register'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'platform': kIsWeb ? 'web' : 'mobile',
          'device_name': 'Tatvik',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString('push_device_token', token);
      } else {
        debugPrint(
          'Push token registration failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error registering push token: $e');
    }
  }
}

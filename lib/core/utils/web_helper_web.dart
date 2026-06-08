// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void openUrl(String url) {
  html.window.location.href = url;
}

void requestNotificationPermission() {
  try {
    if (html.Notification.supported) {
      html.Notification.requestPermission();
    }
  } catch (_) {}
}

bool isAppWindowBackgrounded() {
  try {
    return html.document.visibilityState == 'hidden';
  } catch (_) {
    return false;
  }
}

void showBrowserNotification(String title, String body) {
  try {
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    }
  } catch (_) {}
}

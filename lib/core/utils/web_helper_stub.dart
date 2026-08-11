void openUrl(String url) {
  // Fallback or log, does not use dart:html
}

void requestNotificationPermission() {}

String getNotificationPermissionStatus() => 'unsupported';

Future<bool> requestNotificationPermissionGesture() async => false;

bool isAppWindowBackgrounded() => false;

void showBrowserNotification(String title, String body) {}

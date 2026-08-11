import 'package:web/web.dart' as web;

void saveCookie(String name, String value) {
  try {
    // Save cookie with 365 days expiry, Secure and SameSite=Strict
    web.document.cookie =
        "$name=$value; path=/; max-age=31536000; Secure; SameSite=Strict";
  } catch (_) {}
}

String? getCookie(String name) {
  try {
    final cookies = web.document.cookie;
    final parts = cookies.split(';');
    for (var part in parts) {
      final kv = part.trim().split('=');
      if (kv.length >= 2 && kv[0] == name) {
        return kv.sublist(1).join('=');
      }
    }
  } catch (_) {}
  return null;
}

void deleteCookie(String name) {
  try {
    web.document.cookie = "$name=; path=/; max-age=0; Secure; SameSite=Strict";
  } catch (_) {}
}

import 'dart:ui';

class SpeechHelper {
  static void speak(String text) {
    // No-op on native platforms
  }
  static void stop() {
    // No-op on native platforms
  }
  static void startListening({
    required Function(String text) onResult,
    required VoidCallback onStart,
    required VoidCallback onEnd,
    required Function(String error) onError,
  }) {
    // No-op on native platforms
  }
  static void stopListening() {
    // No-op on native platforms
  }
}

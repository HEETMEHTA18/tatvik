// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class SpeechHelper {
  static void speak(String text) {
    try {
      final synth = html.window.speechSynthesis;
      if (synth == null) return;

      // Stop any ongoing speech
      synth.cancel();

      // Remove markdown tags for cleaner speech
      final cleanText = text
          .replaceAll(
            RegExp(r'\*\*|__|\*|_|`|#'),
            '',
          ) // Remove Markdown symbols
          .replaceAll(
            RegExp(r'\[.*?\]\(.*?\)', caseSensitive: false),
            '',
          ); // Remove links

      final utterance = html.SpeechSynthesisUtterance(cleanText);
      synth.speak(utterance);
    } catch (e) {
      // Ignore errors on unsupported browsers
    }
  }

  static void stop() {
    try {
      final synth = html.window.speechSynthesis;
      if (synth != null) {
        synth.cancel();
      }
    } catch (e) {
      // Ignore
    }
  }
}

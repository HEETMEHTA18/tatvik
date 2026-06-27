// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui';

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

  static html.SpeechRecognition? _recognition;

  static void startListening({
    required Function(String text) onResult,
    required VoidCallback onStart,
    required VoidCallback onEnd,
    required Function(String error) onError,
  }) {
    try {
      if (!html.SpeechRecognition.supported) {
        onError("Speech Recognition is not supported in this browser.");
        return;
      }
      
      _recognition ??= html.SpeechRecognition()
        ..continuous = false
        ..interimResults = false
        ..lang = 'en-US';
        
      _recognition!.onStart.listen((e) => onStart());
      _recognition!.onEnd.listen((e) => onEnd());
      _recognition!.onError.listen((e) => onError("Error recognizing speech."));
      _recognition!.onResult.listen((event) {
        final results = event.results;
        if (results != null && results.isNotEmpty) {
          final result = results[0];
          final alternative = result.item(0);
          final transcript = alternative.transcript;
          if (transcript != null) {
            onResult(transcript);
          }
        }
      });
      _recognition!.start();
    } catch (e) {
      onError(e.toString());
    }
  }

  static void stopListening() {
    try {
      _recognition?.stop();
    } catch (_) {}
  }
}

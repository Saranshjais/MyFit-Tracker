import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for quick meal logging. The phone's own speech service does
/// the recognition; the app only receives the text.
abstract class VoiceInput {
  /// Starts listening. Returns null when listening started, otherwise a
  /// message explaining why it could not.
  Future<String?> start({
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
    required void Function(String message) onError,
    List<String> hints = const [],
  });

  Future<void> stop();
}

class DeviceVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool _available = false;
  String? _localeId;
  void Function()? _onStopped;
  void Function(String message)? _onError;

  static const unavailableMessage =
      'Voice input is not available. Allow the microphone for MyFit Tracker in your phone settings, '
      'or type what you ate instead.';

  @override
  Future<String?> start({
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
    required void Function(String message) onError,
    List<String> hints = const [],
  }) async {
    _onStopped = onStopped;
    _onError = onError;
    try {
      if (!_available) {
        // Asks for the microphone permission the first time.
        _available = await _speech.initialize(
          onStatus: (status) {
            if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _onStopped?.call();
          },
          onError: (SpeechRecognitionError e) {
            _onError?.call(describeError(e.errorMsg));
            _onStopped?.call();
          },
          options: [SpeechToText.androidNoBluetooth],
        );
        if (_available) _localeId = await _pickLocale();
      }
      if (!_available) return unavailableMessage;
      await _speech.listen(
        onResult: (r) => onWords(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          localeId: _localeId,
          contextualPhrases: hints,
        ),
      );
      return null;
    } catch (e) {
      debugPrint('Voice input failed: $e');
      return unavailableMessage;
    }
  }

  /// Indian English understands Hinglish food words best; fall back to the
  /// phone's own language.
  Future<String?> _pickLocale() async {
    final locales = await _speech.locales();
    for (final id in ['en_IN', 'en-IN']) {
      if (locales.any((l) => l.localeId == id)) return id;
    }
    return (await _speech.systemLocale())?.localeId;
  }

  @override
  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  static String describeError(String code) {
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      return "Didn't catch that. Tap the mic and try again, a little slower.";
    }
    if (code.contains('permission')) return unavailableMessage;
    if (code.contains('network') || code.contains('server')) {
      return "The phone's speech service needs internet or an offline speech pack "
          '(Google app › Settings › Voice › Offline speech recognition). You can also type instead.';
    }
    if (code.contains('language')) return "Speech recognition for this language isn't available on this phone.";
    return 'Voice input stopped ($code). You can type instead.';
  }
}

final voiceInputProvider = Provider<VoiceInput>((ref) => DeviceVoiceInput());

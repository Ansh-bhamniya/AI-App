import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/assistant_settings.dart';
import 'language_detector.dart';

/// A voice offered by the device's text-to-speech engine.
class TtsVoice {
  final String name;
  final String locale;
  final String? gender;
  const TtsVoice(this.name, this.locale, this.gender);

  String get label => gender == null ? '$name ($locale)' : '$name ($locale · $gender)';
}

/// Wraps text-to-speech and speech recognition, and publishes the signals
/// the avatar needs for lip-sync: whether it's speaking, and a pulse each
/// time a new word starts.
class VoiceService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  bool _listening = false;
  bool get isListening => _listening;

  bool _sttAvailable = false;
  bool get sttAvailable => _sttAvailable;

  /// Microphone input level (0..1) while listening; makes the face react.
  final ValueNotifier<double> soundLevel = ValueNotifier(0);

  /// Increments whenever the TTS engine starts a new word; the avatar uses
  /// it to time mouth movements to the speech.
  final ValueNotifier<int> wordTick = ValueNotifier(0);

  /// Length of the current word, so longer words keep the mouth open longer.
  int currentWordLength = 4;

  List<TtsVoice> _voices = const [];
  List<TtsVoice> get voices => _voices;

  Completer<void>? _speakDone;

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() => _setSpeaking(true));
      _tts.setCompletionHandler(_finishSpeaking);
      _tts.setCancelHandler(_finishSpeaking);
      _tts.setErrorHandler((_) => _finishSpeaking());
      _tts.setProgressHandler((text, start, end, word) {
        currentWordLength = math.max(1, end - start);
        wordTick.value++;
      });
      await _loadVoices();
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> _loadVoices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return;
    final list = <TtsVoice>[];
    for (final v in raw) {
      if (v is! Map) continue;
      final name = v['name']?.toString();
      final locale = v['locale']?.toString();
      if (name == null || locale == null) continue;
      list.add(TtsVoice(name, locale.replaceAll('_', '-'), v['gender']?.toString()));
    }
    list.sort((a, b) => a.locale == b.locale ? a.name.compareTo(b.name) : a.locale.compareTo(b.locale));
    _voices = list;
    notifyListeners();
  }

  void _setSpeaking(bool v) {
    if (_speaking == v) return;
    _speaking = v;
    notifyListeners();
  }

  void _finishSpeaking() {
    _setSpeaking(false);
    _speakDone?.complete();
    _speakDone = null;
  }

  /// Picks the best voice for [languageCode], honouring the user's chosen
  /// voice when it matches that language.
  TtsVoice? _voiceFor(AssistantSettings s, String languageCode) {
    final locale = LanguageDetector.ttsLocale(languageCode).toLowerCase();
    final lang = locale.split('-').first;
    if (s.voiceName != null) {
      final chosen = _voices.where((v) => v.name == s.voiceName).firstOrNull;
      if (chosen != null && chosen.locale.toLowerCase().startsWith(lang)) return chosen;
    }
    final matches = _voices.where((v) => v.locale.toLowerCase() == locale).toList();
    final langMatches = matches.isNotEmpty
        ? matches
        : _voices.where((v) => v.locale.toLowerCase().startsWith(lang)).toList();
    if (langMatches.isEmpty) return null;
    // Prefer a voice whose reported gender matches the persona.
    final wanted = switch (s.gender) {
      AssistantGender.male => 'male',
      AssistantGender.female => 'female',
      AssistantGender.neutral => null,
    };
    if (wanted != null) {
      final g = langMatches.where((v) => v.gender?.toLowerCase() == wanted).firstOrNull ??
          langMatches.where((v) => v.name.toLowerCase().contains(wanted)).firstOrNull;
      if (g != null) return g;
    }
    return langMatches.first;
  }

  /// Speaks [text] in [languageCode] using the persona's voice settings.
  Future<void> speak(String text, AssistantSettings s, {String? languageCode}) async {
    final clean = _stripForSpeech(text);
    if (clean.isEmpty) return;
    await stopSpeaking();
    final code = languageCode ??
        (s.language == 'auto' ? (LanguageDetector.detect(clean) ?? 'en-US') : s.language);
    try {
      final voice = _voiceFor(s, code);
      if (voice != null) {
        await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      } else {
        await _tts.setLanguage(LanguageDetector.ttsLocale(code));
      }
      await _tts.setPitch(s.pitch.clamp(0.5, 2.0));
      await _tts.setSpeechRate(s.speechRate.clamp(0.0, 1.0));
      await _tts.setVolume(s.volume.clamp(0.0, 1.0));
      _speakDone = Completer<void>();
      _setSpeaking(true);
      await _tts.speak(clean);
      // Some engines never fire the start/progress callbacks; make sure the
      // speaking state doesn't stick if completion is never reported.
      unawaited(_speakDone!.future.timeout(
        Duration(seconds: 5 + clean.length ~/ 6),
        onTimeout: _finishSpeaking,
      ));
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _finishSpeaking();
    }
  }

  Future<void> stopSpeaking() async {
    if (!_speaking) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _finishSpeaking();
  }

  String _stripForSpeech(String text) => text
      .replaceAll(RegExp(r'[*_`#>]+'), '')
      .replaceAll(RegExp(r'https?://\S+'), '')
      .trim();

  /// Starts listening. [onResult] receives partial and final transcripts.
  Future<bool> startListening({
    required String? localeCode,
    required void Function(String text, bool isFinal) onResult,
    void Function(String error)? onError,
  }) async {
    await stopSpeaking();
    if (!_sttAvailable) {
      _sttAvailable = await _stt.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
            _setListening(false);
          }
        },
        onError: (e) {
          _setListening(false);
          onError?.call(e.errorMsg);
        },
      );
      if (!_sttAvailable) {
        onError?.call('Speech recognition is not available on this device.');
        return false;
      }
    }
    String? sttLocale;
    if (localeCode != null) {
      final wanted = LanguageDetector.sttLocale(localeCode).replaceAll('-', '_').toLowerCase();
      final locales = await _stt.locales();
      sttLocale = locales
              .where((l) => l.localeId.toLowerCase() == wanted)
              .map((l) => l.localeId)
              .firstOrNull ??
          locales
              .where((l) => l.localeId.toLowerCase().startsWith(wanted.split('_').first))
              .map((l) => l.localeId)
              .firstOrNull;
    }
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: (level) {
        // Levels are roughly -2..10 dB depending on platform.
        soundLevel.value = ((level + 2) / 12).clamp(0.0, 1.0);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: sttLocale,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 60),
      ),
    );
    _setListening(true);
    return true;
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _setListening(false);
  }

  void _setListening(bool v) {
    if (_listening == v) return;
    _listening = v;
    if (!v) soundLevel.value = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.cancel();
    soundLevel.dispose();
    wordTick.dispose();
    super.dispose();
  }
}

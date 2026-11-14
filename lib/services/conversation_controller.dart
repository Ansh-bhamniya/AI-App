import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/assistant_settings.dart';
import '../models/emotion.dart';
import 'ai_service.dart';
import 'language_detector.dart';
import 'settings_controller.dart';
import 'voice_service.dart';

/// Coordinates a conversation: user input (typed or spoken), streaming AI
/// replies, speaking them aloud, and the avatar's current expression.
class ConversationController extends ChangeNotifier {
  final SettingsController settingsController;
  final VoiceService voice;
  final AiService ai;

  ConversationController({
    required this.settingsController,
    required this.voice,
    AiService? ai,
  }) : ai = ai ?? AiService() {
    voice.addListener(_onVoiceChanged);
  }

  AssistantSettings get settings => settingsController.settings;

  final List<ChatMessage> messages = [];

  Emotion _emotion = Emotion.happy;
  Emotion get emotion => _emotion;

  bool _thinking = false;
  bool get isThinking => _thinking;

  String _partialTranscript = '';
  String get partialTranscript => _partialTranscript;

  /// Language of the most recent exchange.
  String? lastLanguage;

  Timer? _relaxTimer;
  bool _wasSpeaking = false;
  int _requestId = 0;

  void _onVoiceChanged() {
    // When the assistant finishes speaking, relax back to a calm smile.
    if (_wasSpeaking && !voice.isSpeaking) _scheduleRelax();
    _wasSpeaking = voice.isSpeaking;
    notifyListeners();
  }

  void _scheduleRelax([Duration delay = const Duration(seconds: 4)]) {
    _relaxTimer?.cancel();
    _relaxTimer = Timer(delay, () {
      if (voice.isSpeaking || _thinking) return;
      setEmotion(Emotion.happy);
    });
  }

  void setEmotion(Emotion e) {
    if (_emotion == e) return;
    _emotion = e;
    notifyListeners();
  }

  String greeting() {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return "$part! I'm ${settings.name}. How can I help you today?";
  }

  Future<void> send(String input) async {
    final text = input.trim();
    if (text.isEmpty) return;
    final id = ++_requestId;
    _relaxTimer?.cancel();
    await voice.stopSpeaking();

    final detected = settings.language == 'auto' ? LanguageDetector.detect(text) : settings.language;
    messages.add(ChatMessage(fromUser: true, text: text, language: detected));
    final reply = ChatMessage(fromUser: false, text: '', emotion: Emotion.thinking);
    messages.add(reply);
    _thinking = true;
    _emotion = Emotion.thinking;
    notifyListeners();

    try {
      AiChunk? last;
      await for (final chunk in ai.reply(
        settings,
        messages.sublist(0, messages.length - 1),
        detectedLanguage: detected,
      )) {
        if (id != _requestId) return; // superseded by a newer message
        last = chunk;
        reply.text = chunk.text;
        if (chunk.emotion != null) {
          reply.emotion = chunk.emotion!;
          if (_thinking && chunk.text.isNotEmpty) {
            _thinking = false;
            _emotion = chunk.emotion!;
          }
        }
        reply.language = chunk.language ?? reply.language;
        notifyListeners();
      }
      _thinking = false;
      final lang = last?.language ?? detected ?? 'en-US';
      reply.language = lang;
      lastLanguage = lang;
      _emotion = reply.emotion == Emotion.thinking ? Emotion.happy : reply.emotion;
      notifyListeners();
      if (settings.speakReplies && reply.text.isNotEmpty) {
        await voice.speak(reply.text, settings, languageCode: lang);
      } else {
        _scheduleRelax(const Duration(seconds: 6));
      }
    } catch (e) {
      if (id != _requestId) return;
      _thinking = false;
      reply
        ..text = e is AiException ? e.message : 'Something went wrong: $e'
        ..isError = true
        ..emotion = Emotion.sad;
      _emotion = Emotion.sad;
      notifyListeners();
      _scheduleRelax(const Duration(seconds: 5));
    }
  }

  Future<void> toggleListening({void Function(String)? onError}) async {
    if (voice.isListening) {
      await voice.stopListening();
      return;
    }
    _partialTranscript = '';
    final locale = settings.language != 'auto' ? settings.language : lastLanguage;
    await voice.startListening(
      localeCode: locale,
      onResult: (words, isFinal) {
        _partialTranscript = words;
        notifyListeners();
        if (isFinal && words.trim().isNotEmpty) {
          _partialTranscript = '';
          send(words);
        }
      },
      onError: onError,
    );
  }

  void clear() {
    _requestId++;
    messages.clear();
    voice.stopSpeaking();
    _thinking = false;
    _emotion = Emotion.happy;
    notifyListeners();
  }

  /// Speaks a sample line so users can preview voice settings.
  Future<void> previewVoice() async {
    setEmotion(Emotion.happy);
    final lang = settings.language == 'auto' ? (settings.voiceLocale ?? 'en-US') : settings.language;
    final samples = <String, String>{
      'hi': 'नमस्ते! मैं ${settings.name} हूँ। बताइए, मैं आपकी क्या मदद करूँ?',
      'ur': 'السلام علیکم! میں ${settings.name} ہوں۔',
      'es': '¡Hola! Soy ${settings.name}. ¿En qué puedo ayudarte?',
      'fr': 'Bonjour ! Je suis ${settings.name}. Comment puis-je t\'aider ?',
      'ja': 'こんにちは！${settings.name}です。',
      'zh': '你好！我是${settings.name}。',
      'de': 'Hallo! Ich bin ${settings.name}.',
    };
    final text = lang == LanguageDetector.hinglish
        ? 'Hello ji! Main ${settings.name} hoon. Batao, kya help chahiye?'
        : samples[lang.split('-').first] ?? "Hi! I'm ${settings.name}. This is how I sound.";
    await voice.speak(text, settings, languageCode: lang);
  }

  @override
  void dispose() {
    _relaxTimer?.cancel();
    voice.removeListener(_onVoiceChanged);
    super.dispose();
  }
}

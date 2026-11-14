import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assistant_settings.dart';
import '../models/emotion.dart';
import 'language_detector.dart';

/// A single chat turn.
class ChatMessage {
  final bool fromUser;
  String text;
  Emotion emotion;
  String? language;
  bool isError;

  ChatMessage({
    required this.fromUser,
    required this.text,
    this.emotion = Emotion.neutral,
    this.language,
    this.isError = false,
  });
}

/// Incremental update while a reply is streaming in.
class AiChunk {
  /// Full reply text received so far (metadata tag stripped).
  final String text;
  final Emotion? emotion;
  final String? language;
  final bool done;
  const AiChunk(this.text, {this.emotion, this.language, this.done = false});
}

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Talks to the Claude Messages API over raw HTTP (there is no official Dart
/// SDK) and streams the reply back.
///
/// Each reply starts with a tag like `[[happy|hi-IN]]` carrying the emotion
/// for the avatar's face and the language used, so the voice can switch.
class AiService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static final _tag = RegExp(r'^\s*\[\[\s*([a-zA-Z]+)\s*\|\s*([A-Za-z-]+)\s*\]\]\s*');

  final http.Client _client;
  AiService({http.Client? client}) : _client = client ?? http.Client();

  String systemPrompt(AssistantSettings s, {String? detectedLanguage}) {
    final pronoun = switch (s.gender) {
      AssistantGender.male => 'You present as male.',
      AssistantGender.female => 'You present as female.',
      AssistantGender.neutral => 'You present as gender-neutral.',
    };
    final langRule = s.language == 'auto'
        ? 'Always reply in the same language and script the user wrote or spoke in. '
            'If they mix Hindi and English in Latin script (Hinglish), reply in Hinglish. '
            'If they write Urdu, reply in Urdu script.'
        : 'Always reply in ${LanguageDetector.nameOf(s.language)} (${s.language}), '
            'unless the user explicitly asks for another language.';
    final hint = detectedLanguage == null
        ? ''
        : ' A quick local detector guessed the user\'s latest message is '
            '${LanguageDetector.nameOf(detectedLanguage)}; trust the actual text over this guess.';
    final emotions = Emotion.values.map((e) => e.name).join(', ');

    return '''
You are ${s.name}, a personal AI voice assistant shown as an animated face. $pronoun
Your personality is ${s.personality.prompt}. You are intelligent, honest and helpful.
If the user calls you by another name or renames you, accept it gracefully.

Language: $langRule$hint

Your replies are read aloud by text-to-speech, so write the way people talk:
short sentences, usually 1-4 of them, no markdown, no bullet lists, no code
blocks, no emoji, and no URLs unless asked. Give longer answers only when the
user clearly wants detail.

Format: begin EVERY reply with a tag [[emotion|language]] and then the reply.
- emotion is the facial expression that fits your reply, one of: $emotions
- language is the BCP-47 tag of the language you reply in (for example en-US,
  hi-IN, ur-PK, es-ES, fr-FR, ja-JP, zh-CN). Use hi-Latn for Hinglish.
Example: [[happy|en-US]] Hey there! What can I do for you today?
''';
  }

  /// Streams the reply to [history] (the last entry is the user's message).
  Stream<AiChunk> reply(
    AssistantSettings settings,
    List<ChatMessage> history, {
    String? detectedLanguage,
  }) async* {
    if (settings.apiKey.trim().isEmpty) {
      yield* _offlineReply(settings, history.last.text, detectedLanguage);
      return;
    }

    final messages = _toApiMessages(history);
    final body = jsonEncode({
      'model': settings.model,
      'max_tokens': 64000,
      'stream': true,
      // Chat replies are short; low effort keeps the voice snappy.
      'output_config': {'effort': 'low'},
      // On a safety-classifier decline, let the API retry on a fallback model.
      'fallbacks': 'default',
      'system': systemPrompt(settings, detectedLanguage: detectedLanguage),
      'messages': messages,
    });

    final request = http.Request('POST', Uri.parse(_endpoint))
      ..headers.addAll({
        'content-type': 'application/json',
        'x-api-key': settings.apiKey.trim(),
        'anthropic-version': '2026-10-21',
        'anthropic-beta': 'server-side-fallback-2026-07-01',
        // Needed when the app runs in a browser (Flutter web).
        'anthropic-dangerous-direct-browser-access': 'true',
      })
      ..body = body;

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw AiException('The AI took too long to respond. Please try again.');
    } catch (e) {
      throw AiException('Network error: could not reach the AI service.');
    }

    if (response.statusCode != 200) {
      final errBody = await response.stream.bytesToString();
      throw AiException(_describeHttpError(response.statusCode, errBody));
    }

    var raw = StringBuffer();
    Emotion? emotion;
    String? language;
    var tagResolved = false;
    String? stopReason;

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      final Map<String, dynamic> event;
      try {
        event = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      switch (event['type']) {
        case 'content_block_delta':
          final delta = event['delta'] as Map<String, dynamic>?;
          if (delta?['type'] != 'text_delta') break;
          raw.write(delta!['text'] as String? ?? '');
          var text = raw.toString();
          if (!tagResolved) {
            final m = _tag.firstMatch(text);
            if (m != null) {
              emotion = EmotionInfo.parse(m.group(1));
              language = m.group(2);
              tagResolved = true;
            } else if (text.trimLeft().startsWith('[[') && text.length < 60) {
              break; // wait for the rest of the tag
            } else {
              tagResolved = true; // model skipped the tag
            }
          }
          text = text.replaceFirst(_tag, '');
          yield AiChunk(text, emotion: emotion, language: language);
        case 'message_delta':
          final delta = event['delta'] as Map<String, dynamic>?;
          stopReason = delta?['stop_reason'] as String? ?? stopReason;
        case 'error':
          final err = event['error'] as Map<String, dynamic>?;
          throw AiException(err?['message'] as String? ?? 'The AI service returned an error.');
      }
    }

    final finalText = raw.toString().replaceFirst(_tag, '').trim();
    if (stopReason == 'refusal' && finalText.isEmpty) {
      yield const AiChunk("Sorry, I can't help with that one. Let's try something else!",
          emotion: Emotion.sad, done: true);
      return;
    }
    yield AiChunk(finalText, emotion: emotion ?? Emotion.happy, language: language, done: true);
  }

  List<Map<String, Object>> _toApiMessages(List<ChatMessage> history) {
    // Keep the recent conversation; the API needs alternating roles starting
    // with the user, so merge consecutive same-role turns.
    final recent = history.where((m) => !m.isError && m.text.trim().isNotEmpty).toList();
    final trimmed = recent.length > 30 ? recent.sublist(recent.length - 30) : recent;
    final out = <Map<String, Object>>[];
    for (final m in trimmed) {
      final role = m.fromUser ? 'user' : 'assistant';
      if (out.isEmpty && role == 'assistant') continue;
      final content = m.fromUser
          ? m.text
          : '[[${m.emotion.name}|${m.language ?? 'en-US'}]] ${m.text}';
      if (out.isNotEmpty && out.last['role'] == role) {
        out.last['content'] = '${out.last['content']}\n$content';
      } else {
        out.add({'role': role, 'content': content});
      }
    }
    return out;
  }

  String _describeHttpError(int status, String body) {
    String? apiMessage;
    try {
      apiMessage = ((jsonDecode(body) as Map)['error'] as Map?)?['message'] as String?;
    } catch (_) {}
    return switch (status) {
      401 => 'Your API key was rejected. Check it in Settings.',
      403 => 'This API key does not have permission for that request.',
      404 => 'Model not found. Check the model name in Settings.',
      429 => 'Too many requests right now. Please wait a moment and try again.',
      >= 500 => 'The AI service is having trouble. Please try again shortly.',
      _ => apiMessage ?? 'Request failed ($status).',
    };
  }

  /// Small built-in responder so the app is usable (and the face animates)
  /// before an API key is configured.
  Stream<AiChunk> _offlineReply(AssistantSettings s, String input, String? lang) async* {
    final q = input.toLowerCase();
    final language = lang ?? 'en-US';
    String text;
    Emotion emotion;
    final greetings = <String, String>{
      'hi-IN': 'नमस्ते! मैं ${s.name} हूँ। पूरी बातचीत के लिए सेटिंग्स में API key जोड़ें।',
      LanguageDetector.hinglish:
          'Namaste! Main ${s.name} hoon. Poori baat-cheet ke liye Settings mein API key daal do.',
      'ur-PK': 'السلام علیکم! میں ${s.name} ہوں۔ مکمل گفتگو کے لیے سیٹنگز میں API key شامل کریں۔',
      'es-ES': '¡Hola! Soy ${s.name}. Añade una clave de API en Ajustes para conversar de verdad.',
      'fr-FR': 'Bonjour ! Je suis ${s.name}. Ajoute une clé API dans les réglages pour discuter.',
      'ja-JP': 'こんにちは！${s.name}です。設定でAPIキーを追加すると会話できます。',
      'zh-CN': '你好！我是${s.name}。请在设置中添加 API 密钥，我们就能聊天了。',
    };
    if (RegExp(r'\b(joke|funny|mazak|chutkula)\b').hasMatch(q)) {
      text = 'Why did the robot go on vacation? It needed to recharge its batteries!';
      emotion = Emotion.laugh;
    } else if (RegExp(r'\b(sad|upset|cry|dukhi)\b').hasMatch(q)) {
      text = "I'm sorry you feel that way. I'm here for you.";
      emotion = Emotion.sad;
    } else if (RegExp(r'\b(love|pyaar|cute)\b').hasMatch(q)) {
      text = 'Aww, that is so sweet of you!';
      emotion = Emotion.love;
    } else if (RegExp(r'\b(name|naam)\b').hasMatch(q)) {
      text = 'My name is ${s.name}. You can change it any time in Settings.';
      emotion = Emotion.wink;
    } else {
      text = greetings[language] ??
          "Hi! I'm ${s.name}. I'm running in demo mode. Add your Anthropic API key in Settings so I can really chat with you.";
      emotion = Emotion.happy;
    }
    // Simulate streaming so the UI behaves like the real thing.
    final words = text.split(' ');
    for (var i = 1; i <= words.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 35));
      yield AiChunk(words.take(i).join(' '), emotion: emotion, language: language);
    }
    yield AiChunk(text, emotion: emotion, language: language, done: true);
  }
}

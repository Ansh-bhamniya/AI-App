import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'feature_box.dart';
import 'models/emotion.dart';
import 'pallete.dart';
import 'services/ai_service.dart';
import 'services/conversation_controller.dart';
import 'services/language_detector.dart';
import 'services/settings_controller.dart';
import 'settings_page.dart';
import 'widgets/avatar/animated_avatar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(ConversationController convo, [String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    convo.send(t);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsController>(); // rebuild on customization changes
    final convo = context.watch<ConversationController>();
    final s = convo.settings;
    final voice = convo.voice;
    final media = MediaQuery.of(context);
    final hasChat = convo.messages.isNotEmpty;
    final avatarSize = (media.size.shortestSide * (hasChat ? 0.45 : 0.62)).clamp(140.0, 320.0);

    final status = voice.isListening
        ? (convo.partialTranscript.isEmpty ? 'Listening…' : convo.partialTranscript)
        : convo.isThinking
            ? 'Thinking…'
            : voice.isSpeaking
                ? 'Speaking…'
                : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name, style: const TextStyle(fontFamily: 'Cera Pro', fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: hasChat
            ? IconButton(
                tooltip: 'New conversation',
                icon: const Icon(Icons.refresh),
                onPressed: convo.clear,
              )
            : null,
        actions: [
          if (convo.lastLanguage != null || s.language != 'auto')
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.translate, size: 16),
                label: Text(LanguageDetector.nameOf(
                    s.language == 'auto' ? convo.lastLanguage! : s.language)),
              ),
            ),
          IconButton(
            tooltip: 'Customize assistant',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedAvatar(
                settings: s,
                emotion: convo.emotion,
                speaking: voice.isSpeaking,
                listening: voice.isListening,
                thinking: convo.isThinking,
                listenLevel: voice.soundLevel,
                wordTick: voice.wordTick,
                size: avatarSize,
              ),
            ),
            SizedBox(
              height: 28,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: status == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(status),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Pallete.mainFontColor.withValues(alpha: 0.7)),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: hasChat ? _chatList(convo) : _welcome(convo),
            ),
            _inputBar(convo),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ConversationController convo) {
    final s = convo.settings;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 32).copyWith(top: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Pallete.borderColor),
            borderRadius: BorderRadius.circular(20).copyWith(topLeft: Radius.zero),
          ),
          child: Text(
            convo.greeting(),
            style: const TextStyle(color: Pallete.mainFontColor, fontSize: 22, fontFamily: 'Cera Pro'),
          ),
        ),
        if (s.apiKey.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
            child: Text(
              'Demo mode — add your Anthropic API key in Settings to unlock full conversations.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 18, 32, 4),
          child: Text(
            'Try saying…',
            style: TextStyle(
              fontFamily: 'Cera Pro',
              fontSize: 20,
              color: Pallete.mainFontColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        FeatureBox(
          color: Pallete.firstSuggestionBoxColor,
          headerText: 'Chat in any language',
          descriptionText: 'Bolo "Aaj ka plan kya hona chahiye?" or "¿Qué tiempo hace en Madrid?"',
          onTap: () => _send(convo, 'Aaj ka din productive kaise banaun?'),
        ),
        FeatureBox(
          color: Pallete.secondSuggestionBoxColor,
          headerText: 'Have some fun',
          descriptionText: 'Ask for a joke and watch ${s.name} laugh along.',
          onTap: () => _send(convo, 'Tell me a funny joke!'),
        ),
        FeatureBox(
          color: Pallete.thirdSuggestionBoxColor,
          headerText: 'Make it yours',
          descriptionText: 'Change the name, face, gender, voice, accent and personality any time.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
      ],
    );
  }

  Widget _chatList(ConversationController convo) {
    final items = convo.messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => _Bubble(message: items[i], accent: convo.settings.accentColor),
    );
  }

  Widget _inputBar(ConversationController convo) {
    final listening = convo.voice.isListening;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(convo),
              decoration: InputDecoration(
                hintText: 'Message ${convo.settings.name}…',
                filled: true,
                fillColor: Pallete.assistantCircleColor.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            icon: const Icon(Icons.send_rounded),
            color: Pallete.mainFontColor,
            onPressed: () => _send(convo),
          ),
          if (convo.voice.isSpeaking)
            IconButton(
              tooltip: 'Stop speaking',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: convo.voice.stopSpeaking,
            ),
          FloatingActionButton.small(
            heroTag: 'mic',
            elevation: listening ? 6 : 2,
            backgroundColor: listening ? Colors.redAccent : Pallete.firstSuggestionBoxColor,
            tooltip: listening ? 'Stop listening' : 'Speak',
            onPressed: () => convo.toggleListening(onError: _showError),
            child: Icon(listening ? Icons.stop : Icons.mic, color: listening ? Colors.white : Pallete.blackColor),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final Color accent;
  const _Bubble({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    final waiting = !user && message.text.isEmpty;
    final bg = user
        ? Pallete.secondSuggestionBoxColor
        : message.isError
            ? Colors.red.shade50
            : Color.lerp(Colors.white, accent, 0.12)!;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: user ? Radius.zero : null,
            topLeft: user ? null : Radius.zero,
          ),
        ),
        child: waiting
            ? const _TypingDots()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(message.text, style: const TextStyle(fontSize: 16, color: Pallete.blackColor)),
                  if (!user && !message.isError && message.emotion != Emotion.thinking)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${message.emotion.emoji}  ${message.language == null ? '' : LanguageDetector.nameOf(message.language!)}',
                        style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final v = ((_c.value * 3 - i) % 3);
          final up = v < 1 ? (1 - (v - 0.5).abs() * 2) : 0.0;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7,
            height: 7,
            transform: Matrix4.translationValues(0, -4 * up, 0),
            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          );
        }),
      ),
    );
  }
}

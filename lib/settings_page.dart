import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/assistant_settings.dart';
import 'models/emotion.dart';
import 'pallete.dart';
import 'services/conversation_controller.dart';
import 'services/language_detector.dart';
import 'services/settings_controller.dart';
import 'services/voice_service.dart';
import 'widgets/avatar/animated_avatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  Emotion _preview = Emotion.happy;
  bool _showKey = false;

  static const _accents = [
    Color(0xFF3DE0FF), Color(0xFF7C4DFF), Color(0xFFFF4F9A), Color(0xFF00E676),
    Color(0xFFFFB300), Color(0xFFFF5252), Color(0xFF448AFF), Color(0xFF26C6DA),
  ];
  static const _skins = [
    Color(0xFFFFE0CC), Color(0xFFF1C9A5), Color(0xFFE0AC69), Color(0xFFC68642),
    Color(0xFF8D5524), Color(0xFF5C3A1E),
  ];
  static const _hairs = [
    Color(0xFF1B1B1B), Color(0xFF3B2416), Color(0xFF7B4A2A), Color(0xFFC59A5B),
    Color(0xFFE8D19A), Color(0xFFB0412C), Color(0xFF9E9E9E), Color(0xFF7E57C2),
  ];
  static const _eyes = [
    Color(0xFF4E342E), Color(0xFF1B1B1B), Color(0xFF3E7CB1), Color(0xFF4C8C4A),
    Color(0xFF8D6E63), Color(0xFF9C6ADE),
  ];

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>().settings;
    _name = TextEditingController(text: s.name);
    _apiKey = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
  }

  @override
  void dispose() {
    _name.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final voice = context.watch<VoiceService>();
    final s = ctrl.settings;
    void set(AssistantSettings Function(AssistantSettings) f) => ctrl.update(f);

    return Scaffold(
      appBar: AppBar(title: const Text('Customize Assistant')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // Live preview.
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedAvatar(
                settings: s,
                emotion: _preview,
                speaking: voice.isSpeaking,
                wordTick: voice.wordTick,
                size: 200,
              ),
            ),
          ),
          Center(child: Text(s.name, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in Emotion.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text('${e.emoji} ${e.name}'),
                      selected: _preview == e,
                      onSelected: (_) => setState(() => _preview = e),
                    ),
                  ),
              ],
            ),
          ),

          _section('Identity'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Assistant name',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (v.trim().isNotEmpty) set((s) => s.copyWith(name: v.trim()));
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AssistantGender>(
              segments: [
                for (final g in AssistantGender.values)
                  ButtonSegment(value: g, label: Text(g.label), icon: Icon(g.icon)),
              ],
              selected: {s.gender},
              onSelectionChanged: (v) => set((s) => s.copyWith(
                    gender: v.first,
                    pitch: v.first.defaultPitch,
                    clearVoice: true,
                  )),
            ),
          ),
          _label('Personality'),
          _chips<Personality>(
            Personality.values,
            s.personality,
            (p) => p.label,
            (p) => set((s) => s.copyWith(personality: p)),
          ),

          _section('Face & Avatar'),
          _chips<AvatarStyle>(
            AvatarStyle.values,
            s.avatarStyle,
            (a) => a.label,
            (a) => set((s) => s.copyWith(avatarStyle: a)),
          ),
          _label(s.avatarStyle == AvatarStyle.human ? 'Clothing colour' : 'Glow / accent colour'),
          _swatches(_accents, s.accentColor, (c) => set((s) => s.copyWith(accentColor: c))),
          if (s.avatarStyle == AvatarStyle.human) ...[
            _label('Skin tone'),
            _swatches(_skins, s.skinTone, (c) => set((s) => s.copyWith(skinTone: c))),
            _label('Hair colour'),
            _swatches(_hairs, s.hairColor, (c) => set((s) => s.copyWith(hairColor: c))),
            _label('Eye colour'),
            _swatches(_eyes, s.eyeColor, (c) => set((s) => s.copyWith(eyeColor: c))),
          ],

          _section('Language'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: s.language,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Conversation language',
                prefixIcon: Icon(Icons.translate),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'auto', child: Text('Auto-detect (reply in your language)')),
                for (final l in LanguageDetector.languages)
                  DropdownMenuItem(value: l.code, child: Text('${l.name} · ${l.nativeName}')),
              ],
              onChanged: (v) => set((s) => s.copyWith(language: v)),
            ),
          ),

          _section('Voice'),
          _voicePicker(voice, s, set),
          _slider('Pitch', s.pitch, 0.5, 2.0, (v) => set((s) => s.copyWith(pitch: v)),
              display: s.pitch.toStringAsFixed(2)),
          _slider('Speaking speed', s.speechRate, 0.1, 1.0, (v) => set((s) => s.copyWith(speechRate: v)),
              display: '${(s.speechRate * 2).toStringAsFixed(1)}×'),
          _slider('Volume', s.volume, 0, 1, (v) => set((s) => s.copyWith(volume: v)),
              display: '${(s.volume * 100).round()}%'),
          SwitchListTile(
            title: const Text('Speak replies aloud'),
            value: s.speakReplies,
            onChanged: (v) => set((s) => s.copyWith(speakReplies: v)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Preview voice'),
              onPressed: () => context.read<ConversationController>().previewVoice(),
            ),
          ),

          _section('AI Brain'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _apiKey,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Anthropic API key',
                helperText: 'Stored only on this device. Get one at console.anthropic.com',
                prefixIcon: const Icon(Icons.key),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
              onChanged: (v) => set((s) => s.copyWith(apiKey: v.trim())),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _model,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Model',
                prefixIcon: Icon(Icons.memory),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (v.trim().isNotEmpty) set((s) => s.copyWith(model: v.trim()));
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset appearance & voice to defaults'),
              onPressed: () async {
                await ctrl.reset();
                _name.text = ctrl.settings.name;
                _model.text = ctrl.settings.model;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _voicePicker(
    VoiceService voice,
    AssistantSettings s,
    void Function(AssistantSettings Function(AssistantSettings)) set,
  ) {
    final voices = voice.voices;
    if (voices.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Using the system default voice'),
        subtitle: Text('Install more voices in your device\'s text-to-speech settings.'),
      );
    }
    // Show voices for the chosen language first (or all when auto-detecting).
    final lang = s.language == 'auto' ? null : LanguageDetector.ttsLocale(s.language).split('-').first;
    final filtered = lang == null
        ? voices
        : voices.where((v) => v.locale.toLowerCase().startsWith(lang)).toList();
    final list = filtered.isEmpty ? voices : filtered;
    final current = list.any((v) => v.name == s.voiceName) ? s.voiceName : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String?>(
        initialValue: current,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Voice & accent',
          prefixIcon: Icon(Icons.graphic_eq),
          border: OutlineInputBorder(),
          helperText: 'Auto picks a voice matching the language and gender',
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Auto')),
          for (final v in list)
            DropdownMenuItem<String?>(value: v.name, child: Text(v.label, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (name) {
          if (name == null) {
            set((s) => s.copyWith(clearVoice: true));
          } else {
            final v = list.firstWhere((v) => v.name == name);
            set((s) => s.copyWith(voiceName: v.name, voiceLocale: v.locale));
          }
        },
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cera Pro',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Pallete.mainFontColor,
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) onSelect) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final v in values)
            ChoiceChip(label: Text(label(v)), selected: v == selected, onSelected: (_) => onSelect(v)),
        ],
      ),
    );
  }

  Widget _swatches(List<Color> colors, Color selected, void Function(Color) onSelect) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onSelect(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.toARGB32() == selected.toARGB32() ? Pallete.mainFontColor : Colors.black12,
                    width: c.toARGB32() == selected.toARGB32() ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged,
      {required String display}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(
            child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
          ),
          SizedBox(width: 48, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

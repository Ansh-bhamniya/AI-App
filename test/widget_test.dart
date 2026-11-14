import 'package:aiapp/models/assistant_settings.dart';
import 'package:aiapp/models/emotion.dart';
import 'package:aiapp/services/language_detector.dart';
import 'package:aiapp/widgets/avatar/animated_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageDetector', () {
    test('detects scripts and Latin-script languages', () {
      expect(LanguageDetector.detect('नमस्ते, आप कैसे हैं?'), 'hi-IN');
      expect(LanguageDetector.detect('آپ کیسے ہیں؟ میں ٹھیک ہوں'), 'ur-PK');
      expect(LanguageDetector.detect('今日はいい天気ですね'), 'ja-JP');
      expect(LanguageDetector.detect('你好，今天天气怎么样'), 'zh-CN');
      expect(LanguageDetector.detect('Hola, ¿cómo estás?'), 'es-ES');
      expect(LanguageDetector.detect("Bonjour, comment ça va ?"), 'fr-FR');
      expect(LanguageDetector.detect('bhai kya haal hai, sab theek?'), LanguageDetector.hinglish);
      expect(LanguageDetector.detect('Hello, how are you today?'), 'en-US');
    });
  });

  testWidgets('every avatar style renders every expression', (tester) async {
    for (final style in AvatarStyle.values) {
      for (final gender in AssistantGender.values) {
        for (final emotion in Emotion.values) {
          await tester.pumpWidget(MaterialApp(
            home: Center(
              child: AnimatedAvatar(
                settings: AssistantSettings(avatarStyle: style, gender: gender),
                emotion: emotion,
                speaking: emotion.index.isEven,
                size: 200,
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: '$style $gender $emotion');
        }
      }
    }
  });

  test('settings survive a JSON round-trip', () {
    const s = AssistantSettings(
      name: 'Aria',
      gender: AssistantGender.female,
      avatarStyle: AvatarStyle.human,
      personality: Personality.funny,
      pitch: 1.3,
      language: 'hi-IN',
    );
    final back = AssistantSettings.fromJson(s.toJson());
    expect(back.name, 'Aria');
    expect(back.gender, AssistantGender.female);
    expect(back.avatarStyle, AvatarStyle.human);
    expect(back.personality, Personality.funny);
    expect(back.pitch, 1.3);
    expect(back.language, 'hi-IN');
  });
}

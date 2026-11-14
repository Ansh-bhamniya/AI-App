import 'package:flutter/material.dart';

/// Gender of the assistant persona. Affects default voice pitch, the human
/// avatar's hair style and how the assistant refers to itself.
enum AssistantGender { male, female, neutral }

/// Visual style of the animated face.
enum AvatarStyle {
  /// Glossy glowing robot orb.
  orb,

  /// Flat kawaii doodle face.
  kawaii,

  /// Stylised 2D human face with skin, hair, eyes, brows and lips.
  human,
}

/// Overall personality tone the assistant uses.
enum Personality { friendly, funny, professional, calm, energetic }

extension AssistantGenderLabel on AssistantGender {
  String get label => switch (this) {
        AssistantGender.male => 'Male',
        AssistantGender.female => 'Female',
        AssistantGender.neutral => 'Gender-Neutral',
      };

  IconData get icon => switch (this) {
        AssistantGender.male => Icons.male,
        AssistantGender.female => Icons.female,
        AssistantGender.neutral => Icons.transgender,
      };

  /// Pitch used when the user hasn't tuned it manually.
  double get defaultPitch => switch (this) {
        AssistantGender.male => 0.85,
        AssistantGender.female => 1.2,
        AssistantGender.neutral => 1.0,
      };
}

extension AvatarStyleLabel on AvatarStyle {
  String get label => switch (this) {
        AvatarStyle.orb => 'Robot Orb',
        AvatarStyle.kawaii => 'Kawaii',
        AvatarStyle.human => 'Human',
      };
}

extension PersonalityLabel on Personality {
  String get label => switch (this) {
        Personality.friendly => 'Friendly',
        Personality.funny => 'Funny',
        Personality.professional => 'Professional',
        Personality.calm => 'Calm',
        Personality.energetic => 'Energetic',
      };

  String get prompt => switch (this) {
        Personality.friendly =>
          'warm, friendly, polite and encouraging, with light humour',
        Personality.funny =>
          'playful and witty, fond of gentle jokes and puns, while still genuinely helpful',
        Personality.professional =>
          'polite, precise and professional, friendly but to the point',
        Personality.calm => 'calm, soothing, patient and kind',
        Personality.energetic =>
          'upbeat, enthusiastic and cheerful, full of positive energy',
      };
}

/// All user-customisable assistant settings.
@immutable
class AssistantSettings {
  final String name;
  final AssistantGender gender;
  final AvatarStyle avatarStyle;
  final Personality personality;

  // Appearance
  final Color accentColor;
  final Color skinTone;
  final Color hairColor;
  final Color eyeColor;

  // Voice
  final String? voiceName;
  final String? voiceLocale;
  final double pitch;
  final double speechRate;
  final double volume;
  final bool speakReplies;

  // Language
  /// 'auto' to detect the user's language, otherwise a BCP-47 tag.
  final String language;

  // AI backend
  final String apiKey;
  final String model;

  const AssistantSettings({
    this.name = 'Nova',
    this.gender = AssistantGender.neutral,
    this.avatarStyle = AvatarStyle.orb,
    this.personality = Personality.friendly,
    this.accentColor = const Color(0xFF3DE0FF),
    this.skinTone = const Color(0xFFF1C9A5),
    this.hairColor = const Color(0xFF3B2416),
    this.eyeColor = const Color(0xFF4E342E),
    this.voiceName,
    this.voiceLocale,
    this.pitch = 1.0,
    this.speechRate = 0.5,
    this.volume = 1.0,
    this.speakReplies = true,
    this.language = 'auto',
    this.apiKey = '',
    this.model = 'claude-opus-5-5',
  });

  AssistantSettings copyWith({
    String? name,
    AssistantGender? gender,
    AvatarStyle? avatarStyle,
    Personality? personality,
    Color? accentColor,
    Color? skinTone,
    Color? hairColor,
    Color? eyeColor,
    String? voiceName,
    String? voiceLocale,
    bool clearVoice = false,
    double? pitch,
    double? speechRate,
    double? volume,
    bool? speakReplies,
    String? language,
    String? apiKey,
    String? model,
  }) {
    return AssistantSettings(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      personality: personality ?? this.personality,
      accentColor: accentColor ?? this.accentColor,
      skinTone: skinTone ?? this.skinTone,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      voiceName: clearVoice ? null : (voiceName ?? this.voiceName),
      voiceLocale: clearVoice ? null : (voiceLocale ?? this.voiceLocale),
      pitch: pitch ?? this.pitch,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      speakReplies: speakReplies ?? this.speakReplies,
      language: language ?? this.language,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'gender': gender.name,
        'avatarStyle': avatarStyle.name,
        'personality': personality.name,
        'accentColor': accentColor.toARGB32(),
        'skinTone': skinTone.toARGB32(),
        'hairColor': hairColor.toARGB32(),
        'eyeColor': eyeColor.toARGB32(),
        'voiceName': voiceName,
        'voiceLocale': voiceLocale,
        'pitch': pitch,
        'speechRate': speechRate,
        'volume': volume,
        'speakReplies': speakReplies,
        'language': language,
        'model': model,
      };

  factory AssistantSettings.fromJson(Map<String, dynamic> j, {String apiKey = ''}) {
    const d = AssistantSettings();
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.firstWhere((e) => e.name == v, orElse: () => fallback);
    Color color(Object? v, Color fallback) => v is int ? Color(v) : fallback;
    double dbl(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
    return AssistantSettings(
      name: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : d.name,
      gender: pick(AssistantGender.values, j['gender'], d.gender),
      avatarStyle: pick(AvatarStyle.values, j['avatarStyle'], d.avatarStyle),
      personality: pick(Personality.values, j['personality'], d.personality),
      accentColor: color(j['accentColor'], d.accentColor),
      skinTone: color(j['skinTone'], d.skinTone),
      hairColor: color(j['hairColor'], d.hairColor),
      eyeColor: color(j['eyeColor'], d.eyeColor),
      voiceName: j['voiceName'] as String?,
      voiceLocale: j['voiceLocale'] as String?,
      pitch: dbl(j['pitch'], d.pitch),
      speechRate: dbl(j['speechRate'], d.speechRate),
      volume: dbl(j['volume'], d.volume),
      speakReplies: j['speakReplies'] as bool? ?? d.speakReplies,
      language: j['language'] as String? ?? d.language,
      model: j['model'] as String? ?? d.model,
      apiKey: apiKey,
    );
  }
}

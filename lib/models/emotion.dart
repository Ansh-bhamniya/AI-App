/// Facial expressions the avatar can show. The AI tags each reply with one
/// of these so the face reacts naturally to what it is saying.
enum Emotion {
  neutral,
  happy,
  laugh,
  wink,
  playful,
  love,
  surprised,
  thinking,
  confused,
  sad,
  crying,
  angry,
  sleepy,
  dizzy,
}

extension EmotionInfo on Emotion {
  String get emoji => switch (this) {
        Emotion.neutral => '🙂',
        Emotion.happy => '😊',
        Emotion.laugh => '😆',
        Emotion.wink => '😉',
        Emotion.playful => '😜',
        Emotion.love => '🥰',
        Emotion.surprised => '😮',
        Emotion.thinking => '🤔',
        Emotion.confused => '😵‍💫',
        Emotion.sad => '😢',
        Emotion.crying => '😭',
        Emotion.angry => '😠',
        Emotion.sleepy => '😴',
        Emotion.dizzy => '😵',
      };

  static Emotion parse(String? s) => Emotion.values.firstWhere(
        (e) => e.name == s?.trim().toLowerCase(),
        orElse: () => Emotion.happy,
      );
}

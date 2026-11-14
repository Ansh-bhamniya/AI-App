/// A supported language: display name, BCP-47 tag used for TTS / STT.
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  const AppLanguage(this.code, this.name, this.nativeName);
}

/// Lightweight, offline language detection based on Unicode scripts and
/// common function words. It is used to pick a speech locale instantly; the
/// AI also reports the language it answered in, which takes precedence.
class LanguageDetector {
  static const hinglish = 'hi-Latn';

  static const languages = <AppLanguage>[
    AppLanguage('en-US', 'English (US)', 'English'),
    AppLanguage('en-GB', 'English (UK)', 'English'),
    AppLanguage('en-IN', 'English (India)', 'English'),
    AppLanguage('hi-IN', 'Hindi', 'हिन्दी'),
    AppLanguage(hinglish, 'Hinglish', 'Hinglish'),
    AppLanguage('ur-PK', 'Urdu', 'اردو'),
    AppLanguage('es-ES', 'Spanish', 'Español'),
    AppLanguage('fr-FR', 'French', 'Français'),
    AppLanguage('de-DE', 'German', 'Deutsch'),
    AppLanguage('it-IT', 'Italian', 'Italiano'),
    AppLanguage('pt-BR', 'Portuguese', 'Português'),
    AppLanguage('ru-RU', 'Russian', 'Русский'),
    AppLanguage('ar-SA', 'Arabic', 'العربية'),
    AppLanguage('fa-IR', 'Persian', 'فارسی'),
    AppLanguage('tr-TR', 'Turkish', 'Türkçe'),
    AppLanguage('ja-JP', 'Japanese', '日本語'),
    AppLanguage('zh-CN', 'Chinese', '中文'),
    AppLanguage('ko-KR', 'Korean', '한국어'),
    AppLanguage('bn-IN', 'Bengali', 'বাংলা'),
    AppLanguage('pa-IN', 'Punjabi', 'ਪੰਜਾਬੀ'),
    AppLanguage('gu-IN', 'Gujarati', 'ગુજરાતી'),
    AppLanguage('ta-IN', 'Tamil', 'தமிழ்'),
    AppLanguage('te-IN', 'Telugu', 'తెలుగు'),
    AppLanguage('kn-IN', 'Kannada', 'ಕನ್ನಡ'),
    AppLanguage('ml-IN', 'Malayalam', 'മലയാളം'),
    AppLanguage('mr-IN', 'Marathi', 'मराठी'),
    AppLanguage('th-TH', 'Thai', 'ไทย'),
    AppLanguage('vi-VN', 'Vietnamese', 'Tiếng Việt'),
    AppLanguage('id-ID', 'Indonesian', 'Bahasa Indonesia'),
    AppLanguage('nl-NL', 'Dutch', 'Nederlands'),
    AppLanguage('pl-PL', 'Polish', 'Polski'),
    AppLanguage('uk-UA', 'Ukrainian', 'Українська'),
    AppLanguage('el-GR', 'Greek', 'Ελληνικά'),
    AppLanguage('he-IL', 'Hebrew', 'עברית'),
    AppLanguage('sw-KE', 'Swahili', 'Kiswahili'),
  ];

  static String nameOf(String code) =>
      languages.where((l) => l.code == code).map((l) => l.name).firstOrNull ?? code;

  /// Locale to hand to text-to-speech. Hinglish is spoken by an Indian
  /// English/Hindi voice since TTS engines don't have a Hinglish locale.
  static String ttsLocale(String code) => code == hinglish ? 'en-IN' : code;

  /// Locale to hand to speech recognition.
  static String sttLocale(String code) => code == hinglish ? 'hi-IN' : code;

  static const _hinglishWords = {
    'hai', 'hain', 'kya', 'kaise', 'kaisa', 'kaisi', 'nahi', 'nahin', 'mera',
    'meri', 'mere', 'tum', 'tera', 'teri', 'aap', 'aapka', 'kar', 'karo',
    'karna', 'raha', 'rahi', 'rahe', 'kyun', 'kyu', 'bhai', 'yaar', 'acha',
    'accha', 'achha', 'theek', 'thik', 'haan', 'bahut', 'bohot', 'mujhe',
    'tujhe', 'hum', 'batao', 'bata', 'kuch', 'abhi', 'kab', 'kahan', 'chalo',
    'matlab', 'samjha', 'samjhao', 'pyaar', 'dost', 'ho', 'gaya', 'gayi',
  };
  static const _spanishWords = {
    'el', 'la', 'los', 'las', 'que', 'por', 'para', 'como', 'estás', 'estas',
    'hola', 'gracias', 'qué', 'cómo', 'muy', 'pero', 'también', 'es', 'una',
    'yo', 'tú', 'usted', 'buenos', 'días', 'quiero', 'puedes',
  };
  static const _frenchWords = {
    'le', 'les', 'des', 'est', 'je', 'tu', 'vous', 'nous', 'bonjour', 'merci',
    'oui', 'non', 'avec', 'pour', 'pas', 'une', 'comment', 'ça', 'suis',
    "c'est", 'très', 'bien', 'salut', 'pourquoi', 'qui', 'quoi',
  };
  static const _germanWords = {
    'der', 'die', 'das', 'und', 'ist', 'nicht', 'ich', 'du', 'sie', 'wir',
    'hallo', 'danke', 'bitte', 'wie', 'was', 'warum', 'mit', 'ein', 'eine',
  };
  static const _portugueseWords = {
    'você', 'obrigado', 'obrigada', 'não', 'olá', 'tudo', 'bem', 'muito',
    'como', 'está', 'eu', 'é', 'um', 'uma', 'com',
  };
  static const _italianWords = {
    'ciao', 'grazie', 'sono', 'come', 'stai', 'perché', 'il', 'gli', 'della',
    'questo', 'molto', 'buongiorno', 'prego',
  };
  static const _englishWords = {
    'the', 'is', 'are', 'you', 'what', 'how', 'hello', 'hi', 'please', 'can',
    'i', 'my', 'me', 'and', 'to', 'of', 'it', 'this', 'that', 'do', 'tell',
  };

  /// Returns a BCP-47 code (or [hinglish]) for [text], or null when unsure.
  static String? detect(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    final counts = <String, int>{};
    var hasKana = false;
    var hasUrduLetters = false;
    var hasPersianLetters = false;
    for (final r in t.runes) {
      final s = _script(r);
      if (s != null) counts[s] = (counts[s] ?? 0) + 1;
      if ((r >= 0x3040 && r <= 0x30FF)) hasKana = true;
      // ٹ ڈ ڑ ں ے ھ are specific to Urdu.
      if (const {0x0679, 0x0688, 0x0691, 0x06BA, 0x06D2, 0x06BE}.contains(r)) {
        hasUrduLetters = true;
      }
      if (const {0x067E, 0x0686, 0x0698, 0x06AF, 0x06A9, 0x06CC}.contains(r)) {
        hasPersianLetters = true;
      }
    }

    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      if (top != 'latin') {
        switch (top) {
          case 'han':
            return hasKana ? 'ja-JP' : 'zh-CN';
          case 'kana':
            return 'ja-JP';
          case 'arabic':
            if (hasUrduLetters) return 'ur-PK';
            if (hasPersianLetters) return 'fa-IR';
            return 'ar-SA';
          default:
            return top;
        }
      }
    }

    // Latin script: score by function words.
    final words = t
        .toLowerCase()
        .split(RegExp(r"[^\p{L}']+", unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    int score(Set<String> dict) => words.where(dict.contains).length;

    final scores = <String, int>{
      hinglish: score(_hinglishWords),
      'es-ES': score(_spanishWords) + (RegExp('[ñ¿¡]').hasMatch(t) ? 2 : 0),
      'fr-FR': score(_frenchWords) + (RegExp('[çœ]').hasMatch(t) ? 2 : 0),
      'de-DE': score(_germanWords) + (RegExp('[ßäöü]').hasMatch(t) ? 2 : 0),
      'pt-BR': score(_portugueseWords) + (RegExp('[ãõ]').hasMatch(t) ? 2 : 0),
      'it-IT': score(_italianWords),
      'en-US': score(_englishWords),
    };
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value == 0) return null;
    // English ties are common for short loan-word phrases; prefer English.
    if (best.key != 'en-US' && best.value <= scores['en-US']!) return 'en-US';
    return best.key;
  }

  static String? _script(int r) {
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      return 'latin';
    }
    if (r >= 0x0900 && r <= 0x097F) return 'hi-IN'; // Devanagari
    if (r >= 0x0980 && r <= 0x09FF) return 'bn-IN';
    if (r >= 0x0A00 && r <= 0x0A7F) return 'pa-IN';
    if (r >= 0x0A80 && r <= 0x0AFF) return 'gu-IN';
    if (r >= 0x0B80 && r <= 0x0BFF) return 'ta-IN';
    if (r >= 0x0C00 && r <= 0x0C7F) return 'te-IN';
    if (r >= 0x0C80 && r <= 0x0CFF) return 'kn-IN';
    if (r >= 0x0D00 && r <= 0x0D7F) return 'ml-IN';
    if (r >= 0x0E00 && r <= 0x0E7F) return 'th-TH';
    if (r >= 0x0600 && r <= 0x06FF) return 'arabic';
    if (r >= 0x0590 && r <= 0x05FF) return 'he-IL';
    if (r >= 0x0400 && r <= 0x04FF) return 'ru-RU';
    if (r >= 0x0370 && r <= 0x03FF) return 'el-GR';
    if (r >= 0x3040 && r <= 0x30FF) return 'kana';
    if (r >= 0xAC00 && r <= 0xD7AF) return 'ko-KR';
    if (r >= 0x4E00 && r <= 0x9FFF) return 'han';
    return null;
  }
}

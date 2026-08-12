
class LanguageDetector {
  static final RegExp _urduScript = RegExp(r'[\u0600-\u06FF]');

  static const Set<String> _romanUrduHints = {
    'ko', 'karo', 'kar', 'kia', 'kya', 'hai', 'haan', 'ha', 'nahi', 'nahin',
    'bhejo', 'bhej', 'lagao', 'laga', 'wala', 'wali', 'ka', 'ki', 'ke', 'se',
    'mein', 'main', 'mujhe', 'mujhy', 'krdo', 'krna', 'karna',
    'aap', 'tum', 'apko', 'apki', 'mera', 'meri', 'mere', 'usko', 'isko',
    'bhai', 'ami', 'ammi', 'abu', 'abbu', 'yaar', 'theek', 'bilkul',
    'sunao', 'batao', 'bataen', 'batayein', 'chahiye', 'chahye',
    'baje', 'subah', 'shaam', 'raat', 'kal', 'aaj', 'abhi', 'jaldi',
    'mat', 'ji', 'g', 'assalam', 'salam', 'walaikum', 'alaikum',
    'yaad', 'dehani',
    'milao', 'mila', 'baat', 'karao', 'parho', 'parh',
    'dena', 'dijye', 'dijiye',
    'zara', 'thora', 'thoda', 'ek', 'aik', 'kisko', 'kis',
    'naam',
  };

  /// Returns `ur`, `roman_ur`, or `en`.
  static String detect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'en';

    if (_urduScript.hasMatch(trimmed)) return 'ur';

    final words = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'en';

    var hits = 0;
    for (final w in words) {
      if (_romanUrduHints.contains(w)) hits++;
    }

    // A single function word ("ko", "karo", "baje") is enough for Roman Urdu
    // because commands are short: "Ali ko call karo".
    if (hits >= 1) return 'roman_ur';
    return 'en';
  }

  /// TTS locale. en-IN is clearer for Pakistani English / Roman Urdu.
  static String ttsLocale(String language) {
    switch (language) {
      case 'ur':
        return 'ur-PK';
      case 'roman_ur':
      case 'en':
      default:
        return 'en-IN';
    }
  }

  /// STT locale. en-IN handles Pakistani accents and Roman Urdu far better
  /// than en-US. ur-PK only when the user explicitly chose Urdu.
  static String sttLocale(String language) {
    switch (language) {
      case 'ur':
        return 'ur-PK';
      case 'roman_ur':
      case 'en':
      default:
        return 'en-IN';
    }
  }
}

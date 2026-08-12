/// Fixes common speech-to-text mishearings for Pakistani English and Roman Urdu.
///
/// Google STT often turns "ko call karo" into "go call carol", "call" into
/// "coal", "ammi" into "army", etc. These replacements run before NLP.
class SpeechCorrector {
  SpeechCorrector._();

  /// Longer phrases first so they win over single-word swaps.
  static final List<(RegExp, String)> _fixes = [
    // Roman Urdu command phrases
    (RegExp(r'\bgo call carol\b'), 'ko call karo'),
    (RegExp(r'\bgo call karo\b'), 'ko call karo'),
    (RegExp(r'\bgo call caro\b'), 'ko call karo'),
    (RegExp(r'\bgo call cargo\b'), 'ko call karo'),
    (RegExp(r'\bgo call car o\b'), 'ko call karo'),
    (RegExp(r'\bto call carol\b'), 'ko call karo'),
    (RegExp(r'\bgo coal karo\b'), 'ko call karo'),
    (RegExp(r'\bgo coal carol\b'), 'ko call karo'),
    (RegExp(r'\bko call carol\b'), 'ko call karo'),
    (RegExp(r'\bko coal karo\b'), 'ko call karo'),
    (RegExp(r'\bgo phone carol\b'), 'ko phone karo'),
    (RegExp(r'\bgo phone karo\b'), 'ko phone karo'),
    (RegExp(r'\bko phone carol\b'), 'ko phone karo'),
    (RegExp(r'\bgo message carol\b'), 'ko message karo'),
    (RegExp(r'\bgo message karo\b'), 'ko message karo'),
    (RegExp(r'\bgo message beige\b'), 'ko message bhejo'),
    (RegExp(r'\bgo msg karo\b'), 'ko msg karo'),
    (RegExp(r'\bgo text karo\b'), 'ko text karo'),
    (RegExp(r'\bgo sms karo\b'), 'ko sms karo'),
    (RegExp(r'\bcall carol\b'), 'call karo'),
    (RegExp(r'\bphone carol\b'), 'phone karo'),
    (RegExp(r'\bmessage carol\b'), 'message karo'),
    (RegExp(r'\bgo call\b'), 'ko call'),
    (RegExp(r'\bgo phone\b'), 'ko phone'),
    (RegExp(r'\bgo message\b'), 'ko message'),
    (RegExp(r'\bgo msg\b'), 'ko msg'),
    (RegExp(r'\bgo text\b'), 'ko text'),
    (RegExp(r'\bdial a call to\b'), 'dial call to'),
    (RegExp(r'\bmake a call to\b'), 'make call to'),
    (RegExp(r'\bsend a message to\b'), 'send message to'),
    (RegExp(r'\bset an alarm\b'), 'set alarm'),
    (RegExp(r'\bset the alarm\b'), 'set alarm'),
    (RegExp(r'\bwake me up at\b'), 'alarm '),
    (RegExp(r'\bwake me at\b'), 'alarm '),
    (RegExp(r'\ba long\b'), 'alarm'),
    (RegExp(r'\ball arm\b'), 'alarm'),

    // Command keywords
    (RegExp(r'\bcoal\b'), 'call'),
    (RegExp(r'\bcole\b'), 'call'),
    (RegExp(r'\bkohl\b'), 'call'),
    (RegExp(r'\bkaul\b'), 'call'),
    (RegExp(r'\bcal\b'), 'call'),
    (RegExp(r'\bcalled\b'), 'call'),
    (RegExp(r'\bcalling\b'), 'call'),
    (RegExp(r'\bdale\b'), 'dial'),
    (RegExp(r'\bdahl\b'), 'dial'),
    (RegExp(r'\bmassage\b'), 'message'),
    (RegExp(r'\bmessages\b'), 'message'),
    (RegExp(r'\balong\b'), 'alarm'),
    (RegExp(r'\balaram\b'), 'alarm'),
    (RegExp(r'\ba ram\b'), 'alarm'),
    (RegExp(r'\bfoam\b'), 'phone'),
    (RegExp(r'\bfone\b'), 'phone'),
    (RegExp(r'\bfon\b'), 'phone'),
    (RegExp(r'\btax\b'), 'text'),
    (RegExp(r'\bsms\b'), 'sms'),

    // Roman Urdu function words
    (RegExp(r'\bcarol\b'), 'karo'),
    (RegExp(r'\bcargo\b'), 'karo'),
    (RegExp(r'\bcaro\b'), 'karo'),
    (RegExp(r'\bkara\b'), 'karo'),
    (RegExp(r'\bbhejo\b'), 'bhejo'),
    (RegExp(r'\bbeige o\b'), 'bhejo'),
    (RegExp(r'\bbeige\b'), 'bhejo'),
    (RegExp(r'\blago\b'), 'lagao'),
    (RegExp(r'\blogo\b'), 'lagao'),
    (RegExp(r'\blaga o\b'), 'lagao'),
    (RegExp(r'\bbudget\b'), 'baje'),
    (RegExp(r'\bbarge\b'), 'baje'),
    (RegExp(r'\bbadge\b'), 'baje'),
    (RegExp(r'\bbhajay\b'), 'baje'),
    (RegExp(r'\barmy\b'), 'ammi'),
    (RegExp(r'\bmummy\b'), 'ammi'),
    (RegExp(r'\bmommy\b'), 'ammi'),
    (RegExp(r'\bmom\b'), 'mom'),
    (RegExp(r'\baboo\b'), 'abu'),
    (RegExp(r'\ba boo\b'), 'abu'),
  ];

  /// Cleans punctuation and applies phonetic command fixes.
  ///
  /// When [aggressive] is false (message dictation), only light cleanup
  /// runs so the SMS body is not rewritten.
  static String correct(String input, {bool aggressive = true}) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = text.replaceAll(RegExp(r'[.,!?]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (!aggressive) return text;

    var lower = text.toLowerCase();
    for (final fix in _fixes) {
      lower = lower.replaceAll(fix.$1, fix.$2);
    }
    return lower.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

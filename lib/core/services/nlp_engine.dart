/// Multilingual NLP engine for the voice assistant.
///
/// Language support:
///   English     : "Call Salman", "Dial Mom", "Call to Salman"
///   Roman Urdu  : "Salman ko call karo", "Mom ko phone lagao"
///   Urdu script : "کال سلمان", "سلمان کو کال کرو", "سلمان کو فون کرو"
///   Mixed       : "please call Salman bhai"
///
/// Because STT always produces en-US output (see SpeechService), Urdu-script
/// input spoken aloud comes back as its phonetic English equivalent, e.g.:
///   Spoken: "کال سلمان" → STT returns: "call Salman"
///   Spoken: "سلمان کو فون کرو" → STT returns: "Salman ko phone karo"
///
/// The engine therefore primarily handles English + Roman Urdu patterns.
/// Urdu-script handling is kept as a safety net in case the user types input.

enum AssistantIntent {
  call,
  message,
  alarm,
  reminder,
  calendarSchedule,
  addEvent,
  deleteEvent,
  navigate,
  time,
  nextMeeting,
  readMessages,
  replyMessage,
  greeting,
  unknown,
}

class ParsedIntent {
  final AssistantIntent intent;
  final String? contactName;
  final String? messageText;
  final String? title;
  final String? time;
  final String? date;
  final String? targetScreen;
  final String? simSlot;
  final String rawQuery;

  ParsedIntent({
    required this.intent,
    this.contactName,
    this.messageText,
    this.title,
    this.time,
    this.date,
    this.targetScreen,
    this.simSlot,
    required this.rawQuery,
  });

  @override
  String toString() =>
      'ParsedIntent(intent: $intent, contact: $contactName, '
      'message: $messageText, title: $title, time: $time, '
      'date: $date, screen: $targetScreen, sim: $simSlot)';
}

class NlpEngine {
  // ======================================================================= //
  //  Public API                                                               //
  // ======================================================================= //

  static ParsedIntent parse(String query) {
    if (query.trim().isEmpty) {
      return ParsedIntent(intent: AssistantIntent.unknown, rawQuery: query);
    }

    final clean = query.toLowerCase().trim();

    // -------------------------------------------------------------------- //
    //  1. GREETING                                                           //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, [
      'hello', 'hi ', 'hi,', 'hey', 'hey assistant',
      'assalamu alaikum', 'assalam', 'salam',
      'a salaam', 'helo', 'good morning', 'good evening',
    ])) {
      return ParsedIntent(intent: AssistantIntent.greeting, rawQuery: query);
    }

    // -------------------------------------------------------------------- //
    //  2. TIME                                                               //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, [
      'what time is it', 'time check', 'time kya hai',
      'waqt kya', 'time kya hua', 'abhi kya time',
      'current time', 'tell me the time',
    ])) {
      return ParsedIntent(intent: AssistantIntent.time, rawQuery: query);
    }

    // -------------------------------------------------------------------- //
    //  3. CALL INTENT                                                        //
    //                                                                        //
    //  Patterns detected:                                                    //
    //    English   : "call salman", "dial salman", "call to salman"          //
    //    Roman Urdu: "salman ko call karo", "salman ko phone karo",          //
    //                "salman ko phone lagao", "salman ko milao",             //
    //                "salman se baat karao"                                  //
    //    Urdu      : "کال سلمان", "سلمان کو کال کرو", "سلمان کو فون کرو"    //
    //                (safety net — STT returns phonetic English normally)    //
    // -------------------------------------------------------------------- //
    if (_isCallIntent(clean)) {
      final extracted = _extractCallDetails(clean, query);
      return extracted;
    }

    // -------------------------------------------------------------------- //
    //  4. MESSAGING                                                          //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, [
      'read my latest messages', 'read messages', 'read my messages',
      'message parho', 'msg parh', 'messages sunao',
    ])) {
      return ParsedIntent(intent: AssistantIntent.readMessages, rawQuery: query);
    }

    if (_matchesAny(clean, [
      'reply to this message', 'reply this message',
      'reply karo', 'jawab do',
    ])) {
      return ParsedIntent(intent: AssistantIntent.replyMessage, rawQuery: query);
    }

    if (_isMessageIntent(clean)) {
      return _extractMessageIntent(clean, query);
    }

    // -------------------------------------------------------------------- //
    //  5. ALARM                                                              //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, [
      'alarm', 'wake me up', 'baje ka alarm', 'set an alarm',
      'alarm set', 'alarm lagao', 'alarm laga',
    ])) {
      final timeStr = _extractTime(clean);
      final dateStr = (clean.contains('tomorrow') || clean.contains('kal'))
          ? 'tomorrow'
          : 'today';
      return ParsedIntent(
        intent: AssistantIntent.alarm,
        time: timeStr,
        date: dateStr,
        rawQuery: query,
      );
    }

    // -------------------------------------------------------------------- //
    //  6. REMINDER                                                           //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, [
      'remind', 'yad dehani', 'remind karo', 'yaad dilao',
    ])) {
      return _extractReminderIntent(clean, query);
    }

    // -------------------------------------------------------------------- //
    //  7. CALENDAR                                                           //
    // -------------------------------------------------------------------- //
    if (_matchesAny(clean, ['schedule', 'agenda', 'today events'])) {
      return ParsedIntent(
        intent: AssistantIntent.calendarSchedule,
        date: 'today',
        rawQuery: query,
      );
    }

    if (_matchesAny(clean, ['next meeting', 'agla meeting', 'agli meeting'])) {
      return ParsedIntent(intent: AssistantIntent.nextMeeting, rawQuery: query);
    }

    if (clean.startsWith('add ') ||
        _matchesAny(clean, ['set meeting', 'meeting set kar do'])) {
      return _extractAddEventIntent(clean, query);
    }

    if (clean.contains('delete ') &&
        (clean.contains('event') || clean.contains('meeting'))) {
      return _extractDeleteEventIntent(clean, query);
    }

    // -------------------------------------------------------------------- //
    //  8. NAVIGATION                                                         //
    // -------------------------------------------------------------------- //
    if (clean.startsWith('open ') ||
        clean.startsWith('show ') ||
        clean.startsWith('go to ')) {
      final nav = _extractNavigationIntent(clean, query);
      if (nav != null) return nav;
    }

    // -------------------------------------------------------------------- //
    //  9. UNKNOWN                                                            //
    // -------------------------------------------------------------------- //
    return ParsedIntent(intent: AssistantIntent.unknown, rawQuery: query);
  }

  // ======================================================================= //
  //  Call intent detection                                                   //
  // ======================================================================= //

  /// Returns true if [clean] contains any call-related trigger.
  static bool _isCallIntent(String clean) {
    // English
    if (clean.startsWith('call ') ||
        clean.startsWith('dial ') ||
        clean.startsWith('phone ') ||
        clean.startsWith('call to ') ||
        clean.startsWith('please call ') ||
        clean.startsWith('can you call ') ||
        clean.startsWith('i want to call ')) {
      return true;
    }

    // Roman Urdu patterns
    if (clean.contains(' ko call karo') ||
        clean.contains(' ko call lagao') ||
        clean.contains(' ko phone karo') ||
        clean.contains(' ko phone lagao') ||
        clean.contains(' ko milao') ||
        clean.contains(' se baat karao') ||
        clean.contains(' se baat karo') ||
        clean.contains(' ko call kar') ||
        clean.contains(' ki call karo') ||
        clean.contains('call lagao') ||
        clean.contains('phone lagao')) {
      return true;
    }

    // Urdu script patterns (safety net)
    if (clean.contains('کال') ||
        clean.contains('فون') ||
        clean.contains('ملاؤ') ||
        clean.contains('ملانا')) {
      return true;
    }

    // Bare "call" in the middle of a sentence
    if (clean.contains(' call ') || clean.contains(' dial ')) {
      return true;
    }

    return false;
  }

  /// Extracts the contact name and optional SIM slot from a call command.
  static ParsedIntent _extractCallDetails(String clean, String rawQuery) {
    String name = '';
    String? simSlot;

    // ---- English patterns ---- //
    if (clean.startsWith('call to ')) {
      name = clean.replaceFirst('call to ', '');
    } else if (clean.startsWith('please call ')) {
      name = clean.replaceFirst('please call ', '');
    } else if (clean.startsWith('can you call ')) {
      name = clean.replaceFirst('can you call ', '');
    } else if (clean.startsWith('i want to call ')) {
      name = clean.replaceFirst('i want to call ', '');
    } else if (clean.startsWith('call ')) {
      name = clean.replaceFirst('call ', '');
    } else if (clean.startsWith('dial ')) {
      name = clean.replaceFirst('dial ', '');
    } else if (clean.startsWith('phone ')) {
      name = clean.replaceFirst('phone ', '');
    }

    // ---- Roman Urdu patterns ---- //
    else if (clean.contains(' ko call karo')) {
      name = clean.split(' ko call karo').first.trim();
    } else if (clean.contains(' ko call lagao')) {
      name = clean.split(' ko call lagao').first.trim();
    } else if (clean.contains(' ko call kar')) {
      name = clean.split(' ko call kar').first.trim();
    } else if (clean.contains(' ko phone karo')) {
      name = clean.split(' ko phone karo').first.trim();
    } else if (clean.contains(' ko phone lagao')) {
      name = clean.split(' ko phone lagao').first.trim();
    } else if (clean.contains(' ko milao')) {
      name = clean.split(' ko milao').first.trim();
    } else if (clean.contains(' se baat karao')) {
      name = clean.split(' se baat karao').first.trim();
    } else if (clean.contains(' se baat karo')) {
      name = clean.split(' se baat karo').first.trim();
    } else if (clean.contains(' ki call karo')) {
      name = clean.split(' ki call karo').first.trim();
    } else if (clean.contains('call lagao')) {
      // "X call lagao" — extract X
      name = clean.replaceAll('call lagao', '').trim();
    } else if (clean.contains('phone lagao')) {
      name = clean.replaceAll('phone lagao', '').trim();
    } else if (clean.contains(' call ')) {
      // Generic "X call Y" — take the part before "call"
      final parts = clean.split(' call ');
      name = parts.first.trim();
    } else if (clean.contains(' dial ')) {
      final parts = clean.split(' dial ');
      name = parts.last.trim();
    }

    // ---- Urdu script patterns (safety net) ---- //
    else if (clean.contains('کال')) {
      // "کال سلمان" or "سلمان کو کال کرو"
      name = clean
          .replaceAll('کال', '')
          .replaceAll('کو', '')
          .replaceAll('کرو', '')
          .replaceAll('لگاؤ', '')
          .trim();
    } else if (clean.contains('فون')) {
      name = clean
          .replaceAll('فون', '')
          .replaceAll('کو', '')
          .replaceAll('کرو', '')
          .replaceAll('لگاؤ', '')
          .trim();
    }

    // ---- Strip SIM selection suffix ---- //
    // e.g. "salman from zong", "salman on jazz", "salman via sim1"
    name = _stripSimFromName(name, (sim) => simSlot = sim);

    // ---- Strip filler words from the name ---- //
    name = _stripCallFillers(name);

    // Capitalize properly
    final cleanName = _toTitleCase(name.trim());

    print('NlpEngine: call intent — raw="$rawQuery" → name="$cleanName" sim="$simSlot"');

    return ParsedIntent(
      intent: AssistantIntent.call,
      contactName: cleanName,
      simSlot: simSlot?.toLowerCase(),
      rawQuery: rawQuery,
    );
  }

  // ======================================================================= //
  //  Name cleaning helpers                                                   //
  // ======================================================================= //

  /// Removes SIM selection words from [name] and calls [onSimFound] with the
  /// extracted SIM name.
  static String _stripSimFromName(String name, void Function(String) onSimFound) {
    for (final sep in [' from ', ' on ', ' via ', ' se ', ' using ']) {
      if (name.contains(sep)) {
        final parts = name.split(sep);
        onSimFound(parts.last.trim());
        return parts.first.trim();
      }
    }
    return name;
  }

  /// Removes common filler/command words that might still appear in the name.
  static String _stripCallFillers(String name) {
    final fillers = [
      // English
      'call', 'dial', 'phone', 'to', 'please', 'can you', 'i want',
      // Roman Urdu
      'ko', 'karo', 'lagao', 'milao', 'se', 'ki', 'kar', 'baat',
      // Urdu script
      'کو', 'کرو', 'لگاؤ', 'کال', 'فون',
    ];
    var result = name;
    for (final filler in fillers) {
      // Only strip whole words at start/end to avoid mangling names
      result = result.replaceAll(RegExp(r'^\s*' + RegExp.escape(filler) + r'\s+', caseSensitive: false), '');
      result = result.replaceAll(RegExp(r'\s+' + RegExp.escape(filler) + r'\s*$', caseSensitive: false), '');
    }
    return result.trim();
  }

  // ======================================================================= //
  //  Other intent extractors                                                 //
  // ======================================================================= //

  // ======================================================================= //
  //  Message intent detection                                                //
  // ======================================================================= //

  /// Returns true if [clean] contains any message-related trigger.
  ///
  /// Patterns:
  ///   English   : "send message to X", "text X", "message X", "whatsapp X"
  ///   Roman Urdu: "X ko message karo", "X ko msg karo", "X ko text bhejo",
  ///               "X ko message bhejo", "X ko text karo"
  ///   Urdu      : "X کو پیغام بھیجو", "X کو میسج کرو"  (safety net)
  static bool _isMessageIntent(String clean) {
    // English
    if (clean.startsWith('send message to ') ||
        clean.startsWith('send a message to ') ||
        clean.startsWith('message to ') ||
        clean.startsWith('send sms to ') ||
        clean.startsWith('send text to ') ||
        clean.startsWith('text to ') ||
        clean.startsWith('whatsapp ')) {
      return true;
    }

    // English bare "text X" / "message X" (first word)
    if (clean.startsWith('text ') || clean.startsWith('message ')) return true;

    // Roman Urdu patterns
    if (clean.contains(' ko message karo') ||
        clean.contains(' ko message bhejo') ||
        clean.contains(' ko msg karo') ||
        clean.contains(' ko msg bhejo') ||
        clean.contains(' ko text karo') ||
        clean.contains(' ko text bhejo') ||
        clean.contains(' ko sms karo') ||
        clean.contains(' ko sms bhejo') ||
        clean.contains('message karo') ||
        clean.contains('message bhejo') ||
        clean.contains('msg bhejo') ||
        clean.contains('msg karo')) {
      return true;
    }

    // Urdu script safety net
    if (clean.contains('پیغام') || clean.contains('میسج')) {
      return true;
    }

    return false;
  }

  static ParsedIntent _extractMessageIntent(String clean, String rawQuery) {
    String name = '';
    String? msgText;

    // ---------- English patterns ----------
    for (final prefix in [
      'send message to ',
      'send a message to ',
      'message to ',
      'send sms to ',
      'send text to ',
      'text to ',
    ]) {
      if (clean.startsWith(prefix)) {
        final remainder = clean.replaceFirst(prefix, '');
        final separators = [' saying ', ' that ', ' ko bolo ', ': '];
        bool found = false;
        for (final sep in separators) {
          if (remainder.contains(sep)) {
            final parts = remainder.split(sep);
            name = parts[0].trim();
            msgText = parts.sublist(1).join(sep).trim();
            found = true;
            break;
          }
        }
        if (!found) name = remainder.trim();
        break;
      }
    }

    // "text X <msg>" or "message X <msg>"
    if (name.isEmpty) {
      for (final prefix in ['text ', 'message ', 'whatsapp ']) {
        if (clean.startsWith(prefix)) {
          final remainder = clean.replaceFirst(prefix, '');
          final words = remainder.split(' ');
          if (words.isNotEmpty) {
            name = words[0];
            if (words.length > 1) msgText = words.sublist(1).join(' ').trim();
          }
          break;
        }
      }
    }

    // ---------- Roman Urdu patterns ----------
    if (name.isEmpty) {
      final patterns = [
        ' ko message karo', ' ko message bhejo',
        ' ko msg karo', ' ko msg bhejo',
        ' ko text karo', ' ko text bhejo',
        ' ko sms karo', ' ko sms bhejo',
      ];
      for (final pat in patterns) {
        if (clean.contains(pat)) {
          final parts = clean.split(pat);
          name = parts[0].trim();
          if (parts.length > 1) {
            msgText = parts[1]
                .replaceAll(RegExp(r'^\s*(ke|that|text|bol|bolo|yeh)\s*'), '')
                .trim();
          }
          break;
        }
      }
    }

    // ---------- Urdu script safety net ----------
    if (name.isEmpty && clean.contains('پیغام')) {
      // "X کو پیغام بھیجو" → name before کو
      final parts = clean.split('کو');
      if (parts.isNotEmpty) name = parts[0].trim();
    }

    // Strip any call-like fillers that snuck into the name
    name = _stripMessageFillers(name);

    return ParsedIntent(
      intent: AssistantIntent.message,
      contactName: _toTitleCase(name.trim()),
      messageText: msgText != null && msgText.isNotEmpty
          ? _toTitleCase(msgText)
          : null,
      rawQuery: rawQuery,
    );
  }

  static String _stripMessageFillers(String name) {
    final fillers = [
      'message', 'text', 'send', 'sms', 'msg',
      'ko', 'karo', 'bhejo', 'to', 'please', 'can you',
      'پیغام', 'میسج', 'کو', 'کرو', 'بھیجو',
    ];
    var result = name;
    for (final f in fillers) {
      result = result.replaceAll(RegExp(r'^\s*' + RegExp.escape(f) + r'\s+', caseSensitive: false), '');
      result = result.replaceAll(RegExp(r'\s+' + RegExp.escape(f) + r'\s*$', caseSensitive: false), '');
    }
    return result.trim();
  }

  static ParsedIntent _extractReminderIntent(String clean, String rawQuery) {
    String? title;
    final timeStr = _extractTime(clean);
    final dateStr = (clean.contains('tomorrow') || clean.contains('kal')) ? 'tomorrow' : 'today';

    if (clean.contains('to take ')) {
      title = 'take ' + clean.split('to take ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
    } else if (clean.contains('to ')) {
      title = clean.split('to ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
    } else if (clean.contains('about my ')) {
      title = clean.split('about my ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
    } else if (clean.contains('about ')) {
      title = clean.split('about ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
    } else if (clean.contains('remind karo ')) {
      title = clean.split('remind karo ')[1].split(' at ')[0].split(' kal ')[0].trim();
    }

    return ParsedIntent(
      intent: AssistantIntent.reminder,
      title: title != null ? _toTitleCase(title) : null,
      time: timeStr,
      date: dateStr,
      rawQuery: rawQuery,
    );
  }

  static ParsedIntent _extractAddEventIntent(String clean, String rawQuery) {
    final timeStr = _extractTime(clean);
    final dateStr = (clean.contains('tomorrow') || clean.contains('kal')) ? 'tomorrow' : 'today';
    String title = 'Meeting';

    if (clean.contains('add ')) {
      title = clean.split('add ')[1].split(' tomorrow')[0].split(' at ')[0].trim();
    } else if (clean.contains('set ')) {
      title = clean.split('set ')[1].split(' tomorrow')[0].split(' at ')[0].trim();
    }

    return ParsedIntent(
      intent: AssistantIntent.addEvent,
      title: _toTitleCase(title),
      time: timeStr,
      date: dateStr,
      rawQuery: rawQuery,
    );
  }

  static ParsedIntent _extractDeleteEventIntent(String clean, String rawQuery) {
    String day = 'today';
    const days = {
      'friday': 'Friday', 'monday': 'Monday', 'tuesday': 'Tuesday',
      'wednesday': 'Wednesday', 'thursday': 'Thursday',
      'saturday': 'Saturday', 'sunday': 'Sunday',
    };
    for (final entry in days.entries) {
      if (clean.contains(entry.key)) {
        day = entry.value;
        break;
      }
    }
    return ParsedIntent(intent: AssistantIntent.deleteEvent, date: day, rawQuery: rawQuery);
  }

  static ParsedIntent? _extractNavigationIntent(String clean, String rawQuery) {
    String screen = '';
    if (clean.contains('message') || clean.contains('chat')) {
      screen = 'messages';
    } else if (clean.contains('reminder')) {
      screen = 'reminders';
    } else if (clean.contains('alarm')) {
      screen = 'alarms';
    } else if (clean.contains('calendar') || clean.contains('schedule')) {
      screen = 'calendar';
    } else if (clean.contains('setting')) {
      screen = 'settings';
    } else if (clean.contains('contact')) {
      screen = 'contacts';
    }

    if (screen.isEmpty) return null;

    return ParsedIntent(
      intent: AssistantIntent.navigate,
      targetScreen: screen,
      rawQuery: rawQuery,
    );
  }

  // ======================================================================= //
  //  Utilities                                                               //
  // ======================================================================= //

  static bool _matchesAny(String query, List<String> triggers) {
    for (final trigger in triggers) {
      if (query.contains(trigger)) return true;
    }
    return false;
  }

  /// Capitalizes each word (title case).
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String? _extractTime(String query) {
    final timeRegex = RegExp(r'(\d{1,2})(:\d{2})?\s*(am|pm|baje)?');
    final match = timeRegex.firstMatch(query);
    if (match == null) return null;

    final hour = match.group(1)!;
    final min = match.group(2) ?? ':00';
    String period = match.group(3)?.toLowerCase() ?? '';

    if (period.isEmpty) {
      if (query.contains('morning') || query.contains('subah')) {
        period = 'am';
      } else if (query.contains('evening') || query.contains('shaam') ||
          query.contains('night') || query.contains('raat')) {
        period = 'pm';
      } else {
        final h = int.parse(hour);
        period = (h >= 7 && h <= 11) ? 'am' : 'pm';
      }
    }

    if (period == 'baje') {
      final h = int.parse(hour);
      period = h < 8 ? 'am' : 'pm';
    }

    return '$hour$min ${period.toUpperCase()}';
  }
}

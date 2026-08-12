/// Multilingual NLP for English, Urdu, and Roman Urdu voice commands.
///
/// STT usually returns English/Roman Urdu phonetics even when the user speaks
/// Urdu. Urdu-script patterns are kept as a safety net for typed input.
library;

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
  help,
  cancel,
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
  static ParsedIntent parse(String query) {
    if (query.trim().isEmpty) {
      return ParsedIntent(intent: AssistantIntent.unknown, rawQuery: query);
    }

    final clean = query.toLowerCase().trim();

    if (_isCancel(clean)) {
      return ParsedIntent(intent: AssistantIntent.cancel, rawQuery: query);
    }

    if (_isGreeting(clean)) {
      return ParsedIntent(intent: AssistantIntent.greeting, rawQuery: query);
    }

    if (_isHelp(clean)) {
      return ParsedIntent(intent: AssistantIntent.help, rawQuery: query);
    }

    if (_isTime(clean)) {
      return ParsedIntent(intent: AssistantIntent.time, rawQuery: query);
    }

    if (_isCallIntent(clean)) {
      return _extractCallDetails(clean, query);
    }

    if (_matchesAny(clean, [
      'read my latest messages',
      'read messages',
      'read my messages',
      'message parho',
      'msg parh',
      'messages sunao',
      'inbox parho',
    ])) {
      return ParsedIntent(intent: AssistantIntent.readMessages, rawQuery: query);
    }

    if (_matchesAny(clean, [
      'reply to this message',
      'reply this message',
      'reply karo',
      'jawab do',
    ])) {
      return ParsedIntent(intent: AssistantIntent.replyMessage, rawQuery: query);
    }

    if (_isMessageIntent(clean)) {
      return _extractMessageIntent(clean, query);
    }

    if (_isAlarmIntent(clean)) {
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

    if (_matchesAny(clean, [
      'remind',
      'yad dehani',
      'yaad dehani',
      'remind karo',
      'yaad dilao',
      'yaad dila',
    ])) {
      return _extractReminderIntent(clean, query);
    }

    if (_matchesAny(clean, ['schedule', 'agenda', 'today events', 'aaj kya hai'])) {
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

    if (clean.startsWith('open ') ||
        clean.startsWith('show ') ||
        clean.startsWith('go to ')) {
      final nav = _extractNavigationIntent(clean, query);
      if (nav != null) return nav;
    }

    return ParsedIntent(intent: AssistantIntent.unknown, rawQuery: query);
  }

  static bool _isCancel(String clean) {
    return _matchesAny(clean, [
      'cancel',
      'stop',
      'never mind',
      'nevermind',
      'forget it',
      'band karo',
      'rehne do',
      'mat karo',
      'cancel karo',
    ]);
  }

  static bool _isGreeting(String clean) {
    return _matchesAny(clean, [
      'hello',
      'hi ',
      'hi,',
      'hey',
      'hey assistant',
      'assalamu alaikum',
      'assalam',
      'salam',
      'a salaam',
      'helo',
      'good morning',
      'good evening',
      'good afternoon',
    ]) ||
        clean == 'hi';
  }

  static bool _isHelp(String clean) {
    return _matchesAny(clean, [
      'what can you do',
      'help',
      'help me',
      'kya kar sakte',
      'kya kar saktay',
      'options',
      'commands',
      'madad',
    ]);
  }

  static bool _isTime(String clean) {
    return _matchesAny(clean, [
      'what time is it',
      'time check',
      'time kya hai',
      'waqt kya',
      'time kya hua',
      'abhi kya time',
      'current time',
      'tell me the time',
      'kitna time',
    ]);
  }

  static bool _isCallIntent(String clean) {
    const prefixes = [
      'call ',
      'dial ',
      'phone ',
      'call to ',
      'dial to ',
      'dial call to ',
      'dial a call to ',
      'make a call to ',
      'make call to ',
      'place a call to ',
      'please call ',
      'can you call ',
      'i want to call ',
      'i wanna call ',
      'phone call to ',
      'ring ',
    ];
    for (final p in prefixes) {
      if (clean.startsWith(p)) return true;
    }

    if (clean.contains(' ko call karo') ||
        clean.contains(' ko call lagao') ||
        clean.contains(' ko phone karo') ||
        clean.contains(' ko phone lagao') ||
        clean.contains(' ko milao') ||
        clean.contains(' se baat karao') ||
        clean.contains(' se baat karo') ||
        clean.contains(' ko call kar') ||
        clean.contains(' ki call karo') ||
        clean.contains(' call karo') ||
        clean.contains(' phone karo') ||
        clean.contains('call lagao') ||
        clean.contains('phone lagao') ||
        clean.contains('call karo') ||
        clean.contains('phone kar do')) {
      return true;
    }

    if (clean.contains('کال') ||
        clean.contains('فون') ||
        clean.contains('ملاؤ') ||
        clean.contains('ملانا')) {
      return true;
    }

    if (RegExp(r'\b(call|dial|phone)\b').hasMatch(clean) &&
        !clean.contains('recall') &&
        !clean.contains('callback')) {
      return true;
    }

    return false;
  }

  static ParsedIntent _extractCallDetails(String clean, String rawQuery) {
    String name = '';
    String? simSlot;

    const prefixes = [
      'dial a call to ',
      'dial call to ',
      'make a call to ',
      'make call to ',
      'place a call to ',
      'phone call to ',
      'i want to call ',
      'i wanna call ',
      'can you call ',
      'please call ',
      'call to ',
      'dial to ',
      'call ',
      'dial ',
      'phone ',
      'ring ',
    ];

    for (final prefix in prefixes) {
      if (clean.startsWith(prefix)) {
        name = clean.substring(prefix.length);
        break;
      }
    }

    if (name.isEmpty) {
      final roman = <String, String Function(String)>{
        ' ko call karo': (s) => s.split(' ko call karo').first,
        ' ko call lagao': (s) => s.split(' ko call lagao').first,
        ' ko call kar': (s) => s.split(' ko call kar').first,
        ' ko phone karo': (s) => s.split(' ko phone karo').first,
        ' ko phone lagao': (s) => s.split(' ko phone lagao').first,
        ' ko milao': (s) => s.split(' ko milao').first,
        ' se baat karao': (s) => s.split(' se baat karao').first,
        ' se baat karo': (s) => s.split(' se baat karo').first,
        ' ki call karo': (s) => s.split(' ki call karo').first,
        ' call karo': (s) => s.split(' call karo').first,
        ' phone karo': (s) => s.split(' phone karo').first,
      };
      for (final entry in roman.entries) {
        if (clean.contains(entry.key)) {
          name = entry.value(clean).trim();
          break;
        }
      }
    }

    if (name.isEmpty && clean.contains('call lagao')) {
      name = clean.replaceAll('call lagao', '');
    } else if (name.isEmpty && clean.contains('phone lagao')) {
      name = clean.replaceAll('phone lagao', '');
    } else if (name.isEmpty && clean.contains(' call ')) {
      final parts = clean.split(' call ');
      name = parts.last.trim().isNotEmpty ? parts.last : parts.first;
    } else if (name.isEmpty && clean.contains(' dial ')) {
      name = clean.split(' dial ').last.trim();
    }

    if (name.isEmpty && (clean.contains('کال') || clean.contains('فون'))) {
      name = clean
          .replaceAll('کال', '')
          .replaceAll('فون', '')
          .replaceAll('کو', '')
          .replaceAll('کرو', '')
          .replaceAll('لگاؤ', '')
          .trim();
    }

    name = _stripSimFromName(name, (sim) => simSlot = sim);
    name = _stripCallFillers(name);

    final cleanName = _toTitleCase(name.trim());
    // ignore: avoid_print
    print('NlpEngine: call intent — raw="$rawQuery" → name="$cleanName" sim="$simSlot"');

    return ParsedIntent(
      intent: AssistantIntent.call,
      contactName: cleanName.isEmpty ? null : cleanName,
      simSlot: simSlot?.toLowerCase(),
      rawQuery: rawQuery,
    );
  }

  static bool _isMessageIntent(String clean) {
    const prefixes = [
      'send message to ',
      'send a message to ',
      'send sms to ',
      'send a sms to ',
      'send text to ',
      'message to ',
      'text to ',
      'sms to ',
      'whatsapp ',
      'text ',
      'message ',
      'sms ',
    ];
    for (final p in prefixes) {
      if (clean.startsWith(p)) return true;
    }

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
        clean.contains('msg karo') ||
        clean.contains('text bhejo')) {
      return true;
    }

    if (clean.contains('پیغام') || clean.contains('میسج')) {
      return true;
    }

    return false;
  }

  static ParsedIntent _extractMessageIntent(String clean, String rawQuery) {
    String name = '';
    String? msgText;

    for (final prefix in [
      'send a message to ',
      'send message to ',
      'send a sms to ',
      'send sms to ',
      'send text to ',
      'message to ',
      'text to ',
      'sms to ',
    ]) {
      if (clean.startsWith(prefix)) {
        final remainder = clean.substring(prefix.length);
        final separators = [
          ' saying ',
          ' that ',
          ' ko bolo ',
          ' and say ',
          ' and tell ',
          ': ',
        ];
        var found = false;
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

    if (name.isEmpty) {
      for (final prefix in ['text ', 'message ', 'whatsapp ', 'sms ']) {
        if (clean.startsWith(prefix)) {
          final remainder = clean.substring(prefix.length);
          final words = remainder.split(' ');
          if (words.isNotEmpty) {
            name = words[0];
            if (words.length > 1) {
              msgText = words.sublist(1).join(' ').trim();
            }
          }
          break;
        }
      }
    }

    if (name.isEmpty) {
      final patterns = [
        ' ko message karo',
        ' ko message bhejo',
        ' ko msg karo',
        ' ko msg bhejo',
        ' ko text karo',
        ' ko text bhejo',
        ' ko sms karo',
        ' ko sms bhejo',
      ];
      for (final pat in patterns) {
        if (clean.contains(pat)) {
          final parts = clean.split(pat);
          name = parts[0].trim();
          if (parts.length > 1) {
            msgText = parts[1]
                .replaceAll(RegExp(r'^\s*(ke|that|text|bol|bolo|yeh|keh)\s*'), '')
                .trim();
          }
          break;
        }
      }
    }

    if (name.isEmpty && (clean.contains('پیغام') || clean.contains('میسج'))) {
      final parts = clean.split('کو');
      if (parts.isNotEmpty) name = parts[0].trim();
    }

    name = _stripMessageFillers(name);
    if (msgText != null && msgText.isEmpty) msgText = null;

    // Keep the user's original casing for the SMS body.
    if (msgText != null) {
      final idx = rawQuery.toLowerCase().lastIndexOf(msgText);
      if (idx >= 0) {
        msgText = rawQuery.substring(idx, idx + msgText.length).trim();
      }
    }

    return ParsedIntent(
      intent: AssistantIntent.message,
      contactName: name.trim().isEmpty ? null : _toTitleCase(name.trim()),
      messageText: msgText,
      rawQuery: rawQuery,
    );
  }

  static bool _isAlarmIntent(String clean) {
    return _matchesAny(clean, [
      'alarm',
      'wake me up',
      'wake me',
      'baje ka alarm',
      'set an alarm',
      'set alarm',
      'alarm set',
      'alarm lagao',
      'alarm laga',
      'alarm laga do',
      'الارم',
    ]);
  }

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

  static String _stripCallFillers(String name) {
    final fillers = [
      'call', 'dial', 'phone', 'to', 'please', 'can you', 'i want',
      'a', 'the', 'like', 'someone', 'contact',
      'ko', 'karo', 'lagao', 'milao', 'se', 'ki', 'kar', 'baat',
      'کو', 'کرو', 'لگاؤ', 'کال', 'فون',
    ];
    var result = name;
    for (final filler in fillers) {
      result = result.replaceAll(
        RegExp(r'^\s*' + RegExp.escape(filler) + r'\s*$', caseSensitive: false),
        '',
      );
      result = result.replaceAll(
        RegExp(r'^\s*' + RegExp.escape(filler) + r'\s+', caseSensitive: false),
        '',
      );
      result = result.replaceAll(
        RegExp(r'\s+' + RegExp.escape(filler) + r'\s*$', caseSensitive: false),
        '',
      );
    }
    return result.trim();
  }

  static String _stripMessageFillers(String name) {
    final fillers = [
      'message', 'text', 'send', 'sms', 'msg',
      'ko', 'karo', 'bhejo', 'to', 'please', 'can you',
      'پیغام', 'میسج', 'کو', 'کرو', 'بھیجو',
    ];
    var result = name;
    for (final f in fillers) {
      result = result.replaceAll(
        RegExp(r'^\s*' + RegExp.escape(f) + r'\s+', caseSensitive: false),
        '',
      );
      result = result.replaceAll(
        RegExp(r'\s+' + RegExp.escape(f) + r'\s*$', caseSensitive: false),
        '',
      );
    }
    return result.trim();
  }

  static ParsedIntent _extractReminderIntent(String clean, String rawQuery) {
    String? title;
    final timeStr = _extractTime(clean);
    final dateStr =
        (clean.contains('tomorrow') || clean.contains('kal')) ? 'tomorrow' : 'today';

    if (clean.contains('to take ')) {
      title = 'take ${clean.split('to take ')[1].split(' at ')[0].split(' tomorrow')[0].trim()}';
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
    final dateStr =
        (clean.contains('tomorrow') || clean.contains('kal')) ? 'tomorrow' : 'today';
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
      'friday': 'Friday',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
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

  static bool _matchesAny(String query, List<String> triggers) {
    for (final trigger in triggers) {
      if (query.contains(trigger)) return true;
    }
    return false;
  }

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
      } else if (query.contains('evening') ||
          query.contains('shaam') ||
          query.contains('night') ||
          query.contains('raat')) {
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

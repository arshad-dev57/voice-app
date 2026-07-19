
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
  unknown
}

class ParsedIntent {
  final AssistantIntent intent;
  final String? contactName;
  final String? messageText;
  final String? title;
  final String? time;
  final String? date;
  final String? targetScreen;
  final String rawQuery;

  ParsedIntent({
    required this.intent,
    this.contactName,
    this.messageText,
    this.title,
    this.time,
    this.date,
    this.targetScreen,
    required this.rawQuery,
  });

  @override
  String toString() {
    return 'ParsedIntent(intent: $intent, contact: $contactName, message: $messageText, title: $title, time: $time, date: $date, screen: $targetScreen)';
  }
}

class NlpEngine {
  static ParsedIntent parse(String query) {
    final cleanQuery = query.toLowerCase().trim();

    // 1. GREETING INTENT
    if (_matchesAny(cleanQuery, ['hello', 'hi ', 'hey assistant', 'assalamu alaikum', 'a salaam', 'helo'])) {
      return ParsedIntent(intent: AssistantIntent.greeting, rawQuery: query);
    }

    // 2. TIME INTENT
    if (_matchesAny(cleanQuery, ['what time is it', 'time check', 'time kya hai', 'waqt kya hua', 'time kya hua'])) {
      return ParsedIntent(intent: AssistantIntent.time, rawQuery: query);
    }

    // 3. CALL INTENT
    // e.g. "Call Ali", "Dial Ahmed", "Ali ko call karo", "Mom ko phone karo"
    if (cleanQuery.startsWith('call ') || 
        cleanQuery.startsWith('dial ') || 
        cleanQuery.endsWith(' ko call karo') || 
        cleanQuery.endsWith(' ko phone karo') ||
        cleanQuery.endsWith(' ko call lagao') ||
        cleanQuery.contains(' phone karo ')) {
      
      String name = '';
      if (cleanQuery.startsWith('call ')) {
        name = cleanQuery.replaceFirst('call ', '');
      } else if (cleanQuery.startsWith('dial ')) {
        name = cleanQuery.replaceFirst('dial ', '');
      } else if (cleanQuery.endsWith(' ko call karo')) {
        name = cleanQuery.replaceFirst(' ko call karo', '');
      } else if (cleanQuery.endsWith(' ko phone karo')) {
        name = cleanQuery.replaceFirst(' ko phone karo', '');
      } else if (cleanQuery.endsWith(' ko call lagao')) {
        name = cleanQuery.replaceFirst(' ko call lagao', '');
      }
      
      return ParsedIntent(
        intent: AssistantIntent.call,
        contactName: _capitalize(name.trim()),
        rawQuery: query,
      );
    }

    // 4. MESSAGING INTENTS
    // "Read my latest messages"
    if (_matchesAny(cleanQuery, ['read my latest messages', 'read messages', 'read my messages', 'message parho', 'msg parh'])) {
      return ParsedIntent(intent: AssistantIntent.readMessages, rawQuery: query);
    }

    // "Reply to this message"
    if (_matchesAny(cleanQuery, ['reply to this message', 'reply this message', 'reply karo', 'jawab do'])) {
      return ParsedIntent(intent: AssistantIntent.replyMessage, rawQuery: query);
    }

    // "Send message to Mom", "Text Ali I am coming", "Ali ko message karo text"
    // Regex for: Text [name] [content] or Send message to [name] or [name] ko message karo [content]
    if (cleanQuery.contains('send message to ') || 
        cleanQuery.contains('text ') || 
        cleanQuery.contains(' message karo ') || 
        cleanQuery.contains(' ko message karo')) {
      
      String name = '';
      String? msgText;

      if (cleanQuery.startsWith('send message to ')) {
        // e.g. "send message to mom" or "send message to mom that i am coming"
        final remainder = cleanQuery.replaceFirst('send message to ', '');
        final parts = remainder.split(' that ');
        name = parts[0].trim();
        if (parts.length > 1) msgText = parts[1].trim();
      } else if (cleanQuery.startsWith('text ')) {
        // e.g. "text ali i am coming"
        final remainder = cleanQuery.replaceFirst('text ', '');
        final words = remainder.split(' ');
        if (words.isNotEmpty) {
          name = words[0];
          if (words.length > 1) {
            msgText = words.sublist(1).join(' ').trim();
          }
        }
      } else if (cleanQuery.contains(' ko message karo')) {
        // e.g. "ali ko message karo i am coming" or "ali ko message karo ke main aa raha hoon"
        final parts = cleanQuery.split(' ko message karo');
        name = parts[0].trim();
        if (parts.length > 1) {
          msgText = parts[1].replaceAll(RegExp(r'^(\s*(ke|that|text)\s*)'), '').trim();
        }
      }

      return ParsedIntent(
        intent: AssistantIntent.message,
        contactName: _capitalize(name.trim()),
        messageText: msgText != null ? _capitalize(msgText) : null,
        rawQuery: query,
      );
    }

    // 5. ALARM INTENTS
    // "set alarm for 7 am tomorrow", "wake me up at 6 am", "alarm laga do 7 baje"
    if (cleanQuery.contains('alarm') || cleanQuery.contains('wake me up') || cleanQuery.contains('baje ka alarm')) {
      final timeStr = _extractTime(cleanQuery);
      final dateStr = cleanQuery.contains('tomorrow') || cleanQuery.contains('kal') ? 'tomorrow' : 'today';
      return ParsedIntent(
        intent: AssistantIntent.alarm,
        time: timeStr,
        date: dateStr,
        rawQuery: query,
      );
    }

    // 6. REMINDER INTENTS
    // "remind me to take medicine at 9 pm", "remind me about my meeting tomorrow"
    if (cleanQuery.contains('remind') || cleanQuery.contains('yad dehani') || cleanQuery.contains('remind karo')) {
      String? title;
      String? timeStr = _extractTime(cleanQuery);
      String? dateStr = cleanQuery.contains('tomorrow') || cleanQuery.contains('kal') ? 'tomorrow' : 'today';

      // Attempt to extract title
      if (cleanQuery.contains('to take ')) {
        title = 'take ' + cleanQuery.split('to take ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
      } else if (cleanQuery.contains('to ')) {
        title = cleanQuery.split('to ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
      } else if (cleanQuery.contains('about my ')) {
        title = cleanQuery.split('about my ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
      } else if (cleanQuery.contains('about ')) {
        title = cleanQuery.split('about ')[1].split(' at ')[0].split(' tomorrow')[0].trim();
      } else if (cleanQuery.contains('remind karo ')) {
        title = cleanQuery.split('remind karo ')[1].split(' at ')[0].split(' kal ')[0].trim();
      }

      return ParsedIntent(
        intent: AssistantIntent.reminder,
        title: title != null ? _capitalize(title) : null,
        time: timeStr,
        date: dateStr,
        rawQuery: query,
      );
    }

    // 7. CALENDAR EVENTS & SCHEDULE
    // "what is my schedule today?", "next meeting", "add meeting tomorrow at 5 PM", "delete friday event"
    if (cleanQuery.contains('schedule') || cleanQuery.contains('agenda') || cleanQuery.contains('today events')) {
      return ParsedIntent(
        intent: AssistantIntent.calendarSchedule,
        date: 'today',
        rawQuery: query,
      );
    }

    if (cleanQuery.contains('next meeting') || cleanQuery.contains('agla meeting') || cleanQuery.contains('agli meeting')) {
      return ParsedIntent(intent: AssistantIntent.nextMeeting, rawQuery: query);
    }

    if (cleanQuery.startsWith('add ') || cleanQuery.contains('set meeting') || cleanQuery.contains('meeting set kar do')) {
      String? timeStr = _extractTime(cleanQuery);
      String dateStr = cleanQuery.contains('tomorrow') || cleanQuery.contains('kal') ? 'tomorrow' : 'today';
      String title = 'Meeting';
      
      if (cleanQuery.contains('add ')) {
        title = cleanQuery.split('add ')[1].split(' tomorrow')[0].split(' at ')[0].trim();
      } else if (cleanQuery.contains('set ')) {
        title = cleanQuery.split('set ')[1].split(' tomorrow')[0].split(' at ')[0].trim();
      }

      return ParsedIntent(
        intent: AssistantIntent.addEvent,
        title: _capitalize(title),
        time: timeStr,
        date: dateStr,
        rawQuery: query,
      );
    }

    if (cleanQuery.contains('delete ') && (cleanQuery.contains('event') || cleanQuery.contains('meeting'))) {
      // e.g. "delete friday event"
      String day = 'today';
      if (cleanQuery.contains('friday')) day = 'Friday';
      if (cleanQuery.contains('monday')) day = 'Monday';
      if (cleanQuery.contains('tuesday')) day = 'Tuesday';
      if (cleanQuery.contains('wednesday')) day = 'Wednesday';
      if (cleanQuery.contains('thursday')) day = 'Thursday';
      if (cleanQuery.contains('saturday')) day = 'Saturday';
      if (cleanQuery.contains('sunday')) day = 'Sunday';

      return ParsedIntent(
        intent: AssistantIntent.deleteEvent,
        date: day,
        rawQuery: query,
      );
    }

    // 8. NAVIGATION INTENTS
    // "open messages", "show reminders", "go to settings"
    if (cleanQuery.startsWith('open ') || cleanQuery.startsWith('show ') || cleanQuery.startsWith('go to ')) {
      String screen = '';
      if (cleanQuery.contains('message') || cleanQuery.contains('chat')) {
        screen = 'messages';
      } else if (cleanQuery.contains('reminder')) {
        screen = 'reminders';
      } else if (cleanQuery.contains('alarm')) {
        screen = 'alarms';
      } else if (cleanQuery.contains('calendar') || cleanQuery.contains('schedule')) {
        screen = 'calendar';
      } else if (cleanQuery.contains('setting')) {
        screen = 'settings';
      } else if (cleanQuery.contains('contact')) {
        screen = 'contacts';
      }

      if (screen.isNotEmpty) {
        return ParsedIntent(
          intent: AssistantIntent.navigate,
          targetScreen: screen,
          rawQuery: query,
        );
      }
    }

    return ParsedIntent(
      intent: AssistantIntent.unknown,
      rawQuery: query,
    );
  }

  static bool _matchesAny(String query, List<String> triggers) {
    for (var trigger in triggers) {
      if (query.contains(trigger)) return true;
    }
    return false;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String? _extractTime(String query) {
    // Regex matches e.g. "7:00 am", "9 pm", "10:30", "5 baje"
    final timeRegex = RegExp(r'(\d{1,2})(:\d{2})?\s*(am|pm|baje)?');
    final match = timeRegex.firstMatch(query);
    if (match != null) {
      String hour = match.group(1)!;
      String min = match.group(2) ?? ':00';
      String period = match.group(3) ?? 'pm';

      if (period == 'baje') {
        // Urdu "baje", assume logic or just keep time string
        int h = int.parse(hour);
        if (h < 8) {
          // simple heuristic, e.g. 5 baje -> 5 PM
          period = 'pm';
        } else {
          period = 'am';
        }
      }

      return '$hour$min ${period.toUpperCase()}';
    }
    return null;
  }
}

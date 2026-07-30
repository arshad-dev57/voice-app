import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/nlp_engine.dart';
import '../../../../core/services/shake_detection_service.dart';
import '../../../../routing/app_router.dart';

enum OrbState { idle, listening, processing, responding, error }

class AssistantState {
  final OrbState orbState;
  final String transcript;
  final String responseText;
  final List<AssistantHistory> history;

  // Conversational session context
  final bool isConfirming;
  final ParsedIntent? pendingIntent;
  final String?
  missingField; // "contactName", "messageText", "title", "time", "date"
  final String? navigationTarget; // Screen name to navigate to

  AssistantState({
    this.orbState = OrbState.idle,
    this.transcript = '',
    this.responseText = 'Hello! Press the mic or shake your phone to speak.',
    this.history = const [],
    this.isConfirming = false,
    this.pendingIntent,
    this.missingField,
    this.navigationTarget,
  });

  AssistantState copyWith({
    OrbState? orbState,
    String? transcript,
    String? responseText,
    List<AssistantHistory>? history,
    bool? isConfirming,
    ParsedIntent? pendingIntent,
    String? missingField,
    String? navigationTarget,
  }) {
    return AssistantState(
      orbState: orbState ?? this.orbState,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      history: history ?? this.history,
      isConfirming: isConfirming ?? this.isConfirming,
      pendingIntent: pendingIntent ?? this.pendingIntent,
      missingField: missingField ?? this.missingField,
      navigationTarget:
          navigationTarget, // If null is passed, clear navigationTarget
    );
  }
}

class AssistantController extends StateNotifier<AssistantState> {
  final Ref _ref;

  AssistantController(this._ref) : super(AssistantState()) {
    loadHistory();
    _initializeShakeDetection();
  }

  Future<void> loadHistory() async {
    final repo = _ref.read(localRepositoryProvider);
    final hist = await repo.getHistory();
    state = state.copyWith(history: hist);
  }

  void _initializeShakeDetection() {
    ShakeDetectionService.initialize();
    ShakeDetectionService.setOnShakeDetectedCallback(() {
      _onShakeDetected();
    });
  }

  void _onShakeDetected() {
    // When shake is detected, greet the user and start listening
    if (state.orbState == OrbState.idle || state.orbState == OrbState.error) {
      _greetAndListen();
    }
  }

  Future<void> _greetAndListen() async {
    // Random greeting messages for variety
    final greetings = [
      'Yes? How can I help you?',
      'I\'m listening. What do you need?',
      'Yes, tell me what you want to do.',
      'I\'m here. How can I assist you?',
      'What can I do for you?',
      'Yes, go ahead.',
      'Listening. What would you like me to do?',
    ];
    
    // Select random greeting
    final randomGreeting = greetings[DateTime.now().millisecond % greetings.length];
    
    // Update state to show assistant is active
    state = state.copyWith(
      orbState: OrbState.responding,
      responseText: randomGreeting,
    );
    
    // Speak greeting
    await _speakResponse(randomGreeting);
    
    // Small delay then start listening
    await Future.delayed(const Duration(milliseconds: 500));
    await toggleListening();
  }

  void clearNavigation() {
    state = state.copyWith(navigationTarget: null);
  }

  Future<void> toggleListening() async {
    final speech = _ref.read(speechServiceProvider);
    if (speech.isListening) {
      await speech.stopListening();
      state = state.copyWith(orbState: OrbState.idle);
    } else {
      state = state.copyWith(
        orbState: OrbState.listening,
        transcript: 'Listening...',
      );

      await speech.startListening(
        onResult: (text) {
          state = state.copyWith(transcript: text);
        },
        onSoundLevelChanged: () {},
        onError: () {
          state = state.copyWith(
            orbState: OrbState.error,
            responseText: 'Microphone error or permission denied.',
          );
          _speakResponse('Microphone error or permission denied.');
        },
        onComplete: () {
          processSpokenText(state.transcript);
        },
      );
    }
  }

  Future<void> processSpokenText(String text) async {
    if (text.isEmpty || text == 'Listening...') {
      state = state.copyWith(
        orbState: OrbState.idle,
        responseText: 'I didn\'t hear anything.',
      );
      await _speakResponse('I didn\'t hear anything.');
      return;
    }

    state = state.copyWith(orbState: OrbState.processing);
    await Future.delayed(
      const Duration(milliseconds: 600),
    ); // Simulate brain processing

    final cleanText = text.toLowerCase().trim();

    // Clear any pending intent from previous interactions if this is a new command
    // Check if this is a new command (starts with call, dial, etc.) rather than a response
    // This allows seamless switching between alarm, call, and other flows
    if (!state.isConfirming && state.missingField != null) {
      final isNewCommand = cleanText.startsWith('call ') || 
                          cleanText.startsWith('dial ') ||
                          cleanText.startsWith('send ') ||
                          cleanText.startsWith('text ') ||
                          cleanText.startsWith('set ') ||
                          cleanText.startsWith('what ') ||
                          cleanText.startsWith('read ') ||
                          cleanText.startsWith('open ') ||
                          cleanText.contains('call ') ||
                          cleanText.contains('alarm ') ||
                          cleanText.contains('dial ') ||
                          cleanText.contains('wake me up') ||
                          cleanText.contains('remind ');
      
      if (isNewCommand) {
        state = state.copyWith(pendingIntent: null, missingField: null);
      }
    }

    // A. Handle Confirmation Flows
    if (state.isConfirming && state.pendingIntent != null) {
      final isYes = _matchesYes(cleanText);
      final isNo = _matchesNo(cleanText);

      if (isYes) {
        await _executeIntent(state.pendingIntent!);
      } else if (isNo) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: 'Okay, cancelled.',
          isConfirming: false,
          pendingIntent: null,
          missingField: null,
        );
        await _speakResponse('Okay, cancelled.');
      } else {
        final prompt = 'Please say Yes or No. Do you want to proceed?';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: prompt,
        );
        await _speakResponse(prompt);
      }
      return;
    }

    // B. Handle Missing Fields Dialog Flows
    if (state.missingField != null && state.pendingIntent != null) {
      final field = state.missingField!;
      ParsedIntent updatedIntent;

      if (field == 'contactName') {
        updatedIntent = ParsedIntent(
          intent: state.pendingIntent!.intent,
          contactName: text,
          messageText: state.pendingIntent!.messageText,
          title: state.pendingIntent!.title,
          time: state.pendingIntent!.time,
          date: state.pendingIntent!.date,
          targetScreen: state.pendingIntent!.targetScreen,
          simSlot: state.pendingIntent!.simSlot,
          rawQuery: state.pendingIntent!.rawQuery,
        );
      } else if (field == 'messageText') {
        updatedIntent = ParsedIntent(
          intent: state.pendingIntent!.intent,
          contactName: state.pendingIntent!.contactName,
          messageText: text,
          title: state.pendingIntent!.title,
          time: state.pendingIntent!.time,
          date: state.pendingIntent!.date,
          targetScreen: state.pendingIntent!.targetScreen,
          simSlot: state.pendingIntent!.simSlot,
          rawQuery: state.pendingIntent!.rawQuery,
        );
      } else if (field == 'title') {
        updatedIntent = ParsedIntent(
          intent: state.pendingIntent!.intent,
          contactName: state.pendingIntent!.contactName,
          messageText: state.pendingIntent!.messageText,
          title: text,
          time: state.pendingIntent!.time,
          date: state.pendingIntent!.date,
          targetScreen: state.pendingIntent!.targetScreen,
          simSlot: state.pendingIntent!.simSlot,
          rawQuery: state.pendingIntent!.rawQuery,
        );
      } else if (field == 'time') {
        updatedIntent = ParsedIntent(
          intent: state.pendingIntent!.intent,
          contactName: state.pendingIntent!.contactName,
          messageText: state.pendingIntent!.messageText,
          title: state.pendingIntent!.title,
          time: text,
          date: state.pendingIntent!.date,
          targetScreen: state.pendingIntent!.targetScreen,
          simSlot: state.pendingIntent!.simSlot,
          rawQuery: state.pendingIntent!.rawQuery,
        );
      } else if (field == 'simSlot') {
        // User specified the SIM to use
        updatedIntent = ParsedIntent(
          intent: state.pendingIntent!.intent,
          contactName: state.pendingIntent!.contactName,
          messageText: state.pendingIntent!.messageText,
          title: state.pendingIntent!.title,
          time: state.pendingIntent!.time,
          date: state.pendingIntent!.date,
          targetScreen: state.pendingIntent!.targetScreen,
          simSlot: text.toLowerCase(),
          rawQuery: state.pendingIntent!.rawQuery,
        );
      } else {
        updatedIntent = state.pendingIntent!;
      }

      // Check if another field is missing
      await _checkAndProgressIntent(updatedIntent);
      return;
    }

    // C. Fresh intent detection
    final parsed = NlpEngine.parse(text);
    await _checkAndProgressIntent(parsed);
  }

  Future<void> _checkAndProgressIntent(ParsedIntent intent) async {
    final repo = _ref.read(localRepositoryProvider);

    switch (intent.intent) {
      case AssistantIntent.greeting:
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: 'Hello! How can I help you today?',
        );
        await _speakResponse('Hello! How can I help you today?');
        _logHistory(
          intent.rawQuery,
          'Hello! How can I help you today?',
          'greeting',
        );
        break;

      case AssistantIntent.time:
        final timeStr = DateFormat('hh:mm a').format(DateTime.now());
        final reply = 'The current time is $timeStr.';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
        );
        await _speakResponse(reply);
        _logHistory(intent.rawQuery, reply, 'time');
        break;

      case AssistantIntent.call:
        if (intent.contactName == null || intent.contactName!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'Who do you want to call?',
            missingField: 'contactName',
            pendingIntent: intent,
          );
          await _speakResponse('Who do you want to call?');
        } else {
          // Search contacts in database
          var contactName = intent.contactName!;
          
          // Aggressive cleaning: remove common command words and prefixes
          contactName = contactName
              .replaceAll(RegExp(r'(?i)^call\s+'), '')
              .replaceAll(RegExp(r'(?i)^dial\s+'), '')
              .replaceAll(RegExp(r'(?i)^to\s+'), '')
              .replaceAll(RegExp(r'(?i)^phone\s+'), '')
              .trim();
          
          debugPrint('AssistantController: cleaned contact name from "${intent.contactName}" to "$contactName"');
          debugPrint('AssistantController: searching for contact "$contactName"');
          var matched = await repo.searchContacts(contactName);
          debugPrint('AssistantController: found ${matched.length} contacts in initial search');
          
          // If not found locally, try importing the phone's real contacts once
          // (e.g. "call Uzair" where Uzair is a device contact), then re-search.
          if (matched.isEmpty) {
            debugPrint('AssistantController: no contacts found, importing device contacts');
            final imported = await _ref.read(contactsServiceProvider).importDeviceContacts(repo);
            debugPrint('AssistantController: imported $imported contacts from device');
            matched = await repo.searchContacts(contactName);
            debugPrint('AssistantController: found ${matched.length} contacts after import');
          }
          
          // Fallback: try partial matching with individual words
          if (matched.isEmpty && contactName.contains(' ')) {
            final words = contactName.split(' ');
            debugPrint('AssistantController: trying partial match with words: $words');
            for (final word in words) {
              if (word.length > 2) { // Skip very short words
                final partialMatch = await repo.searchContacts(word);
                if (partialMatch.isNotEmpty) {
                  matched = partialMatch;
                  debugPrint('AssistantController: found ${matched.length} contacts with partial match "$word"');
                  break;
                }
              }
            }
          }
          
          if (matched.isEmpty) {
            final reply =
                'I couldn\'t find anyone named ${intent.contactName} in your contacts.';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: reply,
            );
            await _speakResponse(reply);
          } else if (matched.length > 1) {
            // Multiple contacts found
            final reply =
                'I found ${matched.length} contacts matching ${intent.contactName}. Which one do you want to call?';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: reply,
              missingField: 'contactName', // will search again with input
              pendingIntent: intent,
            );
            await _speakResponse(reply);
          } else {
            // Exactly one contact found
            final contact = matched.first;
            
            // Directly call the contact without confirmation
            // SIM selection will be handled by accessibility service if needed
            final prompt = 'Calling ${contact.name}.';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: prompt,
              isConfirming: false,
              missingField: null,
              pendingIntent: ParsedIntent(
                intent: AssistantIntent.call,
                contactName: contact.name,
                messageText: contact.phoneNumber,
                simSlot: intent.simSlot,
                rawQuery: intent.rawQuery,
              ),
            );
            await _speakResponse(prompt);
          }
        }
        break;

      case AssistantIntent.message:
        if (intent.contactName == null || intent.contactName!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'Who do you want to message?',
            missingField: 'contactName',
            pendingIntent: intent,
          );
          await _speakResponse('Who do you want to message?');
        } else if (intent.messageText == null || intent.messageText!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'What is the message content?',
            missingField: 'messageText',
            pendingIntent: intent,
          );
          await _speakResponse('What is the message content?');
        } else {
          // Verify contact
          final matched = await repo.searchContacts(intent.contactName!);
          if (matched.isEmpty) {
            final reply =
                'I couldn\'t find a contact named ${intent.contactName}.';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: reply,
            );
            await _speakResponse(reply);
          } else {
            final contact = matched.first;
            final prompt =
                'Do you want to send: "${intent.messageText}" to ${contact.name}?';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: prompt,
              isConfirming: true,
              missingField: null,
              pendingIntent: ParsedIntent(
                intent: AssistantIntent.message,
                contactName: contact.name,
                messageText: intent.messageText,
                targetScreen: contact.phoneNumber, // reuse to store phone
                rawQuery: intent.rawQuery,
              ),
            );
            await _speakResponse(prompt);
          }
        }
        break;

      case AssistantIntent.alarm:
        if (intent.time == null || intent.time!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'What time should I set the alarm for?',
            missingField: 'time',
            pendingIntent: intent,
          );
          await _speakResponse('What time should I set the alarm for?');
        } else {
          // Use the new AlarmService to set both local and system alarms
          final hm = _parseTimeToHourMinute(intent.time!);
          if (hm != null) {
            final success = await _ref.read(alarmServiceProvider).setAlarm(
              hour: hm[0],
              minute: hm[1],
              label: 'Voice Alarm',
              repeatDays: 'Everyday',
              repository: repo,
            );

            final reply = success
                ? 'Your alarm has been set for ${intent.time} in both the app and your system clock.'
                : 'Your alarm has been set for ${intent.time} in the app. Please check your system clock app.';
            
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: reply,
              isConfirming: false,
              pendingIntent: null,
              missingField: null,
            );
            await _speakResponse(reply);
            _logHistory(intent.rawQuery, reply, 'alarm');
          } else {
            final reply = 'I couldn\'t understand the time. Please say it again, like "8 PM" or "7:30 AM".';
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: reply,
              missingField: 'time',
              pendingIntent: intent,
            );
            await _speakResponse(reply);
          }
        }
        break;

      case AssistantIntent.reminder:
        if (intent.title == null || intent.title!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'What should I remind you about?',
            missingField: 'title',
            pendingIntent: intent,
          );
          await _speakResponse('What should I remind you about?');
        } else if (intent.time == null || intent.time!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'When should I remind you?',
            missingField: 'time',
            pendingIntent: intent,
          );
          await _speakResponse('When should I remind you?');
        } else {
          // Everything ready
          final prompt =
              'Do you want me to set a reminder for "${intent.title}" at ${intent.time}?';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: prompt,
            isConfirming: true,
            missingField: null,
            pendingIntent: intent,
          );
          await _speakResponse(prompt);
        }
        break;

      case AssistantIntent.calendarSchedule:
        final events = await repo.getEvents();
        if (events.isEmpty) {
          final reply = 'You have no events scheduled for today.';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        } else {
          final buffer = StringBuffer('Today\'s schedule:\n');
          for (var ev in events) {
            final timeStr = DateFormat('hh:mm a').format(ev.dateTime);
            buffer.write('- ${ev.title} at $timeStr\n');
          }
          final reply = buffer.toString().trim();
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        }
        _logHistory(intent.rawQuery, 'Showed schedule', 'calendar');
        break;

      case AssistantIntent.addEvent:
        if (intent.title == null || intent.title!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'What is the meeting title?',
            missingField: 'title',
            pendingIntent: intent,
          );
          await _speakResponse('What is the meeting title?');
        } else if (intent.time == null || intent.time!.isEmpty) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: 'What time is the meeting?',
            missingField: 'time',
            pendingIntent: intent,
          );
          await _speakResponse('What time is the meeting?');
        } else {
          final prompt =
              'Add meeting "${intent.title}" for tomorrow at ${intent.time}?';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: prompt,
            isConfirming: true,
            missingField: null,
            pendingIntent: intent,
          );
          await _speakResponse(prompt);
        }
        break;

      case AssistantIntent.deleteEvent:
        final prompt = 'Do you want to delete your events?';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: prompt,
          isConfirming: true,
          pendingIntent: intent,
        );
        await _speakResponse(prompt);
        break;

      case AssistantIntent.navigate:
        final screen = intent.targetScreen;
        String response = 'Opening $screen.';
        String route = '';

        if (screen == 'messages') {
          route = AppRouter.messaging;
        } else if (screen == 'reminders') {
          route = AppRouter.reminders;
        } else if (screen == 'alarms') {
          route = AppRouter.alarms;
        } else if (screen == 'calendar') {
          route = AppRouter.calendar;
        } else if (screen == 'settings') {
          route = AppRouter.settings;
        } else if (screen == 'contacts') {
          route = AppRouter.contacts;
        }

        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: response,
          navigationTarget: route.isNotEmpty ? route : null,
        );
        await _speakResponse(response);
        _logHistory(intent.rawQuery, response, 'navigate');
        break;

      case AssistantIntent.nextMeeting:
        final events = await repo.getEvents();
        final upcoming = events
            .where((e) => e.dateTime.isAfter(DateTime.now()))
            .toList();
        if (upcoming.isEmpty) {
          const reply = 'You do not have any upcoming meetings.';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        } else {
          final ev = upcoming.first;
          final timeStr = DateFormat('hh:mm a').format(ev.dateTime);
          final reply =
              'Your next meeting is "${ev.title}" scheduled at $timeStr.';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        }
        break;

      case AssistantIntent.readMessages:
        final convs = await repo.getConversations();
        if (convs.isEmpty) {
          const reply = 'You have no messages.';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        } else {
          final reply =
              'You have ${convs.length} recent chats. The last message is from ${convs.first.contactName}: "${convs.first.lastMessage}".';
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: reply,
          );
          await _speakResponse(reply);
        }
        break;

      case AssistantIntent.replyMessage:
        // Mock active conversation reply
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: 'Who do you want to send a reply to?',
          missingField: 'contactName',
          pendingIntent: ParsedIntent(
            intent: AssistantIntent.message,
            rawQuery: intent.rawQuery,
          ),
        );
        await _speakResponse('Who do you want to send a reply to?');
        break;

      case AssistantIntent.unknown:
        const reply =
            'I\'m sorry, I didn\'t catch that. Could you please try again?';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
        );
        await _speakResponse(reply);
        break;
    }
  }

  Future<void> _executeIntent(ParsedIntent intent) async {
    final repo = _ref.read(localRepositoryProvider);

    switch (intent.intent) {
      case AssistantIntent.call:
        // Intent uses messageText as placeholder for phoneNumber
        final name = intent.contactName ?? 'Someone';
        final phone = intent.messageText ?? '';
        final simName = intent.simSlot;
        final response = simName != null ? 'Calling $name from $simName.' : 'Calling $name.';

        // Debug logging
        print('AssistantController: Attempting to call $name with phone: "$phone" on SIM: "$simName"');

        // Set target SIM for accessibility service if specified
        if (simName != null) {
          await _ref.read(phoneServiceProvider).setTargetSim(simName);
        }

        // Get SIM slot index from SIM name
        int? simSlot;
        if (simName != null) {
          simSlot = _ref.read(phoneServiceProvider).getSimSlotFromName(simName);
          print('AssistantController: Mapped SIM name "$simName" to slot: $simSlot');
        }

        // Make a real phone call using the native dialer
        bool callLaunched = false;
        if (phone.isNotEmpty) {
          callLaunched = await _ref
              .read(phoneServiceProvider)
              .makePhoneCall(phoneNumber: phone, simSlot: simSlot);
          print('AssistantController: Call launched: $callLaunched');
        } else {
          print('AssistantController: Phone number is empty!');
        }

        final finalResponse = callLaunched
            ? response
            : 'I couldn\'t launch the phone dialer for $name. Please check permissions.';
        
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: finalResponse,
          isConfirming: false,
          pendingIntent: null,
        );

        await _speakResponse(finalResponse);
        _logHistory(intent.rawQuery, finalResponse, 'call');
        break;

      case AssistantIntent.message:
        // contactName = name, messageText = body, targetScreen = phone
        final name = intent.contactName ?? '';
        final body = intent.messageText ?? '';
        final phone = intent.targetScreen ?? '';

        final msg = Message(
          id: const Uuid().v4(),
          conversationId: 'conv_$name',
          senderPhone: 'user',
          receiverPhone: phone,
          content: body,
          isRead: true,
          createdAt: DateTime.now(),
        );

        await repo.insertMessage(msg);

        // Send a REAL SMS via the phone's telephony.
        bool sent = false;
        if (phone.isNotEmpty && phone != 'user') {
          sent = await _ref
              .read(phoneServiceProvider)
              .sendSms(phoneNumber: phone, message: body);
        }

        final response = sent
            ? 'Message sent to $name.'
            : 'I saved the message, but couldn\'t send the SMS to $name. Please check permissions.';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: response,
          isConfirming: false,
          pendingIntent: null,
        );
        await _speakResponse(response);
        _logHistory(intent.rawQuery, response, 'message');
        break;

      case AssistantIntent.reminder:
        // Add reminder
        final reminder = Reminder(
          id: const Uuid().v4(),
          title: intent.title!,
          dateTime: DateTime.now().add(
            const Duration(days: 1),
          ), // default tomorrow
          category: 'generic',
          repeatType: 'none',
          isCompleted: false,
          createdAt: DateTime.now(),
        );
        await repo.insertReminder(reminder);

        final response = 'Your reminder for "${intent.title}" has been set.';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: response,
          isConfirming: false,
          pendingIntent: null,
        );
        await _speakResponse(response);
        _logHistory(intent.rawQuery, response, 'reminder');
        break;

      case AssistantIntent.addEvent:
        // Compute the event start: tomorrow (or today) at the spoken time.
        final hm = _parseTimeToHourMinute(intent.time ?? '');
        final base = (intent.date == 'today')
            ? DateTime.now()
            : DateTime.now().add(const Duration(days: 1));
        final start = (hm != null)
            ? DateTime(base.year, base.month, base.day, hm[0], hm[1])
            : base;
        final end = start.add(const Duration(minutes: 60));

        final ev = CalendarEvent(
          id: const Uuid().v4(),
          title: intent.title!,
          dateTime: start,
          durationMinutes: 60,
          createdAt: DateTime.now(),
        );
        await repo.insertEvent(ev);

        // Add it to the phone's REAL calendar too.
        await _ref
            .read(phoneServiceProvider)
            .addCalendarEvent(title: intent.title!, start: start, end: end);

        final response = 'Meeting "${intent.title}" added to your calendar.';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: response,
          isConfirming: false,
          pendingIntent: null,
        );
        await _speakResponse(response);
        _logHistory(intent.rawQuery, response, 'calendar');
        break;

      case AssistantIntent.deleteEvent:
        // Mock deleting Friday event or similar
        final events = await repo.getEvents();
        if (events.isNotEmpty) {
          await repo.deleteEvent(events.first.id);
        }
        const response = 'Event deleted successfully.';
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: response,
          isConfirming: false,
          pendingIntent: null,
        );
        await _speakResponse(response);
        break;

      default:
        break;
    }
  }

  Future<void> _speakResponse(String text) async {
    final tts = _ref.read(ttsServiceProvider);
    await tts.speak(text);
    // After speaking finishes or during, let orb change to idle after timeout
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && state.orbState == OrbState.responding) {
        state = state.copyWith(orbState: OrbState.idle);
      }
    });
  }

  Future<void> _logHistory(String query, String response, String intent) async {
    final repo = _ref.read(localRepositoryProvider);
    final historyItem = AssistantHistory(
      id: const Uuid().v4(),
      userQuery: query,
      assistantResponse: response,
      intent: intent,
      timestamp: DateTime.now(),
    );
    await repo.insertHistory(historyItem);
    await loadHistory();
  }

  /// Parses a time string like "7 PM", "07:30 AM", "9:00 PM" into [hour, minute]
  /// in 24-hour format. Returns null if it can't be parsed.
  List<int>? _parseTimeToHourMinute(String time) {
    if (time.isEmpty) return null;
    final t = time.toUpperCase().trim();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?').firstMatch(t);
    if (match == null) return null;

    int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3);

    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23) hour = 23;
    if (minute > 59) return [hour, 0];
    return [hour, minute];
  }

  bool _matchesYes(String text) {
    return text == 'yes' ||
        text == 'yep' ||
        text == 'yeah' ||
        text == 'haan' ||
        text == 'ji' ||
        text == 'g' ||
        text == 'yes please' ||
        text == 'theek hai';
  }

  bool _matchesNo(String text) {
    return text == 'no' ||
        text == 'nope' ||
        text == 'nah' ||
        text == 'nahi' ||
        text == 'na' ||
        text == 'cancel' ||
        text == 'no thanks' ||
        text == 'mat karo';
  }
}

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
      return AssistantController(ref);
    });

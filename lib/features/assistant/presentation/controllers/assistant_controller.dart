import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/nlp_engine.dart';
import '../../../../core/services/shake_detection_service.dart';
import '../../../../core/services/localized_responses.dart';
import '../../../../core/services/language_detector.dart';
import '../../../../routing/app_router.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

enum OrbState { idle, listening, processing, responding, error }

class AssistantState {
  final OrbState orbState;
  final String transcript;
  final String responseText;
  final List<AssistantHistory> history;

  // Conversational session context
  final bool isConfirming;
  final ParsedIntent? pendingIntent;
  final String? missingField;
  final String? navigationTarget;

  // Multiple contacts disambiguation
  final List<Contact>? multipleContacts;

  AssistantState({
    this.orbState = OrbState.idle,
    this.transcript = '',
    this.responseText = 'Hello! Shake your phone or tap the mic to speak.',
    this.history = const [],
    this.isConfirming = false,
    this.pendingIntent,
    this.missingField,
    this.navigationTarget,
    this.multipleContacts,
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
    List<Contact>? multipleContacts,
    bool clearMultipleContacts = false,
    bool clearPendingIntent = false,
    bool clearMissingField = false,
    bool clearNavigationTarget = false,
  }) {
    return AssistantState(
      orbState: orbState ?? this.orbState,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      history: history ?? this.history,
      isConfirming: isConfirming ?? this.isConfirming,
      pendingIntent: clearPendingIntent ? null : (pendingIntent ?? this.pendingIntent),
      missingField: clearMissingField ? null : (missingField ?? this.missingField),
      navigationTarget: clearNavigationTarget ? null : navigationTarget,
      multipleContacts: clearMultipleContacts ? null : (multipleContacts ?? this.multipleContacts),
    );
  }
}

// ========================================================================== //
//  AssistantController                                                         //
// ========================================================================== //

class AssistantController extends StateNotifier<AssistantState> {
  final Ref _ref;
  String _activeLanguage = 'en';

  AssistantController(this._ref) : super(AssistantState()) {
    _initialize();
  }

  String _lang() => _activeLanguage;

  // ---------------------------------------------------------------------- //
  //  Initialization                                                          //
  // ---------------------------------------------------------------------- //

  Future<void> _initialize() async {
    // 1. Load history
    await loadHistory();

    // 2. Apply current language to TTS
    _syncLanguageToServices();

    // 3. Request permissions upfront (with voice feedback if denied)
    await _ref.read(permissionServiceProvider).requestAllCriticalPermissions(
      speakFeedback: true,
    );

    // 4. Import device contacts into local DB (if not already done)
    final repo = _ref.read(localRepositoryProvider);
    final existing = await repo.getContacts();
    if (existing.length <= 5) {
      // Only 5 mock contacts in DB — import real device contacts
      debugPrint('AssistantController: importing device contacts...');
      await _ref.read(contactsServiceProvider).importDeviceContacts(repo);
    }

    // 5. Initialize shake detection (this also starts the Android service)
    _initializeShakeDetection();

    // Keep the service alive across Doze. Ask once so we don't spam the dialog.
    try {
      final asked = await repo.getSetting('battery_opt_asked');
      if (asked != 'true') {
        await _ref.read(phoneServiceProvider).requestIgnoreBatteryOptimizations();
        await repo.saveSetting('battery_opt_asked', 'true');
      }
    } catch (_) {}

    // 6. Speak the welcome once so a blind user knows the app is ready.
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final greeting =
          LocalizedResponses.getResponse(_lang(), 'initialGreeting');
      state = state.copyWith(responseText: greeting);
      await _speakAndWait(greeting);
    });
  }

  void _syncLanguageToServices() {
    final settings = _ref.read(settingsControllerProvider);
    _activeLanguage = settings.language;
    _ref.read(ttsServiceProvider).setLanguageCode(_activeLanguage);
    _ref.read(speechServiceProvider).setLanguageCode(_activeLanguage);
  }

  void _initializeShakeDetection() {
    // initialize() both registers the method channel handler AND starts
    // the Android foreground service — previously only initialize() was called
    // without ever calling startDetection(), so the service never ran.
    ShakeDetectionService.initialize();
    ShakeDetectionService.setOnShakeDetectedCallback(() {
      _onShakeDetected();
    });
    debugPrint('AssistantController: shake detection initialized and service started');
  }

  // ---------------------------------------------------------------------- //
  //  Shake handler                                                           //
  // ---------------------------------------------------------------------- //

  // ---------------------------------------------------------------------- //
  //  Shake handler                                                           //
  // ---------------------------------------------------------------------- //

  void _onShakeDetected() {
    if (!mounted) return;
    debugPrint('AssistantController: shake detected — starting a fresh session');
    _startFreshSession();
  }

  /// Shake (or a full-screen tap) always starts over: stop TTS/mic, clear
  /// pending prompts, greet, then listen. Blind users never get stuck.
  Future<void> _startFreshSession() async {
    if (!mounted) return;
    await _ref.read(speechServiceProvider).cancelListening();
    await _ref.read(ttsServiceProvider).stop();
    if (!mounted) return;
    state = state.copyWith(
      isConfirming: false,
      clearPendingIntent: true,
      clearMissingField: true,
      clearMultipleContacts: true,
      transcript: '',
    );
    await _greetAndListen();
  }

  Future<void> _greetAndListen() async {
    if (!mounted) return;
    final language = _lang();

    final greetings = [
      LocalizedResponses.getResponse(language, 'greeting1'),
      LocalizedResponses.getResponse(language, 'greeting2'),
      LocalizedResponses.getResponse(language, 'greeting3'),
      LocalizedResponses.getResponse(language, 'greeting4'),
      LocalizedResponses.getResponse(language, 'greeting5'),
      LocalizedResponses.getResponse(language, 'greeting6'),
      LocalizedResponses.getResponse(language, 'greeting7'),
    ];

    final greeting = greetings[DateTime.now().millisecond % greetings.length];

    state = state.copyWith(
      orbState: OrbState.responding,
      responseText: greeting,
    );

    await _speakAndWait(greeting, returnToIdle: false);
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      await _startListening();
    }
  }

  // ---------------------------------------------------------------------- //
  //  Microphone control                                                      //
  // ---------------------------------------------------------------------- //

  Future<void> toggleListening() async {
    final speech = _ref.read(speechServiceProvider);
    if (speech.isListening) {
      await speech.stopListening();
      if (mounted) state = state.copyWith(orbState: OrbState.idle);
    } else {
      await _startFreshSession();
    }
  }

  /// Public entry used by the home screen (tap or shake).
  Future<void> startVoiceSession() => _startFreshSession();

  Future<void> _startListening() async {
    if (!mounted) return;
    final language = _lang();

    // Check microphone permission first
    final hasMic = await _ref
        .read(permissionServiceProvider)
        .ensureMicrophonePermission();
    if (!hasMic) {
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.error,
          responseText: LocalizedResponses.getResponse(language, 'microphoneError'),
        );
      }
      return;
    }

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.listening,
        transcript: LocalizedResponses.getResponse(language, 'listening'),
      );
    }

    final dictatingMessage = state.missingField == 'messageText' ||
        state.missingField == 'title';

    await _ref.read(speechServiceProvider).startListening(
      commandMode: !dictatingMessage,
      onResult: (text) {
        if (mounted) {
          state = state.copyWith(transcript: text);
        }
      },
      onError: () async {
        if (!mounted) return;
        debugPrint('AssistantController: STT error/timeout — ask to repeat');
        final errorMsg = LocalizedResponses.getResponse(language, 'pleaseRepeat');
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: errorMsg,
        );
        await _speakAndWait(errorMsg, returnToIdle: false);
        await _listenAfterPrompt();
      },
      onDone: (finalText) {
        if (mounted) {
          processSpokenText(finalText);
        }
      },
    );
  }

  void clearNavigation() {
    state = state.copyWith(clearNavigationTarget: true);
  }

  // ---------------------------------------------------------------------- //
  //  History                                                                 //
  // ---------------------------------------------------------------------- //

  Future<void> loadHistory() async {
    final repo = _ref.read(localRepositoryProvider);
    final hist = await repo.getHistory();
    if (mounted) state = state.copyWith(history: hist);
  }

  // ---------------------------------------------------------------------- //
  //  Text processing                                                         //
  // ---------------------------------------------------------------------- //

  Future<void> processSpokenText(String text) async {
    if (!mounted) return;

    debugPrint('AssistantController: processSpokenText("$text")');

    final detected = LanguageDetector.detect(text);
    _activeLanguage = detected;
    // TTS follows the user. STT locale stays locked — flipping it mid-session
    // is the main reason speech suddenly "understands something else".
    _ref.read(ttsServiceProvider).setLanguageCode(detected);
    final language = _lang();

    // Empty input
    if (text.trim().isEmpty ||
        text == LocalizedResponses.getResponse(language, 'listening')) {
      final didntHear = LocalizedResponses.getResponse(language, 'didntHear');
      if (mounted) {
        state = state.copyWith(orbState: OrbState.idle, responseText: didntHear);
      }
      await _speakAndWait(didntHear);
      await _listenAfterPrompt();
      return;
    }

    if (mounted) state = state.copyWith(orbState: OrbState.processing);
    await Future.delayed(const Duration(milliseconds: 250));

    final cleanText = text.toLowerCase().trim();

    // ---------------------------------------------------------------- //
    //  A. Multiple contacts disambiguation                               //
    // ---------------------------------------------------------------- //
    if (state.multipleContacts != null && state.multipleContacts!.isNotEmpty) {
      await _handleDisambiguation(text, cleanText);
      return;
    }

    // ---------------------------------------------------------------- //
    //  B. Confirmation flow (message, event, reminder)                  //
    // ---------------------------------------------------------------- //
    if (state.isConfirming && state.pendingIntent != null) {
      if (_matchesYes(cleanText)) {
        await _executeIntent(state.pendingIntent!);
      } else if (_matchesNo(cleanText)) {
        final cancelled = LocalizedResponses.getResponse(language, 'cancelled');
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: cancelled,
            isConfirming: false,
            clearPendingIntent: true,
            clearMissingField: true,
          );
        }
        await _speakAndWait(cancelled);
      } else {
        final prompt = LocalizedResponses.getResponse(language, 'yesNoPrompt');
        if (mounted) {
          state = state.copyWith(orbState: OrbState.responding, responseText: prompt);
        }
        await _speakAndWait(prompt, returnToIdle: false);
        await _listenAfterPrompt();
      }
      return;
    }

    // ---------------------------------------------------------------- //
    //  C. Missing field dialog (contact name, message, time, etc.)      //
    // ---------------------------------------------------------------- //
    if (state.missingField != null && state.pendingIntent != null) {
      final reparsed = NlpEngine.parse(text);
      if (reparsed.intent != AssistantIntent.unknown &&
          reparsed.intent != AssistantIntent.greeting &&
          reparsed.intent != AssistantIntent.cancel &&
          (reparsed.intent != state.pendingIntent!.intent ||
              (state.missingField == 'contactName' &&
                  reparsed.contactName != null &&
                  reparsed.contactName!.trim().isNotEmpty))) {
        await _checkAndProgressIntent(reparsed);
        return;
      }
      final updatedIntent = _fillMissingField(
        state.pendingIntent!,
        state.missingField!,
        text,
      );
      await _checkAndProgressIntent(updatedIntent);
      return;
    }

    // ---------------------------------------------------------------- //
    //  D. Fresh intent                                                   //
    // ---------------------------------------------------------------- //
    final parsed = NlpEngine.parse(text);
    debugPrint('AssistantController: parsed intent = $parsed');
    await _checkAndProgressIntent(parsed);
  }

  // ---------------------------------------------------------------------- //
  //  Multiple contacts disambiguation                                        //
  // ---------------------------------------------------------------------- //

  Future<void> _handleDisambiguation(String text, String cleanText) async {
    if (!mounted) return;
    final language = _lang();
    final contacts = state.multipleContacts!;

    // Try to match the user's reply against the list of multiple contacts
    Contact? selected;
    for (final c in contacts) {
      if (cleanText.contains(c.name.toLowerCase()) ||
          c.name.toLowerCase().contains(cleanText)) {
        selected = c;
        break;
      }
    }

    if (selected != null) {
      if (mounted) {
        state = state.copyWith(clearMultipleContacts: true);
      }
      final pending = state.pendingIntent;
      // Route based on pending intent type
      if (pending?.intent == AssistantIntent.message) {
        if (pending?.messageText != null && pending!.messageText!.isNotEmpty) {
          await _initiateMessage(
            name: selected.name,
            phone: selected.phoneNumber,
            body: pending.messageText!,
            rawQuery: pending.rawQuery,
            language: language,
          );
        } else {
          // Ask for message body
          final ask = _ml(language,
              en: 'What message would you like to send to ${selected.name}?',
              ur: '${selected.name} کو کیا میسج بھیجنا ہے؟',
              ro: '${selected.name} ko kya message bhejna hai?');
          if (mounted) {
            state = state.copyWith(
              orbState: OrbState.responding,
              responseText: ask,
              missingField: 'messageText',
              pendingIntent: ParsedIntent(
                intent: AssistantIntent.message,
                contactName: selected.name,
                messageText: null,
                targetScreen: selected.phoneNumber,
                rawQuery: pending?.rawQuery ?? text,
              ),
            );
          }
          await _speakAndWait(ask);
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) await _startListening();
        }
      } else {
        await _initiateCall(
          name: selected.name,
          phone: selected.phoneNumber,
          simSlot: state.pendingIntent?.simSlot,
          rawQuery: state.pendingIntent?.rawQuery ?? text,
          language: language,
        );
      }
    } else {
      // Couldn't match
      final reply = LocalizedResponses.getResponse(language, 'unknownCommand');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          clearMultipleContacts: true,
          clearPendingIntent: true,
        );
      }
      await _speakAndWait(reply);
    }
  }

  Future<void> _checkAndProgressIntent(ParsedIntent intent) async {
    if (!mounted) return;
    final repo = _ref.read(localRepositoryProvider);
    final language = _lang();

    switch (intent.intent) {
      // ---------------------------------------------------------------- //
      case AssistantIntent.greeting:
        final greeting = LocalizedResponses.getResponse(language, 'greeting1');
        if (mounted) {
          state = state.copyWith(orbState: OrbState.responding, responseText: greeting);
        }
        await _speakAndWait(greeting);
        _logHistory(intent.rawQuery, greeting, 'greeting');
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.time:
        final timeStr = DateFormat('hh:mm a').format(DateTime.now());
        final reply = LocalizedResponses.getFormattedResponse(
            language, 'timeNow', {'time': timeStr});
        if (mounted) {
          state = state.copyWith(orbState: OrbState.responding, responseText: reply);
        }
        await _speakAndWait(reply);
        _logHistory(intent.rawQuery, reply, 'time');
        break;

      // ---------------------------------------------------------------- //
      //  CALL — the main workflow                                          //
      // ---------------------------------------------------------------- //
      case AssistantIntent.call:
        await _handleCallIntent(intent, repo, language);
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.message:
        await _handleMessageIntent(intent, repo, language);
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.alarm:
        await _handleAlarmIntent(intent, repo, language);
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.reminder:
        await _handleReminderIntent(intent, repo, language);
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.calendarSchedule:
        await _handleCalendarSchedule(repo, intent, language);
        break;

      case AssistantIntent.addEvent:
        await _handleAddEvent(intent, repo, language);
        break;

      case AssistantIntent.deleteEvent:
        await _handleDeleteEvent(intent, repo, language);
        break;

      case AssistantIntent.navigate:
        await _handleNavigation(intent, language);
        break;

      case AssistantIntent.nextMeeting:
        await _handleNextMeeting(repo, intent, language);
        break;

      case AssistantIntent.readMessages:
        await _handleReadMessages(repo, intent, language);
        break;

      case AssistantIntent.replyMessage:
        final askContact = LocalizedResponses.getResponse(language, 'askContactName');
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: askContact,
            missingField: 'contactName',
            pendingIntent: ParsedIntent(
              intent: AssistantIntent.message,
              rawQuery: intent.rawQuery,
            ),
          );
        }
        await _speakAndWait(askContact);
        break;

      // ---------------------------------------------------------------- //
      case AssistantIntent.help:
        final help = _ml(language,
            en: 'Shake your phone or tap the screen. You can say: call a contact, message a contact, or set an alarm. Speak in English, Urdu, or Roman Urdu.',
            ur: 'فون ہلائیں یا اسکرین دبائیں۔ آپ کہہ سکتے ہیں: کسی کو کال کرو، میسج بھیجو، یا الارم لگاؤ۔ انگریزی، اردو یا رومن اردو میں بولیں۔',
            ro: 'Phone hilayein ya screen dabayein. Aap keh sakte hain: kisi ko call karo, message bhejo, ya alarm lagao. English, Urdu ya Roman Urdu mein bolein.');
        if (mounted) {
          state = state.copyWith(orbState: OrbState.responding, responseText: help);
        }
        await _speakAndWait(help, returnToIdle: false);
        await _listenAfterPrompt();
        _logHistory(intent.rawQuery, help, 'help');
        break;

      case AssistantIntent.cancel:
        final cancelled = LocalizedResponses.getResponse(language, 'cancelled');
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: cancelled,
            isConfirming: false,
            clearPendingIntent: true,
            clearMissingField: true,
            clearMultipleContacts: true,
          );
        }
        await _speakAndWait(cancelled);
        break;

      case AssistantIntent.unknown:
        final reply = LocalizedResponses.getResponse(language, 'pleaseRepeat');
        if (mounted) {
          state = state.copyWith(orbState: OrbState.responding, responseText: reply);
        }
        await _speakAndWait(reply, returnToIdle: false);
        await _listenAfterPrompt();
        break;
    }
  }

  // ---------------------------------------------------------------------- //
  //  CALL INTENT HANDLER (fixed)                                             //
  // ---------------------------------------------------------------------- //

  Future<void> _handleCallIntent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;

    // Step 1: Ensure we have a contact name
    if (intent.contactName == null || intent.contactName!.trim().isEmpty) {
      final askContact = LocalizedResponses.getResponse(language, 'askContactName');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askContact,
          missingField: 'contactName',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askContact);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // Step 2: Check contacts permission
    final hasContacts = await _ref
        .read(permissionServiceProvider)
        .ensureContactsPermission();
    if (!hasContacts) return;

    final contactName = intent.contactName!.trim();
    debugPrint('AssistantController: looking up contact "$contactName"');

    // Step 3: Search — try fuzzy first, then SQL LIKE, then import+retry
    var matched = await repo.fuzzySearchContacts(contactName);

    if (matched.isEmpty) {
      debugPrint('AssistantController: fuzzy found nothing, trying SQL LIKE');
      matched = await repo.searchContacts(contactName);
    }

    if (matched.isEmpty) {
      debugPrint('AssistantController: no results, importing device contacts');
      await _ref.read(contactsServiceProvider).importDeviceContacts(repo);
      matched = await repo.fuzzySearchContacts(contactName);
      if (matched.isEmpty) {
        matched = await repo.searchContacts(contactName);
      }
      if (matched.isEmpty) {
        matched = await _ref
            .read(contactsServiceProvider)
            .searchDeviceLive(contactName);
      }
    }

    // Step 4: No contact found
    if (matched.isEmpty) {
      final reply = LocalizedResponses.getFormattedResponse(
          language, 'callFailed', {'name': contactName});
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          missingField: 'contactName',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(reply);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // Step 5: Multiple contacts — ask which one
    if (matched.length > 1) {
      final names = matched.map((c) => c.name).join(', ');
      final reply =
          'I found ${matched.length} contacts: $names. Which one would you like to call?';
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          multipleContacts: matched,
          pendingIntent: intent,
        );
      }
      await _speakAndWait(reply);
      // Start listening again to hear the disambiguation answer
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // Step 6: Exactly one contact found — call immediately
    final contact = matched.first;
    await _initiateCall(
      name: contact.name,
      phone: contact.phoneNumber,
      simSlot: intent.simSlot,
      rawQuery: intent.rawQuery,
      language: language,
    );
  }

  /// Places the actual phone call after contact has been resolved.
  ///
  /// Fix: previously this was only reached via [_executeIntent] which required
  /// the user to say "yes" (isConfirming=true). Now it is called directly
  /// after finding exactly one contact, making the flow truly hands-free.
  Future<void> _initiateCall({
    required String name,
    required String phone,
    required String language,
    required String rawQuery,
    String? simSlot,
  }) async {
    if (!mounted) return;

    // Speak "Calling {name}" — user hears this while dialer opens
    final callingMsg = LocalizedResponses.getFormattedResponse(
        language, 'callConfirm', {'name': name});

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: callingMsg,
        isConfirming: false,
        clearPendingIntent: true,
        clearMissingField: true,
        clearMultipleContacts: true,
      );
    }

    // Speak and await — so TTS finishes before the dialer opens
    await _speakAndWait(callingMsg);

    // Check phone permission
    final hasPhone = await _ref
        .read(permissionServiceProvider)
        .ensureCallPermission();
    if (!hasPhone) return;

    // SIM selection for accessibility service
    if (simSlot != null) {
      await _ref.read(phoneServiceProvider).setTargetSim(simSlot);
    }

    int? simSlotIndex;
    if (simSlot != null) {
      simSlotIndex =
          _ref.read(phoneServiceProvider).getSimSlotFromName(simSlot);
    }

    debugPrint(
        'AssistantController: placing call to $name ($phone) on SIM $simSlot');

    // Place the call
    final callLaunched = await _ref
        .read(phoneServiceProvider)
        .makePhoneCall(phoneNumber: phone, simSlot: simSlotIndex);

    debugPrint('AssistantController: callLaunched=$callLaunched');

    final finalResponse = callLaunched
        ? LocalizedResponses.getFormattedResponse(
            language, 'callSuccess', {'name': name})
        : LocalizedResponses.getFormattedResponse(
            language, 'callFailed', {'name': name});

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: finalResponse,
      );
    }

    if (!callLaunched) {
      await _speakAndWait(finalResponse);
    }

    _logHistory(rawQuery, finalResponse, 'call');

    // Return to idle after a brief delay
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && state.orbState == OrbState.responding) {
      state = state.copyWith(orbState: OrbState.idle);
    }
  }

  // ---------------------------------------------------------------------- //
  //  Execute confirmed intents                                               //
  // ---------------------------------------------------------------------- //

  Future<void> _executeIntent(ParsedIntent intent) async {
    if (!mounted) return;
    final repo = _ref.read(localRepositoryProvider);
    final language = _lang();

    switch (intent.intent) {
      case AssistantIntent.call:
        // messageText holds the phone number (set during contact resolution)
        final name = intent.contactName ?? 'Someone';
        final phone = intent.messageText ?? '';
        await _initiateCall(
          name: name,
          phone: phone,
          simSlot: intent.simSlot,
          rawQuery: intent.rawQuery,
          language: language,
        );
        break;

      case AssistantIntent.message:
        final name = intent.contactName ?? '';
        final body = intent.messageText ?? '';
        final phone = intent.targetScreen ?? '';

        bool sent = false;
        if (phone.isNotEmpty && phone != 'user') {
          sent = await _ref
              .read(phoneServiceProvider)
              .sendSms(phoneNumber: phone, message: body);
        }

        final response = sent
            ? LocalizedResponses.getFormattedResponse(
                language, 'messageSent', {'name': name})
            : LocalizedResponses.getResponse(language, 'messageFailed');

        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: response,
            isConfirming: false,
            clearPendingIntent: true,
          );
        }
        await _speakAndWait(response);
        _logHistory(intent.rawQuery, response, 'message');
        break;

      case AssistantIntent.reminder:
        final reminder = Reminder(
          id: const Uuid().v4(),
          title: intent.title ?? 'Reminder',
          dateTime: DateTime.now().add(const Duration(days: 1)),
          category: 'generic',
          repeatType: 'none',
          isCompleted: false,
          createdAt: DateTime.now(),
        );
        await repo.insertReminder(reminder);

        final response = LocalizedResponses.getFormattedResponse(
            language, 'reminderSet', {
          'title': intent.title ?? '',
          'time': intent.time ?? '',
          'date': intent.date ?? '',
        });
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: response,
            isConfirming: false,
            clearPendingIntent: true,
          );
        }
        await _speakAndWait(response);
        _logHistory(intent.rawQuery, response, 'reminder');
        break;

      case AssistantIntent.addEvent:
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
          title: intent.title ?? 'Event',
          dateTime: start,
          durationMinutes: 60,
          createdAt: DateTime.now(),
        );
        await repo.insertEvent(ev);
        await _ref.read(phoneServiceProvider).addCalendarEvent(
              title: intent.title ?? 'Event',
              start: start,
              end: end,
            );

        final response = LocalizedResponses.getFormattedResponse(
            language, 'eventAdded', {
          'title': intent.title ?? '',
          'time': intent.time ?? '',
          'date': intent.date ?? '',
        });
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: response,
            isConfirming: false,
            clearPendingIntent: true,
          );
        }
        await _speakAndWait(response);
        _logHistory(intent.rawQuery, response, 'calendar');
        break;

      case AssistantIntent.deleteEvent:
        final events = await repo.getEvents();
        if (events.isNotEmpty) await repo.deleteEvent(events.first.id);

        final response = LocalizedResponses.getFormattedResponse(
            language, 'eventDeleted', {'date': intent.date ?? ''});
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: response,
            isConfirming: false,
            clearPendingIntent: true,
          );
        }
        await _speakAndWait(response);
        break;

      default:
        break;
    }
  }

  // ---------------------------------------------------------------------- //
  //  Other intent handlers                                                   //
  // ---------------------------------------------------------------------- //

  Future<void> _handleMessageIntent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;

    // ── Step 1: Need a contact name ──────────────────────────────────────────
    if (intent.contactName == null || intent.contactName!.trim().isEmpty) {
      final ask = _ml(language,
          en: 'Who would you like to message? Please say the contact name.',
          ur: 'آپ کس کو میسج کرنا چاہتے ہیں؟ رابطے کا نام بتائیں۔',
          ro: 'Kisko message karna chahte hain? Contact ka naam batayein.');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: ask,
          missingField: 'contactName',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(ask);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // ── Step 2: Check contacts permission ────────────────────────────────────
    final hasContacts = await _ref
        .read(permissionServiceProvider)
        .ensureContactsPermission();
    if (!hasContacts) return;

    final contactName = intent.contactName!.trim();
    debugPrint('AssistantController(message): searching "$contactName"');

    // ── Step 3: Fuzzy contact lookup ─────────────────────────────────────────
    var matched = await repo.fuzzySearchContacts(contactName);
    if (matched.isEmpty) matched = await repo.searchContacts(contactName);
    if (matched.isEmpty) {
      await _ref.read(contactsServiceProvider).importDeviceContacts(repo);
      matched = await repo.fuzzySearchContacts(contactName);
      if (matched.isEmpty) matched = await repo.searchContacts(contactName);
      if (matched.isEmpty) {
        matched = await _ref
            .read(contactsServiceProvider)
            .searchDeviceLive(contactName);
      }
    }

    // ── Step 4: Contact not found ────────────────────────────────────────────
    if (matched.isEmpty) {
      final reply = _ml(language,
          en: 'I couldn\'t find a contact named $contactName. Please say the name again.',
          ur: '$contactName نام کا رابطہ نہیں ملا۔ دوبارہ نام بتائیں۔',
          ro: '$contactName naam ka contact nahi mila. Dobara naam batayein.');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          missingField: 'contactName',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(reply);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // ── Step 5: Multiple contacts disambiguation ──────────────────────────────
    if (matched.length > 1) {
      final names = matched.map((c) => c.name).join(', ');
      final reply = _ml(language,
          en: 'I found ${matched.length} contacts: $names. Which one would you like to message?',
          ur: '${matched.length} رابطے ملے: $names۔ کس کو میسج کریں؟',
          ro: '${matched.length} contacts mile: $names. Kisko message karein?');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          multipleContacts: matched,
          pendingIntent: ParsedIntent(
            intent: AssistantIntent.message,
            contactName: contactName,
            messageText: intent.messageText,
            rawQuery: intent.rawQuery,
          ),
        );
      }
      await _speakAndWait(reply);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    final contact = matched.first;

    // ── Step 6: Need the message body ─────────────────────────────────────────
    if (intent.messageText == null || intent.messageText!.trim().isEmpty) {
      final ask = _ml(language,
          en: 'What message would you like to send to ${contact.name}?',
          ur: '${contact.name} کو کیا میسج بھیجنا ہے؟',
          ro: '${contact.name} ko kya message bhejna hai?');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: ask,
          missingField: 'messageText',
          pendingIntent: ParsedIntent(
            intent: AssistantIntent.message,
            contactName: contact.name,
            messageText: null,
            targetScreen: contact.phoneNumber,
            rawQuery: intent.rawQuery,
          ),
        );
      }
      await _speakAndWait(ask);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _startListening();
      return;
    }

    // ── Step 7: Send SMS directly ─────────────────────────────────────────────
    await _initiateMessage(
      name: contact.name,
      phone: contact.phoneNumber,
      body: intent.messageText!.trim(),
      rawQuery: intent.rawQuery,
      language: language,
    );
  }

  /// Sends the SMS and gives spoken feedback — no confirmation required.
  Future<void> _initiateMessage({
    required String name,
    required String phone,
    required String body,
    required String rawQuery,
    required String language,
  }) async {
    if (!mounted) return;

    // Check SMS permission
    final hasSms = await _ref
        .read(permissionServiceProvider)
        .ensureSmsPermission();
    if (!hasSms) return;

    final sendingMsg = _ml(language,
        en: 'Sending a phone message to $name.',
        ur: '$name کو فون میسج بھیج رہا ہوں۔',
        ro: '$name ko phone message bhej raha hoon.');

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: sendingMsg,
        isConfirming: false,
        clearPendingIntent: true,
        clearMissingField: true,
        clearMultipleContacts: true,
      );
    }
    await _speakAndWait(sendingMsg);

    debugPrint('AssistantController(message): sending "$body" to $name ($phone)');

    final sent = await _ref
        .read(phoneServiceProvider)
        .sendSms(phoneNumber: phone, message: body);

    debugPrint('AssistantController(message): sent=$sent');

    final finalResponse = sent
        ? _ml(language,
            en: 'Message sent to $name in your phone Messages app.',
            ur: '$name کو فون کے میسجز ایپ میں پیغام بھیج دیا گیا۔',
            ro: '$name ko phone ki Messages app mein message bhej diya.')
        : _ml(language,
            en: 'Sorry, I couldn\'t send the phone message to $name. Please check SMS permission.',
            ur: 'معذرت، $name کو فون میسج نہیں بھیجا جا سکا۔',
            ro: 'Sorry, $name ko phone message nahi bhej saka.');

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: finalResponse,
      );
    }

    await _speakAndWait(finalResponse);

    _logHistory(rawQuery, finalResponse, 'message');

    await Future.delayed(const Duration(seconds: 3));
    if (mounted && state.orbState == OrbState.responding) {
      state = state.copyWith(orbState: OrbState.idle);
    }
  }

  /// Helper: returns the string for the current app language.
  String _ml(String lang, {required String en, required String ur, required String ro}) {
    if (lang == 'ur') return ur;
    if (lang == 'roman_ur') return ro;
    return en;
  }

  Future<void> _handleAlarmIntent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;
    if (intent.time == null || intent.time!.isEmpty) {
      final askTime = LocalizedResponses.getResponse(language, 'askTime');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askTime,
          missingField: 'time',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askTime, returnToIdle: false);
      await _listenAfterPrompt();
      return;
    }

    final hm = _parseTimeToHourMinute(intent.time!);
    if (hm != null) {
      await _ref.read(alarmServiceProvider).setAlarm(
            hour: hm[0],
            minute: hm[1],
            label: 'Voice Alarm',
            repeatDays: 'Everyday',
            repository: repo,
          );
      final reply = LocalizedResponses.getFormattedResponse(
          language, 'alarmSet', {'time': intent.time!, 'date': ''});
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          isConfirming: false,
          clearPendingIntent: true,
          clearMissingField: true,
        );
      }
      await _speakAndWait(reply);
      _logHistory(intent.rawQuery, reply, 'alarm');
    } else {
      final reply = _ml(language,
          en: 'I couldn\'t understand the time. Please say it like 8 PM or 7 30 AM.',
          ur: 'وقت سمجھ نہیں آیا۔ براہ کرم اس طرح کہیں جیسے 8 بجے یا 7:30۔',
          ro: 'Time samajh nahi aaya. Please 8 PM ya 7 30 AM kehein.');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: reply,
          missingField: 'time',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(reply, returnToIdle: false);
      await _listenAfterPrompt();
    }
  }

  Future<void> _handleReminderIntent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;
    if (intent.title == null || intent.title!.isEmpty) {
      final askTitle = LocalizedResponses.getResponse(language, 'askTitle');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askTitle,
          missingField: 'title',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askTitle, returnToIdle: false);
      await _listenAfterPrompt();
      return;
    }
    if (intent.time == null || intent.time!.isEmpty) {
      final askTime = LocalizedResponses.getResponse(language, 'askTime');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askTime,
          missingField: 'time',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askTime, returnToIdle: false);
      await _listenAfterPrompt();
      return;
    }

    final prompt = LocalizedResponses.getFormattedResponse(
        language, 'reminderSet', {
      'title': intent.title!,
      'time': intent.time!,
      'date': intent.date ?? '',
    });
    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: prompt,
        isConfirming: true,
        clearMissingField: true,
        pendingIntent: intent,
      );
    }
    await _speakAndWait(prompt);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _startListening();
  }

  Future<void> _handleCalendarSchedule(
    dynamic repo,
    ParsedIntent intent,
    String language,
  ) async {
    if (!mounted) return;
    final events = await repo.getEvents();
    if (events.isEmpty) {
      final reply = LocalizedResponses.getResponse(language, 'noEvents');
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    } else {
      final buffer = StringBuffer();
      buffer.write(LocalizedResponses.getFormattedResponse(
          language, 'scheduleToday', {'count': events.length.toString()}));
      for (final ev in events) {
        final timeStr = DateFormat('hh:mm a').format(ev.dateTime);
        buffer.write(' ${ev.title} at $timeStr.');
      }
      final reply = buffer.toString();
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    }
    _logHistory(intent.rawQuery, 'Showed schedule', 'calendar');
  }

  Future<void> _handleAddEvent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;
    if (intent.title == null || intent.title!.isEmpty) {
      final askTitle = LocalizedResponses.getResponse(language, 'askTitle');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askTitle,
          missingField: 'title',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askTitle, returnToIdle: false);
      await _listenAfterPrompt();
      return;
    }
    if (intent.time == null || intent.time!.isEmpty) {
      final askTime = LocalizedResponses.getResponse(language, 'askTime');
      if (mounted) {
        state = state.copyWith(
          orbState: OrbState.responding,
          responseText: askTime,
          missingField: 'time',
          pendingIntent: intent,
        );
      }
      await _speakAndWait(askTime, returnToIdle: false);
      await _listenAfterPrompt();
      return;
    }

    final prompt = LocalizedResponses.getFormattedResponse(
        language, 'eventAdded', {
      'title': intent.title!,
      'time': intent.time!,
      'date': intent.date ?? '',
    });
    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: prompt,
        isConfirming: true,
        clearMissingField: true,
        pendingIntent: intent,
      );
    }
    await _speakAndWait(prompt);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _startListening();
  }

  Future<void> _handleDeleteEvent(
    ParsedIntent intent,
    dynamic repo,
    String language,
  ) async {
    if (!mounted) return;
    const prompt = 'Do you want to delete your events?';
    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: prompt,
        isConfirming: true,
        pendingIntent: intent,
      );
    }
    await _speakAndWait(prompt);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _startListening();
  }

  Future<void> _handleNavigation(ParsedIntent intent, String language) async {
    if (!mounted) return;
    final screen = intent.targetScreen;
    final response = LocalizedResponses.getFormattedResponse(
        language, 'navigation', {'screen': screen ?? ''});
    String route = '';

    switch (screen) {
      case 'messages':
        await _ref.read(phoneServiceProvider).openSystemMessages();
        final opened = _ml(language,
            en: 'Opening your phone Messages app.',
            ur: 'فون کی میسجز ایپ کھول رہا ہوں۔',
            ro: 'Phone ki Messages app khol raha hoon.');
        if (mounted) {
          state = state.copyWith(
            orbState: OrbState.responding,
            responseText: opened,
          );
        }
        await _speakAndWait(opened);
        _logHistory(intent.rawQuery, opened, 'navigate');
        return;
      case 'reminders':
        route = AppRouter.reminders;
        break;
      case 'alarms':
        route = AppRouter.alarms;
        break;
      case 'calendar':
        route = AppRouter.calendar;
        break;
      case 'settings':
        route = AppRouter.settings;
        break;
      case 'contacts':
        route = AppRouter.contacts;
        break;
    }

    if (mounted) {
      state = state.copyWith(
        orbState: OrbState.responding,
        responseText: response,
        navigationTarget: route.isNotEmpty ? route : null,
      );
    }
    await _speakAndWait(response);
    _logHistory(intent.rawQuery, response, 'navigate');
  }

  Future<void> _handleNextMeeting(
    dynamic repo,
    ParsedIntent intent,
    String language,
  ) async {
    if (!mounted) return;
    final events = await repo.getEvents();
    final upcoming = events
        .where((e) => e.dateTime.isAfter(DateTime.now()))
        .toList();

    if (upcoming.isEmpty) {
      final reply = LocalizedResponses.getResponse(language, 'noEvents');
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    } else {
      final ev = upcoming.first;
      final timeStr = DateFormat('hh:mm a').format(ev.dateTime);
      final reply = LocalizedResponses.getFormattedResponse(
          language, 'nextMeeting', {'title': ev.title, 'time': timeStr});
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    }
  }

  Future<void> _handleReadMessages(
    dynamic repo,
    ParsedIntent intent,
    String language,
  ) async {
    if (!mounted) return;
    final inbox = await _ref
        .read(phoneServiceProvider)
        .readInboxMessages(limit: 3);
    if (inbox.isEmpty) {
      final reply = _ml(language,
          en: 'There are no SMS messages in your phone inbox.',
          ur: 'فون ان باکس میں کوئی میسج نہیں ہے۔',
          ro: 'Phone inbox mein koi message nahi hai.');
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    } else {
      final last = inbox.first;
      final from = last.address ?? 'someone';
      final body = last.body ?? '';
      final reply = _ml(language,
          en: 'Latest phone message from $from: $body',
          ur: 'فون کا تازہ میسج $from سے: $body',
          ro: 'Phone ka latest message $from se: $body');
      if (mounted) {
        state = state.copyWith(orbState: OrbState.responding, responseText: reply);
      }
      await _speakAndWait(reply);
    }
  }

  // ---------------------------------------------------------------------- //
  //  Missing field filler                                                    //
  // ---------------------------------------------------------------------- //

  ParsedIntent _fillMissingField(
    ParsedIntent intent,
    String field,
    String text,
  ) {
    switch (field) {
      case 'contactName':
        return ParsedIntent(
          intent: intent.intent,
          contactName: text.trim(),
          messageText: intent.messageText,
          title: intent.title,
          time: intent.time,
          date: intent.date,
          targetScreen: intent.targetScreen,
          simSlot: intent.simSlot,
          rawQuery: intent.rawQuery,
        );
      case 'messageText':
        return ParsedIntent(
          intent: intent.intent,
          contactName: intent.contactName,
          messageText: text.trim(),
          title: intent.title,
          time: intent.time,
          date: intent.date,
          targetScreen: intent.targetScreen,
          simSlot: intent.simSlot,
          rawQuery: intent.rawQuery,
        );
      case 'title':
        return ParsedIntent(
          intent: intent.intent,
          contactName: intent.contactName,
          messageText: intent.messageText,
          title: text.trim(),
          time: intent.time,
          date: intent.date,
          targetScreen: intent.targetScreen,
          simSlot: intent.simSlot,
          rawQuery: intent.rawQuery,
        );
      case 'time':
        return ParsedIntent(
          intent: intent.intent,
          contactName: intent.contactName,
          messageText: intent.messageText,
          title: intent.title,
          time: text.trim(),
          date: intent.date,
          targetScreen: intent.targetScreen,
          simSlot: intent.simSlot,
          rawQuery: intent.rawQuery,
        );
      case 'simSlot':
        return ParsedIntent(
          intent: intent.intent,
          contactName: intent.contactName,
          messageText: intent.messageText,
          title: intent.title,
          time: intent.time,
          date: intent.date,
          targetScreen: intent.targetScreen,
          simSlot: text.toLowerCase().trim(),
          rawQuery: intent.rawQuery,
        );
      default:
        return intent;
    }
  }

  // ---------------------------------------------------------------------- //
  //  TTS — awaitable                                                         //
  // ---------------------------------------------------------------------- //

  /// Speaks [text] and awaits TTS completion before returning.
  ///
  /// When [returnToIdle] is false, the caller will start the microphone next
  /// so we stay in the responding state until listening begins.
  Future<void> _speakAndWait(String text, {bool returnToIdle = true}) async {
    if (!mounted) return;
    final tts = _ref.read(ttsServiceProvider);
    try {
      await tts.speak(text);
    } catch (e) {
      debugPrint('AssistantController: TTS error: $e');
    }
    if (returnToIdle && mounted && state.orbState == OrbState.responding) {
      state = state.copyWith(orbState: OrbState.idle);
    }
  }

  Future<void> _listenAfterPrompt() async {
    // Give the speaker time to fully stop so the mic does not hear TTS.
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) await _startListening();
  }

  // ---------------------------------------------------------------------- //
  //  History                                                                 //
  // ---------------------------------------------------------------------- //

  Future<void> _logHistory(
    String query,
    String response,
    String intent,
  ) async {
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

  // ---------------------------------------------------------------------- //
  //  Utilities                                                               //
  // ---------------------------------------------------------------------- //

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
    const yesWords = {
      'yes', 'yep', 'yeah', 'sure', 'ok', 'okay', 'alright', 'go', 'proceed',
      'haan', 'ji', 'g', 'theek hai', 'bilkul', 'zaroor', 'ha',
    };
    return yesWords.any((w) => text == w || text.startsWith('$w '));
  }

  bool _matchesNo(String text) {
    const noWords = {
      'no', 'nope', 'nah', 'cancel', 'stop', 'dont', "don't",
      'nahi', 'na', 'mat karo', 'band karo', 'rukao',
    };
    return noWords.any((w) => text == w || text.startsWith('$w '));
  }
}

// ========================================================================== //
//  Provider                                                                   //
// ========================================================================== //

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(ref);
});

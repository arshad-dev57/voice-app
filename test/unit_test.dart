import 'package:flutter_test/flutter_test.dart';
import 'package:voice_recoginization_app/core/services/nlp_engine.dart';

void main() {
  group('NLP Engine Parsing Tests', () {
    test('English Call Command', () {
      final parsed = NlpEngine.parse('Call Ali');
      expect(parsed.intent, AssistantIntent.call);
      expect(parsed.contactName, 'Ali');
    });

    test('Urdu Call Command', () {
      final parsed = NlpEngine.parse('Ali ko call karo');
      expect(parsed.intent, AssistantIntent.call);
      expect(parsed.contactName, 'Ali');
    });

    test('Roman Urdu Call Command', () {
      final parsed = NlpEngine.parse('Mom ko phone karo');
      expect(parsed.intent, AssistantIntent.call);
      expect(parsed.contactName, 'Mom');
    });

    test('English SMS Command', () {
      final parsed = NlpEngine.parse('Text Ali I am coming');
      expect(parsed.intent, AssistantIntent.message);
      expect(parsed.contactName, 'Ali');
      expect(parsed.messageText?.toLowerCase(), 'i am coming');
    });

    test('Urdu/Mixed SMS Command', () {
      final parsed = NlpEngine.parse('Ali ko message karo text I am coming');
      expect(parsed.intent, AssistantIntent.message);
      expect(parsed.contactName, 'Ali');
      expect(parsed.messageText?.toLowerCase(), 'i am coming');
    });

    test('English Alarm Command', () {
      final parsed = NlpEngine.parse('Set alarm for 7 AM tomorrow');
      expect(parsed.intent, AssistantIntent.alarm);
      expect(parsed.time, '7:00 AM');
      expect(parsed.date, 'tomorrow');
    });

    test('English Reminder Command', () {
      final parsed = NlpEngine.parse('Remind me to take medicine at 9 PM');
      expect(parsed.intent, AssistantIntent.reminder);
      expect(parsed.title?.toLowerCase(), 'take medicine');
      expect(parsed.time, '9:00 PM');
    });

    test('General Time Check', () {
      final parsed = NlpEngine.parse('What time is it?');
      expect(parsed.intent, AssistantIntent.time);
    });

    test('General Schedule Check', () {
      final parsed = NlpEngine.parse('What is my schedule today?');
      expect(parsed.intent, AssistantIntent.calendarSchedule);
    });

    test('Dial call to contact', () {
      final parsed = NlpEngine.parse('dial call to Ali');
      expect(parsed.intent, AssistantIntent.call);
      expect(parsed.contactName, 'Ali');
    });

    test('Message to contact without body', () {
      final parsed = NlpEngine.parse('message to Mom');
      expect(parsed.intent, AssistantIntent.message);
      expect(parsed.contactName, 'Mom');
      expect(parsed.messageText, isNull);
    });

    test('Roman Urdu message without body', () {
      final parsed = NlpEngine.parse('Ammi ko message karo');
      expect(parsed.intent, AssistantIntent.message);
      expect(parsed.contactName, 'Ammi');
    });
  });
}

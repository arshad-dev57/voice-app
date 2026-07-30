import 'package:flutter/foundation.dart';
import 'local_database.dart';
import 'models.dart';
import 'package:sqflite/sqflite.dart';
import '../services/firebase_service.dart';

class LocalRepository {
  final LocalDatabase _dbHelper = LocalDatabase.instance;
  final FirebaseService _firebase = FirebaseService.instance;

  // --- SETTINGS ---
  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- USERS ---
  Future<AppUser?> getCurrentUser() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'is_authenticated = ?',
      whereArgs: [1],
    );
    if (maps.isNotEmpty) {
      return AppUser.fromMap(maps.first);
    }
    return null;
  }

  Future<void> saveUser(AppUser user) async {
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAuthUsers() async {
    final db = await _dbHelper.database;
    await db.update('users', {'is_authenticated': 0});
  }

  // --- CONTACTS ---
  Future<List<Contact>> getContacts() async {
    final db = await _dbHelper.database;
    final result = await db.query('contacts', orderBy: 'name ASC');
    return result.map((map) => Contact.fromMap(map)).toList();
  }

  Future<List<Contact>> searchContacts(String nameQuery) async {
    final db = await _dbHelper.database;
    final lowerQuery = nameQuery.toLowerCase();
    debugPrint('LocalRepository: searching for contact with query: "$nameQuery" (lowercase: "$lowerQuery")');
    
    final result = await db.query(
      'contacts',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%$lowerQuery%'],
      orderBy: 'name ASC',
    );
    
    debugPrint('LocalRepository: found ${result.length} contacts matching "$nameQuery"');
    for (final map in result) {
      debugPrint('LocalRepository: matched contact - name: "${map['name']}", phone: "${map['phone_number']}"');
    }
    
    return result.map((map) => Contact.fromMap(map)).toList();
  }

  Future<void> insertContact(Contact contact) async {
    final db = await _dbHelper.database;
    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- CONVERSATIONS & MESSAGES ---
  Future<List<Conversation>> getConversations() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'conversations',
      orderBy: 'last_message_time DESC',
    );
    return result.map((map) => Conversation.fromMap(map)).toList();
  }

  Future<List<Message>> getMessagesForConversation(
    String conversationId,
  ) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<void> insertMessage(Message message) async {
    final db = await _dbHelper.database;
    await db.insert('messages', message.toMap());
    // Opportunistic cloud backup (no-op if signed out / offline).
    _firebase.syncMessage(message);

    // Update conversation last message
    final contacts = await db.query(
      'contacts',
      where: 'phone_number = ?',
      whereArgs: [
        message.receiverPhone == 'user'
            ? message.senderPhone
            : message.receiverPhone,
      ],
    );
    String contactName = 'Unknown';
    if (contacts.isNotEmpty) {
      contactName = contacts.first['name'] as String;
    }

    final conv = Conversation(
      id: message.conversationId,
      contactName: contactName,
      contactPhone: message.receiverPhone == 'user'
          ? message.senderPhone
          : message.receiverPhone,
      lastMessage: message.content,
      lastMessageTime: message.createdAt,
    );

    await db.insert(
      'conversations',
      conv.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- ALARMS ---
  Future<List<Alarm>> getAlarms() async {
    final db = await _dbHelper.database;
    final result = await db.query('alarms', orderBy: 'time ASC');
    return result.map((map) => Alarm.fromMap(map)).toList();
  }

  Future<void> insertAlarm(Alarm alarm) async {
    final db = await _dbHelper.database;
    await db.insert(
      'alarms',
      alarm.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _firebase.syncAlarm(alarm);
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final db = await _dbHelper.database;
    await db.update(
      'alarms',
      alarm.toMap(),
      where: 'id = ?',
      whereArgs: [alarm.id],
    );
    _firebase.syncAlarm(alarm);
  }

  Future<void> deleteAlarm(String id) async {
    final db = await _dbHelper.database;
    await db.delete('alarms', where: 'id = ?', whereArgs: [id]);
    _firebase.deleteAlarm(id);
  }

  // --- REMINDERS ---
  Future<List<Reminder>> getReminders() async {
    final db = await _dbHelper.database;
    final result = await db.query('reminders', orderBy: 'date_time ASC');
    return result.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<void> insertReminder(Reminder reminder) async {
    final db = await _dbHelper.database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _firebase.syncReminder(reminder);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await _dbHelper.database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    _firebase.syncReminder(reminder);
  }

  Future<void> deleteReminder(String id) async {
    final db = await _dbHelper.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    _firebase.deleteReminder(id);
  }

  // --- CALENDAR EVENTS ---
  Future<List<CalendarEvent>> getEvents() async {
    final db = await _dbHelper.database;
    final result = await db.query('calendar_events', orderBy: 'date_time ASC');
    return result.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<void> insertEvent(CalendarEvent event) async {
    final db = await _dbHelper.database;
    await db.insert(
      'calendar_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _firebase.syncEvent(event);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final db = await _dbHelper.database;
    await db.update(
      'calendar_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    _firebase.syncEvent(event);
  }

  Future<void> deleteEvent(String id) async {
    final db = await _dbHelper.database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
    _firebase.deleteEvent(id);
  }

  // --- ASSISTANT HISTORY ---
  Future<List<AssistantHistory>> getHistory() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'assistant_history',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => AssistantHistory.fromMap(map)).toList();
  }

  Future<void> insertHistory(AssistantHistory history) async {
    final db = await _dbHelper.database;
    await db.insert(
      'assistant_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearHistory() async {
    final db = await _dbHelper.database;
    await db.delete('assistant_history');
  }

  // Wipe All Data for GDPR compliance
  Future<void> wipeAllData() async {
    final db = await _dbHelper.database;
    await db.delete('users');
    await db.delete('contacts');
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('reminders');
    await db.delete('alarms');
    await db.delete('calendar_events');
    await db.delete('assistant_history');
    await db.delete('app_settings');
    await _dbHelper.populateMockData(
      db,
    ); // re-initialize default settings & data
  }
}

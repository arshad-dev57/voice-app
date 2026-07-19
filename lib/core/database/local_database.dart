import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_assistant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // SQLite handles bools as 0 or 1

    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        email $textType,
        is_authenticated $boolType,
        created_at $textType
      )
    ''');

    // Contacts Table
    await db.execute('''
      CREATE TABLE contacts (
        id $idType,
        name $textType,
        phone_number $textType,
        email $textNullable,
        photo_uri $textNullable,
        created_at $textType
      )
    ''');

    // Messages Table
    await db.execute('''
      CREATE TABLE messages (
        id $idType,
        conversation_id $textType,
        sender_phone $textType,
        receiver_phone $textType,
        content $textType,
        is_read $boolType,
        created_at $textType
      )
    ''');

    // Conversations Table
    await db.execute('''
      CREATE TABLE conversations (
        id $idType,
        contact_name $textType,
        contact_phone $textType,
        last_message $textType,
        last_message_time $textType
      )
    ''');

    // Reminders Table
    await db.execute('''
      CREATE TABLE reminders (
        id $idType,
        title $textType,
        date_time $textType,
        category $textType,
        repeat_type $textType,
        is_completed $boolType,
        created_at $textType
      )
    ''');

    // Alarms Table
    await db.execute('''
      CREATE TABLE alarms (
        id $idType,
        time $textType,
        label $textType,
        is_enabled $boolType,
        repeat_days $textType,
        created_at $textType
      )
    ''');

    // Calendar Events Table
    await db.execute('''
      CREATE TABLE calendar_events (
        id $idType,
        title $textType,
        description $textNullable,
        date_time $textType,
        duration_minutes $integerType,
        created_at $textType
      )
    ''');

    // Assistant Command/History Table
    await db.execute('''
      CREATE TABLE assistant_history (
        id $idType,
        user_query $textType,
        assistant_response $textType,
        intent $textType,
        timestamp $textType
      )
    ''');

    // App Settings Table
    await db.execute('''
      CREATE TABLE app_settings (
        key $idType,
        value $textType
      )
    ''');

    // Populate Initial Mock/Demo Data for high-fidelity offline usability
    await populateMockData(db);
  }

  Future populateMockData(Database db) async {
    final now = DateTime.now();

    // 1. App Settings
    await db.insert('app_settings', {'key': 'theme', 'value': 'dark'});
    await db.insert('app_settings', {'key': 'language', 'value': 'en'});
    await db.insert('app_settings', {'key': 'speech_rate', 'value': '1.0'});
    await db.insert('app_settings', {'key': 'speech_pitch', 'value': '1.0'});
    await db.insert('app_settings', {'key': 'shake_activation', 'value': 'true'});
    await db.insert('app_settings', {'key': 'wake_word', 'value': 'hey_smart'});
    await db.insert('app_settings', {'key': 'notification_enabled', 'value': 'true'});

    // 2. Contacts
    final mockContacts = [
      {'id': 'c1', 'name': 'Ali Khan', 'phone_number': '+923001234567', 'email': 'ali@gmail.com', 'photo_uri': null, 'created_at': now.toIso8601String()},
      {'id': 'c2', 'name': 'Mom', 'phone_number': '+923129876543', 'email': 'mom@gmail.com', 'photo_uri': null, 'created_at': now.toIso8601String()},
      {'id': 'c3', 'name': 'Ahmed Raza', 'phone_number': '+923335551212', 'email': 'ahmed@yahoo.com', 'photo_uri': null, 'created_at': now.toIso8601String()},
      {'id': 'c4', 'name': 'Sara Ahmed', 'phone_number': '+923014445555', 'email': 'sara@outlook.com', 'photo_uri': null, 'created_at': now.toIso8601String()},
      {'id': 'c5', 'name': 'Ali Raza', 'phone_number': '+923214567890', 'email': 'aliraza@gmail.com', 'photo_uri': null, 'created_at': now.toIso8601String()},
    ];
    for (var contact in mockContacts) {
      await db.insert('contacts', contact);
    }

    // 3. Conversations
    final mockConversations = [
      {'id': 'conv1', 'contact_name': 'Mom', 'contact_phone': '+923129876543', 'last_message': 'Remember to take medicine', 'last_message_time': now.subtract(const Duration(minutes: 10)).toIso8601String()},
      {'id': 'conv2', 'contact_name': 'Ali Khan', 'contact_phone': '+923001234567', 'last_message': 'I am coming to the office', 'last_message_time': now.subtract(const Duration(hours: 1)).toIso8601String()},
    ];
    for (var conv in mockConversations) {
      await db.insert('conversations', conv);
    }

    // 4. Messages
    final mockMessages = [
      {'id': 'm1', 'conversation_id': 'conv1', 'sender_phone': '+923129876543', 'receiver_phone': 'user', 'content': 'Assalamu Alaikum. How are you?', 'is_read': 1, 'created_at': now.subtract(const Duration(minutes: 15)).toIso8601String()},
      {'id': 'm2', 'conversation_id': 'conv1', 'sender_phone': 'user', 'receiver_phone': '+923129876543', 'content': 'Walaikum Assalam, I am fine.', 'is_read': 1, 'created_at': now.subtract(const Duration(minutes: 12)).toIso8601String()},
      {'id': 'm3', 'conversation_id': 'conv1', 'sender_phone': '+923129876543', 'receiver_phone': 'user', 'content': 'Remember to take medicine', 'is_read': 0, 'created_at': now.subtract(const Duration(minutes: 10)).toIso8601String()},
      {'id': 'm4', 'conversation_id': 'conv2', 'sender_phone': '+923001234567', 'receiver_phone': 'user', 'content': 'Are you free today at 5 PM?', 'is_read': 1, 'created_at': now.subtract(const Duration(hours: 2)).toIso8601String()},
      {'id': 'm5', 'conversation_id': 'conv2', 'sender_phone': 'user', 'receiver_phone': '+923001234567', 'content': 'Yes, let me know.', 'is_read': 1, 'created_at': now.subtract(const Duration(hours: 1, minutes: 30)).toIso8601String()},
      {'id': 'm6', 'conversation_id': 'conv2', 'sender_phone': '+923001234567', 'receiver_phone': 'user', 'content': 'I am coming to the office', 'is_read': 0, 'created_at': now.subtract(const Duration(hours: 1)).toIso8601String()},
    ];
    for (var msg in mockMessages) {
      await db.insert('messages', msg);
    }

    // 5. Alarms
    final mockAlarms = [
      {'id': 'a1', 'time': '06:00', 'label': 'Morning Prayer', 'is_enabled': 1, 'repeat_days': 'Mon,Tue,Wed,Thu,Fri,Sat,Sun', 'created_at': now.toIso8601String()},
      {'id': 'a2', 'time': '07:30', 'label': 'Office Alarm', 'is_enabled': 1, 'repeat_days': 'Mon,Tue,Wed,Thu,Fri', 'created_at': now.toIso8601String()},
      {'id': 'a3', 'time': '09:00', 'label': 'Weekend Wakeup', 'is_enabled': 0, 'repeat_days': 'Sat,Sun', 'created_at': now.toIso8601String()},
    ];
    for (var alarm in mockAlarms) {
      await db.insert('alarms', alarm);
    }

    // 6. Reminders
    final mockReminders = [
      {'id': 'r1', 'title': 'Take medicine', 'date_time': DateTime(now.year, now.month, now.day, 21, 0).toIso8601String(), 'category': 'medicine', 'repeat_type': 'daily', 'is_completed': 0, 'created_at': now.toIso8601String()},
      {'id': 'r2', 'title': 'Project Sync Meeting', 'date_time': DateTime(now.year, now.month, now.day + 1, 15, 0).toIso8601String(), 'category': 'meeting', 'repeat_type': 'none', 'is_completed': 0, 'created_at': now.toIso8601String()},
      {'id': 'r3', 'title': 'Water the plants', 'date_time': DateTime(now.year, now.month, now.day, 18, 0).toIso8601String(), 'category': 'generic', 'repeat_type': 'weekly', 'is_completed': 1, 'created_at': now.toIso8601String()},
    ];
    for (var reminder in mockReminders) {
      await db.insert('reminders', reminder);
    }

    // 7. Calendar Events
    final mockEvents = [
      {'id': 'e1', 'title': 'Design Review', 'description': 'Discuss UI/UX revisions for mobile apps.', 'date_time': DateTime(now.year, now.month, now.day, 11, 0).toIso8601String(), 'duration_minutes': 60, 'created_at': now.toIso8601String()},
      {'id': 'e2', 'title': 'Client Demo', 'description': 'Demo voice commands and speech synthesis performance.', 'date_time': DateTime(now.year, now.month, now.day, 17, 0).toIso8601String(), 'duration_minutes': 30, 'created_at': now.toIso8601String()},
      {'id': 'e3', 'title': 'Weekly Coding Sync', 'description': 'Review codebase architectural structure.', 'date_time': DateTime(now.year, now.month, now.day + 1, 10, 0).toIso8601String(), 'duration_minutes': 90, 'created_at': now.toIso8601String()},
    ];
    for (var ev in mockEvents) {
      await db.insert('calendar_events', ev);
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

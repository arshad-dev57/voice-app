import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../database/models.dart';

/// Central wrapper around Firebase Auth and Cloud Firestore.
///
/// Design notes:
/// - SQLite stays the offline source of truth. Firestore is used for cloud
///   auth and opportunistic sync/backup so data follows the user across
///   devices.
/// - Every Firestore call is wrapped in try/catch so the app keeps working
///   offline if the network (or Firebase) is unavailable.
/// - User-scoped data lives under `users/{uid}/<collection>/{docId}` so each
///   account only ever sees its own reminders, alarms, events and messages.
class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  FirebaseService._init();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  /// Creates a new Firebase account and sets the display name.
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    // Store a profile document for the user.
    await _saveUserProfile(cred.user, name: name.trim());
    return cred.user;
  }

  /// Signs an existing user in.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _saveUserProfile(User? user, {required String name}) async {
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).set({
        'name': name,
        'email': user.email,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseService: failed to save profile: $e');
    }
  }

  CollectionReference<Map<String, dynamic>>? _userCollection(String name) {
    final id = uid;
    if (id == null) return null;
    return _db.collection('users').doc(id).collection(name);
  }

  // ---------------------------------------------------------------------------
  // SYNC: REMINDERS
  // ---------------------------------------------------------------------------

  Future<void> syncReminder(Reminder r) async {
    try {
      await _userCollection('reminders')?.doc(r.id).set(r.toMap());
    } catch (e) {
      debugPrint('FirebaseService: syncReminder failed: $e');
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _userCollection('reminders')?.doc(id).delete();
    } catch (e) {
      debugPrint('FirebaseService: deleteReminder failed: $e');
    }
  }

  Future<List<Reminder>> fetchReminders() async {
    try {
      final snap = await _userCollection('reminders')?.get();
      if (snap == null) return [];
      return snap.docs.map((d) => Reminder.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('FirebaseService: fetchReminders failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC: ALARMS
  // ---------------------------------------------------------------------------

  Future<void> syncAlarm(Alarm a) async {
    try {
      await _userCollection('alarms')?.doc(a.id).set(a.toMap());
    } catch (e) {
      debugPrint('FirebaseService: syncAlarm failed: $e');
    }
  }

  Future<void> deleteAlarm(String id) async {
    try {
      await _userCollection('alarms')?.doc(id).delete();
    } catch (e) {
      debugPrint('FirebaseService: deleteAlarm failed: $e');
    }
  }

  Future<List<Alarm>> fetchAlarms() async {
    try {
      final snap = await _userCollection('alarms')?.get();
      if (snap == null) return [];
      return snap.docs.map((d) => Alarm.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('FirebaseService: fetchAlarms failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC: CALENDAR EVENTS
  // ---------------------------------------------------------------------------

  Future<void> syncEvent(CalendarEvent e) async {
    try {
      await _userCollection('calendar_events')?.doc(e.id).set(e.toMap());
    } catch (err) {
      debugPrint('FirebaseService: syncEvent failed: $err');
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _userCollection('calendar_events')?.doc(id).delete();
    } catch (e) {
      debugPrint('FirebaseService: deleteEvent failed: $e');
    }
  }

  Future<List<CalendarEvent>> fetchEvents() async {
    try {
      final snap = await _userCollection('calendar_events')?.get();
      if (snap == null) return [];
      return snap.docs.map((d) => CalendarEvent.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('FirebaseService: fetchEvents failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC: MESSAGES
  // ---------------------------------------------------------------------------

  Future<void> syncMessage(Message m) async {
    try {
      await _userCollection('messages')?.doc(m.id).set(m.toMap());
    } catch (e) {
      debugPrint('FirebaseService: syncMessage failed: $e');
    }
  }
}

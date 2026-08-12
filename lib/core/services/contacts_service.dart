import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../database/local_repository.dart';
import '../database/models.dart';

/// Reads the phone's real contacts and imports them into the local SQLite DB.
///
/// The assistant ("call Uzair") and the Contacts screen both query the local
/// `contacts` table via [LocalRepository]. Previously that table only held 5
/// hard-coded demo contacts, so any real contact (like Uzair) was "not found".
/// This service bridges the device address book into that table.
class ContactsService {
  static final ContactsService instance = ContactsService._init();
  ContactsService._init();

  /// Requests the READ_CONTACTS permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      debugPrint('ContactsService: Contacts permission permanently denied, user needs to enable in settings');
      return false;
    }
    final result = await Permission.contacts.request();
    if (result.isPermanentlyDenied) {
      debugPrint('ContactsService: Contacts permission permanently denied after request');
      return false;
    }
    return result.isGranted;
  }

  /// Reads all device contacts and upserts them into the local `contacts`
  /// table so the assistant and UI can find them.
  ///
  /// Returns the number of contacts imported, or -1 if permission was denied.
  Future<int> importDeviceContacts(LocalRepository repo) async {
    try {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('ContactsService: contacts permission denied.');
        return -1;
      }

      // Fetch contacts with phone numbers.
      final deviceContacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
      );

      debugPrint('ContactsService: found ${deviceContacts.length} total device contacts');

      int imported = 0;
      for (final c in deviceContacts) {
        if (c.phones.isEmpty) continue;
        final phone = c.phones.first.number.trim();
        final name = c.displayName.trim();
        if (name.isEmpty || phone.isEmpty) continue;

        debugPrint('ContactsService: importing contact - name: "$name", phone: "$phone"');

        final contact = Contact(
          // Stable id based on device contact id so re-imports update, not duplicate.
          id: 'device_${c.id}',
          name: name,
          phoneNumber: phone,
          email: c.emails.isNotEmpty ? c.emails.first.address : null,
          createdAt: DateTime.now(),
        );
        await repo.insertContact(contact);
        imported++;
      }

      debugPrint('ContactsService: successfully imported $imported device contacts.');
      return imported;
    } catch (e) {
      debugPrint('ContactsService: import failed: $e');
      return 0;
    }
  }

  /// Live search against the device address book (not just the local cache).
  Future<List<Contact>> searchDeviceLive(String query) async {
    try {
      final granted = await requestPermission();
      if (!granted) return [];

      final deviceContacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
      );
      final q = query.toLowerCase().trim();
      if (q.isEmpty) return [];

      final matches = <Contact>[];
      for (final c in deviceContacts) {
        if (c.phones.isEmpty) continue;
        final name = c.displayName.trim();
        if (name.isEmpty) continue;
        if (name.toLowerCase().contains(q) ||
            q.contains(name.toLowerCase().split(' ').first)) {
          matches.add(
            Contact(
              id: 'device_${c.id}',
              name: name,
              phoneNumber: c.phones.first.number.trim(),
              email: c.emails.isNotEmpty ? c.emails.first.address : null,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      return matches;
    } catch (e) {
      debugPrint('ContactsService: live search failed: $e');
      return [];
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../routing/app_router.dart';
import '../../../../theme/app_theme.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<Contact> _contacts = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initContacts();
  }

  /// On first open, import the phone's real contacts into the local DB, then
  /// show them. This is what makes "call Uzair" work for real contacts.
  Future<void> _initContacts() async {
    await _syncDeviceContacts(showFeedback: false);
    await _loadContacts();
  }

  Future<void> _syncDeviceContacts({bool showFeedback = true}) async {
    setState(() => _isSyncing = true);
    final service = ref.read(contactsServiceProvider);
    final repo = ref.read(localRepositoryProvider);
    final count = await service.importDeviceContacts(repo);
    setState(() => _isSyncing = false);

    if (!mounted) return;
    if (showFeedback) {
      final msg = count < 0
          ? 'Contacts permission denied. Enable it in Settings to sync.'
          : 'Synced $count contacts from your phone.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    await _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final repo = ref.read(localRepositoryProvider);
    final list = _searchController.text.trim().isEmpty
        ? await repo.getContacts()
        : await repo.searchContacts(_searchController.text);
    setState(() {
      _contacts = list;
      _isLoading = false;
    });
  }

  Future<void> _addNewContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    final repo = ref.read(localRepositoryProvider);
    final contact = Contact(
      id: const Uuid().v4(),
      name: name,
      phoneNumber: phone,
      createdAt: DateTime.now(),
    );

    await repo.insertContact(contact);
    _nameController.clear();
    _phoneController.clear();
    Navigator.pop(context);
    _loadContacts();
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _addNewContact,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Sync phone contacts',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _isSyncing ? null : () => _syncDeviceContacts(),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddContactDialog,
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkBg, const Color(0xFF141923)]
                : [AppTheme.lightBg, const Color(0xFFE6EDF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
              ),
              onChanged: (_) => _loadContacts(),
            ),
            const SizedBox(height: 20),

            // Contacts List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No contacts found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return Card(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              child: Text(
                                contact.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(contact.phoneNumber),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    color: AppTheme.success,
                                  ),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRouter.callManagement,
                                      arguments: {
                                        'contactName': contact.name,
                                        'phoneNumber': contact.phoneNumber,
                                        'incoming': false,
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.message_rounded,
                                    color: AppTheme.accent,
                                  ),
                                  tooltip: 'Open phone Messages',
                                  onPressed: () {
                                    ref.read(phoneServiceProvider).openSystemMessages(
                                          phoneNumber: contact.phoneNumber,
                                        );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

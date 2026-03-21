import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../models/emergency_contact.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supabase = ref.read(supabaseServiceProvider);
    final contacts = await supabase.fetchEmergencyContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Emergency contacts',
      subtitle: 'Add up to three people Cura should call if you need urgent support.',
      actions: [
        if (_contacts.length < 3)
          GlassIconButton(
            icon: Icons.add_rounded,
            onTap: _addContact,
          ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _contacts.isEmpty
              ? _EmptyState(onAdd: _addContact)
              : Column(
                  children: _contacts
                      .map(
                        (contact) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ContactCard(
                            contact: contact,
                            onDelete: () => _delete(contact),
                          ),
                        ),
                      )
                      .toList(),
                ),
    );
  }

  Future<void> _addContact() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (result == null) return;

    final supabase = ref.read(supabaseServiceProvider);
    final uid = supabase.currentUserId ?? 'demo';
    final contact = EmergencyContact(
      id: const Uuid().v4(),
      userId: uid,
      name: result['name']!,
      phoneNumber: result['phone']!,
      priority: _contacts.length + 1,
    );

    await supabase.upsertEmergencyContact(contact);
    await _load();
  }

  Future<void> _delete(EmergencyContact contact) async {
    final supabase = ref.read(supabaseServiceProvider);
    await supabase.deleteEmergencyContact(contact.id);
    await _load();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contacts_rounded,
            size: 52,
            color: AppColors.muted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 3 people Cura will call if you need help.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.hint(context),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add contact'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onDelete;

  const _ContactCard({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder(context)),
              color: AppColors.glassSecondaryFill(context),
            ),
            child: Center(
              child: Text(
                contact.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phoneNumber,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.hint(context),
                  ),
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.delete_outline_rounded,
            color: AppColors.sos(context),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add emergency contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+447700900000',
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: Size.zero),
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty ||
                _phoneCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop({
              'name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

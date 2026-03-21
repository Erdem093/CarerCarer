import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../models/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gpNameCtrl = TextEditingController();
  final _gpSurgeryCtrl = TextEditingController();

  bool _saving = false;
  bool _calendarGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gpNameCtrl.dispose();
    _gpSurgeryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile != null) _populate(profile);
    final granted = await ref.read(calendarServiceProvider).hasPermission();
    if (mounted) {
      setState(() => _calendarGranted = granted);
    }
  }

  void _populate(UserProfile profile) {
    _nameCtrl.text = profile.displayName;
    _phoneCtrl.text = profile.mobileNumber ?? '';
    _gpNameCtrl.text = profile.gpName ?? '';
    _gpSurgeryCtrl.text = profile.gpSurgery ?? '';
    setState(() => _calendarGranted = profile.calendarAccessGranted);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Profile',
      subtitle: 'Personal details, safety contacts, scheduling, and how Cura speaks to you.',
      showBackButton: false,
      actions: [
        _HeaderActionButton(
          label: _saving ? '...' : 'Save',
          onTap: _saving ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Personal'),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              children: [
                _Field(
                  label: 'Your name',
                  controller: _nameCtrl,
                  hint: 'e.g. Margaret',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Mobile number (for calls)',
                  controller: _phoneCtrl,
                  hint: '+447700900000',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _Field(
                  label: "GP's name",
                  controller: _gpNameCtrl,
                  hint: 'e.g. Dr. Smith',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'GP surgery',
                  controller: _gpSurgeryCtrl,
                  hint: 'e.g. Highgate Medical Centre',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionLabel('Emergency & Schedule'),
          const SizedBox(height: 12),
          _NavTile(
            icon: Icons.contacts_rounded,
            title: 'Emergency contacts',
            subtitle: 'Up to 3 people Cura can call',
            onTap: () => context.push('/profile/emergency-contacts'),
          ),
          const SizedBox(height: 12),
          _NavTile(
            icon: Icons.schedule_rounded,
            title: 'Call schedule',
            subtitle: 'Set times for Cura to ring you',
            onTap: () => context.push('/profile/schedule'),
          ),
          const SizedBox(height: 28),
          const AppSectionLabel('Calendar'),
          const SizedBox(height: 12),
          GlassPanel(
            child: Row(
              children: [
                _IconBadge(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allow calendar access',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cura reads upcoming events to give you accurate check-ins.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: AppColors.hint(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _calendarGranted,
                  onChanged: _toggleCalendar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionLabel('Voice'),
          const SizedBox(height: 12),
          const _VoicePicker(),
        ],
      ),
    );
  }

  Future<void> _toggleCalendar(bool value) async {
    if (value) {
      final calendar = ref.read(calendarServiceProvider);
      final granted = await calendar.requestPermission();
      setState(() => _calendarGranted = granted);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar access was not granted. You can enable it from Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    } else {
      setState(() => _calendarGranted = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'To fully revoke calendar access on iPhone, use the Settings app.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final uid = supabase.currentUserId ?? 'demo';
      final existing = await ref.read(userProfileProvider.future);
      final profile = UserProfile(
        id: uid,
        displayName: _nameCtrl.text.trim(),
        mobileNumber:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        gpName: _gpNameCtrl.text.trim().isEmpty ? null : _gpNameCtrl.text.trim(),
        gpSurgery: _gpSurgeryCtrl.text.trim().isEmpty
            ? null
            : _gpSurgeryCtrl.text.trim(),
        calendarAccessGranted: _calendarGranted,
        morningCallTime: existing?.morningCallTime ?? '09:00',
        afternoonCallTime: existing?.afternoonCallTime ?? '14:00',
        eveningCallTime: existing?.eveningCallTime ?? '21:00',
        callsEnabled: existing?.callsEnabled ?? true,
      );
      await supabase.upsertProfile(profile);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HeaderActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      width: 72,
      height: 48,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.label(context),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.label(context), fontSize: 16),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      child: Row(
        children: [
          _IconBadge(icon: icon, color: AppColors.label(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.hint(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.muted(context),
          ),
        ],
      ),
    );
  }
}

class _VoicePicker extends ConsumerWidget {
  const _VoicePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(preferredVoiceProvider);
    // Guard against stale stored id that no longer exists in voiceOptions
    final selected = voiceOptions.firstWhere(
      (v) => v.id == raw.id,
      orElse: () => voiceOptions.first,
    );

    return GlassPanel(
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.record_voice_over_rounded,
            color: AppColors.label(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Cura's voice",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<VoiceOption>(
              dropdownColor: AppColors.card(context),
              value: selected,
              borderRadius: BorderRadius.circular(18),
              items: voiceOptions
                  .map(
                    (voice) => DropdownMenuItem(
                      value: voice,
                      child: Text(
                        voice.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.label(context),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (voice) {
                if (voice != null) {
                  ref.read(preferredVoiceProvider.notifier).setVoice(voice);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder(context)),
        color: AppColors.glassSecondaryFill(context),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

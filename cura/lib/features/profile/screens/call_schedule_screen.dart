import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../services/check_in_debug_service.dart';
import '../../../services/claude_service.dart';

class CallScheduleScreen extends ConsumerStatefulWidget {
  const CallScheduleScreen({super.key});

  @override
  ConsumerState<CallScheduleScreen> createState() => _CallScheduleScreenState();
}

class _CallScheduleScreenState extends ConsumerState<CallScheduleScreen> {
  TimeOfDay _morningTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _afternoonTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 21, minute: 0);
  bool _callsEnabled = true;
  bool _saving = false;
  bool _runningDebugCall = false;
  List<CheckInDebugEntry> _debugEntries = const [];
  final TextEditingController _backendUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _backendUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ref.read(userProfileProvider.future);
    await _loadDebugEntries();
    final backendOverride =
        await ref.read(checkInDebugServiceProvider).loadBackendUrlOverride();
    _backendUrlCtrl.text =
        backendOverride ?? ref.read(twilioServiceProvider).backendUrl;
    if (profile == null || !mounted) return;
    setState(() {
      _callsEnabled = profile.callsEnabled;
      _morningTime = _parseTime(profile.morningCallTime);
      _afternoonTime = _parseTime(profile.afternoonCallTime);
      _eveningTime = _parseTime(profile.eveningCallTime);
    });
  }

  Future<void> _loadDebugEntries() async {
    final entries = await ref.read(checkInDebugServiceProvider).loadEntries();
    if (!mounted) return;
    setState(() => _debugEntries = entries);
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Call schedule',
      subtitle: 'Choose when Cura should ring you, and use the debug tools to confirm the phone flow is reachable.',
      actions: [
        _ScheduleHeaderAction(
          label: _saving ? '...' : 'Save',
          onTap: _saving ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            child: Row(
              children: [
                const _ScheduleIconBadge(
                  icon: Icons.call_outlined,
                  accent: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable calls',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cura will ring your mobile at the times below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.hint(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _callsEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (value) => setState(() => _callsEnabled = value),
                ),
              ],
            ),
          ),
          if (_callsEnabled) ...[
            const SizedBox(height: 24),
            const AppSectionLabel('Call Times'),
            const SizedBox(height: 12),
            _TimeTile(
              icon: Icons.wb_sunny_outlined,
              label: 'Morning check-in',
              time: _morningTime,
              onTap: () async {
                final picked = await _pick(_morningTime);
                if (picked != null) setState(() => _morningTime = picked);
              },
            ),
            const SizedBox(height: 12),
            _TimeTile(
              icon: Icons.wb_twilight,
              label: 'Afternoon check-in',
              time: _afternoonTime,
              onTap: () async {
                final picked = await _pick(_afternoonTime);
                if (picked != null) setState(() => _afternoonTime = picked);
              },
            ),
            const SizedBox(height: 12),
            _TimeTile(
              icon: Icons.nights_stay_outlined,
              label: 'Evening check-in',
              time: _eveningTime,
              onTap: () async {
                final picked = await _pick(_eveningTime);
                if (picked != null) setState(() => _eveningTime = picked);
              },
            ),
          ],
          const SizedBox(height: 24),
          _DebugPanel(
            nextRuns: _buildNextRuns(),
            entries: _debugEntries,
            running: _runningDebugCall,
            backendUrlController: _backendUrlCtrl,
            onTrigger: _runDebugCheckIn,
          ),
        ],
      ),
    );
  }

  Future<TimeOfDay?> _pick(TimeOfDay initial) async {
    return showTimePicker(context: context, initialTime: initial);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final profile = await ref.read(userProfileProvider.future);
      if (profile == null) return;
      await supabase.upsertProfile(profile.copyWith(
        callsEnabled: _callsEnabled,
        morningCallTime: _formatTime(_morningTime),
        afternoonCallTime: _formatTime(_afternoonTime),
        eveningCallTime: _formatTime(_eveningTime),
      ));
      ref.invalidate(userProfileProvider);
      await ref.read(userProfileProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule saved!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runDebugCheckIn(ConversationContext conversationContext) async {
    setState(() => _runningDebugCall = true);
    final debugService = ref.read(checkInDebugServiceProvider);
    final backendUrl = _backendUrlCtrl.text.trim();

    try {
      if (backendUrl.isNotEmpty) {
        ref.read(twilioServiceProvider).setBackendUrl(backendUrl);
        await debugService.saveBackendUrlOverride(backendUrl);
      }

      final backendHealthy = await ref.read(twilioServiceProvider).pingHealth();
      if (!backendHealthy) {
        await debugService.addEntry(
          CheckInDebugEntry(
            context: conversationContext.name,
            timestamp: DateTime.now(),
            success: false,
            detail:
                'Backend health check failed. On a phone, use your Mac IP or public URL instead of localhost.',
          ),
        );
        await _loadDebugEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backend unreachable. Use your Mac IP like http://192.168.x.x:3000 or a public URL.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final profile = await ref.read(userProfileProvider.future);
      if (profile == null || (profile.mobileNumber?.trim().isEmpty ?? true)) {
        await debugService.addEntry(
          CheckInDebugEntry(
            context: conversationContext.name,
            timestamp: DateTime.now(),
            success: false,
            detail: 'Missing mobile number on the profile.',
          ),
        );
      } else {
        final ok = await ref.read(twilioServiceProvider).initiateCheckInCall(
              toPhoneNumber: profile.mobileNumber!,
              userId: profile.id,
              context: conversationContext,
            );
        await debugService.addEntry(
          CheckInDebugEntry(
            context: conversationContext.name,
            timestamp: DateTime.now(),
            success: ok,
            detail: ok
                ? 'Check-in request accepted by the backend.'
                : 'Backend check-in request failed.',
          ),
        );
      }

      await _loadDebugEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _debugEntries.isNotEmpty
                  ? _debugEntries.first.detail
                  : 'Debug check-in completed.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _runningDebugCall = false);
      }
    }
  }

  List<String> _buildNextRuns() {
    if (!_callsEnabled) return const ['Calls are currently disabled.'];
    final now = DateTime.now();
    final times = <String, TimeOfDay>{
      'Morning': _morningTime,
      'Afternoon': _afternoonTime,
      'Evening': _eveningTime,
    };

    return times.entries.map((entry) {
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        entry.value.hour,
        entry.value.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return '${entry.key}: ${DateFormat('EEE d MMM, HH:mm').format(scheduled)}';
    }).toList();
  }
}

class _ScheduleHeaderAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ScheduleHeaderAction({
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

class _TimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      child: Row(
        children: [
          _ScheduleIconBadge(icon: icon, accent: AppColors.label(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
          ),
          Text(
            time.format(context),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final List<String> nextRuns;
  final List<CheckInDebugEntry> entries;
  final bool running;
  final TextEditingController backendUrlController;
  final Future<void> Function(ConversationContext context) onTrigger;

  const _DebugPanel({
    required this.nextRuns,
    required this.entries,
    required this.running,
    required this.backendUrlController,
    required this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug tools',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm what is saved and manually trigger a test check-in request.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.hint(context),
            ),
          ),
          const SizedBox(height: 16),
          ...nextRuns.map(
            (run) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                run,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.label(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: backendUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'http://192.168.x.x:3000',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For a real iPhone, localhost points to the phone itself. Use your Mac IP or a public tunnel URL.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.hint(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DebugButton(
                label: 'Test morning',
                running: running,
                onTap: () => onTrigger(ConversationContext.morning),
              ),
              _DebugButton(
                label: 'Test afternoon',
                running: running,
                onTap: () => onTrigger(ConversationContext.afternoon),
              ),
              _DebugButton(
                label: 'Test evening',
                running: running,
                onTap: () => onTrigger(ConversationContext.evening),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const AppSectionLabel('Recent Debug Attempts'),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'No debug check-ins yet.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.hint(context),
              ),
            )
          else
            ...entries.take(5).map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${DateFormat('d MMM HH:mm').format(entry.timestamp)} • ${entry.context} • ${entry.success ? 'OK' : 'Failed'}\n${entry.detail}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.label(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final bool running;
  final VoidCallback onTap;

  const _DebugButton({
    required this.label,
    required this.running,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: running ? null : onTap,
      child: Text(label),
    );
  }
}

class _ScheduleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _ScheduleIconBadge({
    required this.icon,
    required this.accent,
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
      child: Icon(icon, color: accent, size: 24),
    );
  }
}

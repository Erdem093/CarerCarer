import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';
import '../models/emergency_contact.dart';
import 'supabase_service.dart';

class EmergencyService {
  final SupabaseService _supabase;
  final Logger _log = Logger();

  EmergencyService(this._supabase);

  // ─── Crisis Detection ─────────────────────────────────────────────────────

  bool detectCrisis(String text) {
    final lower = text.toLowerCase();
    return AppConstants.crisisKeywords.any((kw) => lower.contains(kw));
  }

  // ─── Level 1: In-App Check ────────────────────────────────────────────────

  /// Shows the Level 1 emergency overlay.
  /// Returns true if user confirmed they are OK, false if escalation needed.
  Future<bool> showLevel1Check(BuildContext context) async {
    bool userIsOk = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _EmergencyLevel1Dialog(
          onOk: () {
            userIsOk = true;
            Navigator.of(ctx).pop();
          },
          onHelp: () {
            userIsOk = false;
            Navigator.of(ctx).pop();
          },
        );
      },
    );

    return userIsOk;
  }

  // ─── Level 2: Call Emergency Contact ─────────────────────────────────────

  /// Initiates Twilio outbound call to the emergency contact via backend.
  Future<void> callEmergencyContact({
    required EmergencyContact contact,
    required String userName,
    String? sessionId,
  }) async {
    try {
      final dio = Dio();
      await dio.post(
        '${AppConfig.backendUrl}/emergency-call',
        data: {
          'to': contact.phoneNumber,
          'userName': userName,
          'contactName': contact.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      await _supabase.logEmergencyEvent(
        triggerType: 'keyword',
        levelReached: 2,
        contactCalled: true,
        sessionId: sessionId,
      );

      _log.i('Emergency call initiated to ${contact.name}');
    } catch (e) {
      _log.e('Emergency call failed: $e');
      // Try SMS fallback via phone dialer
      await _launchPhone(contact.phoneNumber);
    }
  }

  // ─── Level 3: Call 999 ────────────────────────────────────────────────────

  /// Opens the native phone dialer with 999 pre-filled.
  Future<void> call999() async {
    await _launchPhone('999');
    await _supabase.logEmergencyEvent(
      triggerType: 'manual',
      levelReached: 3,
      call999: true,
    );
  }

  // ─── Full Escalation Flow ─────────────────────────────────────────────────

  /// Runs the full tiered emergency escalation.
  Future<void> initiateEscalation(
    BuildContext context, {
    required String triggerText,
    required String userName,
    String? sessionId,
  }) async {
    _log.w('Emergency escalation triggered: $triggerText');

    await _supabase.logEmergencyEvent(
      triggerType: 'keyword',
      triggerText: triggerText,
      levelReached: 1,
      sessionId: sessionId,
    );

    // Level 1
    final userIsOk = await showLevel1Check(context);
    if (userIsOk) return;

    // Level 2: call emergency contact
    final contacts = await _supabase.fetchEmergencyContacts();
    if (contacts.isNotEmpty) {
      await callEmergencyContact(
        contact: contacts.first,
        userName: userName,
        sessionId: sessionId,
      );
    }

    // Show Level 3 option
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _EmergencyLevel3Dialog(
          onCall999: () {
            Navigator.of(ctx).pop();
            call999();
          },
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ─── Level 1 Dialog Widget ────────────────────────────────────────────────

class _EmergencyLevel1Dialog extends StatefulWidget {
  final VoidCallback onOk;
  final VoidCallback onHelp;

  const _EmergencyLevel1Dialog({required this.onOk, required this.onHelp});

  @override
  State<_EmergencyLevel1Dialog> createState() => _EmergencyLevel1DialogState();
}

class _EmergencyLevel1DialogState extends State<_EmergencyLevel1Dialog> {
  int _secondsLeft = 10;
  late final Stream<int> _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = Stream.periodic(const Duration(seconds: 1), (i) => 9 - i)
        .take(10);
    _countdown.listen(
      (s) => setState(() => _secondsLeft = s),
      onDone: widget.onHelp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFE53935),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Are you okay?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Calling for help in $_secondsLeft seconds...',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              onPressed: widget.onOk,
              child: const Text("I'm okay — continue"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              onPressed: widget.onHelp,
              child: const Text('I need help'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Level 3 Dialog Widget ────────────────────────────────────────────────

class _EmergencyLevel3Dialog extends StatelessWidget {
  final VoidCallback onCall999;
  final VoidCallback onDismiss;

  const _EmergencyLevel3Dialog({
    required this.onCall999,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_hospital, color: Color(0xFFE53935), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Do you need an ambulance?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your emergency contact has been called.\nCall 999 if you need an ambulance.',
              style: TextStyle(fontSize: 16, color: Color(0xFF6C6C70)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
              onPressed: onCall999,
              child: const Text('📞  CALL 999'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDismiss,
              child: const Text(
                'No, I\'m okay now',
                style: TextStyle(fontSize: 16, color: Color(0xFF6C6C70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

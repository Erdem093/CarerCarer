import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/check_in_session.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/emergency_contact.dart';

class SupabaseService {
  static const _localProfileKey = 'local_user_profile';
  static const localProfileId = '00000000-0000-0000-0000-000000000001';

  final SupabaseClient _client;
  final Logger _log = Logger();

  SupabaseService(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  // ─── User Profile ────────────────────────────────────────────────────────

  Future<UserProfile?> fetchProfile() async {
    final uid = currentUserId;
    if (uid == null) {
      return _fetchLocalProfile();
    }
    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data != null) {
        final profile = UserProfile.fromJson(data);
        await _cacheLocalProfile(profile);
        return profile;
      }
      return _fetchLocalProfile();
    } catch (e) {
      _log.e('fetchProfile error: $e');
      return _fetchLocalProfile();
    }
  }

  Future<void> upsertProfile(UserProfile profile) async {
    try {
      final uid = currentUserId;
      final effectiveProfile = uid == null
          ? UserProfile(
              id: localProfileId,
              displayName: profile.displayName,
              mobileNumber: profile.mobileNumber,
              gpName: profile.gpName,
              gpSurgery: profile.gpSurgery,
              timezone: profile.timezone,
              morningCallTime: profile.morningCallTime,
              afternoonCallTime: profile.afternoonCallTime,
              eveningCallTime: profile.eveningCallTime,
              callsEnabled: profile.callsEnabled,
              calendarAccessGranted: profile.calendarAccessGranted,
            )
          : UserProfile(
              id: uid,
              displayName: profile.displayName,
              mobileNumber: profile.mobileNumber,
              gpName: profile.gpName,
              gpSurgery: profile.gpSurgery,
              timezone: profile.timezone,
              morningCallTime: profile.morningCallTime,
              afternoonCallTime: profile.afternoonCallTime,
              eveningCallTime: profile.eveningCallTime,
              callsEnabled: profile.callsEnabled,
              calendarAccessGranted: profile.calendarAccessGranted,
            );

      await _cacheLocalProfile(effectiveProfile);

      if (uid == null) {
        return;
      }

      await _client.from('user_profiles').upsert({
        'id': effectiveProfile.id,
        ...effectiveProfile.toJson(),
      });
    } catch (e) {
      _log.e('upsertProfile error: $e');
      rethrow;
    }
  }

  Future<UserProfile?> _fetchLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localProfileKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheLocalProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localProfileKey,
      jsonEncode({
        'id': profile.id,
        ...profile.toJson(),
      }),
    );
  }

  // ─── Emergency Contacts ──────────────────────────────────────────────────

  Future<List<EmergencyContact>> fetchEmergencyContacts() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('emergency_contacts')
          .select()
          .eq('user_id', uid)
          .order('priority');
      return (data as List).map((d) => EmergencyContact.fromJson(d)).toList();
    } catch (e) {
      _log.e('fetchEmergencyContacts error: $e');
      return [];
    }
  }

  Future<void> upsertEmergencyContact(EmergencyContact contact) async {
    try {
      await _client.from('emergency_contacts').upsert(contact.toJson());
    } catch (e) {
      _log.e('upsertEmergencyContact error: $e');
      rethrow;
    }
  }

  Future<void> deleteEmergencyContact(String id) async {
    try {
      await _client.from('emergency_contacts').delete().eq('id', id);
    } catch (e) {
      _log.e('deleteEmergencyContact error: $e');
      rethrow;
    }
  }

  // ─── Check-in Sessions ───────────────────────────────────────────────────

  Future<String?> createSession(CheckInSession session) async {
    try {
      final data = await _client.from('check_in_sessions').insert({
        'user_id': session.userId,
        'context': session.context.name,
        'mode': session.mode == SessionMode.phoneCall ? 'phone_call' : 'in_app',
        'twilio_call_sid': session.twilioCallSid,
        'started_at': session.startedAt.toIso8601String(),
        'transcript': [],
        'crisis_flagged': false,
      }).select('id').single();
      return (data as Map<String, dynamic>)['id'] as String?;
    } catch (e) {
      _log.e('createSession error: $e');
      return null;
    }
  }

  Future<void> finalizeSession({
    required String sessionId,
    required List<Map<String, dynamic>> transcript,
    required DateTime endedAt,
    int? sleepScore,
    int? painScore,
    int? moodScore,
    String? painLocation,
    required bool crisisFlagged,
  }) async {
    try {
      final durationSeconds = endedAt
          .difference(DateTime.now().subtract(const Duration(seconds: 1)))
          .inSeconds
          .abs();
      await _client.from('check_in_sessions').update({
        'transcript': transcript,
        'ended_at': endedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'sleep_score': sleepScore,
        'pain_score': painScore,
        'mood_score': moodScore,
        'pain_location': painLocation,
        'crisis_flagged': crisisFlagged,
      }).eq('id', sessionId);
    } catch (e) {
      _log.e('finalizeSession error: $e');
      rethrow;
    }
  }

  Future<List<CheckInSession>> fetchRecentSessions({int limit = 20}) async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('check_in_sessions')
          .select()
          .eq('user_id', uid)
          .order('started_at', ascending: false)
          .limit(limit);
      return (data as List).map((d) => CheckInSession.fromJson(d)).toList();
    } catch (e) {
      _log.e('fetchRecentSessions error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyMetrics() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    try {
      final data = await _client
          .from('check_in_sessions')
          .select('started_at, sleep_score, pain_score, mood_score')
          .eq('user_id', uid)
          .gte('started_at', sevenDaysAgo.toIso8601String())
          .order('started_at');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      _log.e('fetchWeeklyMetrics error: $e');
      return [];
    }
  }

  // ─── Medications ─────────────────────────────────────────────────────────

  Future<void> saveMedication(Medication med) async {
    try {
      await _client.from('medications').insert(med.toJson());
    } catch (e) {
      _log.e('saveMedication error: $e');
      rethrow;
    }
  }

  Future<List<Medication>> fetchActiveMedications() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('medications')
          .select()
          .eq('user_id', uid)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return (data as List<dynamic>).map((d) => Medication.fromJson(d as Map<String, dynamic>)).toList();
    } catch (e) {
      _log.e('fetchActiveMedications error: $e');
      return [];
    }
  }

  // ─── Appointments ────────────────────────────────────────────────────────

  Future<void> saveAppointment(Appointment appt) async {
    try {
      await _client.from('appointments').insert(appt.toJson());
    } catch (e) {
      _log.e('saveAppointment error: $e');
      rethrow;
    }
  }

  Future<List<Appointment>> fetchUpcomingAppointments() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('appointments')
          .select()
          .eq('user_id', uid)
          .gte('appointment_date', DateTime.now().toIso8601String().substring(0, 10))
          .order('appointment_date')
          .limit(10);
      return (data as List).map((d) => Appointment.fromJson(d)).toList();
    } catch (e) {
      _log.e('fetchUpcomingAppointments error: $e');
      return [];
    }
  }

  // ─── Emergency Events ────────────────────────────────────────────────────

  Future<void> logEmergencyEvent({
    required String triggerType,
    String? triggerText,
    required int levelReached,
    bool contactCalled = false,
    bool smsSent = false,
    bool call999 = false,
    String? sessionId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.from('emergency_events').insert({
        'user_id': uid,
        'trigger_type': triggerType,
        'trigger_text': triggerText,
        'level_reached': levelReached,
        'emergency_contact_called': contactCalled,
        'sms_sent': smsSent,
        'call_999_initiated': call999,
        'session_id': sessionId,
      });
    } catch (e) {
      _log.e('logEmergencyEvent error: $e');
    }
  }
}

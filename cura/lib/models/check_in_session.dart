import 'conversation_message.dart';

enum SessionContext { morning, afternoon, evening, adhoc }
enum SessionMode { inApp, phoneCall }

class CheckInSession {
  final String id;
  final String userId;
  final SessionContext context;
  final SessionMode mode;
  final String? twilioCallSid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final List<ConversationMessage> transcript;
  final int? sleepScore;
  final int? painScore;
  final int? moodScore;
  final String? painLocation;
  final bool crisisFlagged;

  const CheckInSession({
    required this.id,
    required this.userId,
    required this.context,
    this.mode = SessionMode.inApp,
    this.twilioCallSid,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.transcript = const [],
    this.sleepScore,
    this.painScore,
    this.moodScore,
    this.painLocation,
    this.crisisFlagged = false,
  });

  String get contextLabel {
    switch (context) {
      case SessionContext.morning: return 'Morning check-in';
      case SessionContext.afternoon: return 'Afternoon check-in';
      case SessionContext.evening: return 'Evening check-in';
      case SessionContext.adhoc: return 'Chat with Cura';
    }
  }

  factory CheckInSession.fromJson(Map<String, dynamic> json) {
    final transcriptList = (json['transcript'] as List<dynamic>?) ?? [];
    return CheckInSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      context: _parseContext(json['context'] as String),
      mode: json['mode'] == 'phone_call' ? SessionMode.phoneCall : SessionMode.inApp,
      twilioCallSid: json['twilio_call_sid'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      durationSeconds: json['duration_seconds'] as int?,
      transcript: transcriptList
          .map((m) => ConversationMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      sleepScore: json['sleep_score'] as int?,
      painScore: json['pain_score'] as int?,
      moodScore: json['mood_score'] as int?,
      painLocation: json['pain_location'] as String?,
      crisisFlagged: json['crisis_flagged'] as bool? ?? false,
    );
  }

  static SessionContext _parseContext(String s) {
    switch (s) {
      case 'morning': return SessionContext.morning;
      case 'afternoon': return SessionContext.afternoon;
      case 'evening': return SessionContext.evening;
      default: return SessionContext.adhoc;
    }
  }
}

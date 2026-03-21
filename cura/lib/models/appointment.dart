class Appointment {
  final String id;
  final String userId;
  final String title;
  final String? provider;
  final DateTime? appointmentDateTime;
  final String? location;
  final String? deviceCalendarEventId;
  final String? sourceSessionId;
  final String? notes;
  final DateTime createdAt;

  const Appointment({
    required this.id,
    required this.userId,
    required this.title,
    this.provider,
    this.appointmentDateTime,
    this.location,
    this.deviceCalendarEventId,
    this.sourceSessionId,
    this.notes,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['appointment_date'] != null) {
      final date = json['appointment_date'] as String;
      final time = json['appointment_time'] as String? ?? '00:00';
      dt = DateTime.parse('${date}T$time');
    }
    return Appointment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      provider: json['provider'] as String?,
      appointmentDateTime: dt,
      location: json['location'] as String?,
      deviceCalendarEventId: json['device_calendar_event_id'] as String?,
      sourceSessionId: json['source_session_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'provider': provider,
        'appointment_date': appointmentDateTime?.toIso8601String().substring(0, 10),
        'appointment_time': appointmentDateTime != null
            ? '${appointmentDateTime!.hour.toString().padLeft(2, '0')}:${appointmentDateTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'location': location,
        'device_calendar_event_id': deviceCalendarEventId,
        'source_session_id': sourceSessionId,
        'notes': notes,
      };
}

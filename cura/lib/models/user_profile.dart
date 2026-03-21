class UserProfile {
  final String id;
  final String displayName;
  final String? mobileNumber;
  final String? gpName;
  final String? gpSurgery;
  final String timezone;
  final String morningCallTime;
  final String afternoonCallTime;
  final String eveningCallTime;
  final bool callsEnabled;
  final bool calendarAccessGranted;

  const UserProfile({
    required this.id,
    this.displayName = '',
    this.mobileNumber,
    this.gpName,
    this.gpSurgery,
    this.timezone = 'Europe/London',
    this.morningCallTime = '09:00',
    this.afternoonCallTime = '14:00',
    this.eveningCallTime = '21:00',
    this.callsEnabled = true,
    this.calendarAccessGranted = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      gpName: json['gp_name'] as String?,
      gpSurgery: json['gp_surgery'] as String?,
      timezone: json['timezone'] as String? ?? 'Europe/London',
      morningCallTime: json['morning_call_time'] as String? ?? '09:00',
      afternoonCallTime: json['afternoon_call_time'] as String? ?? '14:00',
      eveningCallTime: json['evening_call_time'] as String? ?? '21:00',
      callsEnabled: json['calls_enabled'] as bool? ?? true,
      calendarAccessGranted: json['calendar_access_granted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'mobile_number': mobileNumber,
        'gp_name': gpName,
        'gp_surgery': gpSurgery,
        'morning_call_time': morningCallTime,
        'afternoon_call_time': afternoonCallTime,
        'evening_call_time': eveningCallTime,
        'calls_enabled': callsEnabled,
        'calendar_access_granted': calendarAccessGranted,
        'updated_at': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({
    String? displayName,
    String? mobileNumber,
    String? gpName,
    String? gpSurgery,
    String? morningCallTime,
    String? afternoonCallTime,
    String? eveningCallTime,
    bool? callsEnabled,
    bool? calendarAccessGranted,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      gpName: gpName ?? this.gpName,
      gpSurgery: gpSurgery ?? this.gpSurgery,
      timezone: timezone,
      morningCallTime: morningCallTime ?? this.morningCallTime,
      afternoonCallTime: afternoonCallTime ?? this.afternoonCallTime,
      eveningCallTime: eveningCallTime ?? this.eveningCallTime,
      callsEnabled: callsEnabled ?? this.callsEnabled,
      calendarAccessGranted: calendarAccessGranted ?? this.calendarAccessGranted,
    );
  }
}

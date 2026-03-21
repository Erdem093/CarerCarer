class Medication {
  final String id;
  final String userId;
  final String name;
  final String? dosage;
  final String? frequency;
  final String? sourceSessionId;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  const Medication({
    required this.id,
    required this.userId,
    required this.name,
    this.dosage,
    this.frequency,
    this.sourceSessionId,
    this.isActive = true,
    this.notes,
    required this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      sourceSessionId: json['source_session_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'source_session_id': sourceSessionId,
        'is_active': isActive,
        'notes': notes,
      };
}

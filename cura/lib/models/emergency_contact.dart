class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final int priority;

  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.priority = 1,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      priority: json['priority'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'phone_number': phoneNumber,
        'priority': priority,
      };
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CheckInDebugEntry {
  final String context;
  final DateTime timestamp;
  final bool success;
  final String detail;

  const CheckInDebugEntry({
    required this.context,
    required this.timestamp,
    required this.success,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
        'context': context,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'detail': detail,
      };

  factory CheckInDebugEntry.fromJson(Map<String, dynamic> json) {
    return CheckInDebugEntry(
      context: json['context'] as String? ?? 'unknown',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      success: json['success'] as bool? ?? false,
      detail: json['detail'] as String? ?? '',
    );
  }
}

class CheckInDebugService {
  static const _key = 'check_in_debug_entries';
  static const _backendUrlKey = 'debug_backend_url';

  Future<List<CheckInDebugEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((entry) => CheckInDebugEntry.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addEntry(CheckInDebugEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    final updated = [entry, ...entries].take(20).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, updated);
  }

  Future<String?> loadBackendUrlOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey);
  }

  Future<void> saveBackendUrlOverride(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url);
  }
}

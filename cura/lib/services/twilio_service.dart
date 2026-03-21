import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_config.dart';
import '../services/claude_service.dart';

class TwilioService {
  final Logger _log = Logger();
  late final Dio _dio;
  String _backendUrl;

  TwilioService({String? backendUrl})
      : _backendUrl = backendUrl ?? AppConfig.backendUrl {
    _dio = Dio(BaseOptions(
      baseUrl: _backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  /// Updates the backend URL (e.g. after ngrok starts or user sets prod URL).
  void setBackendUrl(String url) {
    _backendUrl = url;
    _dio.options.baseUrl = url;
  }

  String get backendUrl => _backendUrl;

  Future<bool> pingHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      _log.e('Twilio health check error: $e');
      return false;
    }
  }

  /// Triggers an outbound AI call to the user's mobile number.
  Future<bool> initiateCheckInCall({
    required String toPhoneNumber,
    required String userId,
    required ConversationContext context,
  }) async {
    try {
      final response = await _dio.post('/initiate-call', data: {
        'to': toPhoneNumber,
        'userId': userId,
        'context': context.name,
      });
      _log.i('Twilio call initiated: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      _log.e('Twilio initiate call error: $e');
      return false;
    }
  }

  /// Triggers a Twilio call to an emergency contact.
  /// The backend plays a TTS message informing the contact.
  Future<bool> initiateEmergencyCall({
    required String toPhoneNumber,
    required String userName,
    required String contactName,
  }) async {
    try {
      final response = await _dio.post('/emergency-call', data: {
        'to': toPhoneNumber,
        'userName': userName,
        'contactName': contactName,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return response.statusCode == 200;
    } catch (e) {
      _log.e('Twilio emergency call error: $e');
      return false;
    }
  }

  /// Returns the context appropriate for the current time of day.
  static ConversationContext contextForNow() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return ConversationContext.morning;
    if (hour >= 12 && hour < 18) return ConversationContext.afternoon;
    return ConversationContext.evening;
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central access point for all environment variables.
/// Call [AppConfig.load()] once in main() before using any values.
class AppConfig {
  AppConfig._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // ── Supabase ──────────────────────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ── Fish Audio ────────────────────────────────────────────────────────
  static String get fishAudioApiKey => dotenv.env['FISH_AUDIO_API_KEY'] ?? '';

  // ── OpenAI ────────────────────────────────────────────────────────────
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  // ── Twilio ────────────────────────────────────────────────────────────
  static String get twilioAccountSid => dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
  static String get twilioAuthToken => dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';
  static String get twilioPhoneNumber => dotenv.env['TWILIO_PHONE_NUMBER'] ?? '';

  // ── Backend ───────────────────────────────────────────────────────────
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
}

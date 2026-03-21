import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';
import '../../services/fish_audio_service.dart';
import '../../services/claude_service.dart';
import '../../services/calendar_service.dart';
import '../../services/supabase_service.dart';
import '../../services/emergency_service.dart';
import '../../services/check_in_debug_service.dart';
import '../../services/twilio_service.dart';
import '../../models/user_profile.dart';
import '../../features/conversation/providers/conversation_provider.dart';

// ── Core Services ─────────────────────────────────────────────────────────

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService(ref.watch(supabaseServiceProvider));
});

// Keys come from .env via AppConfig — no user input required
final fishAudioServiceProvider = Provider<FishAudioService>((ref) {
  return FishAudioService(AppConfig.fishAudioApiKey);
});

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  return ClaudeService(AppConfig.openAiApiKey);
});

final twilioServiceProvider = Provider<TwilioService>((ref) {
  return TwilioService(backendUrl: AppConfig.backendUrl);
});

final checkInDebugServiceProvider = Provider<CheckInDebugService>((ref) {
  return CheckInDebugService();
});

// ── Voice Preference ──────────────────────────────────────────────────────

const _kVoiceKey = 'preferred_voice_id';

/// Voice options: Fish Audio reference IDs (null = S2-Pro default voice).
/// Get reference IDs from https://fish.audio/voices — filter English, copy ID.
const voiceOptions = [
  VoiceOption(id: 'fish_cura',      name: 'Cura (Default)',  fishReferenceId: '933563129e564b19a115bedd57b7406a', openAiVoice: 'shimmer'),
  VoiceOption(id: 'fish_warm',      name: 'Warm British',    fishReferenceId: '54a5170264694bfc8e9ad98df7bd89c3', openAiVoice: 'nova'),
  VoiceOption(id: 'fish_clear',     name: 'Clear & Calm',    fishReferenceId: 'ad5b8ece663340438ab12fdbfcc45d1f', openAiVoice: 'fable'),
  VoiceOption(id: 'openai_shimmer', name: 'Shimmer (Soft)',  fishReferenceId: null,                               openAiVoice: 'shimmer'),
];

class VoiceOption {
  final String id;
  final String name;
  final String? fishReferenceId;
  final String openAiVoice;
  const VoiceOption({
    required this.id,
    required this.name,
    required this.fishReferenceId,
    required this.openAiVoice,
  });

  @override
  bool operator ==(Object other) => other is VoiceOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final preferredVoiceProvider =
    StateNotifierProvider<PreferredVoiceNotifier, VoiceOption>(
  (ref) => PreferredVoiceNotifier(),
);

class PreferredVoiceNotifier extends StateNotifier<VoiceOption> {
  PreferredVoiceNotifier() : super(voiceOptions.first) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kVoiceKey);
    if (id != null) {
      final match = voiceOptions.where((v) => v.id == id).firstOrNull;
      if (match != null) state = match;
    }
  }

  Future<void> setVoice(VoiceOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoiceKey, option.id);
  }
}

// ── User Profile ──────────────────────────────────────────────────────────

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  return ref.watch(supabaseServiceProvider).fetchProfile();
});

// ── Conversation ──────────────────────────────────────────────────────────

final conversationProvider = StateNotifierProvider.family<
    ConversationNotifier, ConversationState, ConversationContext>(
  (ref, context) {
    final notifier = ConversationNotifier(
      fishAudio: ref.watch(fishAudioServiceProvider),
      claude: ref.watch(claudeServiceProvider),
      calendar: ref.watch(calendarServiceProvider),
      supabase: ref.watch(supabaseServiceProvider),
      emergency: ref.watch(emergencyServiceProvider),
      context: context,
      voiceOption: ref.read(preferredVoiceProvider),
    );
    // Keep voice in sync when user changes preference
    ref.listen(preferredVoiceProvider, (_, next) => notifier.updateVoice(next));
    return notifier;
  },
);

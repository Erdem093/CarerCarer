import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
// ignore_for_file: cancel_subscriptions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/conversation_message.dart';
import '../../../models/check_in_session.dart';
import '../../../models/medication.dart';
import '../../../models/appointment.dart';
import '../../../services/fish_audio_service.dart';
import '../../../services/claude_service.dart';
import '../../../services/calendar_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/emergency_service.dart';
import '../../../core/di/providers.dart' show VoiceOption;

enum ConversationTurnState {
  idle,
  listening,
  processing,
  speaking,
  finished,
  error,
}

class ConversationState {
  final ConversationTurnState turnState;
  final List<ConversationMessage> messages;
  final bool isSessionActive;
  final String? sessionId;
  final bool crisisDetected;
  final String? errorMessage;
  final double micAmplitude;

  const ConversationState({
    this.turnState = ConversationTurnState.idle,
    this.messages = const [],
    this.isSessionActive = false,
    this.sessionId,
    this.crisisDetected = false,
    this.errorMessage,
    this.micAmplitude = 0.0,
  });

  ConversationState copyWith({
    ConversationTurnState? turnState,
    List<ConversationMessage>? messages,
    bool? isSessionActive,
    String? sessionId,
    bool? crisisDetected,
    String? errorMessage,
    double? micAmplitude,
  }) {
    return ConversationState(
      turnState: turnState ?? this.turnState,
      messages: messages ?? this.messages,
      isSessionActive: isSessionActive ?? this.isSessionActive,
      sessionId: sessionId ?? this.sessionId,
      crisisDetected: crisisDetected ?? this.crisisDetected,
      errorMessage: errorMessage,
      micAmplitude: micAmplitude ?? this.micAmplitude,
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final FishAudioService _fishAudio;
  final ClaudeService _claude;
  final CalendarService _calendar;
  final SupabaseService _supabase;
  final EmergencyService _emergency;
  final ConversationContext _context;
  VoiceOption? _voiceOption;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final _uuid = const Uuid();

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _silenceTimer;
  Timer? _maxRecordingTimer;
  bool _isRecording = false;
  String? _calendarContext;
  String? _currentAudioPath;

  ConversationNotifier({
    required FishAudioService fishAudio,
    required ClaudeService claude,
    required CalendarService calendar,
    required SupabaseService supabase,
    required EmergencyService emergency,
    required ConversationContext context,
    VoiceOption? voiceOption,
  })  : _fishAudio = fishAudio,
        _claude = claude,
        _calendar = calendar,
        _supabase = supabase,
        _emergency = emergency,
        _context = context,
        _voiceOption = voiceOption,
        super(const ConversationState());

  void updateVoice(VoiceOption option) => _voiceOption = option;

  // ─── Session Control ────────────────────────────────────────────────────

  Future<void> startSession(String userId) async {
    state = state.copyWith(
      isSessionActive: true,
      messages: [],
      turnState: ConversationTurnState.idle,
    );

    // Fetch calendar context
    if (await _calendar.hasPermission()) {
      final events = await _calendar.getUpcomingEvents();
      _calendarContext = _calendar.formatEventsForLLM(events);
    }

    // Create session in Supabase (only if properly authenticated)
    if (userId.isNotEmpty && userId != 'demo') {
      final dbContext = _toSessionContext(_context);
      final sessionId = await _supabase.createSession(CheckInSession(
        id: '',
        userId: userId,
        context: dbContext,
        startedAt: DateTime.now(),
      ));
      state = state.copyWith(sessionId: sessionId);
    }

    await _sendCuraGreeting();
    await _startListening();
  }

  Future<void> endSession(BuildContext context) async {
    await _stopListening();
    await _player.stop();
    state = state.copyWith(
      isSessionActive: false,
      turnState: ConversationTurnState.finished,
    );

    if (state.sessionId != null && state.messages.isNotEmpty) {
      await _finalizeSession(context);
    }
  }

  // ─── Conversation Loop ──────────────────────────────────────────────────

  Future<void> _sendCuraGreeting() async {
    state = state.copyWith(turnState: ConversationTurnState.processing);
    final greetingPrompt = 'Start with a warm ${_context.name} greeting. Keep it under 25 words.';
    try {
      final greeting = await _claude.chat(
        history: [],
        userMessage: greetingPrompt,
        context: _context,
        calendarContext: _calendarContext,
      );
      await _playAndAddMessage(greeting, role: MessageRole.assistant);
    } catch (_) {}
  }

  Future<void> _startListening() async {
    if (!state.isSessionActive) return;
    try {
      if (!await _recorder.hasPermission()) {
        state = state.copyWith(
          turnState: ConversationTurnState.error,
          errorMessage: 'Microphone permission is required before Cura can listen.',
        );
        return;
      }

      state = state.copyWith(
        turnState: ConversationTurnState.listening,
        errorMessage: null,
      );
      _isRecording = true;
      _silenceTimer?.cancel();

      // Configure iOS audio session for simultaneous playback + recording
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);

      final dir = await getTemporaryDirectory();
      final audioPath = '${dir.path}/cura_${_uuid.v4()}.wav';
      _currentAudioPath = audioPath;

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: AppConstants.audioSampleRate,
          numChannels: 1,
        ),
        path: audioPath,
      );

      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final normalised = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        state = state.copyWith(micAmplitude: normalised);

        final isSilent = amp.current < AppConstants.silenceThresholdDb;
        debugPrint(
          '[MIC] dB=${amp.current.toStringAsFixed(1)}  '
          'threshold=${AppConstants.silenceThresholdDb}  '
          'silent=$isSilent  '
          'timerActive=${_silenceTimer != null}',
        );

        if (isSilent) {
          if (_silenceTimer == null) {
            debugPrint('[MIC] Silence started — starting ${AppConstants.silenceDurationMs}ms timer');
            _silenceTimer = Timer(
              Duration(milliseconds: AppConstants.silenceDurationMs),
              () {
                debugPrint('[MIC] Silence timer fired — ending turn');
                _onSilenceDetected(audioPath);
              },
            );
          }
        } else {
          if (_silenceTimer != null) {
            debugPrint('[MIC] Speech detected — resetting silence timer');
          }
          _silenceTimer?.cancel();
          _silenceTimer = null;
        }
      });

      // Fallback: finish the turn even if silence detection never fires.
      _maxRecordingTimer?.cancel();
      _maxRecordingTimer = Timer(
        const Duration(seconds: 30),
        () => finishListeningTurn(),
      );
    } catch (e) {
      state = state.copyWith(
        turnState: ConversationTurnState.error,
        errorMessage: 'Unable to start the microphone. Please check permissions and try again.',
        micAmplitude: 0.0,
      );
    }
  }

  Future<void> _onSilenceDetected(String audioPath) async {
    if (!_isRecording || !state.isSessionActive) return;
    _isRecording = false;
    _silenceTimer = null;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    _currentAudioPath = null;

    await _recorder.stop();
    await _amplitudeSub?.cancel();
    // Give the OS a moment to flush the file to disk before reading it
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(
      turnState: ConversationTurnState.processing,
      micAmplitude: 0.0,
    );

    try {
      final transcript = await _fishAudio.transcribeAudio(audioPath);
      File(audioPath).deleteSync();

      if (transcript.trim().isEmpty) {
        state = state.copyWith(
          errorMessage: 'I did not catch that. Try again, then tap the orb when you finish speaking.',
          turnState: ConversationTurnState.idle,
        );
        if (state.isSessionActive) await _startListening();
        return;
      }

      final userMsg = ConversationMessage(
        role: MessageRole.user,
        content: transcript,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, userMsg]);

      // Crisis detection
      if (_emergency.detectCrisis(transcript)) {
        state = state.copyWith(crisisDetected: true);
        const crisis =
            'That sounds serious. I am contacting your emergency contact right now. Please stay calm.';
        await _playAndAddMessage(crisis, role: MessageRole.assistant);
        state = state.copyWith(
            isSessionActive: false, turnState: ConversationTurnState.finished);
        return;
      }

      final history = state.messages.sublist(0, state.messages.length - 1);
      final reply = await _claude.chat(
        history: history,
        userMessage: transcript,
        context: _context,
        calendarContext: _calendarContext,
        toolExecutor: (name, args) async {
          if (name == 'create_calendar_event') {
            final event = CalendarEvent(
              title: args['title'] as String,
              start: DateTime.parse(args['start_datetime'] as String),
              end: args['end_datetime'] != null
                  ? DateTime.parse(args['end_datetime'] as String)
                  : null,
              location: args['location'] as String?,
            );
            final id = await _calendar.createEvent(event);
            return id != null
                ? '{"success": true}'
                : '{"success": false, "error": "Could not save to calendar"}';
          }
          return '{"error": "unknown tool"}';
        },
      );
      await _playAndAddMessage(reply, role: MessageRole.assistant);

      if (state.isSessionActive) await _startListening();
    } catch (e) {
      state = state.copyWith(
        turnState: ConversationTurnState.error,
        errorMessage: 'Sorry, I had trouble hearing that. Try again, then tap the orb when you finish speaking.',
      );
      await Future.delayed(const Duration(seconds: 2));
      if (state.isSessionActive) await _startListening();
    }
  }

  Future<void> _playAndAddMessage(String text, {required MessageRole role}) async {
    // Strip [bracket style cues] from transcript — they're for TTS only
    final stripped = text
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    // Fall back to original text if stripping emptied the content
    final displayText = stripped.isNotEmpty ? stripped : text.trim();
    final msg = ConversationMessage(
      role: role,
      content: displayText,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      turnState: ConversationTurnState.speaking,
    );

    if (role == MessageRole.assistant) {
      try {
        Uint8List audioBytes;
        final voice = _voiceOption;
        try {
          // Use Fish Audio unless this option is OpenAI-only
          if (voice?.fishReferenceId == null) {
            audioBytes = await _fishAudio.openAiTTSFallback(text, voice: voice!.openAiVoice);
          } else {
            audioBytes = await _fishAudio.synthesizeTTSRest(text, referenceId: voice?.fishReferenceId);
          }
        } catch (e) {
          debugPrint('TTS failed: $e — using OpenAI fallback');
          audioBytes = await _fishAudio.openAiTTSFallback(text, voice: voice?.openAiVoice ?? 'shimmer');
        }

        if (audioBytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/cura_tts_${_uuid.v4()}.mp3';
          await File(path).writeAsBytes(audioBytes);
          await _player.setFilePath(path);

          // Subscribe BEFORE play() so we never miss the completed event
          final completer = Completer<void>();
          StreamSubscription? sub;
          sub = _player.processingStateStream.listen((s) {
            if (s == ProcessingState.completed && !completer.isCompleted) {
              completer.complete();
              sub?.cancel();
            }
          });
          await _player.play();
          await completer.future
              .timeout(const Duration(seconds: 30), onTimeout: () { sub?.cancel(); });
          await _player.stop();
          try { File(path).deleteSync(); } catch (_) {}
          // Give iOS time to release the audio session back to input mode
          await Future.delayed(const Duration(milliseconds: 600));
        }
      } catch (e) {
        debugPrint('TTS error: $e');
      }
    }
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    _maxRecordingTimer?.cancel();
    await _amplitudeSub?.cancel();
    _isRecording = false;
    _currentAudioPath = null;
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<void> finishListeningTurn() async {
    final audioPath = _currentAudioPath;
    if (!_isRecording || audioPath == null) return;
    _silenceTimer?.cancel();
    await _onSilenceDetected(audioPath);
  }

  // ─── Session Finalisation ─────────────────────────────────────────────────

  Future<void> _finalizeSession(BuildContext context) async {
    if (state.sessionId == null || state.messages.isEmpty) return;

    final transcript = state.messages.map((m) => m.toJson()).toList();
    final fullText =
        state.messages.map((m) => '${m.role.name}: ${m.content}').join('\n');

    final extracted = await _claude.extractStructuredData(fullText);

    await _supabase.finalizeSession(
      sessionId: state.sessionId!,
      transcript: transcript,
      endedAt: DateTime.now(),
      sleepScore: extracted.sleepScore,
      painScore: extracted.painScore,
      moodScore: extracted.moodScore,
      painLocation: extracted.painLocation,
      crisisFlagged: extracted.crisisDetected || state.crisisDetected,
    );

    final userId = _supabase.currentUserId ?? '';

    for (final med in extracted.medications) {
      await _supabase.saveMedication(Medication(
        id: _uuid.v4(),
        userId: userId,
        name: med['name'] ?? '',
        dosage: med['dosage'],
        frequency: med['frequency'],
        sourceSessionId: state.sessionId,
        createdAt: DateTime.now(),
      ));
    }

    for (final appt in extracted.appointments) {
      DateTime? dt;
      try {
        if (appt['date'] != null) {
          dt = DateTime.parse('${appt['date']}T${appt['time'] ?? '00:00'}');
        }
      } catch (_) {}

      final appointment = Appointment(
        id: _uuid.v4(),
        userId: userId,
        title: appt['title'] ?? 'Appointment',
        provider: appt['provider'],
        appointmentDateTime: dt,
        location: appt['location'],
        sourceSessionId: state.sessionId,
        createdAt: DateTime.now(),
      );
      await _supabase.saveAppointment(appointment);

      if (dt != null && await _calendar.hasPermission()) {
        await _calendar.createEvent(CalendarEvent(
          title: appointment.title,
          start: dt,
          location: appointment.location,
          notes: 'Added by Cura',
        ));
      }
    }

    if ((extracted.crisisDetected || state.crisisDetected) && context.mounted) {
      final profile = await _supabase.fetchProfile();
      await _emergency.initiateEscalation(
        context,
        triggerText: fullText.substring(0, fullText.length.clamp(0, 200)),
        userName: profile?.displayName ?? 'the carer',
        sessionId: state.sessionId,
      );
    }
  }

  SessionContext _toSessionContext(ConversationContext c) {
    switch (c) {
      case ConversationContext.morning:
        return SessionContext.morning;
      case ConversationContext.afternoon:
        return SessionContext.afternoon;
      case ConversationContext.evening:
        return SessionContext.evening;
      default:
        return SessionContext.adhoc;
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _silenceTimer?.cancel();
    _maxRecordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _fishAudio.dispose();
    super.dispose();
  }
}

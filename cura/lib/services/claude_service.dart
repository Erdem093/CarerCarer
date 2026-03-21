import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_constants.dart';
import '../models/conversation_message.dart';

enum ConversationContext { morning, afternoon, evening, adhoc, letterExplainer, analysis }

class ExtractedData {
  final List<Map<String, String>> medications;
  final List<Map<String, String>> appointments;
  final int? sleepScore;
  final int? painScore;
  final int? moodScore;
  final String? painLocation;
  final bool crisisDetected;

  const ExtractedData({
    this.medications = const [],
    this.appointments = const [],
    this.sleepScore,
    this.painScore,
    this.moodScore,
    this.painLocation,
    this.crisisDetected = false,
  });
}

class LetterExplanation {
  final String documentType;
  final String meaning;
  final String action;
  final String consequence;

  const LetterExplanation({
    required this.documentType,
    required this.meaning,
    required this.action,
    required this.consequence,
  });
}

/// Wraps the OpenAI Chat Completions API.
/// Public interface is unchanged so the rest of the app is unaffected.
class ClaudeService {
  final String _apiKey;
  final Logger _log = Logger();
  late final Dio _dio;

  ClaudeService(this._apiKey) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.openAiBaseUrl,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  // ─── Core Chat ────────────────────────────────────────────────────────────

  Future<String> chat({
    required List<ConversationMessage> history,
    required String userMessage,
    required ConversationContext context,
    String? calendarContext,
    Future<String> Function(String name, Map<String, dynamic> args)? toolExecutor,
  }) async {
    final systemPrompt = _buildSystemPrompt(context, calendarContext);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => m.toClaudeFormat()),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      while (true) {
        final body = <String, dynamic>{
          'model': AppConstants.openAiModel,
          'max_tokens': AppConstants.openAiVoiceMaxTokens,
          'messages': messages,
          if (toolExecutor != null) 'tools': _calendarTools,
          if (toolExecutor != null) 'tool_choice': 'auto',
        };

        final response = await _dio.post(
          AppConstants.openAiChatEndpoint,
          data: jsonEncode(body),
        );

        final data = response.data as Map<String, dynamic>;
        final choice = (data['choices'] as List<dynamic>).first as Map<String, dynamic>;
        final finishReason = choice['finish_reason'] as String;
        final message = choice['message'] as Map<String, dynamic>;

        if (finishReason == 'tool_calls' && toolExecutor != null) {
          messages.add(message);
          final toolCalls = message['tool_calls'] as List<dynamic>;
          for (final tc in toolCalls) {
            final tcMap = tc as Map<String, dynamic>;
            final fn = tcMap['function'] as Map<String, dynamic>;
            final args = jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;
            final result = await toolExecutor(fn['name'] as String, args);
            messages.add({
              'role': 'tool',
              'tool_call_id': tcMap['id'] as String,
              'content': result,
            });
          }
          // loop → AI generates natural language confirmation
        } else {
          return message['content'] as String;
        }
      }
    } catch (e) {
      _log.e('OpenAI chat error: $e');
      rethrow;
    }
  }

  static const _calendarTools = [
    {
      'type': 'function',
      'function': {
        'name': 'create_calendar_event',
        'description':
            'Create a new event in the user\'s device calendar. Use when the user asks to add, book, schedule, or be reminded of any appointment or event.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Event title, e.g. "Doctor appointment"',
            },
            'start_datetime': {
              'type': 'string',
              'description': 'ISO 8601 start datetime, e.g. 2026-03-17T15:00:00',
            },
            'end_datetime': {
              'type': 'string',
              'description': 'ISO 8601 end datetime (optional, defaults to 1 hour after start)',
            },
            'location': {
              'type': 'string',
              'description': 'Event location (optional)',
            },
          },
          'required': ['title', 'start_datetime'],
        },
      },
    }
  ];

  // ─── Post-session Extraction ──────────────────────────────────────────────

  Future<ExtractedData> extractStructuredData(String transcript) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prompt = '''
Analyse this conversation transcript and extract structured data.
Return ONLY valid JSON, no other text.

Format:
{
  "medications": [{"name": "...", "dosage": "...", "frequency": "..."}],
  "appointments": [{"title": "...", "provider": "...", "date": "YYYY-MM-DD", "time": "HH:MM", "location": "..."}],
  "sleepScore": 0-10 or null,
  "painScore": 0-10 or null,
  "moodScore": 0-10 or null,
  "painLocation": "..." or null,
  "crisisDetected": true/false
}

Rules:
- Only include medications/appointments explicitly mentioned
- Scores: 10=excellent/no pain, 0=terrible/severe pain
- crisisDetected: true if user mentioned chest pain, can't breathe, fallen, stroke, unconscious
- Dates: use today's date as reference for relative dates like "Thursday"
- Today is $today

Transcript:
$transcript''';

    try {
      final response = await _dio.post(
        AppConstants.openAiChatEndpoint,
        data: jsonEncode({
          'model': AppConstants.openAiModel,
          'max_tokens': AppConstants.openAiExtractMaxTokens,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      final text = message['content'] as String;

      final cleaned = text.replaceAll(RegExp(r'```json?\s*|\s*```'), '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      return ExtractedData(
        medications: (json['medications'] as List<dynamic>?)
                ?.map((m) => (m as Map).map(
                      (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                    ))
                .toList() ??
            [],
        appointments: (json['appointments'] as List<dynamic>?)
                ?.map((a) => (a as Map).map(
                      (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                    ))
                .toList() ??
            [],
        sleepScore: json['sleepScore'] as int?,
        painScore: json['painScore'] as int?,
        moodScore: json['moodScore'] as int?,
        painLocation: json['painLocation'] as String?,
        crisisDetected: json['crisisDetected'] as bool? ?? false,
      );
    } catch (e) {
      _log.e('OpenAI extraction error: $e');
      return const ExtractedData();
    }
  }

  // ─── Letter Explainer ────────────────────────────────────────────────────

  static const _letterSystemPrompt = '''
You explain official UK government and NHS letters to elderly people.
Return ONLY valid JSON with exactly these four keys:
{"documentType": "...", "meaning": "...", "action": "...", "consequence": "..."}

Rules:
- "documentType": A short plain-English name for this document (e.g. "NHS Appointment Letter", "Council Tax Bill", "DWP Benefits Notice", "Bank Statement"). Maximum 6 words.
- Maximum 40 words per field for meaning, action, and consequence
- Plain British English, no jargon
- "meaning": What this letter is saying in simple terms
- "action": Exactly what the person needs to do and by when
- "consequence": What happens if they do nothing (be specific but calm)
- Never use the word "you may" — be direct and clear''';

  LetterExplanation _parseLetterResponse(String text) {
    final cleaned = text.replaceAll(RegExp(r'```json?\s*|\s*```'), '').trim();
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return LetterExplanation(
      documentType: json['documentType'] as String? ?? 'Official Letter',
      meaning: json['meaning'] as String,
      action: json['action'] as String,
      consequence: json['consequence'] as String,
    );
  }

  Future<LetterExplanation> explainLetterFromImage(String base64Image) async {
    try {
      final response = await _dio.post(
        AppConstants.openAiChatEndpoint,
        data: jsonEncode({
          'model': 'gpt-4o',
          'max_tokens': 600,
          'messages': [
            {'role': 'system', 'content': _letterSystemPrompt},
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                    'detail': 'high',
                  },
                },
                {'type': 'text', 'text': 'Please explain this letter.'},
              ],
            },
          ],
        }),
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      return _parseLetterResponse(message['content'] as String);
    } catch (e) {
      _log.e('OpenAI vision letter explainer error: $e');
      rethrow;
    }
  }

  // ─── System Prompts ───────────────────────────────────────────────────────

  String _buildSystemPrompt(ConversationContext context, String? calendarContext) {
    final calendarSection = calendarContext != null
        ? '\nCALENDAR (next 7 days):\n$calendarContext\nUse this to remind the user of upcoming events.\n'
        : '';

    const safetyRules = '''
SAFETY RULES — follow always:
- You are Cura, a warm AI companion for unpaid elderly carers in the UK
- NEVER diagnose, prescribe, or give medical treatment advice
- NEVER make up medication dosages or medical facts
- If user mentions chest pain, difficulty breathing, fallen, can't get up, stroke, or heart attack:
  Respond: "That sounds serious. I'm contacting your emergency contact right now." then stop.
- Always recommend GP for any health concern
- Keep responses under 60 words (= ~20 seconds of audio)
- Warm, simple British English for someone aged 60-80
- Never use medical jargon or complex words
- Ask maximum 2 questions at a time''';

    final contextSection = switch (context) {
      ConversationContext.morning => '''
MORNING CHECK-IN:
Today is ${_todayLabel()}.
Gently assess: sleep quality (ask for a score 1-10), any pain or discomfort, mood, who is helping them today.
Start with a warm greeting using the time of day.''',
      ConversationContext.afternoon => '''
AFTERNOON CHECK-IN:
Today is ${_todayLabel()}.
Check on how the day is going. Ask about their energy levels. Mention any afternoon appointments from the calendar.
Offer to help with anything they need.''',
      ConversationContext.evening => '''
EVENING CHECK-IN:
Today is ${_todayLabel()}.
Gently review how the day went. Acknowledge their hard work as a carer.
Ask if they've eaten and had any rest. Wish them a good night.''',
      ConversationContext.adhoc => '''
GENERAL CONVERSATION:
Today is ${_todayLabel()}.
The user has initiated a conversation. Be warm and responsive to whatever they need.
Listen carefully for mentions of new medications, appointments, or health concerns.''',
      _ => '',
    };

    const voiceStyleRules = '''
VOICE STYLE (Fish Audio S2 emotion control):
- You may place ONE [emotion cue] at the START of a sentence to shape its delivery. e.g. [warmly], [gently], [with concern], [cheerfully], [softly], [laughing], [sighing].
- ONLY use pure emotion/feeling words in brackets. NEVER describe voice, accent, pitch, or speed — e.g. do NOT write [in a warm accent] or [speaking slowly] as these break the voice.
- Maximum one bracket per sentence. Never place a bracket mid-sentence.
- Most sentences need no bracket. Use sparingly — only where emotional tone truly matters.
- Never bracket questions about scores, facts, or lists.''';

    return '$safetyRules\n$voiceStyleRules\n$calendarSection\n$contextSection';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

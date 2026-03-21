class AppConstants {
  AppConstants._();

  // Fish Audio
  static const String fishAudioBaseUrl = 'https://api.fish.audio';
  static const String fishAudioWsUrl = 'wss://api.fish.audio/v1/tts/live';
  static const String fishAudioTtsEndpoint = '/v1/tts';
  static const String fishAudioAsrEndpoint = '/v1/asr';
  static const String fishAudioModel = 's2-pro';

  // OpenAI
  static const String openAiBaseUrl = 'https://api.openai.com';
  static const String openAiChatEndpoint = '/v1/chat/completions';
  static const String openAiModel = 'gpt-4o-mini';
  static const int openAiVoiceMaxTokens = 300;    // ~60 words, ~20s audio
  static const int openAiExtractMaxTokens = 800;
  static const int openAiLetterMaxTokens = 1500;
  static const int openAiAnalysisMaxTokens = 2000;

  // Audio
  static const int audioSampleRate = 16000;
  static const double silenceThresholdDb = -30.0;
  static const int silenceDurationMs = 1800;

  // Conversation
  static const List<String> crisisKeywords = [
    'chest pain', 'can\'t breathe', 'cannot breathe', 'fallen', 'i\'ve fallen',
    'i have fallen', 'stroke', 'unconscious', 'can\'t get up', 'cannot get up',
    'heart attack', 'not breathing', 'collapsed',
  ];

  // Calendar
  static const int calendarLookAheadDays = 7;
  static const int calendarStripDays = 3;
}

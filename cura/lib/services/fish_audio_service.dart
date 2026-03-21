import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';

class FishAudioService {
  final String _fishApiKey;
  final Logger _log = Logger();

  FishAudioService(this._fishApiKey);

  // ─── STT: Fish Audio ASR ─────────────────────────────────────────────────

  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audioFilePath, filename: 'audio.wav'),
        'language': 'en',
        'ignore_timestamps': 'true',
      });

      _log.i('Fish Audio ASR: sending file $audioFilePath');
      final response = await dio.post(
        'https://api.fish.audio/v1/asr',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $_fishApiKey'},
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      _log.i('Fish Audio ASR response: ${response.statusCode} — ${response.data}');
      final data = response.data as Map<String, dynamic>;
      final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
      final text = data['text'] as String? ?? '';
      _log.i('Fish Audio ASR transcript: "$text" (duration: $duration)');

      // If Fish Audio got no audio, fall back to OpenAI Whisper
      if (text.isEmpty || duration == 0.0) {
        _log.w('Fish Audio ASR returned empty — falling back to Whisper');
        return await _whisperFallback(audioFilePath);
      }
      return text;
    } on DioException catch (e) {
      _log.e('Fish Audio ASR HTTP error ${e.response?.statusCode} — falling back to Whisper');
      return await _whisperFallback(audioFilePath);
    } catch (e) {
      _log.e('Fish Audio ASR error: $e — falling back to Whisper');
      return await _whisperFallback(audioFilePath);
    }
  }

  Future<String> _whisperFallback(String audioFilePath) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(audioFilePath, filename: 'audio.wav'),
      'model': 'whisper-1',
      'language': 'en',
    });
    final response = await dio.post(
      'https://api.openai.com/v1/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer ${AppConfig.openAiApiKey}'},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final data = response.data as Map<String, dynamic>;
    final text = data['text'] as String? ?? '';
    _log.i('Whisper fallback transcript: "$text"');
    return text;
  }

  // ─── TTS: Fish Audio REST (S2-Pro model) ─────────────────────────────────

  Future<Uint8List> synthesizeTTSRest(String text, {String? referenceId}) async {
    Future<Uint8List> doRequest(String? refId) async {
      final dio = Dio();
      final body = <String, dynamic>{
        'text': text,
        'model': AppConstants.fishAudioModel,
        'format': 'mp3',
        if (refId != null) 'reference_id': refId,
      };
      final response = await dio.post(
        'https://api.fish.audio/v1/tts',
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $_fishApiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Uint8List.fromList(response.data as List<int>);
    }

    try {
      return await doRequest(referenceId);
    } catch (e) {
      _log.e('Fish Audio TTS error: $e');
      rethrow;
    }
  }

  // ─── TTS fallback: OpenAI TTS-1 ─────────────────────────────────────────

  Future<Uint8List> openAiTTSFallback(String text, {String voice = 'shimmer'}) async {
    final dio = Dio();
    final response = await dio.post(
      'https://api.openai.com/v1/audio/speech',
      data: jsonEncode({
        'model': 'tts-1',
        'input': text,
        'voice': voice,
        'response_format': 'mp3',
        'speed': 0.95,
      }),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return Uint8List.fromList(response.data as List<int>);
  }

  void dispose() {}
}

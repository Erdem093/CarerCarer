import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';

const _kLetterHistoryKey = 'letter_history';
const _kMaxHistory = 10;

class LetterResultScreen extends ConsumerStatefulWidget {
  final String documentType;
  final String meaning;
  final String action;
  final String consequence;
  final bool isFromHistory;

  const LetterResultScreen({
    super.key,
    required this.documentType,
    required this.meaning,
    required this.action,
    required this.consequence,
    this.isFromHistory = false,
  });

  @override
  ConsumerState<LetterResultScreen> createState() => _LetterResultScreenState();
}

class _LetterResultScreenState extends ConsumerState<LetterResultScreen> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isFromHistory) _saveToHistory();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _saveToHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLetterHistoryKey);
    final list = raw != null
        ? (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    final entry = {
      'documentType': widget.documentType,
      'meaning': widget.meaning,
      'action': widget.action,
      'consequence': widget.consequence,
      'savedAt': DateTime.now().toIso8601String(),
    };

    list.insert(0, entry);
    if (list.length > _kMaxHistory) list.removeRange(_kMaxHistory, list.length);

    await prefs.setString(_kLetterHistoryKey, jsonEncode(list));
  }

  Future<void> _autoPlay() async {
    final fullText =
        'Here is what this letter means. ${widget.meaning}. Here is what you need to do. ${widget.action}. Here is what happens if you do nothing. ${widget.consequence}.';
    await _playText(fullText);
  }

  Future<void> _playText(String text) async {
    setState(() => _isPlaying = true);
    try {
      final fish = ref.read(fishAudioServiceProvider);
      final voice = ref.read(preferredVoiceProvider);
      final Uint8List bytes;
      if (voice.fishReferenceId != null) {
        bytes = await fish.synthesizeTTSRest(text, referenceId: voice.fishReferenceId);
      } else {
        bytes = await fish.openAiTTSFallback(text, voice: voice.openAiVoice);
      }

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/letter_tts.mp3');
      await tempFile.writeAsBytes(bytes);
      await _player.setFilePath(tempFile.path);
      await _player.play();
    } catch (_) {
      // Visible text is the fallback.
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: widget.documentType.isNotEmpty ? widget.documentType : 'Letter explained',
      subtitle: 'A plain-English summary you can read or listen to.',
      actions: [
        GlassIconButton(
          icon: _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
          onTap: () {
            if (_isPlaying) {
              _player.stop();
              setState(() => _isPlaying = false);
            } else {
              _autoPlay();
            }
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExplanationCard(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.secondary,
            title: 'What this means',
            body: widget.meaning,
          ),
          const SizedBox(height: 12),
          _ExplanationCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.primaryLight,
            title: 'What you need to do',
            body: widget.action,
          ),
          const SizedBox(height: 12),
          _ExplanationCard(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            title: 'If you do nothing',
            body: widget.consequence,
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _ExplanationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder(context)),
                  color: AppColors.glassSecondaryFill(context),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: TextStyle(
              fontSize: 17,
              height: 1.55,
              color: AppColors.label(context),
            ),
          ),
        ],
      ),
    );
  }
}

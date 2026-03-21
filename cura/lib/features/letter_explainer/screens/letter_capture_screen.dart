import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/di/providers.dart';

const _kLetterHistoryKey = 'letter_history';
const _kMaxHistory = 10;

class LetterCaptureScreen extends ConsumerStatefulWidget {
  const LetterCaptureScreen({super.key});

  @override
  ConsumerState<LetterCaptureScreen> createState() => _LetterCaptureScreenState();
}

class _LetterCaptureScreenState extends ConsumerState<LetterCaptureScreen> {
  bool _isProcessing = false;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLetterHistoryKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      if (mounted) {
        setState(() => _history = list.cast<Map<String, dynamic>>());
      }
    }
  }

  Future<void> _openCamera() async {
    setState(() { _error = null; });
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    await _processImage(File(picked.path));
  }

  Future<void> _processImage(File imageFile) async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final claude = ref.read(claudeServiceProvider);
      final explanation = await claude.explainLetterFromImage(base64Image);
      if (!mounted) return;
      context.push('/home/letter/result', extra: {
        'documentType': explanation.documentType,
        'meaning': explanation.meaning,
        'action': explanation.action,
        'consequence': explanation.consequence,
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please check your internet connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openHistoryItem(Map<String, dynamic> item) {
    context.push('/home/letter/result', extra: {
      'documentType': item['documentType'] as String,
      'meaning': item['meaning'] as String,
      'action': item['action'] as String,
      'consequence': item['consequence'] as String,
      'isFromHistory': true,
    });
  }

  Future<void> _deleteHistoryItem(int index) async {
    final updated = List<Map<String, dynamic>>.from(_history)..removeAt(index);
    setState(() => _history = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLetterHistoryKey, jsonEncode(updated));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final labelColor = AppColors.label(context);
    final hintColor = AppColors.hint(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _LetterBackdrop()),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.glassFill(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.glassBorder(context)),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18, color: labelColor),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Explain a letter',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.0,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Text(
                      'Take a photo of any official letter — Cura will explain it in plain English.',
                      style: TextStyle(
                        fontSize: 17,
                        color: hintColor,
                        height: 1.4,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.sosBg(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.sos(context).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: AppColors.sos(context), fontSize: 15),
                        ),
                      ),
                    ),
                  ),

                // Camera button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CameraButton(
                      isProcessing: _isProcessing,
                      onTap: _isProcessing ? null : _openCamera,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 36)),

                // History
                if (_history.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Text(
                        'Previous letters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _history[index];
                        final savedAt = DateTime.tryParse(
                                item['savedAt'] as String? ?? '') ??
                            DateTime.now();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Dismissible(
                            key: ValueKey(item['savedAt'] ?? index),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: AppColors.sos(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: AppColors.sos(context), size: 26),
                            ),
                            onDismissed: (_) => _deleteHistoryItem(index),
                            child: _HistoryCard(
                              documentType: item['documentType'] as String,
                              date: DateFormat('d MMM yyyy').format(savedAt),
                              onTap: () => _openHistoryItem(item),
                            ),
                          ),
                        );
                      },
                      childCount: _history.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Reading your letter…',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This takes about 10 seconds',
                        style: TextStyle(fontSize: 15, color: hintColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LetterBackdrop extends StatelessWidget {
  const _LetterBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF181A1F), Color(0xFF101217)]
                : const [Color(0xFFF9F8F5), Color(0xFFF4F5F8)],
          ),
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback? onTap;

  const _CameraButton({required this.isProcessing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.label(context);
    final hintColor = AppColors.hint(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.glassHighlight(context).withValues(
                    alpha: AppColors.isDark(context) ? 0.06 : 0.9,
                  ),
                  AppColors.glassFill(context),
                ],
              ),
              border: Border.all(
                color: AppColors.glassBorder(context),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glassSecondaryFill(context),
                    border: Border.all(
                        color: AppColors.glassBorder(context), width: 1.2),
                  ),
                  child: Icon(Icons.camera_alt_outlined, size: 34, color: labelColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Take a photo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Point at your letter and tap',
                  style: TextStyle(fontSize: 15, color: hintColor, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String documentType;
  final String date;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.documentType,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.label(context);
    final hintColor = AppColors.hint(context);
    final mutedColor = AppColors.muted(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.glassHighlight(context).withValues(
                      alpha: AppColors.isDark(context) ? 0.06 : 0.9,
                    ),
                    AppColors.glassFill(context),
                  ],
                ),
                border: Border.all(
                  color: AppColors.glassBorder(context),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.glassSecondaryFill(context),
                      border: Border.all(color: AppColors.glassBorder(context), width: 1),
                    ),
                    child: Icon(Icons.description_outlined, size: 24, color: hintColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documentType,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(date,
                            style: TextStyle(fontSize: 14, color: mutedColor)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: mutedColor, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

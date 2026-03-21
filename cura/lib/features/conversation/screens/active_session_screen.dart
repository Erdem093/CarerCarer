import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../models/conversation_message.dart';
import '../../../services/claude_service.dart';
import '../providers/conversation_provider.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final ConversationContext conversationContext;

  const ActiveSessionScreen({
    super.key,
    required this.conversationContext,
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ringControllers;
  late final List<Animation<double>> _ringScales;
  late final List<Animation<double>> _ringOpacities;

  Timer? _callTimer;
  int _elapsedSeconds = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();

    _ringControllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      ),
    );
    _ringScales = _ringControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 2.25).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOut),
          ),
        )
        .toList();
    _ringOpacities = _ringControllers
        .map(
          (controller) => Tween<double>(begin: 0.42, end: 0.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOut),
          ),
        )
        .toList();

    for (int index = 0; index < 3; index++) {
      Future.delayed(Duration(milliseconds: index * 420), () {
        if (mounted) _ringControllers[index].repeat();
      });
    }

    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    for (final controller in _ringControllers) {
      controller.dispose();
    }
    _callTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    final supabase = ref.read(supabaseServiceProvider);
    final uid = supabase.currentUserId ?? 'demo';
    await ref
        .read(conversationProvider(widget.conversationContext).notifier)
        .startSession(uid);
  }

  String get _timerLabel {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider(widget.conversationContext));
    final isDark = AppColors.isDark(context);
    final isProcessing = convState.turnState == ConversationTurnState.processing;
    final isSpeaking = convState.turnState == ConversationTurnState.speaking;
    final isListening = convState.turnState == ConversationTurnState.listening;
    final recent = convState.messages.length > 2
        ? convState.messages.sublist(convState.messages.length - 2)
        : convState.messages;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: _CallBackdrop(isDark: isDark),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassPanel(
                        borderRadius: BorderRadius.circular(18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        onTap: () => _triggerEmergency(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: AppColors.sos(context),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Emergency',
                              style: TextStyle(
                                color: AppColors.sos(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GlassPanel(
                        width: 84,
                        height: 48,
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(18),
                        child: Center(
                          child: Text(
                            _timerLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.label(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _CallOrb(
                    ringControllers: _ringControllers,
                    ringScales: _ringScales,
                    ringOpacities: _ringOpacities,
                    isProcessing: isProcessing,
                    isSpeaking: isSpeaking,
                    state: convState.turnState,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cura',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _contextLabel(widget.conversationContext),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.hint(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StateLabel(state: convState.turnState, muted: _muted),
                  if (convState.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        convState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.hint(context),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (recent.isNotEmpty) ...[
                            GlassPanel(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: recent
                                    .map((message) =>
                                        _MiniTranscriptRow(message: message))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallButton(
                                icon: _muted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                label: _muted ? 'Unmute' : 'Mute',
                                active: _muted,
                                onTap: () =>
                                    setState(() => _muted = !_muted),
                              ),
                              GestureDetector(
                                onTap: () => _endSession(context),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.sos(context),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.sos(context)
                                            .withValues(alpha: 0.34),
                                        blurRadius: 22,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.call_end_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              _CallButton(
                                icon: Icons.volume_up_rounded,
                                label: isListening ? 'Listening' : 'Speaker',
                                active: isListening || isSpeaking,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _contextLabel(ConversationContext context) {
    switch (context) {
      case ConversationContext.morning:
        return 'Morning check-in';
      case ConversationContext.afternoon:
        return 'Afternoon check-in';
      case ConversationContext.evening:
        return 'Evening check-in';
      default:
        return 'Chat with Cura';
    }
  }

  Future<void> _endSession(BuildContext context) async {
    await ref
        .read(conversationProvider(widget.conversationContext).notifier)
        .endSession(context);
    if (mounted) context.pushReplacement('/home/session/summary');
  }

  Future<void> _triggerEmergency(BuildContext context) async {
    final emergency = ref.read(emergencyServiceProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    final convState = ref.read(conversationProvider(widget.conversationContext));
    await emergency.initiateEscalation(
      context,
      triggerText: 'Emergency button pressed during session',
      userName: profile?.displayName ?? 'the carer',
      sessionId: convState.sessionId,
    );
  }
}

class _CallBackdrop extends StatelessWidget {
  final bool isDark;

  const _CallBackdrop({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF181A20),
                  Color(0xFF0C0F14),
                ]
              : const [
                  Color(0xFFFBFAF6),
                  Color(0xFFF1F3F7),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 80,
            left: -40,
            child: _CallGlow(
              size: 180,
              color: isDark
                  ? const Color(0xFF3B5564).withValues(alpha: 0.2)
                  : const Color(0xFFEEDFC8).withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            top: 240,
            right: -20,
            child: _CallGlow(
              size: 200,
              color: isDark
                  ? const Color(0xFF6A5642).withValues(alpha: 0.14)
                  : const Color(0xFFDCE5F6).withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            child: _CallGlow(
              size: 160,
              color: isDark
                  ? const Color(0xFF25343D).withValues(alpha: 0.16)
                  : const Color(0xFFEFE6EE).withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _CallGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallOrb extends StatelessWidget {
  final List<AnimationController> ringControllers;
  final List<Animation<double>> ringScales;
  final List<Animation<double>> ringOpacities;
  final bool isProcessing;
  final bool isSpeaking;
  final ConversationTurnState state;

  const _CallOrb({
    required this.ringControllers,
    required this.ringScales,
    required this.ringOpacities,
    required this.isProcessing,
    required this.isSpeaking,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fill = isDark
        ? const [Color(0xFF52555D), Color(0xFF2C2F36)]
        : const [Colors.white, Color(0xFFE7EAF0)];
    final speakingFill = isDark
        ? [AppColors.secondaryLight, AppColors.secondary]
        : [const Color(0xFFFFE7BC), AppColors.secondary];

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isProcessing)
            ...ringControllers.asMap().entries.map((entry) {
              final index = entry.key;
              return AnimatedBuilder(
                animation: ringControllers[index],
                builder: (_, __) => Transform.scale(
                  scale: ringScales[index].value,
                  child: Opacity(
                    opacity: ringOpacities[index].value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.glassBorder(context),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          Container(
            width: 212,
            height: 212,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.glassBorder(context),
                width: 1.4,
              ),
              color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.14),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 158,
            height: 158,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSpeaking ? speakingFill : fill,
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.82),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSpeaking ? AppColors.secondary : AppColors.glassShadow(context))
                      .withValues(alpha: isSpeaking ? 0.26 : 0.18),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: state == ConversationTurnState.finished
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 50)
                  : Icon(
                      Icons.mic_none_rounded,
                      color: AppColors.isDark(context)
                          ? Colors.white70
                          : const Color(0xFF111111),
                      size: 54,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  final ConversationTurnState state;
  final bool muted;

  const _StateLabel({
    required this.state,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (state) {
      case ConversationTurnState.idle:
        label = 'Starting...';
        color = AppColors.hint(context);
      case ConversationTurnState.listening:
        label = muted ? 'Muted' : 'Listening...';
        color = AppColors.primaryLight;
      case ConversationTurnState.processing:
        label = 'Connecting...';
        color = AppColors.secondaryLight;
      case ConversationTurnState.speaking:
        label = 'Cura is speaking';
        color = AppColors.secondary;
      case ConversationTurnState.finished:
        label = 'Call ended';
        color = AppColors.success;
      case ConversationTurnState.error:
        label = 'Try speaking again';
        color = AppColors.sos(context);
    }

    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MiniTranscriptRow extends StatelessWidget {
  final ConversationMessage message;

  const _MiniTranscriptRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              isUser ? 'You' : 'Cura',
              style: TextStyle(
                color: isUser ? AppColors.primaryLight : AppColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.hint(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.glassSecondaryFill(context)
                  : AppColors.glassFill(context).withValues(alpha: 0.68),
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Icon(
              icon,
              color: AppColors.label(context),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.hint(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

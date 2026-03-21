import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/conversation/providers/conversation_provider.dart';

class VoiceOrbWidget extends StatelessWidget {
  static const double outerSize = 190;
  static const double innerSize = 142;

  final ConversationTurnState turnState;
  final double amplitude;
  final VoidCallback onTap;

  const VoiceOrbWidget({
    super.key,
    required this.turnState,
    required this.amplitude,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = turnState == ConversationTurnState.idle ||
        turnState == ConversationTurnState.finished;
    final orbColor = _orbColor(context);
    final isDark = AppColors.isDark(context);
    final ringBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFD8DBE2);
    final outerFillColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.16);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring (listening only)
            if (turnState == ConversationTurnState.listening)
              _PulseRing(amplitude: amplitude),

            // Outer container ring
            Container(
              key: const ValueKey('voice-orb-shell'),
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIdle
                    ? outerFillColor
                    : orbColor.withValues(alpha: isDark ? 0.12 : 0.1),
                border: Border.all(color: ringBorderColor, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glassShadow(context).withValues(
                      alpha: isDark ? 0.34 : 0.18,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                    spreadRadius: -14,
                  ),
                ],
              ),
            ),

            // Core orb
            AnimatedContainer(
              key: const ValueKey('voice-orb-core'),
              duration: const Duration(milliseconds: 300),
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIdle ? AppColors.glassSecondaryFill(context) : null,
                gradient: RadialGradient(
                  colors: _gradientColors(context),
                  center: Alignment.topLeft,
                  radius: 1.2,
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1.2,
                ),
                boxShadow: [
                  if (!isIdle)
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.26),
                      blurRadius: 20,
                      spreadRadius: turnState == ConversationTurnState.listening
                          ? 2 + amplitude * 8
                          : 1.5,
                    ),
                  BoxShadow(
                    color: AppColors.glassShadow(context).withValues(
                      alpha: isDark ? 0.3 : 0.12,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Center(child: _orbIcon(context)),
            ),
          ],
        ),
      ),
    );
  }

  Color _orbColor(BuildContext context) {
    switch (turnState) {
      case ConversationTurnState.listening:
        return AppColors.orbListening;
      case ConversationTurnState.speaking:
      case ConversationTurnState.processing:
        return AppColors.orbSpeaking;
      default:
        return AppColors.orbIdleColor(context);
    }
  }

  List<Color> _gradientColors(BuildContext context) {
    switch (turnState) {
      case ConversationTurnState.listening:
        return [AppColors.orbListening, const Color(0xFF3A5F84)];
      case ConversationTurnState.speaking:
        return [AppColors.orbSpeaking, AppColors.primary];
      case ConversationTurnState.processing:
        return [AppColors.secondary, AppColors.primary];
      case ConversationTurnState.finished:
        return AppColors.isDark(context)
            ? [
                const Color(0xFF4B4E55),
                const Color(0xFF2A2C31),
              ]
            : [
                Colors.white,
                const Color(0xFFE7E9EF),
              ];
      default:
        return AppColors.isDark(context)
            ? [
                const Color(0xFF52555D),
                const Color(0xFF30333A),
              ]
            : [
                Colors.white,
                const Color(0xFFE8EAF0),
              ];
    }
  }

  Widget _orbIcon(BuildContext context) {
    final idleIconColor = AppColors.isDark(context)
        ? Colors.white70
        : const Color(0xFF111111);
    switch (turnState) {
      case ConversationTurnState.listening:
        return const Icon(Icons.mic, color: Colors.white, size: 46);
      case ConversationTurnState.speaking:
        return const Icon(Icons.volume_up_rounded, color: Colors.white, size: 46)
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(end: 1.15, duration: 600.ms)
            .then()
            .scaleXY(end: 1.0, duration: 600.ms);
      case ConversationTurnState.processing:
        return const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        );
      case ConversationTurnState.finished:
        return const Icon(Icons.check_rounded, color: Colors.white, size: 44);
      default:
        return Icon(Icons.mic_none_rounded, color: idleIconColor, size: 46);
    }
  }
}

class _PulseRing extends StatefulWidget {
  final double amplitude;
  const _PulseRing({required this.amplitude});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final scale = 1.0 + _controller.value * (0.3 + widget.amplitude * 0.5);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: VoiceOrbWidget.outerSize - 20,
            height: VoiceOrbWidget.outerSize - 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.orbListening.withValues(
                  alpha: (1 - _controller.value) * 0.36,
                ),
                width: 1.8,
              ),
            ),
          ),
        );
      },
    );
  }
}

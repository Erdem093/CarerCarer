import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/app_mode_provider.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/conversation/providers/conversation_provider.dart';
import '../../../services/claude_service.dart';
import '../../../services/twilio_service.dart';
import '../widgets/voice_orb_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _sessionActive = false;

  @override
  Widget build(BuildContext context) {
    final context0 = TwilioService.contextForNow();
    final convState = ref.watch(conversationProvider(context0));
    final labelColor = AppColors.label(context);
    final isCompactHeight = MediaQuery.sizeOf(context).height < 760;
    final profileName = ref.watch(userProfileProvider).valueOrNull?.displayName;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _greetingLine(),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 27,
                                          fontWeight: FontWeight.w400,
                                          height: 1.1,
                                          letterSpacing: -1.15,
                                          color: labelColor,
                                        ),
                                      ),
                                      if (profileName != null && profileName.trim().isNotEmpty)
                                        Text(
                                          profileName.trim(),
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w400,
                                            height: 1.1,
                                            letterSpacing: -1.15,
                                            color: labelColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  _CarerModeButton(
                                    onTap: () => _toggleCarerMode(context),
                                  ),
                                  const SizedBox(width: 12),
                                  _EmergencyButton(
                                    onTap: () => _triggerManualEmergency(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: isCompactHeight ? 20 : 26),
                          Center(
                            child: Column(
                              children: [
                                VoiceOrbWidget(
                                  turnState: _sessionActive
                                      ? convState.turnState
                                      : ConversationTurnState.idle,
                                  amplitude: convState.micAmplitude,
                                  onTap: () => _handleOrbTap(context, context0),
                                ),
                                SizedBox(height: isCompactHeight ? 14 : 18),
                                Text(
                                  _orbLabel(convState.turnState),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isCompactHeight ? 20 : 24,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.8,
                                    color: labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 20 : 26),
                          _ActionCard(
                            panelKey: const ValueKey('home-letter-card'),
                            icon: Icons.description_outlined,
                            title: 'Explain a letter',
                            subtitle: 'Take a photo of any official letter',
                            onTap: () => context.push('/home/letter'),
                          ),
                          const SizedBox(height: 14),
                          _ActionCard(
                            panelKey: const ValueKey('home-schedule-card'),
                            icon: Icons.call_outlined,
                            title: 'Schedule my check-ins',
                            subtitle: 'Set times for Cura to call you',
                            onTap: () => context.push('/profile/schedule'),
                          ),
                          SizedBox(height: isCompactHeight ? 12 : 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleOrbTap(BuildContext context, ConversationContext ctx) {
    if (_sessionActive) {
      setState(() => _sessionActive = false);
      context.push('/home/session/summary');
    } else {
      setState(() => _sessionActive = true);
      context.push('/home/session', extra: ctx);
    }
  }

  Future<void> _toggleCarerMode(BuildContext context) async {
    final modeNotifier = ref.read(appModeProvider.notifier);
    final currentMode = ref.read(appModeProvider);
    if (currentMode == AppMode.user) {
      final existingPin = await modeNotifier.getPin();
      if (!context.mounted) return;
      if (existingPin == null) {
        final pin = await _showSetPinDialog(context);
        if (pin != null) {
          await modeNotifier.setPin(pin);
          await modeNotifier.setMode(AppMode.carer);
        }
      } else {
        final entered = await _showEnterPinDialog(context);
        if (!context.mounted) return;
        if (entered == existingPin) {
          await modeNotifier.setMode(AppMode.carer);
        } else if (entered != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')),
          );
        }
      }
    } else {
      modeNotifier.setMode(AppMode.user);
    }
  }

  Future<String?> _showSetPinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a carer PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a 4-digit PIN to protect carer settings.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.length == 4) {
                Navigator.pop(dialogContext, ctrl.text);
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showEnterPinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Carer PIN'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(fontSize: 24, letterSpacing: 12),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualEmergency(BuildContext context) async {
    final emergency = ref.read(emergencyServiceProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    await emergency.initiateEscalation(
      context,
      triggerText: 'Manual emergency button pressed',
      userName: profile?.displayName ?? 'the carer',
    );
  }

  String _greetingLine() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _orbLabel(ConversationTurnState state) {
    switch (state) {
      case ConversationTurnState.listening:
        return 'Listening...';
      case ConversationTurnState.processing:
        return 'Thinking...';
      case ConversationTurnState.speaking:
        return 'Cura is speaking';
      case ConversationTurnState.finished:
        return 'Session complete';
      default:
        return 'Tap to talk to Cura';
    }
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

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
                ? const [
                    Color(0xFF181A1F),
                    Color(0xFF101217),
                  ]
                : const [
                    Color(0xFFFBFAF7),
                    Color(0xFFF5F6F9),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -80,
              child: _BlurBlob(
                size: 180,
                color: isDark
                    ? const Color(0xFF3F5866).withValues(alpha: 0.12)
                    : const Color(0xFFF0E4D4).withValues(alpha: 0.48),
              ),
            ),
            Positioned(
              top: 160,
              right: -40,
              child: _BlurBlob(
                size: 180,
                color: isDark
                    ? const Color(0xFF5B4A3A).withValues(alpha: 0.08)
                    : const Color(0xFFE1E8F8).withValues(alpha: 0.26),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -10,
              child: _BlurBlob(
                size: 160,
                color: isDark
                    ? const Color(0xFF283842).withValues(alpha: 0.1)
                    : const Color(0xFFF2E9EF).withValues(alpha: 0.24),
              ),
            ),
            Positioned(
              bottom: 60,
              right: -30,
              child: _BlurBlob(
                size: 140,
                color: isDark
                    ? const Color(0xFF3C434C).withValues(alpha: 0.08)
                    : const Color(0xFFE8EEF8).withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
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

class _CarerModeButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _CarerModeButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appModeProvider);

    return _GlassPanel(
      panelKey: const ValueKey('home-carer-button'),
      width: 58,
      height: 58,
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 28,
          color: AppColors.label(context),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EmergencyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      panelKey: const ValueKey('home-sos-button'),
      width: 58,
      height: 58,
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Center(
        child: Text(
          'SOS',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.sos(context),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Key? panelKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    this.panelKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.label(context);
    final hintColor = AppColors.hint(context);

    return _GlassPanel(
      panelKey: panelKey,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.glassBorder(context),
                width: 1.5,
              ),
              color: AppColors.glassSecondaryFill(context).withValues(
                alpha: AppColors.isDark(context) ? 0.5 : 0.88,
              ),
            ),
            child: Icon(
              icon,
              size: 30,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.08,
                    letterSpacing: -0.7,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.22,
                    letterSpacing: -0.15,
                    color: hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Key? panelKey;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;

  const _GlassPanel({
    super.key,
    this.panelKey,
    required this.child,
    required this.borderRadius,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Ink(
              key: panelKey,
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.glassHighlight(context).withValues(
                      alpha: isDark ? 0.06 : 0.9,
                    ),
                    AppColors.glassFill(context),
                  ],
                ),
                border: Border.all(
                  color: AppColors.glassBorder(context),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glassShadow(context),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                    spreadRadius: -14,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

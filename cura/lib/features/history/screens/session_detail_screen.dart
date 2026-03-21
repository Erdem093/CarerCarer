import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../models/check_in_session.dart';
import '../../../models/conversation_message.dart';

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.watch(supabaseServiceProvider);

    return AppPageScaffold(
      title: 'Session details',
      subtitle: 'Review the transcript and any wellbeing markers recorded during this check-in.',
      child: FutureBuilder<List<CheckInSession>>(
        future: supabase.fetchRecentSessions(limit: 50),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final session =
              snapshot.data!.where((entry) => entry.id == sessionId).firstOrNull;
          if (session == null) {
            return GlassPanel(
              child: Text(
                'Session not found.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.hint(context),
                ),
              ),
            );
          }

          return _SessionContent(session: session);
        },
      ),
    );
  }
}

class _SessionContent extends StatelessWidget {
  final CheckInSession session;

  const _SessionContent({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(
              label: session.contextLabel,
              value: session.mode == SessionMode.phoneCall ? 'Call' : 'In app',
              color: AppColors.primaryLight,
            ),
            if (session.sleepScore != null)
              _MetricChip(
                label: 'Sleep',
                value: '${session.sleepScore}/10',
                color: AppColors.secondary,
              ),
            if (session.painScore != null)
              _MetricChip(
                label: 'Pain',
                value: '${session.painScore}/10',
                color: AppColors.warning,
              ),
            if (session.moodScore != null)
              _MetricChip(
                label: 'Mood',
                value: '${session.moodScore}/10',
                color: AppColors.primary,
              ),
          ],
        ),
        const SizedBox(height: 24),
        const AppSectionLabel('Conversation'),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: session.transcript
                .map((message) => _BubbleRow(message: message))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.hint(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleRow extends StatelessWidget {
  final ConversationMessage message;

  const _BubbleRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.92)
              : AppColors.glassSecondaryFill(context),
          border: Border.all(
            color: isUser
                ? AppColors.primary.withValues(alpha: 0.24)
                : AppColors.glassBorder(context),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.label(context),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

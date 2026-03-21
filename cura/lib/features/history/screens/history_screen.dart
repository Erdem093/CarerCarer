import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';
import '../../../models/check_in_session.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.watch(supabaseServiceProvider);

    return AppPageScaffold(
      title: 'History',
      subtitle: 'Your recent check-ins and the patterns Cura has spotted this week.',
      showBackButton: false,
      child: FutureBuilder(
        future: Future.wait([
          supabase.fetchWeeklyMetrics(),
          supabase.fetchRecentSessions(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final metrics = snapshot.data![0] as List<Map<String, dynamic>>;
          final sessions = snapshot.data![1] as List<CheckInSession>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionLabel('This Week'),
              const SizedBox(height: 12),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seven-day view',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 220, child: _WeekChart(metrics: metrics)),
                    const SizedBox(height: 10),
                    const _ChartLegend(),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const AppSectionLabel('Recent Sessions'),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                GlassPanel(
                  child: Text(
                    'No sessions yet. Tap the orb on the home screen to start your first check-in.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.hint(context),
                    ),
                  ),
                )
              else
                ...sessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionCard(
                      session: session,
                      onTap: () => context.push('/history/${session.id}'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;

  const _WeekChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));

    double avgForDay(DateTime day, String field) {
      final dayMetrics = metrics.where((m) {
        final dt = DateTime.parse(m['started_at'] as String);
        return dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day;
      }).toList();
      if (dayMetrics.isEmpty) return 0;
      final vals = dayMetrics
          .where((m) => m[field] != null)
          .map((m) => (m[field] as int).toDouble());
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    return BarChart(
      BarChartData(
        maxY: 10,
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(7, (i) {
          final day = days[i];
          return BarChartGroupData(
            x: i,
            barsSpace: 5,
            barRods: [
              BarChartRodData(
                toY: avgForDay(day, 'sleep_score'),
                color: AppColors.secondary.withValues(alpha: 0.85),
                width: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              BarChartRodData(
                toY: avgForDay(day, 'mood_score'),
                color: AppColors.primaryLight.withValues(alpha: 0.9),
                width: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: AppColors.muted(context),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final day = days[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      color: AppColors.muted(context),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.glassBorder(context).withValues(alpha: 0.55),
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(
          color: AppColors.secondary.withValues(alpha: 0.85),
          label: 'Sleep',
        ),
        const SizedBox(width: 20),
        _LegendDot(
          color: AppColors.primaryLight.withValues(alpha: 0.9),
          label: 'Mood',
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.hint(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final CheckInSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flagged = session.crisisFlagged;
    final accent = flagged ? AppColors.sos(context) : AppColors.label(context);

    return GlassPanel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder(context)),
              color: flagged
                  ? AppColors.sosBg(context).withValues(alpha: 0.85)
                  : AppColors.glassSecondaryFill(context),
            ),
            child: Icon(
              flagged
                  ? Icons.warning_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForSession(session),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEE d MMM, HH:mm').format(session.startedAt.toLocal()),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.hint(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.muted(context),
          ),
        ],
      ),
    );
  }

  String _titleForSession(CheckInSession session) {
    final contextName = switch (session.context) {
      SessionContext.morning => 'Morning check-in',
      SessionContext.afternoon => 'Afternoon check-in',
      SessionContext.evening => 'Evening check-in',
      SessionContext.adhoc => 'Check-in',
    };

    return session.crisisFlagged ? '$contextName flagged' : contextName;
  }
}

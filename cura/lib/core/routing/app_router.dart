import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/conversation/screens/active_session_screen.dart';
import '../../features/conversation/screens/session_summary_screen.dart';
import '../../features/letter_explainer/screens/letter_capture_screen.dart';
import '../../features/letter_explainer/screens/letter_result_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/history/screens/session_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/emergency_contacts_screen.dart';
import '../../features/profile/screens/call_schedule_screen.dart';
import '../../services/claude_service.dart';
import '../di/app_mode_provider.dart';
import '../theme/app_colors.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNavBar(shell: shell),
      branches: [
        // ── Tab 0: Home ───────────────────────────────────────────────────
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'session',
                builder: (context, state) {
                  final context0 = state.extra as ConversationContext? ??
                      ConversationContext.adhoc;
                  return ActiveSessionScreen(conversationContext: context0);
                },
              ),
              GoRoute(
                path: 'session/summary',
                builder: (context, state) => const SessionSummaryScreen(),
              ),
              GoRoute(
                path: 'letter',
                builder: (context, state) => const LetterCaptureScreen(),
              ),
              GoRoute(
                path: 'letter/result',
                builder: (context, state) {
                  final args = state.extra as Map<String, dynamic>?;
                  return LetterResultScreen(
                    documentType: args?['documentType'] as String? ?? '',
                    meaning: args?['meaning'] as String? ?? '',
                    action: args?['action'] as String? ?? '',
                    consequence: args?['consequence'] as String? ?? '',
                    isFromHistory: args?['isFromHistory'] as bool? ?? false,
                  );
                },
              ),
            ],
          ),
        ]),

        // ── Tab 1: History ────────────────────────────────────────────────
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    SessionDetailScreen(sessionId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),

        // ── Tab 2: Profile ────────────────────────────────────────────────
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'emergency-contacts',
                builder: (context, state) => const EmergencyContactsScreen(),
              ),
              GoRoute(
                path: 'schedule',
                builder: (context, state) => const CallScheduleScreen(),
              ),
            ],
          ),
        ]),
      ],
    ),
  ],
);

class _ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const _ScaffoldWithNavBar({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final isCarerMode = mode == AppMode.carer;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: shell,
        bottomNavigationBar:
            isCarerMode ? _FrostedBottomNavBar(shell: shell) : null,
      ),
    );
  }
}

class _FrostedBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _FrostedBottomNavBar({required this.shell});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassFill(context).withValues(
              alpha: isDark ? 0.76 : 0.92,
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder(context),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glassShadow(context).withValues(
                  alpha: isDark ? 0.32 : 0.12,
                ),
                blurRadius: 24,
                offset: const Offset(0, -6),
                spreadRadius: -14,
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(18, 4, 18, bottomInset + 8),
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.home_filled,
                label: 'Home',
                selected: shell.currentIndex == 0,
                onTap: () => shell.goBranch(
                  0,
                  initialLocation: shell.currentIndex == 0,
                ),
              ),
              _BottomNavItem(
                icon: Icons.history,
                label: 'History',
                selected: shell.currentIndex == 1,
                onTap: () => shell.goBranch(
                  1,
                  initialLocation: shell.currentIndex == 1,
                ),
              ),
              _BottomNavItem(
                icon: Icons.person,
                label: 'Profile',
                selected: shell.currentIndex == 2,
                onTap: () => shell.goBranch(
                  2,
                  initialLocation: shell.currentIndex == 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.label(context);
    final inactiveColor = AppColors.muted(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 34 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: selected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Icon(
                icon,
                size: 26,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

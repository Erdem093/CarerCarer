import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_surfaces.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Session complete',
      subtitle:
          'Your check-in has been saved. Any medications or appointments mentioned have been added.',
      showBackButton: false,
      child: GlassPanel(
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(context)),
                color: AppColors.glassSecondaryFill(context),
              ),
              child: Icon(
                Icons.check_rounded,
                color: AppColors.primaryLight,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Well done',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You can head back home or open your history to review the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.hint(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to home'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/history'),
              child: const Text('View history'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppPageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry contentPadding;
  final bool scrollable;
  final bool showBackButton;
  final CrossAxisAlignment crossAxisAlignment;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.scrollable = true,
    this.showBackButton = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          AppPageHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            showBackButton: showBackButton,
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackdrop()),
          SafeArea(
            child: scrollable
                ? SingleChildScrollView(child: body)
                : body,
          ),
        ],
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final showLeading = showBackButton && canPop;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLeading) ...[
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    height: 1.05,
                    letterSpacing: -1.0,
                    color: AppColors.label(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: AppColors.hint(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 14),
          Row(children: actions),
        ],
      ],
    );
  }
}

class AppAmbientBackdrop extends StatelessWidget {
  const AppAmbientBackdrop({super.key});

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

class GlassPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;
  final Key? panelKey;

  const GlassPanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.width,
    this.height,
    this.panelKey,
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
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glassShadow(context),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
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

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final double iconSize;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 48,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: color ?? AppColors.label(context),
        ),
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String text;

  const AppSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: AppColors.hint(context),
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

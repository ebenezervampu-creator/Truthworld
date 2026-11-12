import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shared dark minimalist option card container using TruthWorld theme tokens.
class DubbingOptionCard extends StatelessWidget {
  const DubbingOptionCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const radius = BorderRadius.all(Radius.circular(14));

    return Material(
      color: colors.appBarSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: colors.hoverOverlay,
        splashColor: colors.selectedOverlay,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Segmented mode switcher matching TruthWorld's monochrome white-brand aesthetic:
/// - Tab 0: AI Dubbing
/// - Tab 1: Direct Audio Track
class DubbingModeSwitcher extends StatelessWidget {
  const DubbingModeSwitcher({
    required this.state,
    super.key,
  });

  final DubbingOptionsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Obx(() {
      final activeTab = state.selectedTab.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeTabPill(
                isActive: activeTab == 0,
                icon: Icons.mic_none_rounded,
                label: 'AI Dubbing',
                onTap: () => state.selectedTab.value = 0,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _ModeTabPill(
                isActive: activeTab == 1,
                icon: Icons.graphic_eq_rounded,
                label: 'Direct Audio Track',
                onTap: () => state.selectedTab.value = 1,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ModeTabPill extends StatelessWidget {
  const _ModeTabPill({
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;
    final fgColor = isActive ? Colors.black : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.button.copyWith(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: fgColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

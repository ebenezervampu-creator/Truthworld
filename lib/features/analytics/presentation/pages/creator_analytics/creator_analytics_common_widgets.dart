import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Section header with brand accent indicator bar for creator analytics.
class CreatorSectionHeader extends StatelessWidget {
  const CreatorSectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Standard glass/surface card with border and elevation for analytics charts.
class CreatorGlassCard extends StatelessWidget {
  const CreatorGlassCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Legend item displaying a color circle indicator, label, and formatted value.
class CreatorLegendItem extends StatelessWidget {
  const CreatorLegendItem({
    required this.color,
    required this.label,
    required this.value,
    super.key,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// GetX controller managing the live viewer pulsing animation lifecycle.
class CreatorPulsingDotController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> opacity;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void onClose() {
    animationController.stop();
    animationController.dispose();
    super.onClose();
  }
}

/// Declarative pulsing dot indicator for live viewer counter in app bar.
class CreatorPulsingDot extends StatelessWidget {
  const CreatorPulsingDot({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CreatorPulsingDotController>(
      init: CreatorPulsingDotController(),
      builder: (controller) {
        return FadeTransition(
          opacity: controller.opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Pure helper for formatting large numerical metrics (K, M).
String formatAnalyticsNumber(int number) {
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toString();
}

import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

import 'package:truthworld/theme/tw_radius.dart';

/// Reusable card container used throughout the Monetization screens.
class MonetizationCardContainer extends StatelessWidget {
  const MonetizationCardContainer({
    required this.child,
    super.key,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final effectivePadding = padding ?? EdgeInsets.all(isMobile ? 12.0 : 20.0);

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: TWRadius.xlBorderRadius,
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

/// Reusable section title bar with a colored vertical accent pill.
class MonetizationSectionTitle extends StatelessWidget {
  const MonetizationSectionTitle({
    required this.title,
    super.key,
    this.accentColor = AppColors.brand,
    this.trailing,
  });

  final String title;
  final Color accentColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

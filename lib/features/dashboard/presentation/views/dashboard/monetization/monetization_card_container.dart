import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Reusable card container used throughout the Monetization screens.
/// Styled with exact Library theme cardColor and subtle border.
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
    final effectivePadding = padding ?? EdgeInsets.all(isMobile ? 14.0 : 20.0);

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Exact Library cardColor
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: child,
    );
  }
}

/// Reusable section title bar with clean typography matching Library page.
class MonetizationSectionTitle extends StatelessWidget {
  const MonetizationSectionTitle({
    required this.title,
    super.key,
    this.accentColor = Colors.white,
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

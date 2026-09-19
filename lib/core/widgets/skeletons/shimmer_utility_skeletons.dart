import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Shimmering text widget typically used inside a button when in a loading or submitting state.
class ShimmerButtonText extends StatelessWidget {
  const ShimmerButtonText(
    this.text, {
    super.key,
    this.style,
    this.baseColor,
    this.highlightColor,
  });

  final String text;
  final TextStyle? style;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.labelLarge;
    final textColor = defaultStyle?.color ?? AppColors.textPrimary;

    return Shimmer.fromColors(
      baseColor: baseColor ?? textColor.withValues(alpha: 0.6),
      highlightColor: highlightColor ?? textColor,
      child: Text(text, style: defaultStyle),
    );
  }
}

/// Standalone video grid loading skeleton with responsive column calculation.
class ShimmerVideoGrid extends StatelessWidget {
  const ShimmerVideoGrid({
    super.key,
    this.itemCount = 6,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final int itemCount;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final isMobile = !isDesktop && !isTablet;
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isMobile ? 1.2 : 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.1,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}

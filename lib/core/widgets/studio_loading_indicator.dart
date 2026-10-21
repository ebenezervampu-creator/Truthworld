import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Lightweight, high-performance loading indicator for Creator Studio sub-pages.
/// Replaces heavy 60fps shimmer ticker loops with a minimal, cost-effective,
/// WCAG AA compliant indicator that renders instantaneously with zero CPU/GPU jank.
class StudioLoadingIndicator extends StatelessWidget {
  const StudioLoadingIndicator({
    super.key,
    this.message,
    this.isFullScreen = true,
    this.size = 28.0,
    this.strokeWidth = 2.5,
  });

  /// Optional helpful contextual status text (e.g. 'Loading audience insights...').
  final String? message;

  /// Whether to expand to take available page area or render inline.
  final bool isFullScreen;

  /// Diameter of the circular progress spinner.
  final double size;

  /// Stroke thickness of the spinner.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final spinnerColor = isDarkMode ? Colors.white : Colors.black87;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : const Color(0xFF606060),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (isFullScreen) {
      return ColoredBox(
        color: AppColors.bgPage,
        child: content,
      );
    }

    return content;
  }
}

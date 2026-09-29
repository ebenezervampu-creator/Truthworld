import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/theme/tw_radius.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Signature TruthWorld credibility badge featuring neon holographic accents,
/// high-precision typography with tabular figures, and status-aware styling.
class TruthCredibilityBadge extends StatelessWidget {
  const TruthCredibilityBadge({
    required this.label,
    this.color,
    this.icon,
    this.isVerified = false,
    this.isDisputed = false,
    this.isFalse = false,
    this.score,
    this.showGlow = true,
    this.padding,
    this.fontSize = 10,
    this.iconSize = 12,
    this.pill = true,
    super.key,
  });

  /// Factory constructor to resolve status from a raw string.
  factory TruthCredibilityBadge.fromStatus({
    required String status,
    double? score,
    bool showGlow = true,
    EdgeInsetsGeometry? padding,
    double fontSize = 10,
    double iconSize = 12,
    bool pill = true,
    Key? key,
  }) {
    final lower = status.toLowerCase();
    final isVerified = lower == 'correct' ||
        lower == 'mostly_correct' ||
        lower == 'verified' ||
        lower == 'true' ||
        lower == 'verified true';
    final isDisputed = lower.contains('dispute') ||
        lower.contains('caution') ||
        lower.contains('mostly_false') ||
        lower.contains('unverified') ||
        lower == 'unconfirmed';
    final isFalse = lower == 'false' || lower == 'incorrect';

    const color = Colors.white;
    String label;
    IconData icon;

    if (isVerified) {
      label = 'VERIFIED TRUE';
      icon = Icons.verified_rounded;
    } else if (isFalse) {
      label = 'FALSE';
      icon = Icons.cancel_outlined;
    } else if (isDisputed) {
      label = 'UNCONFIRMED';
      icon = Icons.warning_amber_rounded;
    } else {
      label = 'ANALYZED';
      icon = Icons.help_outline_rounded;
    }

    return TruthCredibilityBadge(
      key: key,
      label: label,
      color: color,
      icon: icon,
      isVerified: isVerified,
      isDisputed: isDisputed,
      isFalse: isFalse,
      score: score,
      showGlow: showGlow,
      padding: padding,
      fontSize: fontSize,
      iconSize: iconSize,
      pill: pill,
    );
  }

  /// Factory constructor to build from a [ClaimVerdictInfo].
  factory TruthCredibilityBadge.fromVerdict({
    required ClaimVerdictInfo verdict,
    double? score,
    bool showGlow = true,
    EdgeInsetsGeometry? padding,
    double fontSize = 10,
    double iconSize = 12,
    bool pill = true,
    Key? key,
  }) {
    return TruthCredibilityBadge(
      key: key,
      label: verdict.label,
      color: verdict.color,
      icon: verdict.icon,
      isVerified: verdict.isVerified,
      isDisputed: verdict.isCaution,
      isFalse: verdict.isFalse,
      score: score ?? verdict.confidenceVal,
      showGlow: showGlow,
      padding: padding,
      fontSize: fontSize,
      iconSize: iconSize,
      pill: pill,
    );
  }

  final String label;
  final Color? color;
  final IconData? icon;
  final bool isVerified;
  final bool isDisputed;
  final bool isFalse;
  final double? score;
  final bool showGlow;
  final EdgeInsetsGeometry? padding;
  final double fontSize;
  final double iconSize;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    const effectiveColor = Colors.white;

    final effectiveIcon = icon ??
        (isVerified
            ? Icons.verified_rounded
            : isFalse
                ? Icons.cancel_outlined
                : isDisputed
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded);

    final effectiveBorderRadius =
        pill ? TWRadius.pillBorderRadius : TWRadius.smBorderRadius;

    final alpha = isVerified ? 0.15 : (isFalse ? 0.08 : (isDisputed ? 0.09 : 0.10));
    final borderAlpha = isVerified ? 0.35 : (isFalse ? 0.18 : (isDisputed ? 0.20 : 0.22));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          color: effectiveColor.withValues(alpha: alpha),
          border: Border.all(
            color: effectiveColor.withValues(alpha: borderAlpha),
          ),
        ),
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3.5,
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            effectiveIcon,
            size: iconSize,
            color: effectiveColor,
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
              letterSpacing: 0.6,
              fontFamily: TWTypography.uiFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.2),
                borderRadius: TWRadius.smBorderRadius,
              ),
              child: Text(
                score! <= 1.0
                    ? '${(score! * 100).toStringAsFixed(0)}%'
                    : '${score!.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w800,
                  color: effectiveColor,
                  fontFamily: TWTypography.uiFamily,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}

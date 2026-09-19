import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/theme/app_colors.dart';
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

    Color color;
    String label;
    IconData icon;

    if (isVerified) {
      color = const Color(0xFF00E676);
      label = 'VERIFIED TRUE';
      icon = Icons.verified_rounded;
    } else if (isFalse) {
      color = AppColors.error;
      label = 'FALSE';
      icon = Icons.cancel_rounded;
    } else if (isDisputed) {
      color = AppColors.warning;
      label = 'UNCONFIRMED';
      icon = Icons.warning_amber_rounded;
    } else {
      color = AppColors.info;
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
    final effectiveColor = color ??
        (isVerified
            ? const Color(0xFF00E676)
            : isFalse
                ? AppColors.error
                : isDisputed
                    ? AppColors.warning
                    : AppColors.info);

    final effectiveIcon = icon ??
        (isVerified
            ? Icons.verified_rounded
            : isFalse
                ? Icons.cancel_rounded
                : isDisputed
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded);

    final effectiveBorderRadius =
        pill ? TWRadius.pillBorderRadius : TWRadius.smBorderRadius;

    final baseGlowColor = isVerified
        ? const Color(0xFF00F2FE)
        : effectiveColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: baseGlowColor.withValues(alpha: isVerified ? 0.28 : 0.16),
                  blurRadius: isVerified ? 8 : 5,
                ),
              ]
            : null,
        gradient: isVerified
            ? const LinearGradient(
                colors: [
                  Color(0x3300F2FE),
                  Color(0x1F4FACFE),
                  Color(0x3300E676),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isVerified ? null : effectiveColor.withValues(alpha: 0.14),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF00E676).withValues(alpha: 0.75)
              : effectiveColor.withValues(alpha: 0.55),
          width: isVerified ? 1.2 : 1.0,
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
            color: isVerified ? const Color(0xFF00F2FE) : effectiveColor,
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: isVerified ? const Color(0xFFE0F7FA) : effectiveColor,
              letterSpacing: 0.8,
              fontFamily: TWTypography.uiFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.22),
                borderRadius: TWRadius.smBorderRadius,
              ),
              child: Text(
                score! <= 1.0
                    ? '${(score! * 100).toStringAsFixed(0)}%'
                    : '${score!.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w800,
                  color: isVerified ? const Color(0xFF00E676) : effectiveColor,
                  fontFamily: TWTypography.uiFamily,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

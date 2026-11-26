import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Pulsing emerald live beacon used to indicate active/ready dubbing languages
/// without using `StatefulWidget` or `setState`.
class LivePulseDot extends StatelessWidget {
  const LivePulseDot({
    this.size = 7,
    this.color = AppColors.success,
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.2,
      height: size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.9,
            height: size * 1.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.35),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(0.65, 0.65),
                end: const Offset(1.35, 1.35),
                duration: 1400.ms,
                curve: Curves.easeOut,
              )
              .fadeOut(
                begin: 0.75,
                duration: 1400.ms,
                curve: Curves.easeOut,
              ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium, industry-standard language selection card for TruthWorld Dubbing Studio.
///
/// Features:
/// - Country flag via [ChannelWizardCountryCard.buildCountryFlagByCode]
/// - Animated pulsing `LIVE` indicator for active languages
/// - Shimmering `SOON` badge for upcoming languages
/// - Smooth `AnimatedContainer` selection state (Zero `setState` Policy)
class DubbingLanguageCard extends StatelessWidget {
  const DubbingLanguageCard({
    required this.language,
    required this.isAvailable,
    required this.isNotPlanned,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final DubbingLanguage language;
  final bool isAvailable;
  final bool isNotPlanned;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = isAvailable
        ? '${language.name}, live'
        : (isNotPlanned
            ? '${language.name}, not yet supported'
            : '${language.name}, coming soon');

    final cardGradient = isSelected
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF262A34),
              Color(0xFF191C24),
            ],
          )
        : (isAvailable
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1D24),
                  Color(0xFF13151A),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bgInput.withValues(alpha: 0.65),
                  AppColors.bgInput.withValues(alpha: 0.45),
                ],
              ));

    final borderColor = isSelected
        ? AppColors.brand
        : (isAvailable
            ? AppColors.success.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.06));

    return Semantics(
      enabled: isAvailable,
      selected: isSelected,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: cardGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : (isAvailable
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null),
            ),
            child: Row(
              children: [
                // Country Flag Badge
                _FlagBadge(
                  countryCode: language.countryCode,
                  isAvailable: isAvailable,
                  isSelected: isSelected,
                ),
                const SizedBox(width: 11),

                // Language Name & Native Script
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        language.name,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isAvailable || isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary.withValues(alpha: 0.72),
                          fontSize: 13.5,
                          fontWeight: isAvailable || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isAvailable
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Column: Animated Status Pill + Selection Indicator
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AnimatedStatusPill(
                      isAvailable: isAvailable,
                      isNotPlanned: isNotPlanned,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : (isAvailable
                                ? Icons.radio_button_unchecked_rounded
                                : Icons.schedule_rounded),
                        key: ValueKey('${isSelected}_$isAvailable'),
                        color: isSelected
                            ? AppColors.brand
                            : (isAvailable
                                ? AppColors.textSecondary
                                : AppColors.textTertiary.withValues(alpha: 0.6)),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({
    required this.countryCode,
    required this.isAvailable,
    required this.isSelected,
  });

  final String countryCode;
  final bool isAvailable;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final flag = ChannelWizardCountryCard.buildCountryFlagByCode(
      countryCode,
      width: 30,
      height: 21,
      borderRadius: 4,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isSelected ? 0.1 : 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.35)
              : (isAvailable
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05)),
          width: 0.8,
        ),
      ),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.65,
        child: flag,
      ),
    );
  }
}

class _AnimatedStatusPill extends StatelessWidget {
  const _AnimatedStatusPill({
    required this.isAvailable,
    required this.isNotPlanned,
  });

  final bool isAvailable;
  final bool isNotPlanned;

  @override
  Widget build(BuildContext context) {
    if (isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.successContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35),
            width: 0.7,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LivePulseDot(size: 5.5),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.success,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    if (isNotPlanned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.6,
          ),
        ),
        child: Text(
          'N/A',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textTertiary.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // Upcoming ("SOON") with smooth studio shimmer sweep & breathing dot
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withValues(alpha: 0.85),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.35, end: 1.0, duration: 1500.ms),
          const SizedBox(width: 4),
          const Text(
            'SOON',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: 1200.ms,
          duration: 1600.ms,
          color: Colors.white.withValues(alpha: 0.16),
        );
  }
}

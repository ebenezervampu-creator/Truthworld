import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_plan_selection_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Card presenting Standard or Custom creator plan details and interactive selection.
class ChannelPlanCard extends StatelessWidget {
  const ChannelPlanCard({
    required this.controller,
    required this.type,
    required this.isDark,
    super.key,
  });

  final ChannelPlanSelectionController controller;
  final ChannelPlanType type;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isStandard = type == ChannelPlanType.standard;

    // Aesthetic colors for standard vs custom
    final primaryColor = isStandard
        ? const Color(0xFF3B82F6)
        : const Color(0xFF8B5CF6);
    final gradientStart = isStandard
        ? const Color(0xFF60A5FA)
        : const Color(0xFFA78BFA);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => controller.hoveredPlan.value = type,
      onExit: (_) => controller.hoveredPlan.value = null,
      child: GestureDetector(
        onTap: () => controller.selectedPlan.value = type,
        child: Obx(() {
          final isSelected = controller.selectedPlan.value == type;
          final isHovered = controller.hoveredPlan.value == type;
          final scale = isSelected ? 1.03 : (isHovered ? 1.015 : 1.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scaleByDouble(scale, scale, 1, 1),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? (isSelected
                        ? const Color(0xFF1E293B)
                        : (isHovered
                              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                              : const Color(0xFF111827)))
                  : (isSelected
                        ? AppColors.textPrimary
                        : (isHovered
                              ? AppColors.textPrimary
                              : const Color(0xFFF8FAFC))),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isHovered
                          ? primaryColor.withValues(alpha: 0.5)
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0))),
                width: isSelected ? 2.5 : (isHovered ? 1.5 : 1),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : (isHovered
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : []),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (isStandard)
                      const AppLogo(
                        size: 52,
                        borderRadius: 26,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gradientStart, primaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: AppColors.textPrimary,
                          size: 28,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStandard ? 'Standard Plan' : 'Custom Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            isStandard
                                ? 'YouTube-style Model'
                                : 'Maximum Revenue',
                            style: TextStyle(
                              fontSize: 14,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selection Indicator
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.black26),
                          width: 2,
                        ),
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.textPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Revenue Highlights
                ChannelPlanHighlight(
                  mainText: isStandard
                      ? '70% Creator Ad & Premium Revenue'
                      : '100% Creator Ad & Premium Revenue',
                  subText: isStandard ? '30% Platform Fee' : '0% Platform Fee',
                  color: primaryColor,
                ),
                const SizedBox(height: 20),
                ChannelPlanHighlight(
                  mainText: '100% Memberships & Superchats Revenue',
                  subText: '0% Platform Fee (Direct to Creator)',
                  color: primaryColor,
                ),
                const SizedBox(height: 32),

                const Divider(
                  color: AppColors.textSecondary,
                  height: 1,
                  thickness: 0.3,
                ),
                const SizedBox(height: 24),

                // Features List & How It Works
                if (isStandard) ...[
                  ChannelPlanFeatureRow(
                    text:
                        '70% Revenue Share from ads revenue and premium subscribers',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        '10 minutes total video upload duration limit per day (dynamic split e.g. 2 x 5 min or 7 min + 3 min)',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        'Resolution support up to 4K Ultra HD (Free viewing up to 1040p, Premium for 4K)',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        r'100% Free platform hosting & video transcoding ($0 upfront fees)',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        '100% Direct Fan Revenue: 0% commission on Memberships & Superchats!',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  ChannelPlanHowItWorksBox(
                    title: 'How Standard Channel Works:',
                    description:
                        'Standard channels require zero upfront costs or technical management. '
                        'Truthworld covers 100% of video hosting and transcoding. You earn a 70% revenue share on ads and premium views, '
                        'and keep 100% of direct fan support (Memberships, Superchats, etc.) with 0% platform commission.',
                    color: primaryColor,
                    isDark: isDark,
                  ),
                ] else ...[
                  ChannelPlanFeatureRow(
                    text:
                        r'🎁 $10 Free Infrastructure Grant included for every new Custom Channel!',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        '100% Creator revenue retention on ads, premium views, and content',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        'Unlimited video upload duration & max resolution up to 4K Ultra HD',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        r'Flexible Infrastructure Tiers ($15, $30, $45/mo, etc.) with allocated storage & bandwidth',
                    isDark: isDark,
                  ),
                  ChannelPlanFeatureRow(
                    text:
                        '100% Direct Fan Revenue: 0% commission on Memberships & Superchats!',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  ChannelPlanHowItWorksBox(
                    title: 'How Custom Channel Works:',
                    description:
                        'Custom channels provide maximum earning power with 100% ad & content revenue retention. '
                        r'Every new custom channel receives a $10 free infrastructure grant automatically credited to your balance. '
                        r'Choose an infrastructure plan ($15, $30, $45/mo) tailored to your storage & bandwidth needs, '
                        'and stream in up to 4K Ultra HD with 0% commission on direct fan contributions.',
                    color: primaryColor,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Highlight badge summarizing major revenue distribution percentages.
class ChannelPlanHighlight extends StatelessWidget {
  const ChannelPlanHighlight({
    required this.mainText,
    required this.subText,
    required this.color,
    super.key,
  });

  final String mainText;
  final String subText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature checklist item row.
class ChannelPlanFeatureRow extends StatelessWidget {
  const ChannelPlanFeatureRow({
    required this.text,
    required this.isDark,
    super.key,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: const Icon(
              Icons.check_circle,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Educational box explaining operation mechanics for standard or custom plans.
class ChannelPlanHowItWorksBox extends StatelessWidget {
  const ChannelPlanHowItWorksBox({
    required this.title,
    required this.description,
    required this.color,
    required this.isDark,
    super.key,
  });

  final String title;
  final String description;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

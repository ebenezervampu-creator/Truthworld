import 'package:flutter/material.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated section displaying transparent AI Fact-Checking pricing for channels,
/// duration-tiered rates, monthly creator passes, and algorithmic discovery benefits.
class ChannelFactCheckPricingSection extends StatelessWidget {
  final ChannelType channelType;
  final bool isCustom;

  const ChannelFactCheckPricingSection({
    required this.channelType,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.twTypography;
    const tiers = ChannelWalletService.factCheckDurationTiers;
    const plans = ChannelWalletService.channelFactCheckPlans;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Row(
            children: [
              TruthLottieAnimation.verifiedShield(size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Fact-Checking Pricing & Verification',
                  style: typography.headline.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isCustom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'CUSTOM CHANNEL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Extract empirical claims, cross-reference verified citations, and earn TruthWorld Trust Badges. Deducted directly from your channel spendable balance.',
            style: typography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // ── Complete Ground-Truth Fact-Checking Tier ──
          Text(
            'COMPLETE GROUND-TRUTH FACT-CHECKING (100% FREE)',
            style: typography.overline.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF34D399)),
                            const SizedBox(width: 8),
                            Text(
                              'Complete Ground-Truth Fact-Checking',
                              style: typography.label.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            '100% FREE',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          r'FREE ($0.00)',
                          style: typography.title.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• Sponsored 100% by TruthWorld Platform',
                          style: typography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every single empirical claim in your content is extracted and verified against authoritative registries, peer-reviewed journals, and live Google Search for 100% free.',
                      style: typography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...ChannelWalletService.factCheckDepthPlans.first.features.map((f) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF34D399)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Duration-Tiered Pricing Breakdown ──
          Text(
            'DURATION-BASED COVERAGE (100% FREE ACROSS ALL DURATIONS)',
            style: typography.overline.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiers.map((tier) {
                  return Container(
                    width: isWide ? (constraints.maxWidth - 30) / 4 : (constraints.maxWidth - 10) / 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.name,
                          style: typography.label.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.durationLabel,
                          style: typography.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('All Claims:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                            Text(r'FREE ($0.00)', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Monthly Channel Fact-Check Passes ──
          Text(
            'MONTHLY CHANNEL VERIFICATION PASSES',
            style: typography.overline.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: plans.map((plan) {
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: plan.isPopular
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.bgSurfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: plan.isPopular
                          ? Colors.white.withValues(alpha: 0.4)
                          : AppColors.bgDivider,
                      width: plan.isPopular ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan.title,
                            style: typography.title.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (plan.isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$${plan.priceUSD.toStringAsFixed(2)}',
                            style: typography.hero.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plan.billingPeriod,
                            style: typography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      ...plan.perks.map((perk) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  perk,
                                  style: typography.caption.copyWith(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // ── Creator Credibility & Algorithmic Advantages Footer ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Algorithmic Advantage: Fact-checked videos receive an automatic 15% to 20% discovery rank boost across TruthWorld recommendation feeds and search results.',
                    style: typography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      height: 1.4,
                    ),
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/plan_selection/plan_graphics.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Checklist column displaying plan feature items with icon and descriptions.
class ChecklistColumn extends StatelessWidget {
  const ChecklistColumn({required this.items, super.key});

  final List<Map<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3F3F46),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (item['subtitle']!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item['subtitle']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Card showing selected plan highlights, comparison, and platform fee notices.
class PlanHighlightsCard extends StatelessWidget {
  PlanHighlightsCard({
    required this.controller,
    required this.isDesktop,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController controller;
  final bool isDesktop;
  final bool isDarkMode;

  final RxBool _isHighlightsExpanded = true.obs;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final planVal = controller.selectedPlan.value;
      final isCustom = planVal == 'custom';
      final isStandard = planVal == 'standard';

      final customChecklist = [
        {
          'title':
              'Pro Tier Pricing: ${controller.customPricingTier.value}/month',
          'subtitle':
              'Dedicated cloud storage, global CDN streaming, and 100% revenue retention.',
        },
        {
          'title': '100% Revenue Share from Ads & Premium Subscriptions',
          'subtitle':
              'Earn 100% revenue and power your growth with Pro Channel',
        },
        {
          'title': '100% Direct Revenue from Memberships & Superchats!',
          'subtitle':
              'Keep 100% of fan support with zero commissions or transaction fees',
        },
        {
          'title': 'Unlimited video upload duration | up to 4K (3840x2160)',
          'subtitle': '2-5 times faster processing speed & ultra HD playback',
        },
        {
          'title': r'AI Dubbing (From $0.10/lang at-cost) & Studio Voice Cloning',
          'subtitle':
              'At-cost dubbing with exclusive Studio Voice Cloning from channel spendable balance',
        },
        {
          'title': '30+ Premium Features & Tools',
          'subtitle':
              'Advanced analytics, custom branding, live priority & priority CDN',
        },
        {
          'title': 'Advanced support: Live priority + HD',
          'subtitle': '',
        },
        {
          'title': '100% Free Premium Creator Features Included',
          'subtitle': '',
        },
      ];

      final standardChecklist = [
        {
          'title': '70% Revenue Share from Ads & Premium Subscriptions',
          'subtitle':
              'Earn 70% revenue share on all ad views and premium subscription revenues',
        },
        {
          'title': '90% Revenue from Memberships & Superchats',
          'subtitle':
              'Keep 90% of direct fan support; 10% platform fee covers hosting, gateway & admin fees',
        },
        {
          'title': '10 min/day Upload Limit (Up to 4K Ultra HD)',
          'subtitle':
              'Fast processing with up to 4K Ultra HD resolution (Free playback up to 1040p)',
        },
        {
          'title': r'AI Dubbing (From $0.10/language at-cost)',
          'subtitle':
              'Translate and dub videos into 70+ languages at zero platform markup pass-through rates',
        },
        {
          'title': '10+ Essential Creator Tools',
          'subtitle': 'Standard analytics, community posts, standard uploads',
        },
        {
          'title': '100% Free to Operate',
          'subtitle':
              'TruthWorld covers video hosting & transcoding costs completely',
        },
        {
          'title': 'Upgrade or Switch Plan Once Every 1 Month',
          'subtitle':
              'You can upgrade from Standard to Pro or switch plans once per month from Settings',
        },
      ];

      final allFeaturesChecklist = [
        {
          'title': '70% to 100% Revenue Share from Ads & Subscriptions',
          'subtitle':
              'Standard offers 70% revenue share; Pro offers 100% revenue share.',
        },
        {
          'title': 'Up to 100% Direct Fan Support (Memberships & Superchats)',
          'subtitle':
              'Keep 90% on Standard (10% platform fee) and 100% on Pro channels (0% platform cut).',
        },
        {
          'title':
              '10 Min/Day (Standard) vs Unlimited Upload Duration (Pro)',
          'subtitle':
              'Standard uploads up to 10 min/day in 4K UHD; Pro supports unlimited duration & dedicated infrastructure.',
        },
        {
          'title':
              r'AI Multilingual Dubbing: At-cost pass-through from $0.10/lang',
          'subtitle':
              'Both Standard and Pro channels receive 100% provider pass-through pricing with zero platform markup.',
        },
        {
          'title': 'Storage & Global CDN Infrastructure Tiers',
          'subtitle':
              'Standard: Free hosting. Pro: 50 GB to 800 GB Cloud Storage & 250 GB to 3.2 TB CDN.',
        },
        {
          'title': '100% Creator Revenue Share on Pro (0% Platform Fee)',
          'subtitle':
              'Pro channels retain 100% of all ad revenue, memberships, and superchats.',
        },
        {
          'title':
              '10+ Essential Creator Tools vs 30+ Premium Tools & VIP Support',
          'subtitle':
              'Standard includes essential analytics; Pro adds VIP priority live support & fast transcoding.',
        },
        {
          'title': 'Monthly Plan Upgrade & Switch Policy',
          'subtitle':
              'You can upgrade or switch between Standard and Pro plans anytime from Settings once per month.',
        },
      ];

      final checklistItems = isCustom
          ? customChecklist
          : isStandard
              ? standardChecklist
              : allFeaturesChecklist;

      final highlightsTitle = isCustom
          ? 'Pro Channel Plan Highlights'
          : isStandard
              ? 'Standard Channel Plan Highlights'
              : 'All Channel Features & Comparison';

      return Container(
        padding: EdgeInsets.all(isDesktop ? 24 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      highlightsTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (!isDesktop)
                  IconButton(
                    icon: Icon(
                      _isHighlightsExpanded.value
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    onPressed: () => _isHighlightsExpanded.value =
                        !_isHighlightsExpanded.value,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (isDesktop || _isHighlightsExpanded.value) ...[
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Dashboard3DGraphic(isDesktop: isDesktop),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 6,
                      child: ChecklistColumn(items: checklistItems),
                    ),
                  ],
                )
              else ...[
                Dashboard3DGraphic(isDesktop: isDesktop),
                const SizedBox(height: 20),
                ChecklistColumn(items: checklistItems),
              ],
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF27272A),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        r'Note: Standard channels are 100% free to operate with zero hosting fees. Truthworld takes 30% revenue share from ads and premium subscriptions (70% for creator), and 10% platform fee from superchats and memberships (90% for creator). Custom channels keep 100% revenue across all streams (0% platform cut) with plans starting at $15, $25, $50, $100, $200/mo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD4D4D8),
                          height: 1.5,
                        ),
                      ),

                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

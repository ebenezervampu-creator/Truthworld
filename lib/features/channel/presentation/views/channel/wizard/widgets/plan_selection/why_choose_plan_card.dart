import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card describing key advantages and value proposition of chosen channel plan.
class WhyChoosePlanCard extends StatelessWidget {
  const WhyChoosePlanCard({
    required this.controller,
    required this.isDesktop,
    super.key,
  });

  final ChannelController controller;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final planVal = controller.selectedPlan.value;
      final isCustom = planVal == 'custom';
      final isStandard = planVal == 'standard';

      final planTitle = isCustom
          ? 'Why Choose Custom Channel?'
          : isStandard
              ? 'Why Choose Standard Channel?'
              : 'Why Choose TruthWorld Channel Plans?';

      final selectedTier = controller.customPricingTier.value;
      List<String> customBullets;
      if (selectedTier == 'Custom') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          'Flexible Cloud Storage & Global CDN Bandwidth scaled to your audience',
          'Dedicated 24/7 VIP Account Manager & Direct Technical Support',
          '4K HDR Video Encoding & Custom Transcoding Pipelines',
          r'50% Off AI Dubbing ($0.25/lang) & Studio Vocal Identity Cloning included',
          'Custom Integration & Payout Contract SLAs',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else if (selectedTier == r'$45') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '1 TB Cloud Storage: Space for ~3,000+ HD/4K videos',
          '5 TB High-Speed Global CDN: Fast global streaming (~15,000+ hrs)',
          '4K HDR Video & Lossless Audio encoding',
          r'$20 FREE Monthly Bonus Credit included',
          r'50% Off AI Dubbing ($0.25/lang) & Studio Vocal Identity Cloning included',
          'VIP Priority 24/7 Account Support & HD Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else if (selectedTier == r'$30') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '300 GB Cloud Storage: Space for ~1,000 HD/4K videos',
          '1.5 TB High-Speed Global CDN: Fast streaming (~5,000 hrs)',
          '4K Ultra HD Uploads (3840x2160) + High Bitrate',
          r'$10 FREE Monthly Bonus Credit included',
          r'50% Off AI Dubbing ($0.25/lang) & Studio Vocal Identity Cloning included',
          'Priority Live Support & Fast HD Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '100 GB Cloud Storage: Space for ~300 HD/4K videos',
          '500 GB High-Speed Global CDN: Ultra-fast streaming (~1,500+ hrs)',
          '4K Ultra HD Uploads (3840x2160) & Unlimited Uploads/Day',
          'Google Cloud & Firebase Backend Egress Included',
          r'50% Off AI Dubbing ($0.25/lang) & Studio Vocal Identity Cloning included',
          'Standard Priority Support & Fast Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      }

      final standardBullets = [
        r'100% Forever Free: $0/month — Zero subscription fee',
        'TruthWorld Covers Hosting: Free video transcoding & storage',
        '70% Revenue Share: Earn 70% from ads & subscriptions',
        '100% Direct Fan Revenue: Keep 100% Memberships & Superchats',
        'Up to 4K Ultra HD Uploads: High quality video playback',
        '10 Min/Day Upload Limit: Ideal for starting out creators',
        r'Pay-As-You-Go Dubbing: $0.50/language with standard voice presets from channel earnings',
        'Easy Upgrade Anytime: Switch to Custom plan whenever you grow',
      ];

      final overviewBullets = [
        'Select between 100% Free Standard Channel or Scalable Custom Channel',
        'Earn 70% to 100% Revenue Share on Ads & Premium Subscriptions',
        'Keep 100% Direct Fan Revenue: 0% Platform Commission on Memberships & Superchats',
        'Standard Plan: 100% Free with 10 min/day uploads in up to 4K Ultra HD',
        'Custom Plan: Unlimited uploads, 4K Ultra HD & Cloud Storage up to 1 TB',
        r'AI Dubbing: $0.50/lang (Standard) vs 50% Partner Discount $0.25/lang + Voice Cloning (Custom)',
        r'Custom Bonus: Instant $10 FREE Monthly Bonus Credit included',
        'Easy Upgrade: Switch or upgrade your plan anytime from Channel Settings',
      ];

      final bullets = isCustom
          ? customBullets
          : isStandard
              ? standardBullets
              : overviewBullets;

      return Container(
        padding: EdgeInsets.all(isDesktop ? 12 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFF121215),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  planTitle,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bullets.map(
              (text) => WhyChooseBulletItem(
                text: text,
                isDesktop: isDesktop,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Single bullet row with check circle icon.
class WhyChooseBulletItem extends StatelessWidget {
  const WhyChooseBulletItem({
    required this.text,
    required this.isDesktop,
    super.key,
  });

  final String text;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: isDesktop ? 12 : 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

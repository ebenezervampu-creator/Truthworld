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
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          'Dedicated 24/7 VIP Account Manager & Direct Technical Support',
          '4K HDR Video Encoding & Custom Transcoding Pipelines',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'Custom Integration & Payout Contract SLAs',
          '100% Free Premium Creator Features included',
        ];
      } else if (selectedTier == r'$200') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '800 GB Cloud Storage: Space for ~3,000+ HD/4K videos',
          '3.2 TB Ultra High-Speed Global CDN: Cinema-grade streaming',
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          '8K Cinema Master Encoding & Lossless Dolby Atmos Audio',
          '100% Free AI Fact-Checking: Automatic verification on all uploads',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'Enterprise 24/7 Dedicated Account Manager & VIP Response',
          '100% Free Premium Creator Features included',
        ];
      } else if (selectedTier == r'$100') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '400 GB Cloud Storage: Space for ~1,500+ HD/4K videos',
          '1.6 TB High-Speed Global CDN: Multi-region global streaming',
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          '4K HDR Video & 8K Multi-Track Transcoding',
          '100% Free AI Fact-Checking: Automatic verification on all uploads',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'VIP Priority 24/7 Account Support & Fast Transcoding Queue',
          '100% Free Premium Creator Features included',
        ];
      } else if (selectedTier == r'$45') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '150 GB Cloud Storage: Space for ~500+ HD/4K videos',
          '750 GB High-Speed Global CDN: Fast global streaming (~2,500+ hrs)',
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          '4K HDR Video & Lossless Audio encoding',
          '100% Free AI Fact-Checking: Automatic verification on all uploads',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'VIP Priority 24/7 Account Support & HD Transcoding',
          '100% Free Premium Creator Features included',
        ];
      } else if (selectedTier == r'$30') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '100 GB Cloud Storage: Space for ~300 HD/4K videos',
          '500 GB High-Speed Global CDN: Fast streaming (~1,500 hrs)',
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          '4K Ultra HD Uploads (3840x2160) + High Bitrate',
          '100% Free AI Fact-Checking: Automatic verification on all uploads',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'Priority Live Support & Fast HD Transcoding',
          '100% Free Premium Creator Features included',
        ];
      } else {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '50 GB Cloud Storage: Space for ~150 HD/4K videos',
          '250 GB High-Speed Global CDN: Ultra-fast streaming (~750+ hrs)',
          'Firestore Database Operations & Google Cloud Backend Compute Included',
          '4K Ultra HD Uploads (3840x2160) & Unlimited Uploads/Day',
          r'At-Cost AI Dubbing (From $0.10/lang) & Studio Vocal Identity Cloning included',
          'Standard Priority Support & Fast Transcoding',
          '100% Free Premium Creator Features included',
        ];
      }

      final standardBullets = [
        r'100% Forever Free: $0/month — Zero subscription fee',
        'TruthWorld Covers Hosting: Free video transcoding & storage',
        '70% Revenue Share: Earn 70% from ads & subscriptions',
        '100% Direct Fan Revenue: Keep 100% Memberships & Superchats',
        'Up to 4K Ultra HD Uploads: High quality video playback',
        '10 Min/Day Upload Limit: Ideal for starting out creators',
        r'At-Cost Pass-Through Dubbing: From $0.10/language with zero platform markup',
        'Easy Upgrade Anytime: Switch to Custom plan whenever you grow',
      ];

      final overviewBullets = [
        'Select between 100% Free Standard Channel or Scalable Custom Channel',
        'Earn 70% to 100% Revenue Share on Ads & Premium Subscriptions',
        'Keep 100% Direct Fan Revenue: 0% Platform Commission on Memberships & Superchats',
        'Standard Plan: 100% Free with 10 min/day uploads in up to 4K Ultra HD',
        'Custom Plan: Unlimited uploads, 4K Ultra HD & Cloud Storage up to 800 GB',
        r'AI Dubbing: 100% At-Cost Pass-Through (From $0.10/lang) with 0% platform markup for all channels',
        '100% Creator Retention: Zero platform commissions on custom channels',
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

import 'package:flutter/material.dart';

/// Single comparative feature entry comparing Standard vs Custom channel plans.
class PlanComparisonFeature {
  const PlanComparisonFeature({
    required this.title,
    required this.standardValue,
    required this.customValue,
    this.details,
    this.standardWins = false,
    this.customWins = false,
    this.icon,
  });

  final String title;
  final String standardValue;
  final String customValue;
  final String? details;
  final bool standardWins;
  final bool customWins;
  final IconData? icon;
}

/// Category section grouping related comparison features.
class PlanComparisonSection {
  const PlanComparisonSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<PlanComparisonFeature> features;
}

/// Comprehensive comparison data matrix between Standard and Custom channel tiers.
class ChannelPlanComparisonData {
  ChannelPlanComparisonData._();

  static const List<PlanComparisonSection> sections = [
    PlanComparisonSection(
      title: 'Revenue Share & Monetization',
      description:
          'How much money you keep from advertisements, memberships, and fan funding.',
      icon: Icons.monetization_on_outlined,
      features: [
        PlanComparisonFeature(
          title: 'Ad Revenue Share',
          standardValue: '70% Creator / 30% Platform',
          customValue: '100% Creator (0% Platform Cut)',
          details:
              'Pro channels keep 100% of gross advertising revenue with zero platform commission.',
          customWins: true,
          icon: Icons.attach_money_rounded,
        ),
        PlanComparisonFeature(
          title: 'Premium Views Revenue',
          standardValue: '70% Creator / 30% Platform',
          customValue: '100% Creator (0% Platform Cut)',
          details:
              'Revenue from TruthWorld Premium subscribers watching your content.',
          customWins: true,
          icon: Icons.workspace_premium_rounded,
        ),
        PlanComparisonFeature(
          title: 'Fan Memberships & Superchats',
          standardValue: '90% Creator (10% Fee)',
          customValue: '100% Creator (0% Fee)',
          details:
              'Standard channels retain 90% of fan support (10% platform fee); Pro channels retain 100% (0% fee).',
          icon: Icons.volunteer_activism_rounded,
        ),
        PlanComparisonFeature(
          title: 'Platform Take Rate',
          standardValue: '30% ads/subs • 10% fans',
          customValue: '0% on all creator revenue',
          details:
              'Standard pays via revenue split; Pro operates on flat infrastructure fees.',
          customWins: true,
          icon: Icons.pie_chart_outline_rounded,
        ),
        PlanComparisonFeature(
          title: 'Cash-Out / Payout Rule',
          standardValue: r'1,000 Views & 30h Watch Time (Min ₹100 / $10)',
          customValue: r'1,000 Views & 30h Watch Time (Min ₹100 / $10)',
          details:
              r'Payout rule is identical for Pro and Standard channels: earnings unlock per video once 1,000 views and 30 hours watch time are met. Minimum withdrawal is ₹100 for Indian channels and $10 for other countries in their currencies.',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    ),
    PlanComparisonSection(
      title: 'Upload Limits & Video Specs',
      description:
          'Allowances for daily upload duration, max video length, and visual resolution.',
      icon: Icons.video_library_outlined,
      features: [
        PlanComparisonFeature(
          title: 'Daily Upload Allowance',
          standardValue: '10 Minutes total per day',
          customValue: 'Unlimited Uploads per day',
          details:
              'Standard allowance can be split across multiple videos (e.g. 2 x 5 min or 7 min + 3 min).',
          customWins: true,
          icon: Icons.schedule_rounded,
        ),
        PlanComparisonFeature(
          title: 'Max Video Duration',
          standardValue: 'Up to 10 Minutes',
          customValue: 'Up to 24 Hours per video',
          details:
              'Pro channels can host long-form podcasts, live stream archives, courses, and films.',
          customWins: true,
          icon: Icons.timer_outlined,
        ),
        PlanComparisonFeature(
          title: 'Supported Video Resolution',
          standardValue: 'Up to 4K Ultra HD',
          customValue: 'Up to 4K Ultra HD & 8K Master',
          details:
              'Free viewers stream up to 1040p; Premium subscribers stream up to 4K UHD.',
          icon: Icons.hd_outlined,
        ),
        PlanComparisonFeature(
          title: 'Upload Frequency',
          standardValue: 'Within 10 min daily budget',
          customValue: 'No Daily Limits',
          details:
              'Upload as many videos as your chosen infrastructure tier storage allows.',
          customWins: true,
          icon: Icons.cloud_upload_outlined,
        ),
      ],
    ),
    PlanComparisonSection(
      title: 'Hosting & Infrastructure Costs',
      description:
          'Server bandwidth, cloud storage, and video transcoding allocation.',
      icon: Icons.storage_rounded,
      features: [
        PlanComparisonFeature(
          title: 'Monthly Subscription Cost',
          standardValue: r'$0 / Month (100% Free Forever)',
          customValue: r'From $15 / Month ($15 - $200+)',
          details:
              'Standard has zero upfront or recurring fees. Pro plans choose a tiered infrastructure package.',
          standardWins: true,
          icon: Icons.payments_outlined,
        ),
        PlanComparisonFeature(
          title: 'Cloud Storage',
          standardValue: 'Free Platform Managed Storage',
          customValue: '50 GB to 800 GB+ Dedicated',
          details:
              r'Tiered storage: $15 (50GB), $30 (100GB), $45 (150GB), $100 (400GB), $200 (800GB).',
          icon: Icons.cloud_done_outlined,
        ),
        PlanComparisonFeature(
          title: 'Global CDN Bandwidth',
          standardValue: 'Free Standard CDN Delivery',
          customValue: '250 GB to 3.2 TB+ Global Edge CDN',
          details:
              'Ultra-low-latency worldwide streaming powered by high-speed edge nodes.',
          customWins: true,
          icon: Icons.speed_rounded,
        ),
        PlanComparisonFeature(
          title: 'HLS Transcoding & Operations',
          standardValue: 'Included (Platform Absorbed)',
          customValue: 'Included (Zero Extra Cost)',
          details:
              'Firestore database operations and Google Cloud compute are included in both plans.',
          icon: Icons.sync_alt_rounded,
        ),
      ],
    ),
    PlanComparisonSection(
      title: 'AI Verification & Creator Perks',
      description:
          'Automated fact-checking, language localization, and support priority.',
      icon: Icons.auto_awesome_rounded,
      features: [
        PlanComparisonFeature(
          title: 'AI Fact-Checking & TruthScore',
          standardValue: '100% Free on all uploads',
          customValue: '100% Free on all uploads',
          details:
              'Verified fact-checking badges display on your videos with algorithmic discovery boost.',
          icon: Icons.verified_user_outlined,
        ),
        PlanComparisonFeature(
          title: 'AI Dubbing & Translation',
          standardValue: r'At-Cost Pass-Through (from $0.10/lang)',
          customValue: 'At-Cost + Vocal Identity Cloning',
          details:
              'Zero platform markup on multilingual dubbing; Pro adds studio voice cloning.',
          customWins: true,
          icon: Icons.translate_rounded,
        ),
        PlanComparisonFeature(
          title: 'Customer & Technical Support',
          standardValue: 'Standard Community & Help Desk',
          customValue: 'Priority to 24/7 Dedicated Manager',
          details:
              'Higher Pro tiers receive dedicated VIP account managers and expedited transcoding queues.',
          customWins: true,
          icon: Icons.support_agent_rounded,
        ),
        PlanComparisonFeature(
          title: 'Upgrades & Downgrades',
          standardValue: 'Upgrade to Pro anytime',
          customValue: 'Change or adjust tier anytime',
          details:
              'Creators can switch plans flexibly in Channel Settings without losing content.',
          icon: Icons.swap_horiz_rounded,
        ),
      ],
    ),
  ];
}

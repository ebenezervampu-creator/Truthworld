import 'package:truthworld/data/models/channel.dart';

class CustomChannelPlanTier {
  final String id;
  final String title;
  final double priceUSD;
  final int storageGB;
  final int bandwidthGB;
  final String maxResolution;
  final List<String> features;
  final bool isPopular;

  const CustomChannelPlanTier({
    required this.id,
    required this.title,
    required this.priceUSD,
    required this.storageGB,
    required this.bandwidthGB,
    required this.maxResolution,
    required this.features,
    this.isPopular = false,
  });
}

class InfrastructureMeteringService {
  static const double storageCostPerGBMonth = 0.02; // $0.02 per GB per month
  static const double bandwidthCostPerGB = 0.015; // $0.015 per GB streaming

  /// Pre-defined Custom Channel Plans ($15, $30, $45, Custom)
  static const List<CustomChannelPlanTier> availablePlans = [
    CustomChannelPlanTier(
      id: 'starter_15',
      title: 'Starter',
      priceUSD: 15.0,
      storageGB: 25,
      bandwidthGB: 100,
      maxResolution: '1080p',
      features: [
        '0% Platform Commission',
        '25 GB Video Storage',
        '100 GB CDN Streaming Bandwidth',
        '1080p HD Video Quality',
        'Direct Creator Payouts',
        'Community Posts & Tipping',
      ],
    ),
    CustomChannelPlanTier(
      id: 'growth_30',
      title: 'Growth',
      priceUSD: 30.0,
      storageGB: 75,
      bandwidthGB: 300,
      maxResolution: '1080p 60fps',
      isPopular: true,
      features: [
        '0% Platform Commission',
        '75 GB Video Storage',
        '300 GB CDN Streaming Bandwidth',
        '1080p 60fps Ultra Smooth',
        'Custom Domain Support',
        'Paid Q&A & Priority Reply',
        'Standard Analytics Dashboard',
      ],
    ),
    CustomChannelPlanTier(
      id: 'pro_45',
      title: 'Pro',
      priceUSD: 45.0,
      storageGB: 200,
      bandwidthGB: 1000,
      maxResolution: '4K Ultra HD',
      features: [
        '0% Platform Commission',
        '200 GB Storage (~1,000 hrs)',
        '1,000 GB (1 TB) CDN Bandwidth',
        '4K Ultra HD HDR Streaming',
        'Custom Branding & Theme CSS',
        'Advanced Revenue Analytics',
        'Priority Email & Chat Support',
      ],
    ),
    CustomChannelPlanTier(
      id: 'custom_enterprise',
      title: 'Custom',
      priceUSD: 0.0, // Custom Quote
      storageGB: 1000,
      bandwidthGB: 5000,
      maxResolution: '4K / 8K',
      features: [
        '0% Platform Commission',
        'Unlimited / Custom Storage & Bandwidth',
        'Dedicated Server Node',
        'White-Label Native iOS & Android App',
        'Custom SLA & 99.99% Uptime',
        '24/7 Dedicated Account Manager',
      ],
    ),
  ];

  /// Estimates actual cloud infrastructure cost based on storage and bandwidth used
  static double calculateInfraCost({
    required int storageUsedBytes,
    required int bandwidthUsedBytes,
  }) {
    final storageGB = storageUsedBytes / (1024 * 1024 * 1024);
    final bandwidthGB = bandwidthUsedBytes / (1024 * 1024 * 1024);

    final storageCost = storageGB * storageCostPerGBMonth;
    final bandwidthCost = bandwidthGB * bandwidthCostPerGB;

    return storageCost + bandwidthCost;
  }

  /// Evaluates loss-prevention status for a custom channel given current gross revenue and infra cost
  static LossPreventionMode evaluateLossPreventionStatus({
    required double grossRevenue,
    required double currentInfraCost,
  }) {
    if (grossRevenue <= 0 && currentInfraCost > 10.0) {
      // High cost with zero revenue -> auto-scale video resolution to prevent debt
      return LossPreventionMode.autoScaled;
    }

    if (grossRevenue > 0) {
      final costToRevenueRatio = currentInfraCost / grossRevenue;
      if (costToRevenueRatio >= 1.0) {
        return LossPreventionMode.autoScaled;
      } else if (costToRevenueRatio >= 0.8) {
        return LossPreventionMode.warning;
      }
    }

    return LossPreventionMode.active;
  }

  /// Returns max allowed video playback resolution based on loss-prevention mode
  static String getRecommendedStreamingResolution(LossPreventionMode mode) {
    switch (mode) {
      case LossPreventionMode.active:
        return '1080p';
      case LossPreventionMode.warning:
        return '720p';
      case LossPreventionMode.autoScaled:
        return '480p';
      case LossPreventionMode.suspended:
        return '360p';
    }
  }
}

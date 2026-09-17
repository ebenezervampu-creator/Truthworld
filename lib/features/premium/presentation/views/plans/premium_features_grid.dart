import 'package:flutter/material.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card displaying an individual premium feature benefit.
class PremiumFeatureCard extends StatelessWidget {
  final PremiumFeatureItem feature;

  const PremiumFeatureCard({
    required this.feature,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              feature.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid or column displaying all-inclusive premium benefits.
class PremiumFeaturesGrid extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final List<PremiumFeatureItem> features;

  const PremiumFeaturesGrid({
    this.isDesktop = false,
    this.isTablet = false,
    this.features = kDefaultPremiumFeatures,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop || isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All-Inclusive Benefits',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 220,
            ),
            itemBuilder: (context, index) {
              return PremiumFeatureCard(feature: features[index]);
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All-Inclusive Benefits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: features.map((feat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PremiumFeatureCard(feature: feat),
            );
          }).toList(),
        ),
      ],
    );
  }
}

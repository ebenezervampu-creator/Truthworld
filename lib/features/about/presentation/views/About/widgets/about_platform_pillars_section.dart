import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section showcasing the three foundational pillars of TruthWorld.
class AboutPlatformPillarsSection extends StatelessWidget {
  const AboutPlatformPillarsSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final pillars = [
      _buildFeatureCard(
        Icons.verified_user_outlined,
        'Content Validation Layer',
        'Transparent fact-checking framework analyzing factual claims, linking creator citations, and generating verifiable credibility metrics for viewers.',
        'Trust by Design',
      ),
      _buildFeatureCard(
        Icons.g_translate_rounded,
        'AI Multilingual Dubbing',
        'Automatic transcription, voice preservation, and dubbing across 70+ languages, opening global audiences to every creator effortlessly.',
        'Global Reach',
      ),
      _buildFeatureCard(
        Icons.monetization_on_outlined,
        'Creator-First Economics',
        '100% net ad revenue to video creators and a transparent 75/25 subscription split, setting a new benchmark for ethical creator monetization.',
        'Equitable Revenue',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Core Platform Pillars',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Engineered to solve the crisis of digital trust while providing world-class creator tools.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 44),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pillars[0]),
                const SizedBox(width: 20),
                Expanded(child: pillars[1]),
                const SizedBox(width: 20),
                Expanded(child: pillars[2]),
              ],
            )
          else
            Column(
              children: [
                pillars[0],
                const SizedBox(height: 16),
                pillars[1],
                const SizedBox(height: 16),
                pillars[2],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String description,
    String tagline,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tagline,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

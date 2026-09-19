import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section introducing TruthWorld's executive leadership and founding vision.
class AboutLeadershipSection extends StatelessWidget {
  const AboutLeadershipSection({
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
            'Executive Leadership',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: EdgeInsets.all(isDesktop ? 36 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 3,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Vampu Ebenezer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Founder, Director & Lead Platform Architect',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Vampu Ebenezer is the founder and managing director of TowerVSP Services (OPC) Private Limited. Leading platform engineering, AI verification architectures, and scalable media streaming pipelines, he established Truthworld to create a transparent, reliable, and globally accessible video distribution ecosystem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildChip('AI Verification Architecture'),
                    _buildChip('Cloud-Native Infrastructure'),
                    _buildChip('Media Distribution Systems'),
                    _buildChip('Platform Governance'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Call-to-action banner inviting creators and viewers to join the verified TruthWorld movement.
class AboutCTASection extends StatelessWidget {
  const AboutCTASection({
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
    final margin = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(margin),
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 56 : 36,
        horizontal: isDesktop ? 56 : 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Join the Truthworld Movement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Publish verified content, reach international audiences, and earn equitable revenue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (AuthService.to.hasChannel.value ||
                  AuthService.to.userChannel != null) {
                StudioLauncher.openStudio();
              } else {
                AppNavigator.toChannelWizard();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.bgPage,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: Text(
              AuthService.to.hasChannel.value
                  ? 'Open Creator Studio'
                  : 'Start Creating Verified Content',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Statutory corporate footer with legal links, social handles, and copyright notice.
class AboutFooterSection extends StatelessWidget {
  const AboutFooterSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    required this.onLaunchUrl,
    required this.onSendEmail,
    required this.onCallPhone,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;
  final ValueChanged<String> onLaunchUrl;
  final ValueChanged<String> onSendEmail;
  final ValueChanged<String> onCallPhone;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 40,
      ),
      color: AppColors.bgPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'TOWERVSP SERVICES (OPC) PRIVATE LIMITED',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              _buildFooterLink(
                'hello@truthworld.in',
                () => onSendEmail('hello@truthworld.in'),
              ),
              _buildFooterLink('Terms of Service', AppNavigator.toTerms),
              _buildFooterLink('Privacy Policy', AppNavigator.toPrivacy),
              _buildFooterLink(
                'Copyright & DMCA',
                AppNavigator.toCopyrightComplaint,
              ),
              _buildFooterLink(
                'LinkedIn',
                () => onLaunchUrl(
                  'https://www.linkedin.com/in/ebenezer-vampu-10b9883a9/',
                ),
              ),
              _buildFooterLink(
                'X',
                () => onLaunchUrl('https://x.com/ebenezervampu1'),
              ),
              _buildFooterLink(
                '+91 9390617877',
                () => onCallPhone('+919390617877'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '© 2026 TowerVSP Services (OPC) Private Limited. All rights reserved. Built for the future of trusted video publishing.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

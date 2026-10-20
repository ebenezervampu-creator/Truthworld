import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Interactive option card for selecting a channel type inside the modal.
class ChannelTypeOptionCard extends StatelessWidget {
  const ChannelTypeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.gradientStart,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color gradientStart;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? const Color(0xFF1E293B) : AppColors.bgInput)
              : (isSelected
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppColors.textTertiary : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Benefits and how-it-works explanatory box displayed for the active option.
class ChannelTypeBenefitsBox extends StatelessWidget {
  const ChannelTypeBenefitsBox({
    required this.isStandard,
    required this.isDark,
    required this.primaryColor,
    super.key,
  });

  final bool isStandard;
  final bool isDark;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isStandard
                    ? 'Standard Channel Benefits'
                    : 'Custom Channel Benefits',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isStandard) ...[
            const ChannelTypeBulletPoint(
              text:
                  'Platform Rev-Share: 30% Platform / 70% Creator on Ads & Premium Subscriptions',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Direct Fan Funding: 0% Platform / 100% Creator on Superchats & Memberships',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Infrastructure: 100% Free video bandwidth, storage, HLS transcoding & CDN delivery',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Upload Limit: 10 min daily upload limit (Up to 4K Ultra HD)',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Cash-Out Rule: Per-video cash withdrawal unlocks at 1,000 views & 10 hours watch time (Min ₹100 for India / \$10 for other countries)',
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Text(
              'How it Works:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimary
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Standard channels are 100% free to operate with zero hosting fees. Truthworld takes 30% revenue share from ads and premium subscriptions (70% for creator), and 0% revenue share from superchats and memberships (100% for creator).',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ] else ...[
            const ChannelTypeBulletPoint(
              text:
                  'Platform Rev-Share: 0% Platform share (100% Creator retention on Ads, Premium Subscriptions, Superchats & Memberships)',
            ),
            const ChannelTypeBulletPoint(
              text:
                  r'Flexible Plans: Choose an infrastructure plan ($15, $30, $45, $100, $200/mo etc.) tailored to your needs',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Upload Limit: Unlimited Videos (up to 24 Hours duration)',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Infrastructure: Custom bandwidth, storage & transcoding control',
            ),
            const ChannelTypeBulletPoint(
              text:
                  'Cash-Out Rule: Per-video cash withdrawal unlocks at 1,000 views & 10 hours watch time (Min ₹100 for India / \$10 for other countries • 100% creator retention)',
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Text(
              'How it Works:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimary
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              r'Custom channels give you maximum economic leverage. Truthworld takes 0% revenue share from ads, premium subscriptions, superchats, and memberships (100% creator retention). Custom channels simply select an infrastructure plan tier ($15, $30, $45, $100, $200/mo etc.).',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bullet point row used inside channel type benefits box.
class ChannelTypeBulletPoint extends StatelessWidget {
  const ChannelTypeBulletPoint({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Top overview card displaying Standard Channel value proposition & stats.
class StandardPlanOverviewCard extends StatelessWidget {
  const StandardPlanOverviewCard({
    required this.isSelected,
    required this.onSelect,
    required this.isDark,
    super.key,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '100% FREE FOREVER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const AppLogo(size: 44, borderRadius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Channel',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero hosting fees & platform covers infrastructure',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Price callout
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                r'$0',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ month',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 16),
          _buildPillRow(
            icon: Icons.pie_chart_rounded,
            title: '70% Ad & Subscription Rev-Share',
            subtitle: 'You keep 70%, Platform takes 30%',
            color: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildPillRow(
            icon: Icons.volunteer_activism_rounded,
            title: '100% Memberships & Superchats',
            subtitle: '0% Platform Fee (Direct to Creator)',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildPillRow(
            icon: Icons.timer_outlined,
            title: '10 Min Daily Upload Limit',
            subtitle: 'Split across multiple videos daily',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildPillRow(
            icon: Icons.cloud_done_outlined,
            title: 'Free Hosting, CDN & Transcoding',
            subtitle: 'Zero server or bandwidth costs',
            color: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? primaryColor : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                elevation: isSelected ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isSelected ? 'Standard Selected' : 'Choose Standard Channel',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPillRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top overview card displaying Custom Channel value proposition & stats.
class CustomPlanOverviewCard extends StatelessWidget {
  const CustomPlanOverviewCard({
    required this.isSelected,
    required this.onSelect,
    required this.isDark,
    super.key,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8B5CF6);
    const gradientStart = Color(0xFFA78BFA);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'MAX REVENUE • 100% KEEP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStart, primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Channel',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '0% Platform cut & flexible dedicated infrastructure',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Price callout
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                r'$15+',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ month (Tiered)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 16),
          StandardPlanOverviewCard._buildPillRow(
            icon: Icons.monetization_on_rounded,
            title: '100% Gross Revenue Share',
            subtitle: 'You keep 100% on ads, subs & fans (0% cut)',
            color: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          StandardPlanOverviewCard._buildPillRow(
            icon: Icons.all_inclusive_rounded,
            title: 'Unlimited Uploads & 24h Videos',
            subtitle: 'No daily limits; up to 24 hours per video',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          StandardPlanOverviewCard._buildPillRow(
            icon: Icons.storage_rounded,
            title: 'Dedicated Cloud Storage & CDN',
            subtitle: '50 GB to 800 GB+ storage & fast global CDN',
            color: const Color(0xFF38BDF8),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          StandardPlanOverviewCard._buildPillRow(
            icon: Icons.lock_open_rounded,
            title: '1k Views & 30h Per-Video Cash-Out',
            subtitle: 'Withdraw cash directly on eligible videos',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? primaryColor : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                elevation: isSelected ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isSelected ? 'Pro Selected' : 'Choose Pro Channel',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

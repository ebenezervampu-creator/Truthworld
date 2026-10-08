import 'package:flutter/material.dart';

/// YouTube-style channel membership loyalty milestones based on subscriber tenure.
enum ChannelLoyaltyMilestone {
  newMember,
  threeMonths,
  sixMonths,
  oneYear,
  twoYears,
  threeYears,
  fourYears,
  fiveYears,
  sevenYears,
  tenYears,
}

/// Helper model encapsulating milestone progression, tenure calculations,
/// YouTube-grade loyalty badge colors, icons, and display widgets.
class ChannelLoyaltyBadge {
  const ChannelLoyaltyBadge({
    required this.milestone,
    required this.monthsRequired,
    required this.label,
    required this.color,
    required this.badgeColorHex,
    required this.icon,
  });

  final ChannelLoyaltyMilestone milestone;
  final int monthsRequired;
  final String label;
  final Color color;
  final String badgeColorHex;
  final IconData icon;

  /// Ordered milestones from New Member up to 10 Years tenure.
  static const List<ChannelLoyaltyBadge> allMilestones = [
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.newMember,
      monthsRequired: 0,
      label: 'New member',
      color: Color(0xFF10B981), // Emerald Green (YouTube standard base tier)
      badgeColorHex: '0xFF10B981',
      icon: Icons.star_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.threeMonths,
      monthsRequired: 3,
      label: '3 months',
      color: Color(0xFF0284C7), // Sky Blue
      badgeColorHex: '0xFF0284C7',
      icon: Icons.star_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.sixMonths,
      monthsRequired: 6,
      label: '6 months',
      color: Color(0xFF8B5CF6), // Royal Purple
      badgeColorHex: '0xFF8B5CF6',
      icon: Icons.star_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.oneYear,
      monthsRequired: 12,
      label: '1 year',
      color: Color(0xFFEC4899), // Pink / Magenta
      badgeColorHex: '0xFFEC4899',
      icon: Icons.workspace_premium_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.twoYears,
      monthsRequired: 24,
      label: '2 years',
      color: Color(0xFFF59E0B), // Bronze / Amber
      badgeColorHex: '0xFFF59E0B',
      icon: Icons.workspace_premium_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.threeYears,
      monthsRequired: 36,
      label: '3 years',
      color: Color(0xFFEAB308), // Gold
      badgeColorHex: '0xFFEAB308',
      icon: Icons.workspace_premium_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.fourYears,
      monthsRequired: 48,
      label: '4 years',
      color: Color(0xFF14B8A6), // Turquoise / Teal
      badgeColorHex: '0xFF14B8A6',
      icon: Icons.diamond_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.fiveYears,
      monthsRequired: 60,
      label: '5 years',
      color: Color(0xFF3B82F6), // Sapphire Blue
      badgeColorHex: '0xFF3B82F6',
      icon: Icons.diamond_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.sevenYears,
      monthsRequired: 84,
      label: '7 years',
      color: Color(0xFF06B6D4), // Diamond Cyan / Platinum
      badgeColorHex: '0xFF06B6D4',
      icon: Icons.diamond_rounded,
    ),
    ChannelLoyaltyBadge(
      milestone: ChannelLoyaltyMilestone.tenYears,
      monthsRequired: 120,
      label: '10 years',
      color: Color(0xFFE11D48), // Crimson / Ruby Red
      badgeColorHex: '0xFFE11D48',
      icon: Icons.military_tech_rounded,
    ),
  ];

  /// Resolves the badge definition for a given milestone enum.
  static ChannelLoyaltyBadge fromMilestone(ChannelLoyaltyMilestone milestone) {
    return allMilestones.firstWhere(
      (b) => b.milestone == milestone,
      orElse: () => allMilestones.first,
    );
  }

  /// Calculates the tenure milestone from months subscribed.
  static ChannelLoyaltyMilestone milestoneFromMonths(int months) {
    if (months >= 120) return ChannelLoyaltyMilestone.tenYears;
    if (months >= 84) return ChannelLoyaltyMilestone.sevenYears;
    if (months >= 60) return ChannelLoyaltyMilestone.fiveYears;
    if (months >= 48) return ChannelLoyaltyMilestone.fourYears;
    if (months >= 36) return ChannelLoyaltyMilestone.threeYears;
    if (months >= 24) return ChannelLoyaltyMilestone.twoYears;
    if (months >= 12) return ChannelLoyaltyMilestone.oneYear;
    if (months >= 6) return ChannelLoyaltyMilestone.sixMonths;
    if (months >= 3) return ChannelLoyaltyMilestone.threeMonths;
    return ChannelLoyaltyMilestone.newMember;
  }

  /// Calculates tenure months between [from] date and now.
  static int calculateMonths(DateTime? from, [DateTime? to]) {
    if (from == null) return 0;
    final target = to ?? DateTime.now();
    var months = (target.year - from.year) * 12 + (target.month - from.month);
    if (target.day < from.day) {
      months--;
    }
    return months < 0 ? 0 : months;
  }

  /// Resolves milestone directly from joinedAt DateTime.
  static ChannelLoyaltyMilestone milestoneFromJoinedAt(DateTime? joinedAt) {
    if (joinedAt == null) return ChannelLoyaltyMilestone.newMember;
    return milestoneFromMonths(calculateMonths(joinedAt));
  }

  /// Resolves badge definition directly from joinedAt DateTime.
  static ChannelLoyaltyBadge badgeFromJoinedAt(DateTime? joinedAt) {
    return fromMilestone(milestoneFromJoinedAt(joinedAt));
  }

  /// Constructs a user-friendly tooltip message for the badge.
  String tooltipText({String? tierName}) {
    final prefix = (tierName != null && tierName.trim().isNotEmpty)
        ? '$tierName Member'
        : 'Channel Member';
    return '$prefix · $label';
  }
}

/// Accessible, high-contrast widget rendering YouTube-style loyalty badges beside member comments.
class ChannelLoyaltyBadgeWidget extends StatelessWidget {
  const ChannelLoyaltyBadgeWidget({
    required this.milestone,
    this.tierName,
    this.compact = false,
    this.fontSize = 10,
    this.iconSize = 11,
    super.key,
  });

  final ChannelLoyaltyMilestone milestone;
  final String? tierName;
  final bool compact;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final badge = ChannelLoyaltyBadge.fromMilestone(milestone);
    final badgeColor = badge.color;

    return Tooltip(
      message: badge.tooltipText(tierName: tierName),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: 1.5,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.75),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badge.icon,
              size: iconSize,
              color: badgeColor,
            ),
            if (!compact) ...[
              const SizedBox(width: 3.5),
              Text(
                badge.label,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

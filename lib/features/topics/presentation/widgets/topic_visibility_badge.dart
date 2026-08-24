import 'package:flutter/material.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Reusable Topic Visibility Badge Widget (Public / Private / Channel Only)
/// Matches exact Channel Creation page status badge styling & white icon rule.
class TopicVisibilityBadge extends StatelessWidget {
  const TopicVisibilityBadge({
    required this.visibilityType,
    super.key,
    this.isCompact = false,
  });
  final TopicVisibilityType visibilityType;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final Color badgeBg;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (visibilityType == TopicVisibilityType.private) {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      textColor = const Color(0xFFFBBF24);
      icon = Icons.lock_rounded;
      label = 'Private';
    } else if (visibilityType == TopicVisibilityType.channelOnly) {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
      textColor = const Color(0xFF38BDF8);
      icon = Icons.group_rounded;
      label = 'Channel Only';
    } else {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      icon = Icons.public_rounded;
      label = 'Public';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 10 : 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

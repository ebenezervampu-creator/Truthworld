import 'package:flutter/material.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Reusable Topic Visibility Badge Widget (Public / Private / Channel Only)
class TopicVisibilityBadge extends StatelessWidget {

  const TopicVisibilityBadge({
    required this.visibilityType, super.key,
    this.isCompact = false,
  });
  final TopicVisibilityType visibilityType;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    var label = 'Public';
    var color = const Color(0xFF10B981); // Emerald / Green
    var icon = Icons.public_rounded;

    if (visibilityType == TopicVisibilityType.private) {
      label = 'Private';
      color = const Color(0xFFF59E0B); // Amber
      icon = Icons.lock_rounded;
    } else if (visibilityType == TopicVisibilityType.channelOnly) {
      label = 'Channel';
      color = const Color(0xFF3B82F6); // Blue
      icon = Icons.group_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

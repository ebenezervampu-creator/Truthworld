import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Helper badge item for Channel Plan feature tags
class PlanBadgeItem extends StatelessWidget {
  final String text;

  const PlanBadgeItem({
    required this.text,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias
typedef ChannelPlanBadgeItem = PlanBadgeItem;

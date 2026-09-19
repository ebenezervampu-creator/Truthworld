import 'package:flutter/material.dart';

/// Moderation status badge for channel branding banner and avatar images.
class ChannelBrandingModerationBadge extends StatelessWidget {
  const ChannelBrandingModerationBadge({
    required this.status,
    required this.reason,
    super.key,
  });

  final String status;
  final String reason;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED';
    final isRejected = status == 'REJECTED';
    final isFlagged = status == 'FLAGGED';

    final Color badgeBg;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String label;

    if (isPending) {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
      textColor = const Color(0xFF38BDF8);
      iconData = Icons.hourglass_top_rounded;
      label = 'Verifying...';
    } else if (isApproved) {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.verified_rounded;
      label = 'Verified';
    } else if (isRejected) {
      badgeBg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = const Color(0xFFF87171);
      iconData = Icons.error_outline_rounded;
      label = reason.isNotEmpty ? 'Rejected: $reason' : 'Image Rejected';
    } else if (isFlagged) {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.warning_amber_rounded;
      label = reason.isNotEmpty ? 'Flagged: $reason' : 'Flagged for Review';
    } else {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.check_circle_outline_rounded;
      label = 'Verified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(iconData, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

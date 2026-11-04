import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Badge displaying a user's numerical trust score with appropriate risk color.
class UserTrustScoreBadge extends StatelessWidget {
  final int score;

  const UserTrustScoreBadge({
    required this.score,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor = Colors.red;
    if (score >= 75) {
      scoreColor = Colors.green;
    } else if (score >= 40) {
      scoreColor = Colors.amber;
    } else if (score >= 10) {
      scoreColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: scoreColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Badge displaying user status (ACTIVE, BANNED, SUSPENDED).
class UserStatusBadge extends StatelessWidget {
  final String status;

  const UserStatusBadge({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (status.toLowerCase() == 'banned') {
      color = AppColors.error;
    } else if (status.toLowerCase() == 'suspended') {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Badge displaying AI Vision safe search audit status.
class UserVisionStatusBadge extends StatelessWidget {
  final String status;

  const UserVisionStatusBadge({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    var text = status;
    final upper = status.toUpperCase();

    if (upper == 'APPROVED') {
      bg = AppColors.success.withValues(alpha: 0.15);
      fg = AppColors.success;
      text = 'APPROVED BY VISION AI';
    } else if (upper == 'REJECTED') {
      bg = AppColors.error.withValues(alpha: 0.15);
      fg = AppColors.error;
      text = 'REJECTED BY VISION AI';
    } else if (upper == 'PENDING') {
      bg = Colors.blue.withValues(alpha: 0.15);
      fg = Colors.blue;
      text = 'AWAITING VISION SCAN';
    } else if (upper == 'FLAGGED' || upper == 'MANUAL_REVIEW') {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber;
      text = 'FLAGGED FOR REVIEW';
    } else {
      bg = Colors.white.withValues(alpha: 0.1);
      fg = AppColors.textSecondary;
      text = 'NO AUDIT RECORD';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Styled action button for triggering user moderation workflows.
class UserActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const UserActionButton({
    required this.label,
    required this.onPressed,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

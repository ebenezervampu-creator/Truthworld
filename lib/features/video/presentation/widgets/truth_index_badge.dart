import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class TruthIndexBadge extends StatelessWidget {

  const TruthIndexBadge({
    required this.video, super.key,
    this.showLabel = true,
  });
  final Video video;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildPulseIcon(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return AppColors.warning;
    if (score >= 30) return AppColors.error;
    return const Color(0xFF991B1B);
  }
}





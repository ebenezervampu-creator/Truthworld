import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
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
    final score = video.videoRating;
    final color = _getScoreColor(score);

    return InkWell(
      onTap: () {
        final vc = Get.find<VideoController>(tag: video.id);
        vc.fetchFullDisclosure();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPulseIcon(color),
            const SizedBox(width: 8),
            if (showLabel) ...[
              Text(
                'VIDEO RATING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 10,
                color: color.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              score.toInt().toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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





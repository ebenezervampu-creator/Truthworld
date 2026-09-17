import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisViewerNoteCard extends StatelessWidget {
  final String note;

  const VideoAnalysisViewerNoteCard({required this.note, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'AI VIEWER ADVISORY & SUMMARY',
                style: context.twTypography.overline.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: context.twTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

}

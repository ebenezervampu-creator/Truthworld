import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisViewerNoteCard extends StatelessWidget {
  final String note;

  const VideoAnalysisViewerNoteCard({required this.note, super.key});

  @override
  Widget build(BuildContext context) {
    final cleanNote = UserFeedbackSanitizer.sanitizeViewerNote(note);
    if (cleanNote.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.7)),
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
              Expanded(
                child: Text(
                  'TRUTH INTELLIGENCE ADVISORY',
                  style: context.twTypography.overline.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    letterSpacing: 1.0,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cleanNote,
            style: context.twTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.5,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ],
      ),
    );
  }

}

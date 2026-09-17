import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesAiProgressBanner extends StatelessWidget {
  const SubtitlesAiProgressBanner({
    required this.controller,
    super.key,
  });

  final SubtitlesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isGeneratingAI.value) return const SizedBox.shrink();

      final progress = controller.aiJobProgress.value;
      final status = controller.aiJobStatus.value.isNotEmpty
          ? controller.aiJobStatus.value
          : 'Processing video audio & preparing subtitle tracks...';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Truthworld AI Subtitle Generation in Progress',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '$progress%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA78BFA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: const Color(0xFFDDD6FE),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? (progress / 100.0).clamp(0.0, 1.0) : null,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    });
  }
}

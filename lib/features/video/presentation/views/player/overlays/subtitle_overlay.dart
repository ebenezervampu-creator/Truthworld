import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitleOverlay extends StatelessWidget {
  const SubtitleOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final text = ctrl.currentSubtitle.value;
      if (text.isEmpty) return const SizedBox.shrink();
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: AppColors.bgPage,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOAST
// ─────────────────────────────────────────────────────────────────────────────

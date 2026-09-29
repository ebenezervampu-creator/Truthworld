import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class AbrBadge extends StatelessWidget {
  const AbrBadge({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shortTier = ctrl.abr.currentTier.height > 0
          ? '${ctrl.abr.currentTier.height}p'
          : ctrl.abr.currentTier.label;
      final label = ctrl.abr.isAutoMode.value
          ? 'AUTO·$shortTier'
          : shortTier;
      return InkWell(
        onTap: () => ctrl.openSettings(context),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Text(label, style: TS.badge),
        ),
      );
    });
  }
}

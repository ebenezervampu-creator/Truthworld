import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

class SubtitleOverlay extends StatelessWidget {
  final TowerPlayerController ctrl;
  const SubtitleOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final text = ctrl.currentSubtitle.value;
      if (text.isEmpty) return const SizedBox.shrink();
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              shadows: const [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
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

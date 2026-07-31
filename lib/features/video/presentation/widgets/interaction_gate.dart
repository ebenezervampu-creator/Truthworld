// ============================================================
// interaction_gate.dart
// Root Interaction Gate and YouTube-Style Unlock Pill Overlay
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/player_lock_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Root Interaction Gate that intercepts all gesture recognizers when screen is locked
class InteractionGate extends StatelessWidget {
  const InteractionGate({
    required this.child,
    required this.lockController,
    super.key,
  });
  final Widget child;
  final PlayerLockController lockController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      lockController.isLocked.value;
      lockController.pillState.value;
      final locked = lockController.isLocked.value;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Underlying Player & Controls Layer
          IgnorePointer(
            ignoring: locked,
            child: child,
          ),

          // Interceptor Layer when Locked
          if (locked)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: lockController.showUnlockHint,
              onDoubleTap: lockController.showUnlockHint,
              onPanDown: (_) => lockController.showUnlockHint(),
              child: const SizedBox.expand(),
            ),

          // YouTube-Style Floating Unlock Pill Overlay
          Obx(() {
            lockController.isLocked.value;
            lockController.pillState.value;
            final pillVisible =
                locked &&
                lockController.pillState.value == UnlockPillState.visible;

            return AnimatedOpacity(
              opacity: pillVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !pillVisible,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Semantics(
                      button: true,
                      label: 'Screen locked. Double tap or click to unlock.',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: lockController.unlock,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Screen locked — Tap to unlock',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

class NotificationToggleButton extends StatelessWidget {
  const NotificationToggleButton({required this.videoId, super.key});
  final String videoId;

  // Shared RxBool cache to keep identical cards in sync without custom event systems
  static final Map<String, RxBool> _notifiedCache = {};

  RxBool _getNotifiedRx() {
    if (!_notifiedCache.containsKey(videoId)) {
      _notifiedCache[videoId] = true.obs;
    }
    return _notifiedCache[videoId]!;
  }

  @override
  Widget build(BuildContext context) {
    final isNotified = _getNotifiedRx();
    final isHovered = false.obs;

    void toggleNotification() {
      isNotified.value = !isNotified.value;

      // Provide a premium feedback toast similar to Truthworld
      ScaffoldMessenger.of(context).clearSnackBars();
      AppSnackbar.show(
        isNotified.value ? 'Notification on' : 'Notification off',
        isNotified.value
            ? "We'll notify you when this premiere starts."
            : "You won't be notified about this premiere.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xDD212121),
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
        borderRadius: 8,
        animationDuration: const Duration(milliseconds: 300),
        isDismissible: true,
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
      );
    }

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: toggleNotification,
        child: Obx(() {
          final isNotifiedVal = isNotified.value;
          final isHoveredVal = isHovered.value;

          final backgroundColor = isNotifiedVal
              ? (isHoveredVal
                    ? const Color(0xFF383838)
                    : const Color(0xFF272727))
              : (isHoveredVal
                    ? const Color(0x33FFFFFF)
                    : const Color(0x1EFFFFFF));

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isNotifiedVal
                    ? AppColors.textPrimary.withValues(alpha: 0.08)
                    : AppColors.textPrimary.withValues(alpha: 0.15),
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Text(
                isNotifiedVal ? 'Notification on' : 'Notify me',
                key: ValueKey<bool>(isNotifiedVal),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

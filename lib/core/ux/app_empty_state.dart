import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppEmptyStateController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> fadeAnimation;
  late final Animation<double> scaleAnimation;
  late final Animation<Offset> slideAnimation;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    animationController.forward();
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}

class ActionButtonController extends GetxController {
  bool isHovered = false;
  void setHovered(bool val) {
    isHovered = val;
    update();
  }
}

/// Premium empty state widget for all list/grid screens.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 72,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppEmptyStateController>(
      init: AppEmptyStateController(),
      global: false,
      builder: (controller) {
        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: controller.fadeAnimation,
              child: SlideTransition(
                position: controller.slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Animated Icon Container
                    ScaleTransition(
                      scale: controller.scaleAnimation,
                      child: Container(
                        width: iconSize + 40,
                        height: iconSize + 40,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.brand.withValues(alpha: 0.08),
                              AppColors.brand.withValues(alpha: 0.02),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: iconSize,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        letterSpacing: -0.3,
                      ),
                    ),

                    // Subtitle
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // Action Button
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 28),
                      _ActionButton(label: actionLabel!, onPressed: onAction!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ActionButtonController>(
      init: ActionButtonController(),
      global: false,
      builder: (controller) {
        return MouseRegion(
          onEnter: (_) => controller.setHovered(true),
          onExit: (_) => controller.setHovered(false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.diagonal3Values(
              controller.isHovered ? 1.03 : 1.0,
              controller.isHovered ? 1.03 : 1.0,
              1.0,
            ),
            transformAlignment: Alignment.center,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.isHovered
                    ? AppColors.brandHover
                    : AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: controller.isHovered ? 4 : 0,
                shadowColor: AppColors.brand.withValues(alpha: 0.4),
              ),
              child: Text(
                label,
                style: AppTextStyles.buttonText.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

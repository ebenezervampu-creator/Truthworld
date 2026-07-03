import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppErrorStateController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> fadeAnimation;
  late final Animation<double> shakeAnimation;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
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

class RetryButtonController extends GetxController {
  bool isHovered = false;
  void setHovered(bool val) {
    isHovered = val;
    update();
  }
}

/// Premium error state widget with retry support.
class AppErrorState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const AppErrorState({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppErrorStateController>(
      init: AppErrorStateController(),
      global: false,
      builder: (controller) {
        return Center(
          child: FadeTransition(
            opacity: controller.fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated error icon with shake
                  AnimatedBuilder(
                    animation: controller.shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(controller.shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFEF4444).withValues(alpha: 0.1),
                            const Color(0xFFEF4444).withValues(alpha: 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 56,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    title ?? 'Something went wrong',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Retry button
                  if (onRetry != null) ...[
                    const SizedBox(height: 28),
                    _RetryButton(label: retryLabel, onPressed: onRetry!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RetryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _RetryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RetryButtonController>(
      init: RetryButtonController(),
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
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: controller.isHovered
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: controller.isHovered
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: controller.isHovered
                    ? AppColors.bgSurfaceHover
                    : Colors.transparent,
                side: BorderSide(
                  color: controller.isHovered
                      ? AppColors.brand.withValues(alpha: 0.5)
                      : AppColors.bgDivider,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class FullscreenVerticalActionsBar extends StatelessWidget {
  const FullscreenVerticalActionsBar({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<VideoController>(tag: ctrl.tag)) {
      return const SizedBox.shrink();
    }

    final vc = Get.find<VideoController>(tag: ctrl.tag);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like
          Obx(() {
            return _buildVerticalIconBtn(
              icon: vc.isLiked.value
                  ? Icons.thumb_up_rounded
                  : Icons.thumb_up_outlined,
              onTap: vc.toggleLike,
              isActive: vc.isLiked.value,
            );
          }),
          const SizedBox(height: 6),

          // Dislike
          Obx(() {
            return _buildVerticalIconBtn(
              icon: vc.isDisliked.value
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              onTap: vc.toggleDislike,
              isActive: vc.isDisliked.value,
            );
          }),
          const SizedBox(height: 6),

          // Comments
          Obx(
            () => _buildVerticalIconBtn(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () {
                ctrl.showTranscriptPopup.value = false;
                ctrl.showCommentsPopup.toggle();
                ctrl.startHideTimer();
              },
              isActive: ctrl.showCommentsPopup.value,
            ),
          ),
          const SizedBox(height: 6),

          // Transcript
          Obx(
            () => _buildVerticalIconBtn(
              icon: Icons.description_outlined,
              onTap: () {
                ctrl.showCommentsPopup.value = false;
                ctrl.showTranscriptPopup.toggle();
                ctrl.startHideTimer();
              },
              isActive: ctrl.showTranscriptPopup.value,
            ),
          ),
          const SizedBox(height: 6),

          // Verified / Facts
          Obx(
            () => _buildVerticalIconBtn(
              icon: ctrl.showFactOverlay.value
                  ? Icons.verified_rounded
                  : Icons.verified_outlined,
              onTap: () {
                final claims = vc.video.uiReport?.keyClaims;
                if (claims == null || claims.isEmpty) {
                  ctrl.showToast('No fact-check data for this video');
                  return;
                }
                ctrl.showFactOverlay.toggle();
                ctrl.showToast(
                  ctrl.showFactOverlay.value
                      ? 'Fact overlay enabled'
                      : 'Fact overlay disabled',
                );
              },
              isActive: ctrl.showFactOverlay.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    int? badgeCount,
    bool flipHorizontal = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.textPrimary.withValues(alpha: 0.22)
                  : AppColors.textPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: _AnimatedBounceIcon(
              icon: icon,
              isActive: isActive,
              color: AppColors.textPrimary,
              textDirection: flipHorizontal ? TextDirection.rtl : null,
            ),
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: PT.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedBounceIcon extends StatefulWidget {
  const _AnimatedBounceIcon({
    required this.icon,
    required this.isActive,
    required this.color,
    this.textDirection,
  });
  final IconData icon;
  final bool isActive;
  final Color color;
  final double size = 20;
  final TextDirection? textDirection;

  @override
  State<_AnimatedBounceIcon> createState() => _AnimatedBounceIconState();
}

class _AnimatedBounceIconState extends State<_AnimatedBounceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedBounceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive && widget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
        textDirection: widget.textDirection,
      ),
    );
  }
}

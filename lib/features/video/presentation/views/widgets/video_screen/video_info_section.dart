import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_action_buttons.dart';
import 'package:truthworld/features/video/presentation/widgets/video_description_box.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Video information header section displaying title, contextual banners, action controls, and description.
class VideoInfoHeader extends StatelessWidget {
  const VideoInfoHeader({
    required this.controller,
    required this.mainController,
    required this.onSignInPrompt,
    this.channelController,
    this.isDesktop = false,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final ChannelController? channelController;
  final VoidCallback onSignInPrompt;
  final bool isDesktop;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClickableUrlText(
              text: ctrl.video.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            if (ctrl.video.isUnlisted) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Unlisted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            VideoActionButtons.build(
              context: context,
              controller: ctrl,
              mainController: mainController,
              channelController: channelController,
              onSignInPrompt: onSignInPrompt,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 12),
            VideoDescriptionBox(
              controller: ctrl,
              mainController: mainController,
              isDesktop: isDesktop,
            ),
          ],
        ),
      ),
    );
  }
}

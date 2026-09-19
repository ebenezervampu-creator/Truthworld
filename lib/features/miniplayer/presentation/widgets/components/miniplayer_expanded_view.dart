import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_expanded_details.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_intents.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Full-screen expanded player surface with video controls and details.
class MiniplayerExpandedView extends StatelessWidget {
  final MiniplayerController controller;
  final Size screenSize;

  const MiniplayerExpandedView({
    required this.controller,
    required this.screenSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FocusableActionDetector(
        autofocus: true,
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.escape):
              const MiniplayerCollapseIntent(),
          LogicalKeySet(LogicalKeyboardKey.space):
              const MiniplayerTogglePlayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyK):
              const MiniplayerTogglePlayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyJ):
              const MiniplayerSeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyL):
              const MiniplayerSeekForwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft):
              const MiniplayerSeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight):
              const MiniplayerSeekForwardIntent(),
        },
        actions: <Type, Action<Intent>>{
          MiniplayerCollapseIntent: CallbackAction<MiniplayerCollapseIntent>(
            onInvoke: (_) {
              controller.collapse();
              return null;
            },
          ),
          MiniplayerTogglePlayIntent: CallbackAction<MiniplayerTogglePlayIntent>(
            onInvoke: (_) {
              controller.togglePlayPause();
              return null;
            },
          ),
          MiniplayerSeekBackwardIntent:
              CallbackAction<MiniplayerSeekBackwardIntent>(
            onInvoke: (_) {
              controller.seekBackward();
              return null;
            },
          ),
          MiniplayerSeekForwardIntent:
              CallbackAction<MiniplayerSeekForwardIntent>(
            onInvoke: (_) {
              controller.seekForward();
              return null;
            },
          ),
        },
        child: Material(
          color: AppColors.bgPage,
          child: SafeArea(
            child: Column(
              children: [
                MiniplayerExpandedTopBar(controller: controller),
                Expanded(
                  flex: 5,
                  child: MiniplayerExpandedVideo(controller: controller),
                ),
                Expanded(
                  flex: 3,
                  child: MiniplayerExpandedDetails(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top action bar for the expanded miniplayer mode (Minimize, CC, Fullscreen, Close).
class MiniplayerExpandedTopBar extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerExpandedTopBar({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.bgPage,
      child: Row(
        children: [
          Tooltip(
            message: 'Minimize',
            child: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: controller.collapse,
            ),
          ),
          const Spacer(),
          Obx(() {
            final enabled = controller.subtitlesEnabled.value;
            return Tooltip(
              message: 'Subtitles (CC)',
              child: IconButton(
                icon: Icon(
                  enabled ? Icons.subtitles_rounded : Icons.subtitles_outlined,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: controller.toggleSubtitles,
              ),
            );
          }),
          Tooltip(
            message: 'Open full screen',
            child: IconButton(
              icon: const Icon(
                Icons.open_in_full_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: controller.openFullScreen,
            ),
          ),
          Tooltip(
            message: 'Close',
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: controller.dismiss,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanded video viewport with double-tap seek, thumbnail fallback, subtitles, and play overlay.
class MiniplayerExpandedVideo extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerExpandedVideo({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth / 2;
        var doubleTapX = 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.togglePlayPause,
          onDoubleTapDown: (details) => doubleTapX = details.localPosition.dx,
          onDoubleTap: () {
            if (doubleTapX < half) {
              controller.seekBackward();
            } else {
              controller.seekForward();
            }
          },
          child: Container(
            color: AppColors.bgPage,
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Obx(() {
                  final url = controller.videoInfo.value?.thumbnailUrl ?? '';
                  if (url.isEmpty) return const SizedBox.shrink();
                  return CachedNetworkImage(
                    imageUrl: url.replaceAll(' ', '%20'),
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  );
                }),
                Obx(() {
                  final isReady = controller.isVideoReady.value;
                  final vpc = controller.videoPlayerController;
                  final hasErr = controller.error.value.isNotEmpty;
                  if (hasErr) return const SizedBox.shrink();
                  if (vpc == null || !isReady) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2.5,
                      ),
                    );
                  }
                  return Center(
                    child: AspectRatio(
                      aspectRatio: vpc.value.aspectRatio,
                      child: VideoPlayer(vpc),
                    ),
                  );
                }),
                Obx(() {
                  if (controller.isPlaying.value ||
                      controller.error.value.isNotEmpty) {
                    return const SizedBox.shrink();
                  }
                  return const Center(
                    child: Icon(
                      Icons.play_circle_rounded,
                      color: AppColors.textPrimary,
                      size: 72,
                    ),
                  );
                }),
                Obx(() {
                  final msg = controller.error.value;
                  if (msg.isEmpty) return const SizedBox.shrink();
                  return Container(
                    color: AppColors.bgPage.withValues(alpha: 0.88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: controller.attemptRecovery,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.bgDivider.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.textPrimary,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Obx(() {
                  if (!controller.subtitlesEnabled.value) {
                    return const SizedBox.shrink();
                  }
                  final text = controller.currentSubtitle.value;
                  if (text.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}


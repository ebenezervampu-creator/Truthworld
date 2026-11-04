import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/layout/global_app_bar.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/mixins/video_drag_to_miniplayer_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_feed.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_screen_widgets.dart';
import 'package:truthworld/features/video/presentation/widgets/video_comments_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/views/video_description_screen.dart';
export 'package:truthworld/features/video/presentation/views/widgets/animated_reaction_button.dart';
export 'package:truthworld/features/video/presentation/views/widgets/transcript_segment_tile.dart';
export 'package:truthworld/features/video/presentation/views/widgets/video_comment_item_widget.dart';
export 'package:truthworld/features/video/presentation/views/widgets/video_interactive_avatars.dart';
export 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_feed.dart';
export 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_screen_widgets.dart';

/// Primary Video player screen coordinating playback, metadata, and recommendations.
class VideoScreen extends GetView<VideoController> {
  const VideoScreen({super.key, this.videoTag});
  final String? videoTag;

  @override
  String? get tag => videoTag;

  // Theme Shortcuts
  static const Color primary = AppColors.brand;
  static const Color background = AppColors.bgPage;
  static const Color cardBackground = AppColors.bgSurface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color divider = AppColors.bgDivider;
  static const Color border = AppColors.bgDivider;
  static const Color accent = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;

    // Dismiss miniplayer and apply clip args once when screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.isDismissingToMiniplayer.value || ctrl.isMiniplayerHandoffDone.value) return;
      if (Get.arguments is Map<String, dynamic>) {
        ctrl.applyClipIfPresent(Get.arguments as Map<String, dynamic>?);
      }
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
          Get.isRegistered<MiniplayerController>()) {
        MiniplayerController.to.dismiss();
      }

      // Guaranteed interactive autoplay when arriving from a push notification (YouTube parity)
      final isFromNotification = (Get.arguments is Map &&
              (Get.arguments['fromNotification'] == true ||
                  Get.arguments['fromPush'] == true ||
                  Get.arguments['autoplay'] == true)) ||
          (Get.parameters['autoplay'] == 'true');

      if (isFromNotification) {
        void ensurePlaying() {
          final vpc = ctrl.videoPlayerController;
          if (vpc != null && ctrl.isPlayerInitialized.value && !vpc.value.isPlaying) {
            vpc.play();
          }
        }

        ensurePlaying();
        if (!ctrl.isPlayerInitialized.value) {
          once(ctrl.isPlayerInitialized, (initialized) {
            if (initialized) {
              ensurePlaying();
            }
          });
        }
      }

      // Automatically open comments bottom sheet on mobile when arriving from a comment notification (YouTube behavior)
      final hasTargetComment = (Get.arguments is Map &&
              (Get.arguments['commentId'] != null ||
                  Get.arguments['replyId'] != null)) ||
          (Get.parameters['commentId'] != null &&
              Get.parameters['commentId']!.isNotEmpty) ||
          (Get.parameters['replyId'] != null &&
              Get.parameters['replyId']!.isNotEmpty);

      if (hasTargetComment && context.mounted) {
        final isMobile = MediaQuery.of(context).size.width < kDesktopBreakpoint;
        if (isMobile && !VideoCommentsSheet.isOpen) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (context.mounted && !VideoCommentsSheet.isOpen) {
              VideoCommentsSheet.show(
                context: context,
                controller: ctrl,
                mainController: _mainController,
                onSignInPrompt: _showSignInPrompt,
              );
            }
          });
        }
      }
    });

    return Obx(() {
      final canPop = ctrl.isDismissingToMiniplayer.value;
      final isHandoffDone = ctrl.isMiniplayerHandoffDone.value;

      void handleDismissPop() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (RouteStackObserver.hasRoute('/watch') ||
              RouteStackObserver.hasRoute('watch')) {
            Get.until((r) {
              if (r.isFirst) return true;
              final name = r.settings.name;
              if (name == null) return false;
              return !name.toLowerCase().contains('watch');
            });
            if (RouteStackObserver.hasRoute('/watch') ||
                RouteStackObserver.hasRoute('watch')) {
              RouteStackObserver.navigateToHome();
            }
          } else if (Get.key.currentState?.canPop() == true) {
            Get.back();
          } else {
            RouteStackObserver.navigateToHome();
          }
        });
      }

      // If handoff to miniplayer has completed, immediately render an empty transparent scaffold
      // so neither watch details nor duplicate player flash/blink while the route pops.
      if (isHandoffDone) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            handleDismissPop();
          },
          child: const Scaffold(
            backgroundColor: Colors.transparent,
            body: SizedBox.shrink(),
          ),
        );
      }

      if (ctrl.video.id.isEmpty) {
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (ctrl.isDismissingToMiniplayer.value) {
              handleDismissPop();
              return;
            }
            ctrl.minimizeWithAnimation();
          },
          child: const Scaffold(
            backgroundColor: background,
            body: ShimmerVideoScreen(),
          ),
        );
      }

      if (ctrl.isFullScreen.value) {
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            ctrl.exitFullscreen();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: VideoPlayerView(
                controller: ctrl,
                videoTag: videoTag,
              ),
            ),
          ),
        );
      }

      final screenSize = MediaQuery.sizeOf(context);
      final isDesktop = screenSize.width >= 900;

      if (isDesktop) {
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (ctrl.isDismissingToMiniplayer.value) {
              handleDismissPop();
              return;
            }
            ctrl.minimizeWithAnimation();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: background,
            appBar: ResponsiveVideoAppBar(
              controller: ctrl,
              appBarBuilder: () => buildGlobalAppBar(context),
            ),
            body: VideoScreenLoadedBody(
              controller: ctrl,
              mainController: _mainController,
              channelController: _channelController,
              onSignInPrompt: _showSignInPrompt,
              videoTag: videoTag,
            ),
          ),
        );
      }

          // ── Mobile Watch Screen with Dynamic Scroll & YouTube Miniplayer Drag ──
          final topInset = MediaQuery.paddingOf(context).top;
          final isShort = ctrl.video.isShort;
          final double validRatio;
          if (ctrl.isVpcInitialized &&
              ctrl.vpcAspectRatio.isFinite &&
              ctrl.vpcAspectRatio > 0) {
            validRatio = ctrl.vpcAspectRatio;
          } else if (isShort) {
            validRatio = 9 / 16;
          } else {
            validRatio = 16 / 9;
          }

          const appBarHeight = kToolbarHeight;
          final totalHeaderHeight = topInset + appBarHeight;

          final startWidth = screenSize.width;
          final startHeight = (startWidth / validRatio).clamp(160.0, screenSize.height * 0.65);
          const startX = 0.0;

          // For tall / portrait / vertical aspect videos (aspect ratio < 1.4), the video player
          // naturally scrolls up with the watch feed so comments, chapters, and recommendations
          // are fully visible and readable without cramped peepholes or scroll lock.
          final isTallVideo = validRatio < 1.4;
          final baseStartY = totalHeaderHeight;

          // Miniplayer Dock Target Calculations (Matching MiniplayerFloatingCard)
          final isMobileLayout = MiniplayerConfig.isMobileLayout(screenSize.width);
          final targetWidth = MiniplayerConfig.widthForScreen(screenSize.width);
          final targetHeight = MiniplayerConfig.heightForWidth(targetWidth, isMobile: isMobileLayout) + 2.0;
          final cardSize = Size(targetWidth, targetHeight);
          final targetOffset = MiniplayerController.to.effectiveOffset(cardSize, screenSize);
          const targetRadius = MiniplayerConfig.borderRadius;

          final offset = ctrl.dragDownOffset.value;
          final progress = ctrl.isMiniplayerHandoffDone.value
              ? 1.0
              : (offset / VideoDragToMiniplayerMixin.maxDragDistance).clamp(0.0, 1.0);

          final currentX = ui.lerpDouble(startX, targetOffset.dx, progress)!;
          final currentWidth = ui.lerpDouble(startWidth, targetWidth, progress)!;
          final currentHeight = ui.lerpDouble(startHeight, targetHeight, progress)!;
          final currentRadius = ui.lerpDouble(0.0, targetRadius, progress)!;
          final shadowElevation = ui.lerpDouble(0.0, MiniplayerConfig.elevation, progress)!;
          final borderAlpha = ui.lerpDouble(0.0, 0.4, progress)!;
          final scrimAlpha = (1.0 - progress).clamp(0.0, 1.0);
          final detailsOpacity = (1.0 - progress * 2.5).clamp(0.0, 1.0);
          final detailsOffsetY = offset * 1.4;

          final appBarOpacity = (1.0 - progress * 2.5).clamp(0.0, 1.0);
          final appBarOffsetY = -progress * totalHeaderHeight;

          Widget buildAmbientGlow(double currentStartY) {
            if (progress >= 0.25 || ctrl.video.thumbnailUrl.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: currentStartY - 24,
              left: 0,
              right: 0,
              height: startHeight + 48,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1.0 - progress * 4.0).clamp(0.0, 1.0) * 0.18,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 0.9,
                        colors: [
                          AppColors.brand.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          Widget buildPlayerContainer(double currentStartY) {
            final effectiveCurrentY = ui.lerpDouble(currentStartY, targetOffset.dy, progress)!;
            return Positioned(
              left: currentX,
              top: effectiveCurrentY,
              width: currentWidth,
              height: currentHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(currentRadius),
                  border: borderAlpha > 0.02
                      ? Border.all(
                          color: AppColors.bgDivider.withValues(alpha: borderAlpha),
                        )
                      : null,
                  boxShadow: [
                    if (shadowElevation > 0)
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.55 * progress),
                        blurRadius: shadowElevation,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ctrl.isVpcInitialized
                    ? VideoPlayerView(
                        controller: ctrl,
                        videoTag: videoTag,
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (d) {
                          if (ctrl.scrollController.hasClients &&
                              ctrl.scrollController.offset > 2.0) {
                            ctrl.onFeedDragStart(d);
                          }
                        },
                        onVerticalDragUpdate: (d) {
                          if (d.delta.dy < 0 ||
                              (ctrl.scrollController.hasClients &&
                                  ctrl.scrollController.offset > 2.0 &&
                                  ctrl.dragDownOffset.value <= 0)) {
                            if (ctrl.feedDrag == null) {
                              ctrl.onFeedDragStart(
                                DragStartDetails(
                                  globalPosition: d.globalPosition,
                                  localPosition: d.localPosition,
                                ),
                              );
                            }
                            ctrl.onFeedDragUpdate(d);
                          } else if (d.delta.dy > 0 && ctrl.feedDrag == null) {
                            ctrl.onDragDownDelta(d.delta.dy);
                          }
                        },
                        onVerticalDragEnd: (d) {
                          if (ctrl.dragDownOffset.value > 0) {
                            ctrl.onDragDownEnd(
                              d.primaryVelocity ?? d.velocity.pixelsPerSecond.dy,
                              screenSize.height,
                            );
                          } else {
                            ctrl.onFeedDragEnd(d);
                          }
                        },
                        onVerticalDragCancel: () {
                          ctrl.onDragDownCancel();
                          ctrl.onFeedDragCancel();
                        },
                        child: VideoPlayerView(
                          controller: ctrl,
                          videoTag: videoTag,
                        ),
                      ),
              ),
            );
          }

      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (ctrl.isDismissingToMiniplayer.value) {
            handleDismissPop();
            return;
          }
          ctrl.minimizeWithAnimation();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
              children: [
                // 1. Scrim Background (smoothly reveals previous screen behind watch screen)
                Positioned.fill(
                  child: ColoredBox(
                    color: background.withValues(alpha: scrimAlpha),
                  ),
                ),

                // 2. Watch Screen Details Section (Title, channel, actions, comments, recommendations)
                // Slides down rapidly and fades away during drag down to miniplayer
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: progress > 0.05,
                    child: Transform.translate(
                      offset: Offset(0, detailsOffsetY),
                      child: Opacity(
                        opacity: detailsOpacity,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            ctrl.onWatchScrollUpdate(
                              notification.metrics.pixels.clamp(0.0, double.infinity),
                            );
                            return false;
                          },
                          child: CustomScrollView(
                            controller: ctrl.scrollController,
                            primary: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // Top spacer matching the height of AppBar + video player
                              SliverToBoxAdapter(
                                child: SizedBox(height: totalHeaderHeight + startHeight),
                              ),
                              VideoInfoHeader(
                                controller: ctrl,
                                mainController: _mainController,
                                channelController: _channelController,
                                onSignInPrompt: _showSignInPrompt,
                                videoTag: videoTag,
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: VideoClaimsChaptersSection(
                                    controller: ctrl,
                                    videoTag: videoTag,
                                  ),
                                ),
                              ),
                              RecommendationFeed(
                                video: ctrl.video,
                                videoTag: videoTag,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3 & 4. Ambient Glow & Live Video Player (for tall videos, smoothly tracks scrollController via ListenableBuilder)
                if (isTallVideo)
                  ListenableBuilder(
                    listenable: ctrl.scrollController,
                    builder: (context, _) {
                      final scrollOffset = ctrl.scrollController.hasClients
                          ? ctrl.scrollController.offset.clamp(0.0, startHeight)
                          : 0.0;
                      final dynamicStartY = baseStartY - scrollOffset;
                      return Stack(
                        children: [
                          buildAmbientGlow(dynamicStartY),
                          buildPlayerContainer(dynamicStartY),
                        ],
                      );
                    },
                  )
                else ...[
                  buildAmbientGlow(baseStartY),
                  buildPlayerContainer(baseStartY),
                ],

                // 5. Top App Bar (Pinned above player so scrolled player/content smoothly slides behind it)
                Positioned(
                  top: appBarOffsetY,
                  left: 0,
                  right: 0,
                  height: totalHeaderHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: ctrl.onDragDownStart,
                    onVerticalDragUpdate: (d) => ctrl.onDragDownDelta(d.delta.dy),
                    onVerticalDragEnd: (d) => ctrl.onDragDownEnd(
                      d.primaryVelocity ?? d.velocity.pixelsPerSecond.dy,
                      screenSize.height,
                    ),
                    onVerticalDragCancel: ctrl.onDragDownCancel,
                    child: IgnorePointer(
                      ignoring: progress > 0.05,
                      child: Opacity(
                        opacity: appBarOpacity,
                        child: ColoredBox(
                          color: background,
                          child: buildGlobalAppBar(context),
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        );
      });
    }

  ChannelController? get _channelController {
    try {
      if (tag != null && Get.isRegistered<ChannelController>(tag: tag)) {
        return Get.find<ChannelController>(tag: tag);
      }
      if (Get.isRegistered<ChannelController>()) {
        return Get.find<ChannelController>();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoScreen.channelControllerLookup',
      );
    }
    return null;
  }

  MainController get _mainController {
    if (Get.isRegistered<MainController>()) {
      return Get.find<MainController>();
    }
    return Get.put(MainController(), permanent: true);
  }

  void _showSignInPrompt() {
    AppSnackbar.info(
      'Please sign in to proceed.',
      title: 'Sign In Required',
      actionLabel: 'SIGN IN',
      onAction: () => AuthService.to.triggerPlatformSignIn(),
    );
  }
}


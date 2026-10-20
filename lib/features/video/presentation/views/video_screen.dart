import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/layout/global_app_bar.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_screen_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    if (Get.arguments is Map<String, dynamic>) {
      ctrl.applyClipIfPresent(Get.arguments as Map<String, dynamic>?);
    }

    // Dismiss miniplayer once when screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
          Get.isRegistered<MiniplayerController>()) {
        MiniplayerController.to.dismiss();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: background,
        appBar: ResponsiveVideoAppBar(
          controller: ctrl,
          appBarBuilder: () => buildGlobalAppBar(context),
        ),
        body: Obx(() {
          if (ctrl.video.id.isEmpty) {
            return const ShimmerVideoScreen();
          }
          return VideoScreenLoadedBody(
            controller: ctrl,
            mainController: _mainController,
            channelController: _channelController,
            onSignInPrompt: _showSignInPrompt,
            videoTag: videoTag,
          );
        }),
      ),
    );
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
      onAction: AuthBottomSheet.prompt,
    );
  }
}


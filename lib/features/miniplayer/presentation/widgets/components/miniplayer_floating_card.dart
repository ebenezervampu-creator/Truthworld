import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_info_bar.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_intents.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_video_frame.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Floating draggable card in the viewport.
class MiniplayerFloatingCard extends StatelessWidget {
  final MiniplayerController controller;
  final Size screenSize;

  const MiniplayerFloatingCard({
    required this.controller,
    required this.screenSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MiniplayerConfig.isMobileLayout(screenSize.width);
    final width = MiniplayerConfig.widthForScreen(screenSize.width);
    final height =
        MiniplayerConfig.heightForWidth(width, isMobile: isMobile) +
        2.0; // Account for top/bottom borders
    final cardSize = Size(width, height);

    final cardContent = SizedBox(
      width: width,
      height: height,
      child: FocusableActionDetector(
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.keyI):
              const MiniplayerExpandIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyP):
              const MiniplayerPipIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape):
              const MiniplayerDismissIntent(),
        },
        actions: <Type, Action<Intent>>{
          MiniplayerExpandIntent: CallbackAction<MiniplayerExpandIntent>(
            onInvoke: (_) {
              controller.openFullScreen();
              return null;
            },
          ),
          MiniplayerPipIntent: CallbackAction<MiniplayerPipIntent>(
            onInvoke: (_) {
              controller.enterPip();
              return null;
            },
          ),
          MiniplayerDismissIntent: CallbackAction<MiniplayerDismissIntent>(
            onInvoke: (_) {
              controller.dismiss();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          onEnter: (_) => controller.setHovering(true),
          onExit: (_) => controller.setHovering(false),
          child: MiniplayerCardBody(
            controller: controller,
            cardSize: cardSize,
            screenSize: screenSize,
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Obx(() {
          final pos = controller.effectiveOffset(cardSize, screenSize);
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            width: width,
            height: height,
            child: cardContent,
          );
        }),
      ],
    );
  }
}

/// Body container of the floating miniplayer card with borders, shadows, and gestures.
class MiniplayerCardBody extends StatelessWidget {
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;

  const MiniplayerCardBody({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MiniplayerConfig.isMobileLayout(screenSize.width);
    final videoHeight = isMobile
        ? (cardSize.height - 2.0)
        : (cardSize.width / MiniplayerConfig.videoAspectRatio);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(MiniplayerConfig.borderRadius),
          border: Border.all(
            color: AppColors.bgDivider.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.55),
              blurRadius: MiniplayerConfig.elevation,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: cardSize.width,
              height: videoHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) =>
                    controller.onPanCard(d.delta, cardSize, screenSize),
                onTap: controller.openFullScreen,
                child: MiniplayerVideoFrame(
                  controller: controller,
                  isMobile: isMobile,
                ),
              ),
            ),
            if (!isMobile)
              MiniplayerInfoBar(
                controller: controller,
                cardSize: cardSize,
                screenSize: screenSize,
              ),
          ],
        ),
      ),
    );
  }
}

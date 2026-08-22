import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

class SubtitleOverlay extends StatelessWidget {
  const SubtitleOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final text = ctrl.currentSubtitle.value;
      if (text.isEmpty) return const SizedBox.shrink();

      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final isMobile = screenWidth < 600;

      // Read caption size from User Settings if available, otherwise global option
      var fontSizeOpt =
          TowerPlayerController.globalSubtitleFontSizeOption.value;
      var isHighContrast = false;

      if (Get.isRegistered<UserSettingsController>()) {
        final acc = UserSettingsController.to.accessibility.value;
        fontSizeOpt = acc.captionSize;
        isHighContrast = acc.highContrastSubtitles;
      }

      var baseFontSize = 16.0;
      if (fontSizeOpt == 'Small') {
        baseFontSize = 13.0;
      } else if (fontSizeOpt == 'Large') {
        baseFontSize = 20.0;
      } else if (fontSizeOpt == 'Extra Large') {
        baseFontSize = 24.0;
      }

      // Responsive font scaling for fullscreen and mobile
      final fontSize = isMobile
          ? (baseFontSize * 0.88).clamp(12.0, 22.0)
          : baseFontSize;

      final textColor = isHighContrast
          ? Colors.white
          : TowerPlayerController.globalSubtitleTextColor.value;
      final bgColor = isHighContrast
          ? Colors.black
          : TowerPlayerController.globalSubtitleBgColor.value;
      final bgOpacity = isHighContrast
          ? 0.95
          : TowerPlayerController.globalSubtitleBgOpacity.value;
      final edgeStyle = TowerPlayerController.globalSubtitleEdgeStyle.value;
      final fontFamily = TowerPlayerController.globalSubtitleFontFamily.value;

      var shadows = const <Shadow>[];
      if (isHighContrast) {
        shadows = const [
          Shadow(blurRadius: 2, offset: Offset(1, 1)),
        ];
      } else if (edgeStyle == 'Drop Shadow') {
        shadows = const [
          Shadow(blurRadius: 4, offset: Offset(1, 1)),
        ];
      } else if (edgeStyle == 'Raised') {
        shadows = const [
          Shadow(blurRadius: 1, offset: Offset(-1, -1)),
          Shadow(blurRadius: 3, offset: Offset(2, 2)),
        ];
      } else if (edgeStyle == 'Outline') {
        shadows = const [
          Shadow(blurRadius: 1, offset: Offset(-1, -1)),
          Shadow(blurRadius: 1, offset: Offset(1, -1)),
          Shadow(blurRadius: 1, offset: Offset(-1, 1)),
          Shadow(blurRadius: 1, offset: Offset(1, 1)),
        ];
      }

      return IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Container(
              key: ValueKey<String>(text),
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.90 : 640,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: bgOpacity),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TowerPlayerController.getSubtitleTextStyle(
                  fontFamily: fontFamily,
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  shadows: shadows,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

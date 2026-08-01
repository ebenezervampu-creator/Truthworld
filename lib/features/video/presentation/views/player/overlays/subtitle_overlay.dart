import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      final isMobile = mediaQuery.size.width < 600;

      final fontSizeOpt =
          TowerPlayerController.globalSubtitleFontSizeOption.value;
      var baseFontSize = 16.0;
      if (fontSizeOpt == 'Small') {
        baseFontSize = 13.0;
      } else if (fontSizeOpt == 'Large') {
        baseFontSize = 19.0;
      } else if (fontSizeOpt == 'Extra Large') {
        baseFontSize = 23.0;
      }
      final fontSize = isMobile
          ? (baseFontSize * 0.85).clamp(11.0, 22.0)
          : baseFontSize;

      final textColor = TowerPlayerController.globalSubtitleTextColor.value;
      final bgColor = TowerPlayerController.globalSubtitleBgColor.value;
      final bgOpacity = TowerPlayerController.globalSubtitleBgOpacity.value;
      final edgeStyle = TowerPlayerController.globalSubtitleEdgeStyle.value;
      final fontFamily = TowerPlayerController.globalSubtitleFontFamily.value;

      var shadows = const <Shadow>[];
      if (edgeStyle == 'Drop Shadow') {
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

      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: bgOpacity),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TowerPlayerController.getSubtitleTextStyle(
              fontFamily: fontFamily,
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              shadows: shadows,
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOAST
// ─────────────────────────────────────────────────────────────────────────────

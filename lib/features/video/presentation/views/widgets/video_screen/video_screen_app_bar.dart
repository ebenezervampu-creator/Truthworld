import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// App bar wrapper that hides cleanly in fullscreen mode with local rebuild only.
class ResponsiveVideoAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ResponsiveVideoAppBar({
    required this.controller,
    required this.appBarBuilder,
    super.key,
  });

  final VideoController controller;
  final PreferredSizeWidget? Function() appBarBuilder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isFullScreen.value) {
        return const SizedBox.shrink();
      }
      final bar = appBarBuilder();
      return bar ?? const SizedBox.shrink();
    });
  }

  @override
  Size get preferredSize {
    if (controller.isFullScreen.value) {
      return Size.zero;
    }
    final bar = appBarBuilder();
    return bar?.preferredSize ?? Size.zero;
  }
}

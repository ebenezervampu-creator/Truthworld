import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_components.dart';

export 'components/miniplayer_components.dart';

/// Production-grade YouTube-style floating and expanded miniplayer widget.
class MiniplayerWidget extends StatelessWidget {
  const MiniplayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = MiniplayerController.to;
      final mode = controller.mode.value;
      if (mode == MiniplayerMode.dismissed) return const SizedBox.shrink();

      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (mode == MiniplayerMode.expanded) {
            return MiniplayerExpandedView(
              controller: controller,
              screenSize: size,
            );
          }
          return MiniplayerFloatingCard(
            controller: controller,
            screenSize: size,
          );
        },
      );
    });
  }
}

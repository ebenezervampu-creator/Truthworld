import 'package:flutter/material.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_widget.dart';

/// Renders the miniplayer overlay on top of the app content.
/// 
/// This widget should be placed as the second child in a Stack that has the app
/// content as the first child. It will render the floating miniplayer above all
/// other content.
/// 
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     appContent,
///     const MiniplayerOverlayManager(),
///   ],
/// )
/// ```
class MiniplayerOverlayManager extends StatelessWidget {
  const MiniplayerOverlayManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => const MiniplayerWidget(),
        ),
      ],
    );
  }
}






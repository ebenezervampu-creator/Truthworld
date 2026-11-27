import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';

/// Clean lightweight loading state for Audio Tracks workspace.
class AudioTracksSkeleton extends StatelessWidget {
  const AudioTracksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudioLoadingIndicator(
      message: 'Loading dubs workspace...',
    );
  }
}

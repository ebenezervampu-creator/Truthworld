import 'package:flutter/material.dart';

/// Legacy Channel Verified Badge Widget.
///
/// NOTE: TruthWorld has discontinued blue verified badges for channels to preserve
/// absolute epistemic honesty and transparency across all content creators.
/// Content is judged by truthfulness, evidence, and fact checks—never by identity badges.
class ChannelVerifiedBadge extends StatelessWidget {
  const ChannelVerifiedBadge({
    super.key,
    this.size = 14,
  });

  final double size;

  /// Official TruthWorld Blue Verified color (retained for backward compatibility)
  static const Color badgeColor = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    // Channel blue badges are completely discontinued across the platform.
    return const SizedBox.shrink();
  }
}

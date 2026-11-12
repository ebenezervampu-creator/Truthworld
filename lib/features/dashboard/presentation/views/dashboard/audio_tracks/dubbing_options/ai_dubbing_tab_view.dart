import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_pricing_summary.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_settings_card.dart';

/// Minimalist AI Dubbing tab view composing standalone setting cards
/// and the primary monochrome generation action button.
class AiDubbingTabView extends StatelessWidget {
  const AiDubbingTabView({
    required this.state,
    required this.durationSeconds,
    required this.onGenerate,
    super.key,
  });

  final DubbingOptionsState state;
  final int durationSeconds;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DubbingSettingsCard(state: state),
        const SizedBox(height: 24),
        DubbingPricingSummary(
          state: state,
          durationSeconds: durationSeconds,
          onGenerate: onGenerate,
        ),
      ],
    );
  }
}

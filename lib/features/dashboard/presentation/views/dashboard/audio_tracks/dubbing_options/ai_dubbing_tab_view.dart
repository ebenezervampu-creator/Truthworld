import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_pricing_summary.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_settings_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_tier_card.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Clean, modular ElevenLabs-style AI Voice Dubbing tab view.
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dubbing Production Tier Header & Media Switcher
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dubbing Production Tier',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '1. Vocal Identity & Synthesis Style',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Obx(() {
              final mode = state.selectedMediaMode.value;
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMediaModePill(
                      id: 'audio',
                      label: 'Audio (3 Tiers)',
                      icon: Icons.graphic_eq_rounded,
                      isActive: mode == 'audio',
                      onTap: () {
                        state.selectedMediaMode.value = 'audio';
                        if (state.selectedDubbingTier.value.startsWith('video_')) {
                          state.selectedDubbingTier.value = 'audio_starter';
                          state.voiceType.value = 'standard';
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildMediaModePill(
                      id: 'video',
                      label: 'Video (2 Tiers)',
                      icon: Icons.video_camera_back_rounded,
                      isActive: mode == 'video',
                      onTap: () {
                        state.selectedMediaMode.value = 'video';
                        if (state.selectedDubbingTier.value.startsWith('audio_')) {
                          state.selectedDubbingTier.value = 'video_pro';
                          state.voiceType.value = 'cloned';
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 10),

        // 2. Production Tier Cards (Clean ElevenLabs layout)
        Obx(() {
          final mode = state.selectedMediaMode.value;
          final chan = state.currentChannel.value;
          final isAudioMode = mode == 'audio';
          final activeTiers = isAudioMode
              ? DubbingProductionTier.audioTiers
              : DubbingProductionTier.videoTiers;

          return Column(
            children: activeTiers.map((tier) {
              final isSelected = state.selectedDubbingTier.value == tier.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DubbingTierCard(
                  tier: tier,
                  isSelected: isSelected,
                  durationSeconds: durationSeconds,
                  channel: chan,
                  onSelect: () {
                    state.selectedDubbingTier.value = tier.id;
                    state.selectedMediaMode.value = tier.category;
                    state.voiceType.value = tier.isVoiceClone ? 'cloned' : 'standard';
                  },
                ),
              );
            }).toList(),
          );
        }),

        const SizedBox(height: 14),

        // 3. Settings Card (Speaker Diarization + Voice Gender)
        DubbingSettingsCard(state: state),

        const SizedBox(height: 16),

        // 4. Live Pricing Summary & Action Bar
        DubbingPricingSummary(
          state: state,
          durationSeconds: durationSeconds,
          onGenerate: onGenerate,
        ),
      ],
    );
  }

  Widget _buildMediaModePill({
    required String id,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.black : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

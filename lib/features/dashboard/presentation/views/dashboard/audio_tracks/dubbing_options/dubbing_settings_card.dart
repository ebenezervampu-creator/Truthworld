import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Clean ElevenLabs-style settings card for Diarization and Voice Gender.
class DubbingSettingsCard extends StatelessWidget {
  const DubbingSettingsCard({
    required this.state,
    super.key,
  });

  final DubbingOptionsState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        children: [
          // 1. Speaker Diarization Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speaker Diarization (Multi-Person Videos)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Detects distinct speakers and assigns unique voices',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  return Switch(
                    value: state.enableDiarization.value,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.info,
                    onChanged: (val) => state.enableDiarization.value = val,
                  );
                }),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF222226)),

          // 2. Audio Ducking / Preservation Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.success.withValues(alpha: 0.05),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 15,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Studio Preservation: Discrete stems with Smart Audio Ducking',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF222226)),

          // 3. Speaker Voice Gender Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Speaker Voice Gender',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Obx(() {
                  final gender = state.selectedVoiceGender.value;
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A2A30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGenderPill(
                          id: 'auto',
                          label: 'Auto (AI)',
                          icon: Icons.auto_awesome,
                          isActive: gender == 'auto',
                          onTap: () => state.selectedVoiceGender.value = 'auto',
                        ),
                        const SizedBox(width: 4),
                        _buildGenderPill(
                          id: 'male',
                          label: 'Male Voice',
                          icon: Icons.male_rounded,
                          isActive: gender == 'male',
                          onTap: () => state.selectedVoiceGender.value = 'male',
                        ),
                        const SizedBox(width: 4),
                        _buildGenderPill(
                          id: 'female',
                          label: 'Female Voice',
                          icon: Icons.female_rounded,
                          isActive: gender == 'female',
                          onTap: () => state.selectedVoiceGender.value = 'female',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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

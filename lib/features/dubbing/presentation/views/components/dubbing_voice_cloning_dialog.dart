import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Modal dialog for voice cloning, multi-speaker assignment, and demux options.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`).
class DubbingVoiceCloningDialog extends StatelessWidget {
  const DubbingVoiceCloningDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DubbingStudioController>();

    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.record_voice_over_rounded,
                            color: AppColors.textLink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice Cloning & Studio Controls',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Multi-speaker detection • Audio separation • Voice matching',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Voice Cloning Toggle Card
                      Obx(() => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: controller.voiceCloningEnabled.value
                                ? AppColors.textLink
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.psychology_rounded, color: AppColors.textLink, size: 26),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Voice Cloning',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Matches each speaker's natural tone, pacing, and voice across target languages.",
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: controller.voiceCloningEnabled.value,
                              activeThumbColor: Colors.black,
                              activeTrackColor: Colors.white,
                              onChanged: controller.setVoiceCloning,
                            ),
                          ],
                        ),
                      )),
                      // Consent: shown only when cloning is on; cloning cannot start without it.
                      Obx(() => controller.voiceCloningEnabled.value
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: controller.voiceCloneConsent.value,
                                  onChanged: (val) => controller.voiceCloneConsent.value = val == true,
                                  activeColor: Colors.white,
                                  checkColor: Colors.black,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: const Text(
                                    'I am the person speaking in this video, or every speaker has given me permission to clone their voice.',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Without this, your dub uses natural voices from our native-speaker library.',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink()),
                      const SizedBox(height: 18),

                      // Audio Separation & Mixing Controls
                      const Text(
                        'AUDIO SEPARATION & MIXING',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: AppColors.bgInput,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Obx(() => Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  title: const Text(
                                    'Isolate Vocals (Remove Background Noise)',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Extract clean vocals before transcription',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  value: controller.isolateVocals.value,
                                  activeColor: Colors.white,
                                  checkColor: Colors.black,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) => controller.isolateVocals.value = val == true,
                                ),
                              )),
                              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                              Obx(() => Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  title: const Text(
                                    'Preserve Background Music & Sound Effects',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Keep original music and sound effects, lowered under dubbed speech',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  value: controller.preserveBgm.value,
                                  activeColor: Colors.white,
                                  checkColor: Colors.black,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) => controller.preserveBgm.value = val == true,
                                ),
                              )),
                              const SizedBox(height: 8),
                              // Ducking Slider
                              Obx(() => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Background Music Level:',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${controller.bgmDuckingPercent.value.toInt()}% lower',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textLink,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: controller.bgmDuckingPercent.value,
                                    max: 50.0,
                                    divisions: 10,
                                    activeColor: AppColors.brand,
                                    inactiveColor: AppColors.bgSurfaceHigh,
                                    onChanged: (val) => controller.bgmDuckingPercent.value = val,
                                  ),
                                ],
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Two-Stage Review Pipeline
                      Obx(() => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.rate_review_rounded, color: AppColors.textLink, size: 22),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Review Script Before Dubbing',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Pause before generating dubbed audio so you can review and edit the script.',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: controller.twoStageReviewEnabled.value,
                              activeThumbColor: Colors.black,
                              activeTrackColor: Colors.white,
                              onChanged: (val) => controller.twoStageReviewEnabled.value = val,
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 18),

                      // Speaker Voice, Pitch & Speed Overrides
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SPEAKER VOICE PROFILES',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: controller.addSpeaker,
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: AppColors.textLink),
                            label: const Text(
                              'Add Speaker',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textLink,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Obx(() => Column(
                        children: controller.speakers.map((spk) {
                          const voiceOptions = <Map<String, String>>[
                            {'id': 'default_voice', 'label': 'Auto (Natural Native Voice)'},
                            {'id': 'pNInz6obpgDQGcFmaJgB', 'label': 'Adam — Deep Male'},
                            {'id': '21m00Tcm4TlvDq8ikWAM', 'label': 'Rachel — Clear Female'},
                            {'id': 'ErXwobaYiN019PkySvjV', 'label': 'Antoni — Warm Male'},
                            {'id': 'EXAVITQu4vr4xnSDxMaL', 'label': 'Bella — Expressive Female'},
                          ];
                          final hasSelectedVoice = voiceOptions.any((v) => v['id'] == spk.assignedVoiceId);
                          final activeVoiceId = hasSelectedVoice ? spk.assignedVoiceId : 'default_voice';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgInput,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      spk.label,
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (controller.speakers.length > 1)
                                      IconButton(
                                        onPressed: () => controller.removeSpeaker(spk.id),
                                        icon: const Icon(Icons.close, size: 15, color: AppColors.textTertiary),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: activeVoiceId,
                                  dropdownColor: AppColors.bgSurface,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: AppColors.bgSurface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                  ),
                                  items: voiceOptions
                                      .map((v) => DropdownMenuItem<String>(
                                            value: v['id'],
                                            child: Text(v['label']!),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      controller.updateSpeakerVoice(spk.id, val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Speed: ${spk.speedAdjustment.toStringAsFixed(2)}x',
                                            style: const TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Slider(
                                            value: spk.speedAdjustment.clamp(0.7, 1.2),
                                            min: 0.7,
                                            max: 1.2,
                                            divisions: 10,
                                            activeColor: AppColors.brand,
                                            inactiveColor: AppColors.bgSurfaceHigh,
                                            onChanged: (v) => controller.updateSpeakerTuning(spk.id, speed: v),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pitch: ${spk.pitchAdjustment >= 0 ? '+' : ''}${spk.pitchAdjustment.round()} st',
                                            style: const TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Slider(
                                            value: spk.pitchAdjustment.clamp(-6.0, 6.0),
                                            min: -6.0,
                                            max: 6.0,
                                            divisions: 12,
                                            activeColor: AppColors.brand,
                                            inactiveColor: AppColors.bgSurfaceHigh,
                                            onChanged: (v) => controller.updateSpeakerTuning(spk.id, pitch: v),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: Get.back,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_and_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 10: Subtitles and Dubbing Studio Section.
/// Shows status of AI Subtitles (130+ languages) and Neural Voice Dubbing (70+ languages),
/// and opens the dedicated Subtitles and Dubbing configuration page.
class CreateContentSubtitlesDubbingSection extends StatelessWidget {
  final UploadController uploadController;

  const CreateContentSubtitlesDubbingSection({
    required this.uploadController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubtitles = uploadController.aiGenerateSubtitles.value;
      final isDubbing = uploadController.aiGenerateDubbing.value;

      final selectedSubLangs = uploadController.aiTranslationLanguages;
      final selectedDubLangs = uploadController.aiDubbingLanguages;

      final selectedChan = uploadController.selectedChannel.value;
      final isCustom = selectedChan?.channelType == ChannelType.custom;
      final channelType = isCustom ? ChannelType.custom : ChannelType.standard;
      final durationSec = uploadController.videoDurationSeconds.value;

      final dubbingCost = ChannelWalletService.calculateDubbingCost(
        languageCount: selectedDubLangs.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      final subLangsToBill = (isDubbing
              ? selectedSubLangs
                  .where((l) => !selectedDubLangs.contains(l))
                  .toList()
              : selectedSubLangs.toList())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      final subtitleCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: subLangsToBill.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      final totalCost = (isSubtitles ? subtitleCost : 0.0) +
          (isDubbing ? dubbingCost : 0.0);

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '10. Subtitles and Dubbing',
                      style: context.themeTypography.title.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCustom)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.6)),
                        ),
                        child: const Text(
                          'PRO CHANNEL',
                          style: TextStyle(
                            color: Color(0xFFC4B5FD),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'AI Subtitles (130+ languages) & Neural Audio Dubbing (70+ languages)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitles Status Item
              _buildFeatureStatusTile(
                icon: Icons.subtitles,
                iconColor: const Color(0xFF60A5FA),
                iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                title: 'AI Subtitles & Translation',
                subtitle: isSubtitles
                    ? (selectedSubLangs.isNotEmpty
                        ? '${selectedSubLangs.length} ${selectedSubLangs.length == 1 ? "language" : "languages"} • \$${subtitleCost.toStringAsFixed(2)}'
                        : 'Enabled • Tap to configure')
                    : 'Disabled',
                isEnabled: isSubtitles,
                onToggle: (val) {
                  uploadController.aiGenerateSubtitles.value = val;
                  if (val && selectedSubLangs.isEmpty) {
                    Get.to(() => const UploadSubtitlesAndDubbingPage());
                  }
                },
              ),
              const SizedBox(height: 10),

              // Dubbing Status Item
              _buildFeatureStatusTile(
                icon: Icons.translate,
                iconColor: const Color(0xFFA78BFA),
                iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                title: 'AI Voice Dubbing & Localization',
                subtitle: isDubbing
                    ? (selectedDubLangs.isNotEmpty
                        ? '${selectedDubLangs.length} ${selectedDubLangs.length == 1 ? "language" : "languages"} • \$${dubbingCost.toStringAsFixed(2)}'
                        : 'Enabled • Tap to configure')
                    : 'Disabled (Dubbing is not free)',
                isEnabled: isDubbing,
                onToggle: (val) {
                  uploadController.aiGenerateDubbing.value = val;
                  if (val && selectedDubLangs.isEmpty) {
                    Get.to(() => const UploadSubtitlesAndDubbingPage());
                  }
                },
              ),

              const SizedBox(height: 14),

              // Open in separate page action button
              InkWell(
                onTap: () => Get.to(() => const UploadSubtitlesAndDubbingPage()),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F24),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (isSubtitles || isDubbing)
                              ? 'Configure Subtitles & Dubbing (\$${totalCost.toStringAsFixed(2)})'
                              : 'Configure Subtitles & Dubbing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 13),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFeatureStatusTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEnabled
              ? iconColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isEnabled ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeColor: Colors.white,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

/// Section 11: TruthWorld Verification Section.
/// Standalone epistemic multi-source AI fact-checking toggle card.
class CreateContentTruthVerificationSection extends StatelessWidget {
  final UploadController uploadController;

  const CreateContentTruthVerificationSection({
    required this.uploadController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFactCheck = uploadController.aiFactCheckEnabled.value;

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '11. TruthWorld Verification',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // Toggle Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131316),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFactCheck
                        ? const Color(0xFF34D399).withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.06),
                    width: isFactCheck ? 1.2 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Color(0xFF34D399),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Truth Verification (Full Ground Truth)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Epistemic multi-source AI verification & claim citations',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isFactCheck,
                      activeColor: Colors.white,
                      onChanged: (val) {
                        uploadController.aiFactCheckEnabled.value = val;
                        if (val) {
                          uploadController.aiFactCheckTier.value = 'full_ground';
                          uploadController.allowRatings.value = true;
                          uploadController.aiFactCheckReviewMode.value = 'open_to_users';
                        } else {
                          uploadController.aiFactCheckTier.value = 'none';
                          uploadController.allowRatings.value = false;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}



/// Section 12: Speaker Diarization Section.
/// Dedicated card to enable multi-speaker recognition and labeling.
class CreateContentSpeakerDiarizationSection extends StatelessWidget {
  final UploadController uploadController;

  const CreateContentSpeakerDiarizationSection({
    required this.uploadController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDiarization = uploadController.aiDiarizationEnabled.value;

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDiarization
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
              width: isDiarization ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Color(0xFF60A5FA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '12. Speaker Diarization',
                          style: context.themeTypography.title.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Identify and label multiple speakers',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDiarization,
                    activeColor: Colors.white,
                    onChanged: (val) =>
                        uploadController.aiDiarizationEnabled.value = val,
                  ),
                ],
              ),
              if (isDiarization) ...[
                const SizedBox(height: 8),
                Text(
                  'Multi-speaker detection active. Distinct voices will be automatically identified and tagged in generated subtitles and dubs.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// Section 13: Auto Chapters Section.
/// Dedicated card to enable automated smart video timestamp chapters.
class CreateContentAutoChaptersSection extends StatelessWidget {
  final UploadController uploadController;

  const CreateContentAutoChaptersSection({
    required this.uploadController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isChapters = uploadController.aiChaptersEnabled.value;

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isChapters
                  ? const Color(0xFFA78BFA).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
              width: isChapters ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_label,
                      color: Color(0xFFA78BFA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '13. Auto Chapters',
                          style: context.themeTypography.title.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generate smart video timestamp chapters',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isChapters,
                    activeColor: Colors.white,
                    onChanged: (val) =>
                        uploadController.aiChaptersEnabled.value = val,
                  ),
                ],
              ),
              if (isChapters) ...[
                const SizedBox(height: 8),
                Text(
                  'Auto chapters active. Smart timestamp bookmarks will be detected and indexed for viewers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// Legacy / Backward Compatibility Section.
/// Preserved so existing tests that reference CreateContentAISection continue to pass.
class CreateContentAISection extends StatelessWidget {
  final UploadController controller;

  const CreateContentAISection({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubtitles = controller.aiGenerateSubtitles.value;
      final isDubbing = controller.aiGenerateDubbing.value;
      final isFactCheck = controller.aiFactCheckEnabled.value;
      final isDiarization = controller.aiDiarizationEnabled.value;
      final isChapters = controller.aiChaptersEnabled.value;

      final selectedSubLangs = controller.aiTranslationLanguages;
      final selectedDubLangs = controller.aiDubbingLanguages;

      final selectedChan = controller.selectedChannel.value;
      final isCustom = selectedChan?.channelType == ChannelType.custom;
      final channelType = isCustom ? ChannelType.custom : ChannelType.standard;
      final durationSec = controller.videoDurationSeconds.value;

      final dubbingCost = ChannelWalletService.calculateDubbingCost(
        languageCount: selectedDubLangs.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      final subLangsToBill = (isDubbing
              ? selectedSubLangs
                  .where((l) => !selectedDubLangs.contains(l))
                  .toList()
              : selectedSubLangs.toList())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      final subtitleCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: subLangsToBill.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '10. AI Features & Intelligence',
                    style: context.themeTypography.title.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  if (isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.6)),
                      ),
                      child: const Text(
                        'PRO CHANNEL',
                        style: TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Subtitles Card
              _buildFeatureCard(
                context: context,
                icon: Icons.subtitles,
                iconColor: const Color(0xFF60A5FA),
                iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                title: 'AI Subtitles & Translation (130+ Languages)',
                subtitle: 'Google Cloud Translation supported caption languages',
                isEnabled: isSubtitles,
                onToggle: (val) {
                  controller.aiGenerateSubtitles.value = val;
                  if (val && selectedSubLangs.isEmpty) {
                    Get.to(() => const UploadSubtitlesPage());
                  }
                },
                statusText: isSubtitles
                    ? (selectedSubLangs.isNotEmpty
                        ? '${selectedSubLangs.length} ${selectedSubLangs.length == 1 ? "language" : "languages"} • \$${subtitleCost.toStringAsFixed(2)}'
                        : 'Enabled • Tap to select languages')
                    : 'Disabled • Tap to configure languages & pricing',
                buttonLabel: 'Configure Languages & Pricing →',
                onOpenPage: () => Get.to(() => const UploadSubtitlesPage()),
                selectedLanguages: selectedSubLangs.toList(),
              ),
              const SizedBox(height: 12),

              // 2. Dubbing Card
              _buildFeatureCard(
                context: context,
                icon: Icons.translate,
                iconColor: const Color(0xFFA78BFA),
                iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                badgeLabel: 'DUBBING IS NOT FREE',
                badgeColor: const Color(0xFFF59E0B),
                title: 'AI Audio Translation & Dubbing (70+ Languages)',
                subtitle: 'Natural AI voice dubbing & studio vocal identity',
                isEnabled: isDubbing,
                onToggle: (val) {
                  controller.aiGenerateDubbing.value = val;
                  if (val && selectedDubLangs.isEmpty) {
                    Get.to(() => const UploadDubbingPage());
                  }
                },
                statusText: isDubbing
                    ? (selectedDubLangs.isNotEmpty
                        ? '${selectedDubLangs.length} ${selectedDubLangs.length == 1 ? "language" : "languages"} • ${controller.aiTTSVoiceType.value == "cloned" ? "Voice Clone" : "Standard Voice"} • \$${dubbingCost.toStringAsFixed(2)}'
                        : 'Enabled • Tap to select languages & voices')
                    : 'Disabled • Tap to configure 70+ languages & voices',
                buttonLabel: 'Configure Dubbing, Voices & Pricing →',
                onOpenPage: () => Get.to(() => const UploadDubbingPage()),
                selectedLanguages: selectedDubLangs.toList(),
              ),
              const SizedBox(height: 12),

              // 3. TruthWorld Verification
              _buildDirectToggleCard(
                context: context,
                icon: Icons.verified,
                iconColor: const Color(0xFF34D399),
                iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                title: 'Truth Verification (Full Ground Truth)',
                subtitle: 'Epistemic multi-source AI verification & claim citations',
                isEnabled: isFactCheck,
                onToggle: (val) {
                  controller.aiFactCheckEnabled.value = val;
                  if (val) {
                    controller.aiFactCheckTier.value = 'full_ground';
                    controller.allowRatings.value = true;
                    controller.aiFactCheckReviewMode.value = 'open_to_users';
                  } else {
                    controller.aiFactCheckTier.value = 'none';
                    controller.allowRatings.value = false;
                  }
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),

              // Speaker Diarization Switch
              SwitchListTile(
                value: isDiarization,
                onChanged: (val) => controller.aiDiarizationEnabled.value = val,
                title: const Text(
                  'Speaker Diarization',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Identify and label multiple speakers',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                activeColor: Colors.white,
                secondary: const Icon(Icons.record_voice_over, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // Auto Chapters Switch
              SwitchListTile(
                value: isChapters,
                onChanged: (val) => controller.aiChaptersEnabled.value = val,
                title: const Text(
                  'Auto Chapters',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Generate smart video timestamp chapters',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                activeColor: Colors.white,
                secondary: const Icon(Icons.video_label, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDirectToggleCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    String? badgeLabel,
    Color? badgeColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF34D399).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: isEnabled ? 1.2 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? Colors.white).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (badgeColor ?? Colors.white).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              color: badgeColor ?? Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeColor: Colors.white,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required String statusText,
    required String buttonLabel,
    required VoidCallback onOpenPage,
    String? badgeLabel,
    Color? badgeColor,
    List<String>? selectedLanguages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? Colors.white24 : Colors.white.withValues(alpha: 0.06),
          width: isEnabled ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 8, top: 12, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? Colors.white).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (badgeColor ?? Colors.white).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeColor ?? Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeColor: Colors.white,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),

          if (isEnabled && selectedLanguages != null && selectedLanguages.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...selectedLanguages.take(6).map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        lang,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                  if (selectedLanguages.length > 6)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '+${selectedLanguages.length - 6} more',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const Divider(color: Colors.white10, height: 1),

          InkWell(
            onTap: onOpenPage,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.white60,
                        fontSize: 11.5,
                        fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




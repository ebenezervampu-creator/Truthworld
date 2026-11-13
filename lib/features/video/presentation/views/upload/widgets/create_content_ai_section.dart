import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_and_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 10: Subtitles and Dubbing Studio Section.
/// Shows status of AI Subtitles (130+ languages) and Neural Voice Dubbing (70+ languages),
/// and opens the dedicated Subtitles and Dubbing configuration page.
class CreateContentSubtitlesDubbingSection extends StatelessWidget {
  final UploadController uploadController;
  final bool showHeader;

  const CreateContentSubtitlesDubbingSection({
    required this.uploadController,
    this.showHeader = true,
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
              if (showHeader) ...[
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
                  'AI Subtitles (135+ languages) & Neural Audio Dubbing (78 languages)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Spoken Video Language ("From") Selector: Same 39 languages for Subtitles & Dubbing
              _buildSpokenLanguageSelector(context, uploadController),
              const SizedBox(height: 12),

              // Subtitles Status Item
              _buildFeatureStatusTile(
                icon: Icons.subtitles,
                iconColor: const Color(0xFF60A5FA),
                iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                title: 'AI Subtitles & Translation',
                subtitle: isSubtitles
                    ? (selectedSubLangs.isNotEmpty
                        ? '${selectedSubLangs.length} ${selectedSubLangs.length == 1 ? "language" : "languages"} (Google Cloud Translation & Gemini 2.5 Flash) • \$${subtitleCost.toStringAsFixed(2)}'
                        : 'Enabled • 135+ target languages available')
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
                        ? '${selectedDubLangs.length} ${selectedDubLangs.length == 1 ? "language" : "languages"} (ElevenLabs v4) • \$${dubbingCost.toStringAsFixed(2)}'
                        : 'Enabled • 78 target languages available (ElevenLabs v4)')
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

  Widget _buildSpokenLanguageSelector(BuildContext context, UploadController uploadController) {
    final currentCode = uploadController.primarySpokenLanguage.value.isEmpty
        ? 'auto'
        : uploadController.primarySpokenLanguage.value;
    final match = allSpokenLanguages.firstWhereOrNull((l) => l.code == currentCode);
    final displayName = match != null
        ? (match.code == 'auto' ? match.name : '${match.name} (${match.nativeName})')
        : currentCode.toUpperCase();

    return InkWell(
      onTap: () => showSpokenLanguagePicker(
        context: context,
        controller: uploadController,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111114),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                color: Color(0xFF38BDF8),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spoken Video Language ("From")',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '39 languages supported via AssemblyAI Universal-3.5 Pro & Sarvam AI',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2029),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
  final bool showHeader;

  const CreateContentTruthVerificationSection({
    required this.uploadController,
    this.showHeader = true,
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
              if (showHeader) ...[
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
              ],

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
  final bool showHeader;

  const CreateContentSpeakerDiarizationSection({
    required this.uploadController,
    this.showHeader = true,
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
                          showHeader ? '12. Speaker Diarization' : 'Speaker Diarization',
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
  final bool showHeader;

  const CreateContentAutoChaptersSection({
    required this.uploadController,
    this.showHeader = true,
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
                          showHeader ? '13. Auto Chapters' : 'Auto Chapters',
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

/// Progressive AI Studio Card for video uploads.
/// Consolidates Subtitles, Dubbing, Factcheck, Speaker Diarization, and Auto Chapters
/// into a clean progressive card with 5 quick-toggle feature chips and on-demand expansion.
class CreateContentUnifiedAiSection extends StatelessWidget {
  final UploadController uploadController;

  const CreateContentUnifiedAiSection({
    required this.uploadController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubtitles = uploadController.aiGenerateSubtitles.value;
      final isDubbing = uploadController.aiGenerateDubbing.value;
      final isFactCheck = uploadController.aiFactCheckEnabled.value;
      final isDiarization = uploadController.aiDiarizationEnabled.value;
      final isChapters = uploadController.aiChaptersEnabled.value;
      final isExpanded = uploadController.isAiFeaturesExpanded.value;

      final selectedChan = uploadController.selectedChannel.value;
      final isCustom = selectedChan?.channelType == ChannelType.custom;
      final channelType = isCustom ? ChannelType.custom : ChannelType.standard;
      final durationSec = uploadController.videoDurationSeconds.value;

      final selectedSubLangs = uploadController.aiTranslationLanguages;
      final selectedDubLangs = uploadController.aiDubbingLanguages;

      final dubbingCost = ChannelWalletService.calculateDubbingCost(
        languageCount: selectedDubLangs.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      final subLangsToBill = (isDubbing
              ? selectedSubLangs.where((l) => !selectedDubLangs.contains(l)).toList()
              : selectedSubLangs.toList())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      final subtitleCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: subLangsToBill.length,
        durationSeconds: durationSec,
        channelType: channelType,
        channel: selectedChan,
      );

      final totalCost = (isSubtitles ? subtitleCost : 0.0) + (isDubbing ? dubbingCost : 0.0);

      final activeCount = [
        isSubtitles,
        isDubbing,
        isFactCheck,
        isDiarization,
        isChapters,
      ].where((v) => v).length;

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
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '10. AI Features & Intelligence',
                              style: context.themeTypography.title.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isCustom) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.6)),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Color(0xFFC4B5FD),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeCount == 0
                              ? 'Tap to add AI subtitles, dubbing, fact-checking & chapters'
                              : '$activeCount features enabled${totalCost > 0 ? " • \$${totalCost.toStringAsFixed(2)}" : " • Free (\$0.00)"}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222227),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFA78BFA),
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'AI Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5 Feature Toggles / Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFeatureChip(
                    label: 'Subtitles',
                    icon: Icons.subtitles_rounded,
                    isActive: isSubtitles && selectedSubLangs.isNotEmpty,
                    badgeText: selectedSubLangs.isNotEmpty ? '${selectedSubLangs.length}' : null,
                    onTap: () {
                      Get.to(() => const UploadSubtitlesPage());
                    },
                  ),
                  _buildFeatureChip(
                    label: 'Dubbing',
                    icon: Icons.translate_rounded,
                    isActive: isDubbing && selectedDubLangs.isNotEmpty,
                    badgeText: selectedDubLangs.isNotEmpty
                        ? '${selectedDubLangs.length} • \$${dubbingCost.toStringAsFixed(0)}'
                        : null,
                    onTap: () {
                      Get.to(() => const UploadDubbingPage());
                    },
                  ),
                  _buildFeatureChip(
                    label: 'Factcheck',
                    icon: Icons.verified_outlined,
                    isActive: isFactCheck,
                    badgeText: isFactCheck ? 'Verified' : null,
                    onTap: () {
                      uploadController.aiFactCheckEnabled.value = !isFactCheck;
                    },
                  ),
                  _buildFeatureChip(
                    label: 'Speaker Diarization',
                    icon: Icons.record_voice_over_rounded,
                    isActive: isDiarization,
                    onTap: () {
                      uploadController.aiDiarizationEnabled.value = !isDiarization;
                    },
                  ),
                  _buildFeatureChip(
                    label: 'Auto Chapters',
                    icon: Icons.format_list_bulleted_rounded,
                    isActive: isChapters,
                    onTap: () {
                      uploadController.aiChaptersEnabled.value = !isChapters;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Active Studio Configurations (Subtitles & Dubbing)
              if ((isSubtitles && selectedSubLangs.isNotEmpty) || (isDubbing && selectedDubLangs.isNotEmpty)) ...[
                if (isSubtitles && selectedSubLangs.isNotEmpty) ...[
                  _buildActiveTrackCard(
                    icon: Icons.subtitles_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    iconBgColor: const Color(0xFF2563EB).withValues(alpha: 0.16),
                    title: 'AI Subtitles & Captions (${selectedSubLangs.length} ${selectedSubLangs.length == 1 ? "language" : "languages"})',
                    languagesPreview: selectedSubLangs.take(5).join(', ') +
                        (selectedSubLangs.length > 5 ? ' +${selectedSubLangs.length - 5} more' : ''),
                    costLabel: subtitleCost > 0 ? '\$${subtitleCost.toStringAsFixed(2)}' : 'Free (Included)',
                    onEdit: () => Get.to(() => const UploadSubtitlesPage()),
                    onRemove: () {
                      uploadController.aiGenerateSubtitles.value = false;
                      uploadController.aiTranslationLanguages.clear();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (isDubbing && selectedDubLangs.isNotEmpty) ...[
                  _buildActiveTrackCard(
                    icon: Icons.translate_rounded,
                    iconColor: const Color(0xFFA78BFA),
                    iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                    title: 'AI Audio Dubbing (${selectedDubLangs.length} ${selectedDubLangs.length == 1 ? "language" : "languages"} • ElevenLabs v4)',
                    languagesPreview: selectedDubLangs.take(5).join(', ') +
                        (selectedDubLangs.length > 5 ? ' +${selectedDubLangs.length - 5} more' : ''),
                    costLabel: '\$${dubbingCost.toStringAsFixed(2)}',
                    onEdit: () => Get.to(() => const UploadDubbingPage()),
                    onRemove: () {
                      uploadController.aiGenerateDubbing.value = false;
                      uploadController.aiDubbingLanguages.clear();
                    },
                  ),
                ],
              ] else ...[
                // Clean guidance hint when no studio languages are chosen yet
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white60, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap Subtitles or Dubbing to configure source & output languages. Factcheck, Diarization, and Chapters toggle directly.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFeatureChip({
    required String label,
    required IconData icon,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final fgColor = isActive ? Colors.black : Colors.white70;
    final bgColor = isActive ? Colors.white : const Color(0xFF1E1E22);
    final borderColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : icon,
              size: 15,
              color: fgColor,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? Colors.black : const Color(0xFF333339),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrackCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String languagesPreview,
    required String costLabel,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        costLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  languagesPreview,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF222430),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Configure',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
            onPressed: onRemove,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
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




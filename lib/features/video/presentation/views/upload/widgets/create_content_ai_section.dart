import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 10: AI-powered features configuration (Subtitles, Dubbing, Fact Checking, Chapters, Summary)
/// Clean, modular, and optimized with dedicated configuration & pricing pages for Subtitles, Dubbing, and Fact-Checking.
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

      final isCustom = controller.selectedChannel.value?.channelType == ChannelType.custom;
      final channelType = isCustom ? ChannelType.custom : ChannelType.standard;
      final durationSec = controller.videoDurationSeconds.value;

      // Pricing computations
      final dubbingCost = ChannelWalletService.calculateDubbingCost(
        languageCount: selectedDubLangs.length,
        durationSeconds: durationSec,
        channelType: channelType,
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
                        'CUSTOM CHANNEL',
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

              // 1. Subtitles Card with Dedicated Page Navigation
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

              // 2. Dubbing Card with Dedicated Page Navigation
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

              // 3. TruthWorld Verification (Direct On / Off Toggle - 100% Free)
              _buildDirectToggleCard(
                context: context,
                icon: Icons.verified,
                iconColor: const Color(0xFF34D399),
                iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                badgeLabel: '100% FREE',
                badgeColor: const Color(0xFF10B981),
                title: 'Truth Verification (Full Ground Truth)',
                subtitle: 'Epistemic multi-source AI verification & Truth Score',
                isEnabled: isFactCheck,
                onToggle: (val) {
                  controller.aiFactCheckEnabled.value = val;
                  if (val) {
                    controller.aiFactCheckTier.value = 'full_ground';
                  } else {
                    controller.aiFactCheckTier.value = 'none';
                  }
                },
              ),
              if (isFactCheck) ...[
                const SizedBox(height: 10),
                _buildFactCheckReviewModeSelector(context, controller),
              ],
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
                          maxLines: 1,
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
          // Header Row with Switch
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
                              maxLines: 1,
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

          // Selected languages pill preview
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

          // Divider
          const Divider(color: Colors.white10, height: 1),

          // Footer Action & Status Row
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

  Widget _buildFactCheckReviewModeSelector(
    BuildContext context,
    UploadControllerBase controller,
  ) {
    final currentMode = controller.aiFactCheckReviewMode.value;

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.rule_folder_rounded,
                size: 15,
                color: Color(0xFF34D399),
              ),
              SizedBox(width: 8),
              Text(
                'Fact-Check Results Delivery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose whether verification results are immediately visible to users or held for your review first.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildReviewOptionTile(
            title: 'Open for user directly',
            subtitle:
                'Results appear for viewers immediately once verification analysis completes.',
            icon: Icons.public_rounded,
            isSelected: currentMode == 'open_to_users',
            onTap: () =>
                controller.aiFactCheckReviewMode.value = 'open_to_users',
          ),
          const SizedBox(height: 8),
          _buildReviewOptionTile(
            title: 'Show results first to you',
            subtitle:
                'Hidden from viewers on video screen until you review & approve in Studio Notifications.',
            icon: Icons.admin_panel_settings_rounded,
            isSelected: currentMode == 'first_to_creator',
            onTap: () =>
                controller.aiFactCheckReviewMode.value = 'first_to_creator',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.12)
              : const Color(0xFF16171B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF34D399)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? const Color(0xFF34D399) : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white38,
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

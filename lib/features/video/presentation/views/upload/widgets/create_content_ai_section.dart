import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 10: AI-powered features configuration (Subtitles, Dubbing, Fact Checking, Chapters, Summary)
class CreateContentAISection extends StatelessWidget {
  final UploadController controller;

  const CreateContentAISection({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleSearchQuery = ''.obs;
    final dubbingSearchQuery = ''.obs;

    final allSubtitleLangs = supportedLanguages.map((l) => l.name).toList();

    final allDubbingLangs = [
      'English', 'Spanish', 'French', 'German', 'Hindi', 'Japanese', 'Chinese (Mandarin)',
      'Portuguese', 'Italian', 'Arabic', 'Russian', 'Korean', 'Turkish', 'Dutch', 'Swedish', 'Polish',
      'Bengali', 'Telugu', 'Tamil', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu',
      'Indonesian', 'Thai', 'Vietnamese', 'Czech', 'Greek', 'Hebrew', 'Hungarian', 'Danish', 'Finnish',
      'Norwegian', 'Slovak', 'Bulgarian', 'Catalan', 'Croatian', 'Lithuanian', 'Slovenian', 'Afrikaans',
      'Tagalog', 'Malay', 'Persian', 'Romanian', 'Ukrainian', 'Estonian', 'Latvian', 'Serbian', 'Albanian',
      'Azerbaijani', 'Basque', 'Belarusian', 'Bosnian', 'Galician', 'Georgian', 'Icelandic', 'Irish',
      'Macedonian', 'Maltese', 'Nepali', 'Somali', 'Swahili', 'Welsh', 'Yiddish', 'Zulu', 'Kazakh', 'Uzbek'
    ];

    return Obx(() {
      final isFactCheck = controller.aiFactCheckEnabled.value;
      final isSubtitles = controller.aiGenerateSubtitles.value;
      final isDubbing = controller.aiGenerateDubbing.value;
      final isDiarization = controller.aiDiarizationEnabled.value;
      final isChapters = controller.aiChaptersEnabled.value;
      final isSummary = controller.aiSummaryEnabled.value;

      final selectedSubLangs = controller.aiTranslationLanguages;
      final selectedDubLangs = controller.aiDubbingLanguages;

      final filteredSubLangs = subtitleSearchQuery.value.isEmpty
          ? allSubtitleLangs
          : allSubtitleLangs.where((l) => l.toLowerCase().contains(subtitleSearchQuery.value.toLowerCase())).toList();

      final filteredDubLangs = dubbingSearchQuery.value.isEmpty
          ? allDubbingLangs
          : allDubbingLangs.where((l) => l.toLowerCase().contains(dubbingSearchQuery.value.toLowerCase())).toList();

      final isCustom = controller.selectedChannel.value?.channelType == ChannelType.custom;
      final channelType = isCustom ? ChannelType.custom : ChannelType.standard;
      final dubbingCost = ChannelWalletService.calculateDubbingCost(
        languageCount: selectedDubLangs.length,
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
              Text(
                '10. AI Features',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // Auto-Generate Subtitles (100+ Languages)
              SwitchListTile(
                value: isSubtitles,
                onChanged: (val) => controller.aiGenerateSubtitles.value = val,
                title: const Text('Auto-Generate Subtitles (100+ Languages)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Google Cloud Translation supported caption languages', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.subtitles, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              if (isSubtitles) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: (v) => subtitleSearchQuery.value = v,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search 100+ subtitle languages...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: filteredSubLangs.map((lang) {
                              final isSelected = selectedSubLangs.contains(lang);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
                                selectedColor: Colors.white,
                                backgroundColor: const Color(0xFF0F0F11),
                                onSelected: (_) {
                                  controller.toggleSubtitleLanguage(lang);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white10),

              // AI Audio Translation & Dubbing (70+ Languages)
              SwitchListTile(
                value: isDubbing,
                onChanged: (val) => controller.aiGenerateDubbing.value = val,
                title: const Text('AI Audio Translation & Dubbing (70+ Languages)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Natural AI voice dubbing (Selecting dubbing auto-enables subtitles)', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.translate, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              if (isDubbing) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dubbing Pricing Card for Standard vs Custom Channels
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCustom
                              ? const Color(0xFF1F1235)
                              : const Color(0xFF141418),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCustom
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                                : const Color(0xFF27272A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCustom
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCustom ? 'CUSTOM CHANNEL' : 'STANDARD CHANNEL',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isCustom
                                        ? r'$0.25 / language (50% Partner Discount)'
                                        : r'$0.50 / language (Min $1.50)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isCustom
                                  ? '✓ Studio Vocal Identity & Voice Cloning included at no extra charge • Deducted from monthly bonus credit & channel revenue.'
                                  : 'Standard AI voice synthesis • Funded from channel balance & trial credit. (Tip: Custom channels get 50% discount & Voice Cloning).',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                            if (selectedDubLangs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${selectedDubLangs.length} ${selectedDubLangs.length == 1 ? "language" : "languages"} selected',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      'Estimated Cost: \$${dubbingCost.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Channel Wallet Balance & Quick Add Money
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Wallet: \$${(controller.selectedChannel.value?.walletBalanceUSD ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (controller.selectedChannel.value != null)
                                    GestureDetector(
                                      onTap: () {
                                        ChannelWalletTopupSheet.show(
                                          context,
                                          channel: controller.selectedChannel.value!,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '+ Add Money',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        onChanged: (v) => dubbingSearchQuery.value = v,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search 70+ dubbing languages...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: filteredDubLangs.map((lang) {
                              final isSelected = selectedDubLangs.contains(lang);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
                                selectedColor: Colors.white,
                                backgroundColor: const Color(0xFF0F0F11),
                                onSelected: (_) {
                                  controller.toggleDubbingLanguage(lang);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white10),

              // Speaker Diarization
              SwitchListTile(
                value: isDiarization,
                onChanged: (val) => controller.aiDiarizationEnabled.value = val,
                title: const Text('Speaker Diarization', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Identify and label multiple speakers', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.record_voice_over, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // Auto Chapters
              SwitchListTile(
                value: isChapters,
                onChanged: (val) => controller.aiChaptersEnabled.value = val,
                title: const Text('Auto Chapters', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Generate smart video timestamp chapters', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.video_label, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // AI Summary
              SwitchListTile(
                value: isSummary,
                onChanged: (val) => controller.aiSummaryEnabled.value = val,
                title: const Text('AI Video Summary', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Generate smart key takeaways overview', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // Truth Verification
              SwitchListTile(
                value: isFactCheck,
                onChanged: (val) => controller.aiFactCheckEnabled.value = val,
                title: const Text('Truth Verification Analysis', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Enable automated fact-checking & claim verification', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.verified, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
    });
  }
}

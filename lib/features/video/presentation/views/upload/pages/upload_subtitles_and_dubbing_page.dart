import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';

/// Dedicated Subtitles and Dubbing Hub Page.
/// Redesigned with ElevenLabs clean, modern dark aesthetic, high contrast typography,
/// and country-selection-style multi-language modal pickers.
class UploadSubtitlesAndDubbingPage extends StatelessWidget {
  const UploadSubtitlesAndDubbingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadController = Get.isRegistered<UploadController>()
        ? Get.find<UploadController>()
        : Get.put(UploadController());

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101116),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF222430), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtitles and Dubbing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Multilingual captions & neural AI voice localization',
              style: TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              onPressed: Get.back,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Obx(() {
                final isSubtitles = uploadController.aiGenerateSubtitles.value;
                final isDubbing = uploadController.aiGenerateDubbing.value;

                final selectedSubLangs = uploadController.aiTranslationLanguages;
                final selectedDubLangs = uploadController.aiDubbingLanguages;

                final isCustom = uploadController.selectedChannel.value?.channelType ==
                    ChannelType.custom;
                final channelType =
                    isCustom ? ChannelType.custom : ChannelType.standard;
                final durationSec = uploadController.videoDurationSeconds.value;

                // Costs
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

                final totalCost = (isSubtitles ? subtitleCost : 0.0) +
                    (isDubbing ? dubbingCost : 0.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header / Overview Banner
                    _buildOverviewBanner(context, isCustom),
                    const SizedBox(height: 18),

                    // 0. Spoken Video Language ("From") Card
                    _buildSpokenLanguageCard(context: context, controller: uploadController),
                    const SizedBox(height: 18),

                    // 1. AI Subtitles & Translation Card
                    _buildSubtitlesCard(
                      context: context,
                      controller: uploadController,
                      isEnabled: isSubtitles,
                      selectedLanguages: selectedSubLangs.toList(),
                      subtitleCost: subtitleCost,
                    ),
                    const SizedBox(height: 16),

                    // 2. AI Audio Translation & Dubbing Card
                    _buildDubbingCard(
                      context: context,
                      controller: uploadController,
                      isEnabled: isDubbing,
                      selectedLanguages: selectedDubLangs.toList(),
                      dubbingCost: dubbingCost,
                    ),
                    const SizedBox(height: 18),

                    // 3. Pricing Summary Card
                    _buildPricingSummaryCard(
                      context: context,
                      isSubtitles: isSubtitles,
                      isDubbing: isDubbing,
                      subLangsCount: subLangsToBill.length,
                      dubLangsCount: selectedDubLangs.length,
                      subtitleCost: subtitleCost,
                      dubbingCost: dubbingCost,
                      totalCost: totalCost,
                    ),
                    const SizedBox(height: 24),

                    // Bottom Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: Get.back,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save & Return to Studio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewBanner(BuildContext context, bool isCustom) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262834)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.language,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Global Reach Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                          ),
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
                const SizedBox(height: 4),
                const Text(
                  'Reach viewers worldwide in their native language with AI translation powered by Google Cloud and studio vocal identity.',
                  style: TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpokenLanguageCard({
    required BuildContext context,
    required UploadController controller,
  }) {
    const popularLanguages = [
      {'code': 'auto', 'name': 'Auto-Detect', 'native': 'Auto'},
      {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
      {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
      {'code': 'en', 'name': 'English', 'native': 'English'},
      {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
      {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
      {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
      {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
      {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
      {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    ];

    final currentPrimary = controller.primarySpokenLanguage.value.isEmpty
        ? 'auto'
        : controller.primarySpokenLanguage.value;
    final isMultilingual = controller.isMultilingualSpoken.value;
    final selectedSpoken = controller.spokenLanguages;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spoken Video Language ("From")',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Free native subtitles are generated in this language without translation charges',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Language Chips (Top popular + custom selected + 50+ Languages Browse)
          Builder(
            builder: (context) {
              final displayedChips = <Map<String, String>>[...popularLanguages];
              if (!displayedChips.any((l) => l['code'] == currentPrimary)) {
                final match = allSpokenLanguages.firstWhereOrNull((l) => l.code == currentPrimary);
                if (match != null) {
                  displayedChips.add({
                    'code': match.code,
                    'name': match.name,
                    'native': match.nativeName,
                  });
                }
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...displayedChips.map((lang) {
                    final code = lang['code']!;
                    final isSelected = currentPrimary == code;
                    final label = lang['native'] != lang['name'] && code != 'auto'
                        ? '${lang['name']} (${lang['native']})'
                        : lang['name']!;

                    return InkWell(
                      onTap: () {
                        controller.primarySpokenLanguage.value = code;
                        if (code != 'auto' && !controller.spokenLanguages.contains(code)) {
                          controller.spokenLanguages.insert(0, code);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                              : const Color(0xFF1F2029),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF2C2E3C),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 13),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: () => showSpokenLanguagePicker(
                      context: context,
                      controller: controller,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2029),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, color: Color(0xFF38BDF8), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'More (39 Languages)',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // More than 1 spoken language (Code-Mixed / Multilingual) Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  color: Color(0xFFA78BFA),
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video has more than 1 spoken language',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'e.g. Telugu speech code-mixed with English words, or polyglot interviews',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isMultilingual,
                  activeColor: const Color(0xFFA78BFA),
                  activeTrackColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white10,
                  onChanged: (val) {
                    controller.isMultilingualSpoken.value = val;
                    if (val && selectedSpoken.isEmpty && currentPrimary != 'auto') {
                      selectedSpoken.add(currentPrimary);
                    }
                  },
                ),
              ],
            ),
          ),

          // If more than 1 spoken language: Secondary language selector
          if (isMultilingual) ...[
            const SizedBox(height: 12),
            const Text(
              'Select all languages spoken in this video:',
              style: TextStyle(
                color: Color(0xFFDDD6FE),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final multiChips = <Map<String, String>>[
                  ...popularLanguages.where((l) => l['code'] != 'auto'),
                ];
                for (final code in selectedSpoken) {
                  if (!multiChips.any((l) => l['code'] == code)) {
                    final match = allSpokenLanguages.firstWhereOrNull((l) => l.code == code);
                    if (match != null) {
                      multiChips.add({
                        'code': match.code,
                        'name': match.name,
                        'native': match.nativeName,
                      });
                    }
                  }
                }

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...multiChips.map((lang) {
                      final code = lang['code']!;
                      final isChecked = selectedSpoken.contains(code) || currentPrimary == code;
                      final isPrimary = currentPrimary == code;

                      return FilterChip(
                        label: Text(
                          isPrimary ? '${lang['name']} (Primary)' : lang['name']!,
                          style: TextStyle(
                            color: isChecked ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isChecked,
                        selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        backgroundColor: const Color(0xFF1E202B),
                        checkmarkColor: const Color(0xFFA78BFA),
                        side: BorderSide(
                          color: isChecked
                              ? const Color(0xFFA78BFA)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                        onSelected: isPrimary
                            ? null // Primary cannot be deselected
                            : (selected) {
                                if (selected) {
                                  if (!selectedSpoken.contains(code)) selectedSpoken.add(code);
                                } else {
                                  selectedSpoken.remove(code);
                                }
                              },
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, color: Color(0xFFA78BFA), size: 14),
                      label: const Text(
                        'Add More Languages',
                        style: TextStyle(
                          color: Color(0xFFA78BFA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: const Color(0xFF2E1065).withValues(alpha: 0.25),
                      side: BorderSide(color: const Color(0xFFA78BFA).withValues(alpha: 0.4)),
                      onPressed: () => showSpokenLanguagePicker(
                        context: context,
                        controller: controller,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (selectedSpoken.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🗣️ Multilingual Speech Active: ${selectedSpoken.map((c) => popularLanguages.firstWhere((p) => p['code'] == c, orElse: () => {'name': c})['name']).join(' + ')}',
                  style: const TextStyle(
                    color: Color(0xFFDDD6FE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitlesCard({
    required BuildContext context,
    required UploadController controller,
    required bool isEnabled,
    required List<String> selectedLanguages,
    required double subtitleCost,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
              : const Color(0xFF262834),
          width: isEnabled ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.subtitles,
                    color: Color(0xFF60A5FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Subtitles & Translation (135+ Languages)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Google Cloud Translation API with Gemini 2.5 Flash',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    controller.aiGenerateSubtitles.value = val;
                    if (val && selectedLanguages.isEmpty) {
                      showSubtitlesMultiLanguagePicker(
                        context: context,
                        controller: controller,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Country-Selection-Style Language Selector Trigger (Channel Creation Style)
          if (isEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => showSubtitlesMultiLanguagePicker(
                  context: context,
                  controller: controller,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101116),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262834)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedLanguages.isNotEmpty
                              ? '${selectedLanguages.length} Target Languages Selected'
                              : r'Native Spoken Subtitles Only (Free • $0.00)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selectedLanguages.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F212A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2D303E)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedLanguages.isNotEmpty ? 'Edit' : 'Choose',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white70,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Selected languages chips
          if (isEnabled && selectedLanguages.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...selectedLanguages.take(8).map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1F27),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E3140)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildLanguageFlag(lang, width: 16, height: 11),
                          const SizedBox(width: 6),
                          Text(
                            lang,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              controller.aiTranslationLanguages.remove(lang);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (selectedLanguages.length > 8)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181A22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF262834)),
                      ),
                      child: Text(
                        '+${selectedLanguages.length - 8} more',
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(color: Color(0xFF222430), height: 1),

          InkWell(
            onTap: () => Get.to(() => const UploadSubtitlesPage()),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isEnabled
                          ? (selectedLanguages.isNotEmpty
                              ? '${selectedLanguages.length} ${selectedLanguages.length == 1 ? "language" : "languages"} selected • \$${subtitleCost.toStringAsFixed(2)}'
                              : 'Enabled • Tap to select languages')
                          : 'Disabled • Tap to configure languages & pricing',
                      style: TextStyle(
                        color: isEnabled ? Colors.white : const Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Configure Languages & Pricing →',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDubbingCard({
    required BuildContext context,
    required UploadController controller,
    required bool isEnabled,
    required List<String> selectedLanguages,
    required double dubbingCost,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFFA78BFA).withValues(alpha: 0.45)
              : const Color(0xFF262834),
          width: isEnabled ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.translate,
                    color: Color(0xFFA78BFA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'AI Audio Translation & Dubbing (78 Languages)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'DUBBING IS NOT FREE',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'ElevenLabs v4 model (eleven_v4) neural dubbing & studio vocal identity',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF7C3AED),
                  onChanged: (val) {
                    controller.aiGenerateDubbing.value = val;
                    if (val && selectedLanguages.isEmpty) {
                      Get.to(() => const UploadDubbingPage());
                    }
                  },
                ),
              ],
            ),
          ),

          // Country-Selection-Style Language Selector Trigger (Channel Creation Style)
          if (isEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  final dubCtrl = Get.isRegistered<UploadDubbingController>()
                      ? Get.find<UploadDubbingController>()
                      : Get.put(UploadDubbingController());
                  showDubbingMultiLanguagePicker(
                    context: context,
                    controller: dubCtrl,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101116),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262834)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate, color: Color(0xFFA78BFA), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedLanguages.isNotEmpty
                              ? '${selectedLanguages.length} Dubbing Languages Configured'
                              : 'Select Dubbing Languages',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selectedLanguages.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F212A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2D303E)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedLanguages.isNotEmpty ? 'Edit' : 'Choose',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white70,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Selected languages chips
          if (isEnabled && selectedLanguages.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...selectedLanguages.take(8).map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1F27),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E3140)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildLanguageFlag(lang, width: 16, height: 11),
                          const SizedBox(width: 6),
                          Text(
                            lang,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              controller.aiDubbingLanguages.remove(lang);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (selectedLanguages.length > 8)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181A22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF262834)),
                      ),
                      child: Text(
                        '+${selectedLanguages.length - 8} more',
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(color: Color(0xFF222430), height: 1),

          InkWell(
            onTap: () => Get.to(() => const UploadDubbingPage()),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isEnabled
                          ? (selectedLanguages.isNotEmpty
                              ? '${selectedLanguages.length} ${selectedLanguages.length == 1 ? "language" : "languages"} • ${controller.aiTTSVoiceType.value == "cloned" ? "Voice Clone" : "Standard Voice"} • \$${dubbingCost.toStringAsFixed(2)}'
                              : 'Enabled • Tap to select languages & voices')
                          : 'Disabled • Tap to configure 70+ languages & voices',
                      style: TextStyle(
                        color: isEnabled ? Colors.white : const Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Configure Dubbing, Voices & Pricing →',
                    style: TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSummaryCard({
    required BuildContext context,
    required bool isSubtitles,
    required bool isDubbing,
    required int subLangsCount,
    required int dubLangsCount,
    required double subtitleCost,
    required double dubbingCost,
    required double totalCost,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262834)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFFA1A1AA), size: 18),
              SizedBox(width: 8),
              Text(
                'Live Pricing Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPricingRow(
            label: 'AI Subtitles ($subLangsCount languages)',
            value: isSubtitles ? '\$${subtitleCost.toStringAsFixed(2)}' : r'Disabled ($0.00)',
            isActive: isSubtitles && subLangsCount > 0,
          ),
          const SizedBox(height: 6),
          _buildPricingRow(
            label: 'AI Voice Dubbing ($dubLangsCount languages)',
            value: isDubbing ? '\$${dubbingCost.toStringAsFixed(2)}' : r'Disabled ($0.00)',
            isActive: isDubbing && dubLangsCount > 0,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF222430)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Charges are deducted directly from your Channel Revenue at-cost upon upload submission, or directly paid. If a language is dubbed, subtitles for that language are included complimentary.',
            style: TextStyle(
              color: Color(0xFF71717A),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow({
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFA1A1AA),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF71717A),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

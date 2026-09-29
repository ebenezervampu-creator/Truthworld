import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_advanced_features_section.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_bottom_action_bar.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_languages_grid.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_notice_banner.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_pricing_card.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_search_and_presets.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_tier_header.dart';

/// Dedicated Dubbing Configuration, Voice Options & Pricing Page.
/// Features 70+ dubbing languages, voice cloning, speaker diarization, and transparent flat pricing.
class UploadDubbingPage extends StatelessWidget {
  const UploadDubbingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UploadDubbingController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Voice Dubbing & Localization',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '70+ neural languages • Voice cloning • Multi-speaker diarization',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Obx(() {
            final count = controller.selectedLanguages.length;
            final isFilteredToSelected = controller.selectedCategoryFilter.value == 'selected';
            if (count == 0) {
              return TextButton(
                onPressed: controller.selectTopGlobal,
                child: const Text(
                  'Select Top 5',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (isFilteredToSelected) {
                      controller.selectedCategoryFilter.value = 'all';
                    } else {
                      controller.selectedCategoryFilter.value = 'selected';
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFilteredToSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFilteredToSelected ? Colors.white : Colors.white30,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 13,
                          color: isFilteredToSelected ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count Selected',
                          style: TextStyle(
                            color: isFilteredToSelected ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: controller.clearAll,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DUBBING IS NOT FREE Banner
                  const DubbingNoticeBanner(),
                  const SizedBox(height: 16),

                  // 2. Video & Tier Context Header
                  DubbingTierHeader(controller: controller),
                  const SizedBox(height: 16),

                  // 3. Pricing Breakdown Card
                  DubbingPricingCard(controller: controller),
                  const SizedBox(height: 20),

                  // 4. Advanced Dubbing Features (Voice Cloning, Diarization, Audio Preservation)
                  DubbingAdvancedFeaturesSection(controller: controller),
                  const SizedBox(height: 16),

                  // 4.5 Active Selected Dubbing Languages Section
                  _buildSelectedLanguagesSection(controller),

                  // 5. Search, Category Filters & Presets
                  DubbingSearchAndPresets(controller: controller),
                  const SizedBox(height: 16),

                  // 6. Languages Grid
                  DubbingLanguagesGrid(controller: controller),
                ],
              ),
            ),
          ),

          // 7. Sticky Bottom Action Bar
          DubbingBottomActionBar(controller: controller),
        ],
      ),
    );
  }

  Widget _buildSelectedLanguagesSection(UploadDubbingController controller) {
    return Obx(() {
      final selectedItems = controller.selectedLanguagesList;
      if (selectedItems.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16161A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Dubbing Languages (${selectedItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: controller.clearAll,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedItems.map((lang) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (lang.nativeName.isNotEmpty && lang.nativeName != lang.name) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${lang.nativeName})',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => controller.removeLanguage(lang.name),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black12,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_advanced_features_section.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_bottom_action_bar.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_languages_grid.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_notice_banner.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_pricing_card.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_tier_header.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/spoken_language_selector_card.dart';

/// Dedicated Dubbing Configuration, Voice Options & Pricing Page.
/// Redesigned with ElevenLabs modern, minimalist dark aesthetic, clean typography,
/// and a country-selection-style multi-language modal picker.
class UploadDubbingPage extends StatelessWidget {
  const UploadDubbingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UploadDubbingController());

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
              'AI Voice Dubbing & Localization',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '70+ neural languages • Voice cloning • Multi-speaker diarization',
              style: TextStyle(
                color: Color(0xFFA1A1AA),
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
                    showDubbingMultiLanguagePicker(
                      context: context,
                      controller: controller,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFilteredToSelected ? Colors.white : const Color(0xFF1F212A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFilteredToSelected ? Colors.white : const Color(0xFF333648),
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
                        const SizedBox(width: 5),
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
                      color: Color(0xFFA1A1AA),
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DUBBING IS NOT FREE Banner (ElevenLabs Callout)
                      const DubbingNoticeBanner(),
                      const SizedBox(height: 16),

                      // 2. Video & Tier Context Header
                      DubbingTierHeader(controller: controller),
                      const SizedBox(height: 16),

                      // 2.5 Source Spoken Video Language ("From") Selector (39 languages)
                      SpokenLanguageSelectorCard(
                        controller: controller.uploadController,
                        title: 'Source Spoken Video Language ("From")',
                        subtitle: 'Speech recognition strictly supports 39 languages via AssemblyAI Universal-3.5 Pro & Sarvam AI',
                      ),
                      const SizedBox(height: 16),

                      // 3. Pricing Breakdown Card
                      DubbingPricingCard(controller: controller),
                      const SizedBox(height: 18),

                      // 4. Advanced Dubbing Features (Voice Cloning, Diarization, Audio Preservation)
                      DubbingAdvancedFeaturesSection(controller: controller),
                      const SizedBox(height: 18),

                      // 5. Target Languages (Country-Selection Style Modal Trigger & Selected Chips)
                      DubbingLanguagesGrid(controller: controller),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          DubbingBottomActionBar(controller: controller),
        ],
      ),
    );
  }
}

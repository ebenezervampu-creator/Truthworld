import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';

/// Interactive AI & text search bar for channel discovery matching Image 1.
class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({
    required this.controller,
    super.key,
    this.isMobile = false,
  });

  final DiscoverChannelsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kDiscoverCardBorder,
        ),
      ),
      child: TextField(
        controller: controller.searchController,
        maxLength: ContentValidator.defaultMaxSearchLength,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: TruthworldTextInputFormatters.withLimit(
          ContentValidator.defaultMaxSearchLength,
        ),
        onChanged: controller.onSearchChanged,
        style: const TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText:
              'Ask AI or search channels (e.g. "Top verified science educators", "Emerging AI & robotics creators")...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Obx(() {
            final isFilterActive =
                controller.selectedFilter.value != 'Top Channels' ||
                controller.selectedLanguage.value != 'All Languages';

            return IconButton(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: isFilterActive ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                  if (isFilterActive)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filter Channels',
              onPressed: () {
                HapticFeedback.lightImpact();
                _showFilterBottomSheet(context, controller);
              },
            );
          }),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Voice Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.dialog(
                    VoiceSearchDialog(
                      onSearch: (query) {
                        controller.searchController.text = query;
                        controller.onSearchChanged(query);
                      },
                    ),
                  );
                },
              ),
              Obx(
                () => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: 'Clear',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          controller.clearSearch();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    DiscoverChannelsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161619),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A30), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title row with Reset button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Obx(() {
                      final hasActive =
                          controller.selectedFilter.value != 'Top Channels' ||
                          controller.selectedLanguage.value != 'All Languages';
                      if (!hasActive) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          controller.selectedFilter.value = 'Top Channels';
                          controller.selectedLanguage.value = 'All Languages';
                          controller.resetAllFilters();
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Sort Section
                const Text(
                  'Sort by',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.filters.map((filter) {
                    return Obx(() {
                      final isSelected =
                          controller.selectedFilter.value == filter;
                      return ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF222228),
                        selectedColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (_) {
                          HapticFeedback.lightImpact();
                          controller.selectFilter(filter);
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Language Section
                const Text(
                  'Language',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.languages.map((lang) {
                    return Obx(() {
                      final isSelected =
                          controller.selectedLanguage.value == lang;
                      return ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Text(
                          lang,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF222228),
                        selectedColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (_) {
                          HapticFeedback.lightImpact();
                          controller.selectLanguage(lang);
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Get.back();
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

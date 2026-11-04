import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';

/// Horizontal interactive filter pills bar for Discover Channels.
/// Exposes languages, topics, and sorting according to industry standards.
class DiscoverFilterPillsBar extends StatelessWidget {
  const DiscoverFilterPillsBar({
    required this.controller,
    super.key,
    this.showLanguages = true,
    this.showTopics = true,
  });

  final DiscoverChannelsController controller;
  final bool showLanguages;
  final bool showTopics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Filter Bar: Sort Presets + Language & Topic Triggers
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              // Clear all filters if active
              Obx(() {
                if (!controller.hasActiveFilters) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: const Color(0xFF2E2E34),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      controller.resetAllFilters();
                    },
                  ),
                );
              }),

              // Sort Pills: Top Channels, Emerging, Verified Only, Most Active
              ...controller.filters.map((filter) {
                return Obx(() {
                  final isSelected = controller.selectedFilter.value == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      backgroundColor: const Color(0xFF1B1B1E),
                      selectedColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSelected: (_) {
                        HapticFeedback.lightImpact();
                        controller.selectFilter(filter);
                      },
                    ),
                  );
                });
              }),

              // Language Selector BottomSheet Trigger Pill
              if (showLanguages)
                Obx(() {
                  final isCustomLang =
                      controller.selectedLanguage.value != 'All Languages';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        Icons.translate_rounded,
                        size: 14,
                        color: isCustomLang ? Colors.black : Colors.white70,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.selectedLanguage.value,
                            style: TextStyle(
                              color: isCustomLang ? Colors.black : Colors.white70,
                              fontSize: 12.5,
                              fontWeight: isCustomLang
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: isCustomLang ? Colors.black : Colors.white70,
                          ),
                        ],
                      ),
                      backgroundColor: isCustomLang
                          ? Colors.white
                          : const Color(0xFF1B1B1E),
                      side: BorderSide(
                        color: isCustomLang
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showLanguageBottomSheet(context, controller);
                      },
                    ),
                  );
                }),

              // Niche Topic Selector BottomSheet Trigger Pill
              if (showTopics)
                Obx(() {
                  final isCustomTopic =
                      controller.selectedTopic.value != 'All Topics';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        Icons.interests_rounded,
                        size: 14,
                        color: isCustomTopic ? Colors.black : Colors.white70,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.selectedTopic.value,
                            style: TextStyle(
                              color: isCustomTopic ? Colors.black : Colors.white70,
                              fontSize: 12.5,
                              fontWeight: isCustomTopic
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: isCustomTopic ? Colors.black : Colors.white70,
                          ),
                        ],
                      ),
                      backgroundColor: isCustomTopic
                          ? Colors.white
                          : const Color(0xFF1B1B1E),
                      side: BorderSide(
                        color: isCustomTopic
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showTopicBottomSheet(context, controller);
                      },
                    ),
                  );
                }),
            ],
          ),
        ),

        // Active Secondary Language Quick Switch Bar (if not 'All' or when user wants instant multi-lingual access)
        if (showLanguages) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: controller.languages.map((lang) {
                return Obx(() {
                  final isSelected = controller.selectedLanguage.value == lang;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.selectLanguage(lang);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.black : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  );
                });
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  void _showLanguageBottomSheet(
    BuildContext context,
    DiscoverChannelsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Filter by Language',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...controller.languages.map((lang) {
              return Obx(() {
                final isSelected = controller.selectedLanguage.value == lang;
                return ListTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: isSelected
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.selectLanguage(lang);
                    Get.back();
                  },
                );
              });
            }),
          ],
        ),
      ),
    );
  }

  void _showTopicBottomSheet(
    BuildContext context,
    DiscoverChannelsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Filter by Niche Topic',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...controller.nicheTopics.map((topicMap) {
              final topicName = topicMap['name'] ?? '';
              return Obx(() {
                final isSelected =
                    controller.selectedTopic.value == topicName;
                return ListTile(
                  title: Text(
                    topicName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: isSelected
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.selectTopic(topicName);
                    Get.back();
                  },
                );
              });
            }),
          ],
        ),
      ),
    );
  }
}

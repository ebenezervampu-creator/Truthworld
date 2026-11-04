import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';

/// GetX controller managing search bar focus and hover reactivity without setState.
class ExploreTopicsSearchBarController extends GetxController {
  final FocusNode focusNode = FocusNode();
  final RxBool isFocused = false.obs;
  final RxBool isHovered = false.obs;

  @override
  void onInit() {
    super.onInit();
    focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    isFocused.value = focusNode.hasFocus;
  }

  @override
  void onClose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.onClose();
  }
}

/// Professional responsive search bar with AI semantic exploration hint,
/// category filtering support, voice search integration, interactive focus/hover states,
/// and reactive clear action across Mobile, Tablet, and Desktop.
class ExploreTopicsSearchBar extends StatelessWidget {
  const ExploreTopicsSearchBar({
    super.key,
    this.isMobile = false,
    this.isTablet = false,
    this.isDesktop = false,
    this.isCategoryView = false,
    this.category,
  });

  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool isCategoryView;
  final TopicCategory? category;

  String _getHintText() {
    if (isCategoryView) {
      final categoryTitle = category?.title ?? 'Category';
      final hintExamples = (category?.searchHintExamples.isNotEmpty ?? false)
          ? category!.searchHintExamples
          : '"worship", "gospel", "piano"';

      if (isMobile) {
        return 'Search topics in $categoryTitle...';
      } else if (isTablet) {
        return 'Search topics in $categoryTitle...';
      } else {
        return 'Search topics in $categoryTitle (e.g. $hintExamples)...';
      }
    }

    if (isMobile) {
      return 'Ask AI or explore topics...';
    } else if (isTablet) {
      return 'Ask AI or explore topics (e.g. "Peace of mind", "Bible study")...';
    } else {
      return 'Ask AI or explore topics (e.g. "Peace of mind", "Bible study", "Science & faith")...';
    }
  }

  String get _controllerTag {
    if (isCategoryView) {
      return 'explore_search_bar_cat_${category?.id ?? 'default'}';
    }
    return 'explore_search_bar_overview';
  }

  @override
  Widget build(BuildContext context) {
    final searchBarController =
        Get.isRegistered<ExploreTopicsSearchBarController>(tag: _controllerTag)
            ? Get.find<ExploreTopicsSearchBarController>(tag: _controllerTag)
            : Get.put(
                ExploreTopicsSearchBarController(),
                tag: _controllerTag,
              );

    final controller = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : Get.put(ExploreTopicsController());

    final borderRadius = BorderRadius.circular(isDesktop ? 16 : 14);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => searchBarController.isHovered.value = true,
        onExit: (_) => searchBarController.isHovered.value = false,
        cursor: SystemMouseCursors.text,
        child: Obx(() {
          final isFocused = searchBarController.isFocused.value;
          final isHovered = searchBarController.isHovered.value;

          final borderColor = isFocused
              ? Colors.white.withValues(alpha: 0.85)
              : (isHovered
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.12));

          final fieldBgColor = isFocused
              ? const Color(0xFF1B1B20)
              : (isHovered ? const Color(0xFF17171C) : const Color(0xFF141418));

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fieldBgColor,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: isFocused ? 1.5 : 1.0,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.07),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: controller.searchController,
              focusNode: searchBarController.focusNode,
              maxLength: ContentValidator.defaultMaxSearchLength,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(
                ContentValidator.defaultMaxSearchLength,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: controller.updateSearchQuery,
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 15 : 14,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
              ),
              cursorColor: Colors.white,
              cursorWidth: 1.8,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                prefixIcon: isCategoryView
                    ? Padding(
                        padding: const EdgeInsets.only(left: 14, right: 12),
                        child: Icon(
                          Icons.search_rounded,
                          color: isFocused
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.65),
                          size: isDesktop ? 22 : 20,
                        ),
                      )
                    : Obx(() {
                        final isFilterActive = controller.hasActiveFilters;

                        return IconButton(
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                color: isFilterActive
                                    ? Colors.white
                                    : Colors.white70,
                                size: isDesktop ? 22 : 20,
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
                          tooltip: 'Filter Topics',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _showFilterBottomSheet(context, controller);
                          },
                        );
                      }),
                prefixIconConstraints: BoxConstraints(
                  minWidth: isDesktop ? 48 : 44,
                  minHeight: isDesktop ? 48 : 44,
                ),
                hintText: _getHintText(),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: isDesktop ? 15 : 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 16 : (isTablet ? 14 : 12),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final hasText =
                          controller.searchQuery.value.isNotEmpty ||
                              controller.searchController.text.isNotEmpty;
                      if (!hasText) return const SizedBox.shrink();
                      return Tooltip(
                        message: 'Clear search',
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              controller.clearSearch();
                              searchBarController.focusNode.requestFocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: isDesktop ? 20 : 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    Tooltip(
                      message: 'Search by voice',
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Get.dialog(
                              VoiceSearchDialog(
                                onSearch: (query) {
                                  controller.searchController.text = query;
                                  controller.updateSearchQuery(query);
                                },
                              ),
                              useSafeArea: false,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.mic_rounded,
                              color: isFocused
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.85),
                              size: isDesktop ? 22 : 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    ExploreTopicsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161619),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A30)),
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

                // Title row with Reset button and Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Filter Topics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Obx(() {
                      if (!controller.hasActiveFilters) {
                        return const SizedBox.shrink();
                      }
                      return TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
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
                const Row(
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sort by',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.sortFilters.map((filter) {
                    final filterIcon = switch (filter) {
                      'Trending' => Icons.local_fire_department_rounded,
                      'Newest' => Icons.access_time_rounded,
                      'Popular' => Icons.star_rounded,
                      _ => Icons.explore_rounded,
                    };

                    return Obx(() {
                      final isSelected =
                          controller.currentSortFilterName == filter;
                      return ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: Icon(
                          filterIcon,
                          size: 16,
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
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
                          controller.selectSortFilter(filter);
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Category Section
                const Row(
                  children: [
                    Icon(
                      Icons.category_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Category',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TopicCategoriesConfig.categories.map((cat) {
                    return Obx(() {
                      final isAllCat = cat.id.toLowerCase() == 'all';
                      final currentCat =
                          controller.selectedCategory.value.toLowerCase();
                      final isSelected = isAllCat
                          ? currentCat == 'all'
                          : currentCat == cat.title.toLowerCase() ||
                              currentCat == cat.id.toLowerCase();

                      return ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: cat.icon != null
                            ? Icon(
                                cat.icon,
                                size: 16,
                                color:
                                    isSelected ? Colors.black : Colors.white70,
                              )
                            : null,
                        label: Text(
                          cat.title,
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
                          controller.selectCategory(
                            cat.id == 'all' ? 'all' : cat.title,
                          );
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

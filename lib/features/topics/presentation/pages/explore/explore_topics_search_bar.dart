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
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 12),
                  child: Icon(
                    isCategoryView
                        ? Icons.search_rounded
                        : Icons.auto_awesome_rounded,
                    color: isFocused
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                    size: isDesktop ? 22 : 20,
                  ),
                ),
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
}

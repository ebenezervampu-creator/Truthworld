import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_category_card.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_filter_pills_bar.dart';

/// Responsive 2-column grid of discover categories matching Image 1.
class DiscoverCategoryGrid extends StatelessWidget {
  const DiscoverCategoryGrid({
    required this.controller,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final DiscoverChannelsController controller;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isDesktop ? 2.3 : (isTablet ? 2.2 : 2.1),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = controller.categories[index + 1]; // Skip 'All'
          final catName = category['name'] as String;
          return Obx(() {
            final count = controller.categoryChannelCounts[catName] ??
                controller.getCategoryCount(catName);
            return DiscoverCategoryCard(
              category: category,
              channelCount: count,
              onTap: () => controller.selectCategory(catName),
            );
          });
        },
        childCount: controller.categories.length - 1,
      ),
    );
  }
}

/// Rich category hero header matching Image 2 when a category is actively selected.
class DiscoverSelectedCategoryHeader extends StatelessWidget {
  const DiscoverSelectedCategoryHeader({
    required this.selectedCategory,
    required this.onBack,
    this.channelCount,
    super.key,
  });

  final String selectedCategory;
  final VoidCallback onBack;
  final int? channelCount;

  @override
  Widget build(BuildContext context) {
    final catImage = getCategoryImage(selectedCategory);
    // Real authentic channel count formatted dynamically
    final countText = channelCount != null
        ? formatChannelCount(channelCount!)
        : '';
    final description = getCategoryDescription(selectedCategory);
    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;
    final headerHeight = isMobile ? 165.0 : 210.0;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Compact Hero Image Header (Saving vertical real estate on mobile)
          Container(
            height: headerHeight,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                CachedNetworkImage(
                  imageUrl: catImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: buttonBg),
                  errorWidget: (context, url, error) => Container(color: buttonBg),
                ),

                // Top & Bottom gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.70),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.35, 0.75, 1.0],
                    ),
                  ),
                ),

                // Content: Back button on top-left, Category info at bottom
                Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onBack();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Title
                      Text(
                        selectedCategory,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 30,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (countText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          countText,
                          style: TextStyle(
                            fontSize: isMobile ? 12.5 : 13.5,
                            color: Colors.white.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),

                      // Description
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 12.5,
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.3,
                        ),
                        maxLines: isMobile ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search and Sort Bar with Filter Pills (Image 2)
          DiscoverCategorySearchSortBar(
            selectedCategory: selectedCategory,
          ),
        ],
      ),
    );
  }
}

/// Search and Sort Bar inside category view (Image 2).
class DiscoverCategorySearchSortBar extends StatelessWidget {
  const DiscoverCategorySearchSortBar({
    required this.selectedCategory,
    super.key,
  });

  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DiscoverChannelsController>()
        ? Get.find<DiscoverChannelsController>()
        : null;

    if (controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Search Input Field
            Expanded(
              child: Container(
                height: 46,
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
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search $selectedCategory channels...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              controller.clearSearch();
                            },
                          )
                        : const SizedBox.shrink()),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Sort By Button
            Material(
              color: const Color(0xFF161619),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSortBottomSheet(context, controller);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kDiscoverCardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Sort by',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DiscoverFilterPillsBar(
          controller: controller,
          showTopics: false,
        ),
      ],
    );
  }

  void _showSortBottomSheet(
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
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Sort $selectedCategory Channels',
                style: const TextStyle(
                  color: primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...controller.filters.map((filter) {
              return Obx(() {
                final isSelected = controller.selectedFilter.value == filter;
                return ListTile(
                  title: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: isSelected
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.selectFilter(filter);
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

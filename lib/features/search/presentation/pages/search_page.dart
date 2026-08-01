import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide SearchBar, SearchController;
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// SearchPage: Main search UI (Optimized for 9 Problems & YouTube Exact Look)
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _searchController = TextEditingController();
  late final SearchController _searchCtrl = Get.find<SearchController>();
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Warmup cache on page load
    _searchCtrl.fetchTrendingSuggestions();

    // Setup infinite scroll pagination
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels > position.maxScrollExtent * 0.8) {
        _searchCtrl.loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.twColors;
    final typography = context.twTypography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () {
            if (_searchCtrl.showSuggestions.value) {
              _searchCtrl.showSuggestions.value = false;
            } else {
              Get.back();
            }
          },
        ),
        titleSpacing: 0,
        title: Obx(
          () => SearchBar(
            controller: _searchController,
            isLoading: _searchCtrl.isLoading.value,
            onChanged: _searchCtrl.onSearchChanged,
            onClear: _searchCtrl.clearSearch,
            onSearchSubmitted: () {
              if (_searchController.text.isNotEmpty) {
                _searchCtrl.performSearch(_searchController.text);
              }
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom Layer: Results and chips
            Column(
              children: [
                // Always-visible Scrollable Filter Chips row
                Obx(() {
                  final activeFilter = _searchCtrl.selectedFilter.value;
                  final filters = [
                    'All',
                    'Videos',
                    'Topics',
                    'Playlists',
                    'Channels',
                    'Watched',
                    'Unwatched',
                    'Recently uploaded',
                  ];
                  return Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filters.length,
                      itemBuilder: (context, index) {
                        final filter = filters[index];
                        final isSelected = activeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: typography.label.copyWith(
                                color: isSelected
                                    ? colors.background
                                    : colors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: colors.textPrimary,
                            backgroundColor: colors.surface,
                            checkmarkColor: colors.background,
                            showCheckmark: false,
                            onSelected: (selected) {
                              if (selected) {
                                _searchCtrl.setFilter(filter);
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? colors.textPrimary
                                    : colors.divider,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),

                // Main content area
                Expanded(
                  child: Obx(() {
                    final query = _searchCtrl.searchQuery.value;
                    final results = _searchCtrl.searchResults;
                    final isLoading = _searchCtrl.isLoading.value;
                    final isLoadingMore = _searchCtrl.isLoadingMore.value;
                    final errorMsg = _searchCtrl.errorMessage.value;

                    // CASE 1: Empty search state
                    if (query.isEmpty) {
                      return _buildEmptyState();
                    }

                    // CASE 2: Loading state
                    if (isLoading) {
                      return const SearchResultSkeleton();
                    }

                    // CASE 3: Error state
                    if (errorMsg.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMsg,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _searchCtrl.clearSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.bgDivider,
                                foregroundColor: AppColors.textPrimary,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    }

                    // CASE 4: No results
                    if (results.isEmpty) {
                      return EmptySearchState(
                        query: query,
                        onClearSearch: _searchCtrl.clearSearch,
                      );
                    }

                    // CASE 5: Results List
                    return _buildResultsList(results, isLoadingMore);
                  }),
                ),
              ],
            ),

            // Top Layer: Suggestions overlay (active while typing)
            Obx(() {
              final showSug = _searchCtrl.showSuggestions.value;
              final suggestionsList = _searchCtrl.richSuggestions;
              if (!showSug || suggestionsList.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                color: AppColors.bgPage,
                width: double.infinity,
                height: double.infinity,
                child: ListView.builder(
                  itemCount: suggestionsList.length,
                  itemBuilder: (context, index) {
                    final sug = suggestionsList[index];
                    return SearchSuggestionTile(
                      suggestion: sug,
                      onTap: () {
                        _searchController.text = sug.text;
                        if (sug.matchedResult != null) {
                          _searchCtrl.onResultTapped(sug.matchedResult!);
                        } else {
                          _searchCtrl.performSearch(sug.text);
                        }
                      },
                      onCopy: () {
                        _searchController.text = sug.text;
                        _searchController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: sug.text.length),
                            );
                        _searchCtrl.onSearchChanged(sug.text);
                      },
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build empty search landing state featuring Realtime Trending Today
  Widget _buildEmptyState() {
    final trendingList = _searchCtrl.filteredRealtimeTrending;
    final filter = _searchCtrl.selectedFilter.value;
    final isTypeFilter = [
      'Videos',
      'Topics',
      'Playlists',
      'Channels',
    ].contains(filter);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 🔥 Realtime Trending Today Header & Live Stream List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '🔥 Realtime Trending Today',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: AppColors.error, size: 8),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isTypeFilter
                      ? 'Popular trending $filter right now'
                      : 'Top real-time searches & content across TruthWorld',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                if (_searchCtrl.isRealtimeTrendingLoading.value)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: AppColors.error,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (trendingList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No trending $filter found right now.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trendingList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppColors.bgDivider, height: 1),
                    itemBuilder: (context, index) {
                      final item = trendingList[index];
                      return _buildRealtimeTrendingTile(item);
                    },
                  ),
              ],
            ),
          ),

          // 2. Recent searches
          if (_searchCtrl.recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: RecentSearchesList(
                recentSearches: _searchCtrl.recentSearches,
                onSearchSelected: (query) {
                  _searchController.text = query;
                  _searchCtrl.performSearch(query);
                },
                onClearAll: _searchCtrl.clearRecentSearches,
              ),
            ),

          // 3. "You May Like" Section (Recommended Videos)
          if (_searchCtrl.recommendedResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'You may like',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _searchCtrl.recommendedResults.length,
                      itemBuilder: (context, index) {
                        final video = _searchCtrl.recommendedResults[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          child: _buildRecommendedCard(video),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // 4. Search Tips section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Search Tips',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Use specific keywords for better results\n'
                    '• Try different search terms if no results\n'
                    '• Filter by channels, playlists, or topics',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
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

  /// Realtime Trending Tile widget with Rank Movement & Preview Cards
  Widget _buildRealtimeTrendingTile(TrendingItem item) {
    IconData categoryIcon;
    Color categoryColor;
    switch (item.category) {
      case 'topic':
        categoryIcon = Icons.numbers_rounded;
        categoryColor = AppColors.brandHover;
      case 'playlist':
        categoryIcon = Icons.playlist_play_rounded;
        categoryColor = AppColors.brand;
      case 'channel':
        categoryIcon = Icons.account_circle_rounded;
        categoryColor = Colors.cyanAccent;
      case 'video':
      default:
        categoryIcon = Icons.play_arrow_rounded;
        categoryColor = AppColors.error;
    }

    var movementColor = AppColors.success;
    if (item.movement != null) {
      if (item.movement!.contains('▼')) {
        movementColor = AppColors.warning;
      } else if (item.movement!.contains('NEW')) {
        movementColor = AppColors.brandHover;
      }
    }

    return InkWell(
      onTap: () {
        _searchController.text = item.title;
        _searchCtrl.performSearch(item.title);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // 1. Rank Number & Movement Indicator
            SizedBox(
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#${item.rank}',
                    style: TextStyle(
                      color: item.rank <= 3
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.movement != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.movement!,
                      style: TextStyle(
                        color: movementColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 2. Thumbnail Preview Card (if available) or Category Badge
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 40,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.bgDivider),
                    errorWidget: (context, url, err) => ColoredBox(
                      color: categoryColor.withValues(alpha: 0.2),
                      child: Icon(categoryIcon, color: categoryColor, size: 20),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 20),
              ),

            const SizedBox(width: 12),

            // 3. Title & Metadata (Subtitle / Creator)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.creator != null && item.creator!.isNotEmpty) ...[
                        Text(
                          item.creator!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (item.subtitle != null)
                        Expanded(
                          child: Text(
                            item.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 4. Trending Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.badge.contains('🔥')
                    ? AppColors.error.withValues(alpha: 0.2)
                    : AppColors.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.badge.contains('🔥')
                      ? AppColors.error.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                item.badge,
                style: TextStyle(
                  color: item.badge.contains('🔥')
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.north_west_rounded,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Build results list with pagination support
  Widget _buildResultsList(List results, bool isLoadingMore) {
    final showFallbackBanner = _searchCtrl.isShowingFallback.value;
    final extraItems = (showFallbackBanner ? 1 : 0) + (isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      itemCount: results.length + extraItems,
      itemBuilder: (context, index) {
        // 1. Fallback Banner at index 0
        if (showFallbackBanner && index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            color: const Color(0xFF1E1B2E), // Subtle dark purple background
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No exact matches found for "${_searchCtrl.searchQuery.value}". Showing recommended content instead:',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Adjust index if fallback banner is shown
        final dataIndex = showFallbackBanner ? index - 1 : index;

        // 2. Loading Indicator at the end
        if (dataIndex == results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final result = results[dataIndex];
        return SearchResultCard(
          result: result,
          onTap: () => _searchCtrl.onResultTapped(result),
        );
      },
    );
  }

  /// Build recommended video card for horizontal slider
  Widget _buildRecommendedCard(SearchResult video) {
    final seconds = video.duration;
    String? durationStr;
    if (seconds != null && seconds > 0) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      if (h > 0) {
        durationStr =
            '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        durationStr = '$m:${s.toString().padLeft(2, '0')}';
      }
    }
    return InkWell(
      onTap: () {
        _searchCtrl.onResultTapped(video);
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: video.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnail,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: AppColors.bgDivider),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.play_circle_outline,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : const ColoredBox(
                            color: AppColors.bgDivider,
                            child: Icon(
                              Icons.video_library,
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                ),
                if (durationStr != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandHover.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⭐ Recommended',
                      style: TextStyle(
                        color: AppColors.brandHover,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${FormatUtils.formatCount(video.views)} views • ${video.channelName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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

import 'package:flutter/material.dart' hide SearchBar, SearchController;
import 'package:get/get.dart';
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
      if (!_scrollController.hasClients || _scrollController.positions.length != 1) return;
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
            isLoading: _searchCtrl.isLoading,
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
                    final isLoading = _searchCtrl.isLoading;
                    final isLoadingMore = _searchCtrl.isLoadingMore.value;
                    final errorMsg = _searchCtrl.errorMessage;

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

  /// Build empty search landing state with industry-standard suggestions
  Widget _buildEmptyState() {
    final filter = _searchCtrl.selectedFilter.value;
    final recommendedList = _searchCtrl.recommendedResults;
    final isRecLoading = _searchCtrl.isRecommendedLoading.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Recent Searches
          if (_searchCtrl.recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: RecentSearchesList(
                recentSearches: _searchCtrl.recentSearches,
                onSearchSelected: (query) {
                  _searchController.text = query;
                  _searchCtrl.performSearch(query);
                },
                onClearAll: _searchCtrl.clearRecentSearches,
              ),
            ),

          // 2. Suggested Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              filter == 'All' ? 'Suggested for you' : 'Suggested $filter',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // 3. Suggested Results List
          if (_searchCtrl.isLoading || isRecLoading)
            const SearchResultSkeleton(count: 4, shrinkWrap: true)
          else if (recommendedList.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  filter == 'All'
                      ? 'No suggestions available right now.'
                      : 'No suggested ${filter.toLowerCase()} available right now.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommendedList.length,
              itemBuilder: (context, index) {
                final item = recommendedList[index];
                return SearchResultCard(
                  result: item,
                  onTap: () => _searchCtrl.onResultTapped(item),
                );
              },
            ),
        ],
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
}

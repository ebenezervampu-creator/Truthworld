import 'package:flutter/material.dart' hide SearchBar, SearchController;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// SearchPage: Main search UI (Optimized for 9 Problems & Clean Design)
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  SearchController get _searchCtrl => Get.find<SearchController>();
  TextEditingController get _searchController => _searchCtrl.textEditingController;
  ScrollController get _scrollController => _searchCtrl.scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.twColors;
    final typography = context.twTypography;

    return PopScope(
      canPop: !_searchCtrl.showSuggestions.value,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchCtrl.showSuggestions.value) {
          _searchCtrl.showSuggestions.value = false;
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            tooltip: 'Back',
            onPressed: () {
              if (_searchCtrl.showSuggestions.value) {
                _searchCtrl.showSuggestions.value = false;
                FocusScope.of(context).unfocus();
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
                  FocusScope.of(context).unfocus();
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
                  final userLang = Get.isRegistered<UserLanguagesService>()
                      ? UserLanguagesService.to.primaryLanguage.value
                      : 'English';
                  final filters = [
                    'All',
                    if (userLang.isNotEmpty) 'In $userLang',
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
                      return _buildEmptyState(context);
                    }

                    // CASE 2: Loading state
                    if (isLoading) {
                      return const SearchResultSkeleton();
                    }

                    // CASE 3: Error state (if error and no results and no AI intent)
                    if (errorMsg.isNotEmpty && results.isEmpty && _searchCtrl.activeAiIntent.value == null) {
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: _searchCtrl.clearSearch,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(color: AppColors.bgDivider),
                                  ),
                                  child: const Text('Clear'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    _searchCtrl.performSearch(_searchCtrl.searchQuery.value);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.brand,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    final hasAiBanner = _searchCtrl.activeAiIntent.value != null;

                    // CASE 4: No results and no AI banner
                    if (!hasAiBanner && results.isEmpty) {
                      return EmptySearchState(
                        query: query,
                        onClearSearch: _searchCtrl.clearSearch,
                      );
                    }

                    // CASE 5: Active AI Search or Results List
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasAiBanner) _buildActiveAiSearchBanner(context),
                        Expanded(
                          child: results.isEmpty
                              ? EmptySearchState(
                                  query: query,
                                  onClearSearch: _searchCtrl.clearSearch,
                                )
                              : _buildResultsList(results, isLoadingMore),
                        ),
                      ],
                    );
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
                        _searchCtrl.showSuggestions.value = false;
                        FocusScope.of(context).unfocus();
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
    ),
  );
}

  /// Build empty search landing state with industry-standard suggestions
  Widget _buildEmptyState(BuildContext context) {
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
                  FocusScope.of(context).unfocus();
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
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _searchCtrl.onResultTapped(item);
                  },
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView.builder(
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
              onTap: () {
                FocusScope.of(context).unfocus();
                _searchCtrl.onResultTapped(result);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveAiSearchBanner(BuildContext context) {
    final colors = context.twColors;
    final intent = _searchCtrl.activeAiIntent.value!;
    final matchCount = _searchCtrl.searchResults.length;
    final isBroadened = _searchCtrl.isBroadenedView.value;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intent.explanation.isNotEmpty
                          ? intent.explanation
                          : 'AI Smart Search',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$matchCount results found • Mode: ${intent.resultMode == SearchResultMode.exhaustive ? "All Results" : "Top Ranked"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                tooltip: 'Clear AI Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _searchCtrl.clearAiSearch();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (intent.detectedLanguage != null)
                _buildCriterionChip(
                  context,
                  label: intent.detectedLanguage!,
                  icon: Icons.language_rounded,
                ),
              if (intent.detectedCategory != null)
                _buildCriterionChip(
                  context,
                  label: intent.detectedCategory!,
                  icon: Icons.category_rounded,
                ),
              if (intent.cleanKeywords.isNotEmpty)
                ...intent.cleanKeywords.map(
                  (k) => _buildCriterionChip(
                    context,
                    label: k,
                    icon: Icons.tag_rounded,
                  ),
                ),
              if (intent.excludedTerms.isNotEmpty)
                ...intent.excludedTerms.map(
                  (ex) => _buildCriterionChip(
                    context,
                    label: 'No: $ex',
                    icon: Icons.block_rounded,
                  ),
                ),
              if (intent.resultMode == SearchResultMode.exhaustive)
                _buildCriterionChip(
                  context,
                  label: 'Exhaustive / All',
                  icon: Icons.all_inclusive_rounded,
                ),
            ],
          ),
          // Fallback broadening suggestion when language-specific count is low or filtered
          if (_searchCtrl.broadenedResults.isNotEmpty && !isBroadened) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.travel_explore_rounded,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found $matchCount ${intent.detectedLanguage} results. Broaden to all languages?',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _searchCtrl.broadenSearch();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      intent.broadenPrompt ?? 'Show All Languages',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildCriterionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colors = context.twColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

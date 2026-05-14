import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/search/presentation/controllers/enhanced_search_controller.dart';
import 'package:truthworld/features/search/presentation/controllers/enhanced_search_controller.dart'
    as search_enums;
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Professional Industry-Standard Search Page
/// - Advanced filters for videos, channels, playlists
/// - Cost-effective for millions of users
/// - Responsive design
/// - Professional UI/UX
class IndustrySearchPage extends StatefulWidget {
  const IndustrySearchPage({super.key});

  @override
  State<IndustrySearchPage> createState() => _IndustrySearchPageState();
}

class _IndustrySearchPageState extends State<IndustrySearchPage> {
  late final EnhancedSearchController _controller = Get.put(EnhancedSearchController());
  late final TextEditingController _searchTextController = TextEditingController();
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      _controller.loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search input
          _buildSearchInput(),
          // Filter toggle
          _buildFilterToggle(),
          // Expanded results/filters area
          Expanded(
            child: Obx(() {
              if (_controller.searchQuery.value.isEmpty) {
                return _buildEmptyState();
              }
              if (_controller.isLoading.value) {
                return _buildLoadingState();
              }
              if (_controller.errorMessage.value.isNotEmpty) {
                return _buildErrorState();
              }
              if (_controller.displayedResults.isEmpty) {
                return _buildNoResultsState();
              }
              return _buildResultsView();
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgSurface,
      elevation: 1,
      title: Text(
        'Search',
        style: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchInput() {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchTextController,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _controller.performSearch(value);
                } else {
                  _controller.clearSearch();
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _controller.performSearch(value);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search videos, channels, playlists...',
                hintStyle: GoogleFonts.roboto(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                suffixIcon: _searchTextController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchTextController.clear();
                          _controller.clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.roboto(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterToggle() {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Result type tabs
          Expanded(
            child: Obx(() => Row(
                  children: [
                    _buildTypeTab('All', search_enums.SearchType.all),
                    const SizedBox(width: 8),
                    _buildTypeTab('Videos', search_enums.SearchType.videos),
                    const SizedBox(width: 8),
                    _buildTypeTab('Channels', search_enums.SearchType.channels),
                    const SizedBox(width: 8),
                    _buildTypeTab('Playlists', search_enums.SearchType.playlists),
                  ],
                )),
          ),
          // Filter button
          Obx(
            () => IconButton(
              icon: Icon(
                _controller.showFilters.value ? Icons.filter_list : Icons.filter_list_outlined,
                color: AppColors.brand,
              ),
              onPressed: () => _controller.showFilters.value = !_controller.showFilters.value,
              tooltip: 'Show filters',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String label, search_enums.SearchType type) {
    return Obx(
      () {
        final isSelected = _controller.filters.value.searchType == type;
        return InkWell(
          onTap: () => _controller.setSearchType(type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.brand : AppColors.bgDivider,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Recent searches
          Obx(
            () => _controller.recentSearches.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Searches',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _controller.clearRecentSearches(),
                              child: Text(
                                'Clear All',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _controller.recentSearches
                              .map((query) => InkWell(
                                    onTap: () {
                                      _searchTextController.text = query;
                                      _controller.performSearch(query);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryBackground,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.bgDivider, width: 0.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            query,
                                            style: GoogleFonts.roboto(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => _controller.removeRecentSearch(query),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2.0),
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Recommended/Trending
          Obx(
            () => _controller.recommendedResults.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trending Now',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.recommendedResults.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final result = _controller.recommendedResults[index];
                            return _buildResultCard(result);
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.brand),
          ),
          const SizedBox(height: 12),
          Text(
            'Searching...',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 12),
          Obx(
            () => Text(
              _controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _controller.performSearch(_searchTextController.text);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NO RESULTS STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              'for "${_controller.searchQuery.value}"',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _controller.resetFilters(),
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULTS VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultsView() {
    return Column(
      children: [
        // Results count and filters
        _buildResultsHeader(),
        // Filters panel (if visible)
        Obx(
          () => _controller.showFilters.value ? _buildFiltersPanel() : const SizedBox.shrink(),
        ),
        // Results list
        Expanded(
          child: Obx(
            () => ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _controller.displayedResults.length +
                  (_controller.isLoadingMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _controller.displayedResults.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.brand),
                      ),
                    ),
                  );
                }
                return _buildResultCard(_controller.displayedResults[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULTS HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultsHeader() {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => Text(
                'Results: ${_controller.displayedResults.length}',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          // Cost indicator
          Obx(
            () => _controller.estimatedCost.value > 0
                ? Tooltip(
                    message: 'Est. cost for this search',
                    child: Text(
                      '~\$${_controller.estimatedCost.value.toStringAsFixed(4)}',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTERS PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFiltersPanel() {
    return Container(
      color: AppTheme.secondaryBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort by
          _buildFilterSection(
            'Sort by',
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => DropdownButton<search_enums.SortBy>(
                      value: _controller.filters.value.sortBy,
                      onChanged: (value) {
                        if (value != null) _controller.setSortBy(value);
                      },
                      items: search_enums.SortBy.values.map((sort) {
                        return DropdownMenuItem(
                          value: sort,
                          child: Text(
                            sort.toString().split('.').last,
                            style: GoogleFonts.roboto(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Upload date (for videos only)
          Obx(
            () => _controller.filters.value.searchType != search_enums.SearchType.channels
                ? _buildFilterSection(
                    'Upload date',
                    Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => DropdownButton<search_enums.UploadDate>(
                              value: _controller.filters.value.uploadDate,
                              onChanged: (value) {
                                if (value != null) _controller.setUploadDate(value);
                              },
                              items: search_enums.UploadDate.values.map((date) {
                                return DropdownMenuItem(
                                  value: date,
                                  child: Text(
                                    date.toString().split('.').last,
                                    style: GoogleFonts.roboto(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Reset filters button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _controller.resetFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: AppColors.bgDivider),
              ),
              child: Text(
                'Reset Filters',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        content,
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULT CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultCard(SearchResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider, width: 0.5),
      ),
      child: Row(
        children: [
          // Thumbnail/Icon
          _buildResultThumbnail(result),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Channel/Creator
                Text(
                  result.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Metadata
                Row(
                  children: [
                    Text(
                      '👁️ ${_formatCount(result.viewCount)}',
                      style: GoogleFonts.roboto(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    if (result.type == ResultType.video)
                      Text(
                        '⏱️ ${_formatDuration(result.duration ?? 0)}',
                        style: GoogleFonts.roboto(fontSize: 10, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultThumbnail(SearchResult result) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        result.thumbnail,
        width: 80,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 60,
          color: AppTheme.secondaryBackground,
          child: const Icon(Icons.image_not_supported, size: 24),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) return '${remainingSeconds}s';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }
}







import 'package:flutter/material.dart' hide SearchController, SearchBar;
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// SearchPage: Main search UI (Optimized for 9 Problems)
///
/// Problems Solved:
/// 1. Request cancellation ✅
/// 2. Rate limiting ✅
/// 3. Persistent cache ✅
/// 4. Pagination ✅
/// 5. Input validation ✅
/// 6. Error recovery ✅
/// 7. Mobile-adaptive debounce ✅
/// 8. Analytics ✅
/// 9. Memory optimization ✅
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _searchController = TextEditingController();
  late final SearchController _searchCtrl = Get.put(SearchController());
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Warmup cache on page load
    _searchCtrl.fetchTrendingSuggestions();

    // Setup infinite scroll pagination (Problem 4)
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels > position.maxScrollExtent * 0.8) {
        // User scrolled to 80% bottom → load next page
        _searchCtrl.loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    // Note: SearchController disposal happens in onClose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search'), elevation: 0),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════════════════
          // SEARCH INPUT FIELD (Problem 5: Input validation)
          // ══════════════════════════════════════════════════════════════
          SearchBar(
            controller: _searchController,
            onChanged: _searchCtrl.onSearchChanged,
            onClear: _searchCtrl.clearSearch,
          ),

          // ══════════════════════════════════════════════════════════════
          // COST & RATE LIMIT WARNING (Problem 2 & Cost optimization)
          // ══════════════════════════════════════════════════════════════
          Obx(() {
            if (_searchCtrl.estimatedMonthlyCost.value > 5.0) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'High search usage detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Est. \$${_searchCtrl.estimatedMonthlyCost.value.toStringAsFixed(2)}/month',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SizedBox.shrink();
          }),

          // ══════════════════════════════════════════════════════════════
          // MAIN CONTENT AREA (Problems 4, 6, 8, 9)
          // ══════════════════════════════════════════════════════════════
          Expanded(
            child: Obx(() {
              final query = _searchCtrl.searchQuery.value;
              final results = _searchCtrl.searchResults;
              final isLoading = _searchCtrl.isLoading.value;
              final isLoadingMore = _searchCtrl.isLoadingMore.value;
              final errorMsg = _searchCtrl.errorMessage.value;

              // CASE 1: Empty search (show recent & suggestions)
              if (query.isEmpty) {
                return _buildEmptyState();
              }

              // CASE 2: Loading state
              if (isLoading) {
                return SearchResultSkeleton(count: 5);
              }

              // CASE 3: Rate limit error
              if (errorMsg.contains('Too many searches')) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        size: 48,
                        color: Colors.orange[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Slow down!',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Too many searches in a short time',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _searchCtrl.clearSearch,
                        child: Text('Clear Search'),
                      ),
                    ],
                  ),
                );
              }

              // CASE 4: Validation error (Problem 5)
              if (errorMsg.contains('Invalid characters')) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Invalid search',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use simple text only (no special characters)',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _searchCtrl.clearSearch,
                        child: Text('Clear'),
                      ),
                    ],
                  ),
                );
              }

              // CASE 5: Generic error
              if (errorMsg.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: 16),
                      Text(errorMsg),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _searchCtrl.clearSearch,
                        child: Text('Clear'),
                      ),
                    ],
                  ),
                );
              }

              // CASE 6: No results
              if (results.isEmpty) {
                return EmptySearchState(
                  query: query,
                  onClearSearch: _searchCtrl.clearSearch,
                );
              }

              // CASE 7: Results found
              return _buildResultsList(results, isLoadingMore);
            }),
          ),
        ],
      ),
    );
  }

  /// Build empty search state (show recent searches and suggestions)
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          Obx(
            () => _searchCtrl.recentSearches.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: RecentSearchesList(
                      recentSearches: _searchCtrl.recentSearches,
                      onSearchSelected: (query) {
                        _searchController.text = query;
                        _searchCtrl.searchFromRecent(query);
                      },
                      onClearAll: _searchCtrl.clearRecentSearches,
                    ),
                  )
                : SizedBox.shrink(),
          ),

          // 📈 [NEW] "You May Like" Section (Recommended Videos)
          Obx(
            () => _searchCtrl.recommendedResults.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'You may like',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          height: 180, // Horizontal slider height
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _searchCtrl.recommendedResults.length,
                            itemBuilder: (context, index) {
                              final video =
                                  _searchCtrl.recommendedResults[index];
                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: _buildRecommendedCard(video),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox.shrink(),
          ),

          // Trending searches section
          Obx(
            () => _searchCtrl.suggestions.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trending Today',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _searchCtrl.suggestions
                              .map(
                                (suggestion) => ActionChip(
                                  label: Text(suggestion),
                                  onPressed: () {
                                    _searchController.text = suggestion;
                                    _searchCtrl.searchFromRecent(suggestion);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )
                : SizedBox.shrink(),
          ),

          // Tips section
          Padding(
            padding: EdgeInsets.all(16),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Search Tips',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Use specific keywords for better results\n'
                    '• Try different search terms if no results\n'
                    '• Recent searches save your history',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build results list with pagination support (Problem 4)
  Widget _buildResultsList(List results, bool isLoadingMore) {
    return Column(
      children: [
        // Results summary with cost tracking
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${results.length} results',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Obx(() {
                    final cost = _searchCtrl.estimatedMonthlyCost.value;
                    return Text(
                      'Est. \$${cost.toStringAsFixed(4)}/month',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    );
                  }),
                ],
              ),
              Obx(() {
                final stats = _searchCtrl.cacheStats;
                if (stats.isEmpty) return SizedBox.shrink();
                return Text(
                  'Cache: ${stats['size']}/${stats['maxSize']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                );
              }),
            ],
          ),
        ),
        // Results list with infinite scroll
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: results.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Loading indicator at the end (Problem 4: Pagination)
              if (index == results.length) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final result = results[index];
              return SearchResultCard(
                result: result,
                onTap: () => _searchCtrl.onResultTapped(result),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build recommended video card for horizontal slider
  Widget _buildRecommendedCard(SearchResult video) {
    return InkWell(
      onTap: () {
        _searchCtrl.onResultTapped(video);
      },
      child: Container(
        width: 220,
        margin: EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      video.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.video_library, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '4:20', // Static for now
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${video.views} views • ${video.channelName}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
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






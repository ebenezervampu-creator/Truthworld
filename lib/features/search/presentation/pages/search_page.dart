import 'package:flutter/material.dart' hide SearchController, SearchBar;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// SearchPage: Main search UI (Optimized for 9 Problems & YouTube Exact Look)
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
    return Scaffold(
      backgroundColor: Colors.black, // Dark background like YouTube
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_searchCtrl.showSuggestions.value) {
              _searchCtrl.showSuggestions.value = false;
            } else {
              Get.back();
            }
          },
        ),
        titleSpacing: 0,
        title: SearchBar(
          controller: _searchController,
          onChanged: _searchCtrl.onSearchChanged,
          onClear: _searchCtrl.clearSearch,
          onSearchSubmitted: () {
            if (_searchController.text.isNotEmpty) {
              _searchCtrl.performSearch(_searchController.text);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Bottom Layer: Results and chips
          Column(
            children: [
              // Scrollable Filter Chips row
              Obx(() {
                final query = _searchCtrl.searchQuery.value;
                final hasResults = _searchCtrl.searchResults.isNotEmpty;
                if (query.isEmpty || !hasResults) {
                  return const SizedBox.shrink();
                }
                
                final filters = ['All', 'Watched', 'Unwatched', 'Videos', 'Channels', 'Playlists', 'Topics', 'Recently uploaded', 'Live'];
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final isSelected = _searchCtrl.selectedFilter.value == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF212121),
                          checkmarkColor: Colors.black,
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) {
                              _searchCtrl.setFilter(filter);
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? Colors.white : const Color(0xFF3F3F3F),
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
                    return const SearchResultSkeleton(count: 5);
                  }

                  // CASE 3: Error state
                  if (errorMsg.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(errorMsg, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _searchCtrl.clearSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
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
              color: Colors.black,
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
                      _searchController.selection = TextSelection.fromPosition(
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
    );
  }

  /// Build empty search state
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          Obx(
            () => _searchCtrl.recentSearches.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: RecentSearchesList(
                      recentSearches: _searchCtrl.recentSearches,
                      onSearchSelected: (query) {
                        _searchController.text = query;
                        _searchCtrl.performSearch(query);
                      },
                      onClearAll: _searchCtrl.clearRecentSearches,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // "You May Like" Section (Recommended Videos)
          Obx(
            () => _searchCtrl.recommendedResults.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'You may like',
                            style: TextStyle(
                              color: Colors.white,
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
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildRecommendedCard(video),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Trending searches section
          Obx(
            () => _searchCtrl.suggestions.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trending Today',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _searchCtrl.suggestions
                              .map(
                                (suggestion) => ActionChip(
                                  label: Text(suggestion, style: const TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.white10,
                                  onPressed: () {
                                    _searchController.text = suggestion;
                                    _searchCtrl.performSearch(suggestion);
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.transparent),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Tips section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Search Tips',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Use specific keywords for better results\n'
                    '• Try different search terms if no results\n'
                    '• Filter by channels, playlists, or topics',
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build results list with pagination support
  Widget _buildResultsList(List results, bool isLoadingMore) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: results.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF9B30FF),
                strokeWidth: 2,
              ),
            ),
          );
        }

        final result = results[index];
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
        durationStr = '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
                            placeholder: (context, url) => Container(color: Colors.white10),
                            errorWidget: (context, url, error) => const Icon(Icons.play_circle_outline, color: Colors.white38),
                          )
                        : Container(
                            color: Colors.white10,
                            child: const Icon(Icons.video_library, color: Colors.white38),
                          ),
                  ),
                ),
                if (durationStr != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.views} views • ${video.channelName}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
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

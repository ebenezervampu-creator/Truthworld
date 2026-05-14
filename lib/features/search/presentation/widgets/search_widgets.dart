import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Reusable search result card widget
///
/// Displays:
/// - Video thumbnail
/// - Title
/// - Channel info
/// - View count
/// - Upload date
class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const SearchResultCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case ResultType.channel:
        return _buildChannelCard(context);
      case ResultType.playlist:
        return _buildPlaylistCard(context);
      case ResultType.video:
        return _buildVideoCard(context);
    }
  }

  Widget _buildVideoCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              width: 120,
              height: 67.5,
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: result.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: result.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.error_outline),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.play_circle_outline),
                      ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (result.channelImage.isNotEmpty)
                          UserAvatar(
                            radius: 12,
                            photoUrl: result.channelImage,
                            displayName: result.channelName,
                          ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_formatViews(result.views)} views',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(
                radius: 35,
                photoUrl: result.thumbnail,
                displayName: result.title,
                fontSize: 24,
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${result.channelName} • ${_formatViews(result.views)} subscribers',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 67.5,
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[800],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (result.thumbnail.isNotEmpty)
                    Opacity(
                      opacity: 0.6,
                      child: CachedNetworkImage(
                        imageUrl: result.thumbnail,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 67.5,
                        placeholder: (context, url) => Container(color: Colors.black12),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play, color: Colors.white),
                      Text(
                        '${result.views}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Playlist • ${result.channelName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format view count (e.g., 1.2K, 1M)
  String _formatViews(int views) {
    if (views < 1000) return views.toString();
    if (views < 1000000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '${(views / 1000000).toStringAsFixed(1)}M';
  }
}

/// Empty state widget for no search results
class EmptySearchState extends StatelessWidget {
  final String query;
  final VoidCallback? onClearSearch;

  const EmptySearchState({super.key, required this.query, this.onClearSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text('Try different keywords', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 16),
          if (onClearSearch != null)
            ElevatedButton(
              onPressed: onClearSearch,
              child: Text('Clear Search'),
            ),
        ],
      ),
    );
  }
}

/// Loading skeleton for search results
class SearchResultSkeleton extends StatelessWidget {
  final int count;

  const SearchResultSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              // Thumbnail skeleton
              Container(
                width: 120,
                height: 67.5,
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
              ),
              // Content skeleton
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, color: Colors.grey[300]),
                      SizedBox(height: 8),
                      Container(
                        height: 12,
                        color: Colors.grey[300],
                        width: 100,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Recent searches list widget
class RecentSearchesList extends StatelessWidget {
  final List<String> recentSearches;
  final Function(String) onSearchSelected;
  final VoidCallback onClearAll;

  const RecentSearchesList({
    super.key,
    required this.recentSearches,
    required this.onSearchSelected,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: onClearAll,
                child: Text('Clear All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recentSearches
              .map(
                (search) => InkWell(
                  onTap: () => onSearchSelected(search),
                  child: Chip(
                    label: Text(search),
                    onDeleted: () {
                      // Implement individual delete if needed
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Search bar widget with styling
class SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final String hintText;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search videos...',
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}






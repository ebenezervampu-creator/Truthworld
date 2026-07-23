import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart' as ctrl;
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// GetX Controller to manage state for SubscribeButton
class SubscribeButtonController extends GetxController {
  final RxBool isSubscribed = false.obs;

  void toggle() {
    isSubscribed.toggle();
  }
}

/// GetX Subscribe Button to mock subscriptions interactively
class SubscribeButton extends StatelessWidget {
  const SubscribeButton({required this.channelName, super.key});
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscribeButtonController(), tag: channelName);
    final colors = context.twColors;
    final typography = context.twTypography;

    return Obx(() {
      final isSubscribed = controller.isSubscribed.value;
      return InkWell(
        onTap: () {
          controller.toggle();
          final nextState = controller.isSubscribed.value;
          Get.snackbar(
            nextState ? 'Subscribed' : 'Unsubscribed',
            nextState 
              ? 'Added $channelName to subscriptions.' 
              : 'Removed $channelName from subscriptions.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: colors.textPrimary.withValues(alpha: 0.9),
            colorText: colors.background,
            duration: const Duration(seconds: 2),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSubscribed ? colors.textPrimary.withValues(alpha: 0.1) : colors.textPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            isSubscribed ? 'Subscribed' : 'Subscribe',
            style: typography.label.copyWith(
              color: isSubscribed ? colors.textSecondary : colors.background,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }
}

/// GetX Controller to manage state for FollowButton
class FollowButtonController extends GetxController {
  final RxBool isFollowing = false.obs;

  void toggle() {
    isFollowing.toggle();
  }
}

/// GetX Follow Button for Topic cards
class FollowButton extends StatelessWidget {
  const FollowButton({required this.topicTitle, super.key});
  final String topicTitle;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FollowButtonController(), tag: topicTitle);
    final colors = context.twColors;
    final typography = context.twTypography;

    return Obx(() {
      final isFollowing = controller.isFollowing.value;
      return InkWell(
        onTap: () {
          controller.toggle();
          final nextState = controller.isFollowing.value;
          Get.snackbar(
            nextState ? 'Following' : 'Unfollowed',
            nextState 
              ? 'Now following the $topicTitle topic.' 
              : 'Unfollowed $topicTitle topic.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: colors.textPrimary.withValues(alpha: 0.9),
            colorText: colors.background,
            duration: const Duration(seconds: 2),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isFollowing ? colors.textPrimary.withValues(alpha: 0.1) : colors.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            isFollowing ? 'Following' : 'Follow',
            style: typography.label.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }
}

/// Reusable search result card widget
class SearchResultCard extends StatelessWidget {

  const SearchResultCard({required this.result, super.key, this.onTap});
  final SearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case ResultType.channel:
        return _buildChannelCard(context);
      case ResultType.playlist:
        return _buildPlaylistCard(context);
      case ResultType.topic:
        return _buildTopicCard(context);
      case ResultType.video:
        return _buildVideoCard(context);
    }
  }

  Widget _buildVideoCard(BuildContext context) {
    final seconds = result.duration;
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.38,
                      color: AppColors.textSecondary,
                      child: result.thumbnail.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: result.thumbnail,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: AppColors.bgDivider),
                              errorWidget: (context, url, error) => const Icon(Icons.play_circle_outline, color: AppColors.textTertiary),
                            )
                          : const Icon(Icons.play_circle_outline, color: AppColors.textTertiary),
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
                        color: AppColors.bgPage.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Video Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatViews(result.views)} views • ${_formatRelativeTime(result.createdAt.toDate())}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Channel row
                  Row(
                    children: [
                      if (result.channelImage.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: result.channelImage,
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.bgDivider),
                            errorWidget: (context, url, error) => const Icon(Icons.account_circle, size: 20, color: AppColors.textTertiary),
                          ),
                        )
                      else
                        const Icon(Icons.account_circle, size: 20, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quality badge & snippet mock description
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.bgDivider,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '4K',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Watch in high quality truth stream.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // Circular Avatar
            ClipOval(
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.textSecondary,
                child: result.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: result.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppColors.bgDivider),
                        errorWidget: (context, url, error) => const Icon(Icons.account_circle, size: 40, color: AppColors.textTertiary),
                      )
                    : const Icon(Icons.account_circle, size: 40, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(width: 16),
            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.channelName} • ${_formatViews(result.views)} subscribers',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Official channel. Explore and join.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Subscribe button
            SubscribeButton(channelName: result.title),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with playlist overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.38,
                      color: AppColors.textSecondary,
                      child: result.thumbnail.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: result.thumbnail,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: AppColors.bgDivider),
                              errorWidget: (context, url, error) => const Icon(Icons.playlist_play, color: AppColors.textTertiary),
                            )
                          : const Icon(Icons.playlist_play, color: AppColors.textTertiary),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.playlist_play, color: AppColors.textPrimary),
                        const SizedBox(height: 4),
                        Text(
                          '${result.views}', // acts as video count
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Playlist Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Playlist • ${result.channelName}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View full playlist',
                    style: TextStyle(
                      color: Color(0xFF3EA6FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTopicCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Topic Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.38,
                      color: AppColors.textSecondary,
                      child: result.thumbnail.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: result.thumbnail,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(Icons.topic, color: AppColors.textTertiary),
                                ),
                                Container(
                                  color: Colors.black.withValues(alpha: 0.65),
                                ),
                                CachedNetworkImage(
                                  imageUrl: result.thumbnail,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Container(color: AppColors.bgDivider),
                                  errorWidget: (context, url, error) => const Icon(Icons.topic, color: AppColors.textTertiary),
                                ),
                              ],
                            )
                          : const Icon(Icons.topic, color: AppColors.textTertiary),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B30FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TOPIC',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Topic Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.channelName, // Display slug/handle
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatViews(result.views)} videos available',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FollowButton(topicTitle: result.title),
          ],
        ),
      ),
    );
  }

  /// Helper to format view/sub counts
  String _formatViews(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Helper to format relative upload dates
  String _formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    }
    if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago';
    }
    return 'just now';
  }
}

/// Custom autocomplete suggestion tile
class SearchSuggestionTile extends StatelessWidget {

  const SearchSuggestionTile({
    required this.suggestion, required this.onTap, required this.onCopy, super.key,
  });
  final ctrl.SearchSuggestion suggestion;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              suggestion.icon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.subtitle != null)
                    Text(
                      suggestion.subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (suggestion.imageUrl != null && suggestion.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(suggestion.isRoundImage ? 20 : 4),
                child: CachedNetworkImage(
                  imageUrl: suggestion.imageUrl!,
                  width: 40,
                  height: suggestion.isRoundImage ? 40 : 25,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.bgDivider),
                  errorWidget: (context, url, error) => const Icon(Icons.image, size: 20, color: AppColors.textDisabled),
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.north_west,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                onPressed: onCopy,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for no search results
class EmptySearchState extends StatelessWidget {

  const EmptySearchState({required this.query, super.key, this.onClearSearch});
  final String query;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Try different keywords', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (onClearSearch != null)
            ElevatedButton(
              onPressed: onClearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgDivider,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }
}

/// Loading skeleton for search results
class SearchResultSkeleton extends StatelessWidget {

  const SearchResultSkeleton({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.38,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 12,
                      width: 80,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                    ),
                  ],
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

  const RecentSearchesList({
    required this.recentSearches, required this.onSearchSelected, required this.onClearAll, super.key,
  });
  final List<String> recentSearches;
  final Function(String) onSearchSelected;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text('Clear All', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                    label: Text(search, style: const TextStyle(color: AppColors.textPrimary)),
                    backgroundColor: AppColors.bgDivider,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Search bar widget matching Category Page simple text field design
class SearchBar extends StatefulWidget {

  const SearchBar({
    required this.controller, required this.onChanged, required this.onClear, required this.onSearchSubmitted, super.key,
    this.hintText = 'Search videos, channels, topics...',
    this.isLoading = false,
  });
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final VoidCallback onSearchSubmitted;
  final String hintText;
  final bool isLoading;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final FocusNode _focusNode = FocusNode();
  final RxBool _isFocused = false.obs;
  final RxInt _textLength = 0.obs;

  @override
  void initState() {
    super.initState();
    _textLength.value = widget.controller.text.length;
    widget.controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    _textLength.value = widget.controller.text.length;
  }

  void _handleFocusChange() {
    _isFocused.value = _focusNode.hasFocus;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused.value ? AppColors.brand : AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onSearchSubmitted(),
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: AppColors.brand,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: widget.isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(12),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: _isFocused.value ? AppColors.brand : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: widget.onSearchSubmitted,
                ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_textLength.value > 0)
                IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    _textLength.value = 0;
                    widget.onClear();
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.mic_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  Get.dialog(
                    VoiceSearchDialog(
                      onSearch: (query) {
                        widget.controller.text = query;
                        widget.onChanged(query);
                        widget.onSearchSubmitted();
                      },
                    ),
                    useSafeArea: false,
                  );
                },
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ));
  }
}

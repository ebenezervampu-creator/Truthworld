import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sub-item rendering a playlist search result.
class SearchPlaylistResultItem extends StatelessWidget {
  const SearchPlaylistResultItem({
    required this.result,
    super.key,
    this.onTap,
  });

  final SearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with playlist overlay
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.38,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ColoredBox(
                        color: AppColors.textSecondary,
                        child: result.thumbnail.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: result.thumbnail,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const ColoredBox(
                                  color: AppColors.bgDivider,
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.playlist_play,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.playlist_play,
                                color: Colors.white,
                              ),
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
                          const Icon(
                            Icons.playlist_play,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${result.views}',
                            style: const TextStyle(
                              color: Colors.white,
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
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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
}

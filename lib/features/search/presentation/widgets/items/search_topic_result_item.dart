import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_follow_button.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sub-item rendering a topic search result.
class SearchTopicResultItem extends StatelessWidget {
  const SearchTopicResultItem({
    required this.result,
    super.key,
    this.onTap,
    this.formattedViews = '',
  });

  final SearchResult result;
  final VoidCallback? onTap;
  final String formattedViews;

  @override
  Widget build(BuildContext context) {
    if (result.views <= 0) {
      return const SizedBox.shrink();
    }
    final cleanThumb = result.thumbnail.trim().replaceAll(' ', '%20');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Topic Badge
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
                        child: cleanThumb.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: cleanThumb,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) {
                                      if (kIsWeb) {
                                        return Image.network(
                                          cleanThumb,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.topic,
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                      return const Icon(
                                        Icons.topic,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.65),
                                  ),
                                  CachedNetworkImage(
                                    imageUrl: cleanThumb,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) =>
                                        const ColoredBox(
                                      color: AppColors.bgDivider,
                                    ),
                                    errorWidget: (context, url, error) {
                                      if (kIsWeb) {
                                        return Image.network(
                                          cleanThumb,
                                          fit: BoxFit.contain,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.topic,
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                      return const Icon(
                                        Icons.topic,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.topic,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TOPIC',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                    result.channelName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$formattedViews videos available',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FollowButton(
              topicId: result.id,
              topicName: result.title,
              videoCount: result.views,
            ),
          ],
        ),
      ),
    );
  }
}

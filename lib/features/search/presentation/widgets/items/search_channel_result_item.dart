import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_subscribe_button.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sub-item rendering a channel search result.
class SearchChannelResultItem extends StatelessWidget {
  const SearchChannelResultItem({
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
    final rawThumbnail = result.thumbnail.isNotEmpty
        ? result.thumbnail
        : (result.channelImage.isNotEmpty
            ? result.channelImage
            : (DeepLinkService.instance.getChannelFromCache(result.id)?.avatarUrl ??
                DeepLinkService.instance.getChannelFromCache(result.channelName)?.avatarUrl ??
                ''));
    final cleanThumbnail = rawThumbnail.trim().replaceAll(' ', '%20');

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
                color: AppColors.bgSurface,
                child: cleanThumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: cleanThumbnail,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        memCacheWidth: kIsWeb ? null : 160,
                        memCacheHeight: kIsWeb ? null : 160,
                        placeholder: (context, url) =>
                            Container(color: AppColors.bgDivider),
                        errorWidget: (context, url, error) {
                          if (kIsWeb) {
                            return Image.network(
                              cleanThumbnail,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stack) => const Icon(
                                Icons.account_circle,
                                size: 48,
                                color: Colors.white,
                              ),
                            );
                          }
                          return const Icon(
                            Icons.account_circle,
                            size: 48,
                            color: Colors.white,
                          );
                        },
                      )
                    : const Icon(
                        Icons.account_circle,
                        size: 48,
                        color: Colors.white,
                      ),
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
                    '${result.channelName} • $formattedViews subscribers',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Official channel. Explore and join.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Subscribe button
            SubscribeButton(
              channelId: result.id,
              channelName: result.title,
            ),
          ],
        ),
      ),
    );
  }
}

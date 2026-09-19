import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
                        placeholder: (context, url) =>
                            Container(color: AppColors.bgDivider),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.account_circle,
                          size: 40,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.account_circle,
                        size: 40,
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

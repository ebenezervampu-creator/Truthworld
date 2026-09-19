import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sub-item rendering a video search result.
class SearchVideoResultItem extends StatelessWidget {
  const SearchVideoResultItem({
    required this.result,
    super.key,
    this.onTap,
    this.durationStr,
    this.formattedViews = '',
    this.formattedTime = '',
  });

  final SearchResult result;
  final VoidCallback? onTap;
  final String? durationStr;
  final String formattedViews;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isWide = screenWidth >= 600;
                final thumbWidth = isWide
                    ? (screenWidth * 0.32).clamp(240.0, 360.0)
                    : (screenWidth * 0.38).clamp(140.0, 200.0);
                return SizedBox(
                  width: thumbWidth,
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
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                      if (durationStr != null)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              durationStr!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
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
                    '$formattedViews views • $formattedTime',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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
                            placeholder: (context, url) =>
                                Container(color: AppColors.bgDivider),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.account_circle,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.account_circle,
                          size: 20,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Category badge & metadata snippet
                  if ((result.category != null &&
                          result.category!.isNotEmpty) ||
                      (result.language != null &&
                          result.language!.isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (result.category != null &&
                            result.category!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgDivider,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              result.category!.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (result.language != null &&
                            result.language!.isNotEmpty)
                          Expanded(
                            child: Text(
                              result.language!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

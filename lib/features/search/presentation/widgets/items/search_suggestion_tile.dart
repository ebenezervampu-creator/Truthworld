import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Custom autocomplete suggestion tile.
class SearchSuggestionTile extends StatelessWidget {
  const SearchSuggestionTile({
    required this.suggestion,
    required this.onTap,
    required this.onCopy,
    super.key,
  });

  final SearchSuggestion suggestion;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              suggestion.icon,
              color: Colors.white,
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
            if (suggestion.imageUrl != null &&
                suggestion.imageUrl!.trim().isNotEmpty) () {
              final cleanSuggestionUrl =
                  suggestion.imageUrl!.trim().replaceAll(' ', '%20');
              return ClipRRect(
                borderRadius: BorderRadius.circular(
                  suggestion.isRoundImage ? 20 : 4,
                ),
                child: CachedNetworkImage(
                  imageUrl: cleanSuggestionUrl,
                  width: 40,
                  height: suggestion.isRoundImage ? 40 : 25,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.bgDivider),
                  errorWidget: (context, url, error) {
                    if (kIsWeb) {
                      return Image.network(
                        cleanSuggestionUrl,
                        width: 40,
                        height: suggestion.isRoundImage ? 40 : 25,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) => const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.white,
                        ),
                      );
                    }
                    return const Icon(
                      Icons.image,
                      size: 20,
                      color: Colors.white,
                    );
                  },
                ),
              );
            }()
            else
              IconButton(
                icon: const Icon(
                  Icons.north_west,
                  color: Colors.white,
                  size: 18,
                ),
                tooltip: 'Insert suggestion',
                onPressed: onCopy,
                padding: const EdgeInsets.all(8),
              ),
          ],
        ),
      ),
    );
  }
}

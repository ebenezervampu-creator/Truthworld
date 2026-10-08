import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';

/// Card displaying an individual discover category with icon, title, count, image, and chevron.
/// Matches exact visual architecture from Discover Channels Main Page (Image 1).
class DiscoverCategoryCard extends StatelessWidget {
  const DiscoverCategoryCard({
    required this.category,
    required this.onTap,
    this.channelCount,
    super.key,
  });

  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final int? channelCount;

  @override
  Widget build(BuildContext context) {
    final catName = category['name'] as String;
    final imageUrl = (category['imageUrl'] as String?) ?? getCategoryImage(catName);
    // Authentic real channel count: uses channelCount parameter or category map count.
    final count = channelCount ?? (category['channelCount'] as int?);
    final countText = count != null
        ? formatChannelCount(count)
        : ((category['channelCountDisplay'] as String?)?.trim() ?? '');
    final iconData = category['iconData'] is IconData
        ? category['iconData'] as IconData
        : getCategoryIcon(catName);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kDiscoverCardBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Rich background photo
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: buttonBg),
                errorWidget: (context, url, error) => Container(color: buttonBg),
              ),

              // Smooth gradient overlay to protect text contrast while exposing image details
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.60),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),

              // Subtle bottom/top gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),

              // Foreground content row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Icon in circular translucent container
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          iconData,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Channel count (omitted when empty to prevent mock count display)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName,
                            style: const TextStyle(
                              color: primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (countText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              countText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Chevron circle button
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

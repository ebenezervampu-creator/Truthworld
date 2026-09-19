import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_action_handler.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_item.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

/// Section rendering followed channels in the navigation rail.
class NavRailSubscriptionsSection extends StatelessWidget {
  const NavRailSubscriptionsSection({
    required this.currentUser,
    required this.isCompact,
    required this.homeController,
    super.key,
  });

  final User? currentUser;
  final bool isCompact;
  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NavRailDivider(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: NavRailSectionHeader(
            title: 'FOLLOWING',
            isCompact: isCompact,
          ),
        ),
        Obx(() {
          if (homeController.isLoadingSubscriptions.value) {
            return Column(
              children: List.generate(
                3,
                (_) => _buildSubscriptionShimmer(context),
              ),
            );
          }

          final channelsData = homeController.subscribedChannelList;

          if (channelsData.isEmpty) {
            return _buildSubscriptionMessage(
              context,
              isCompact ? '' : 'No subscriptions yet',
              Icons.add_link_rounded,
            );
          }

          return Column(
            children: channelsData.map((data) {
              final channelName = data['name'] ?? '';
              final channel = Channel(
                id: data['id'],
                ownerId: currentUser!.uid,
                name: channelName,
                nameLowercase: channelName.toLowerCase(),
                handle: '@${channelName.replaceAll(' ', '').toLowerCase()}',
                handleLowercase:
                    '@${channelName.replaceAll(' ', '').toLowerCase()}',
                description: '',
                avatarUrl: data['avatar'],
                bannerUrl: '',
                createdAt: Timestamp.now(),
                updatedAt: Timestamp.now(),
              );

              return ModernChannelListItem(
                channel: channel,
                isCompact: isCompact,
                onTap: () => NavRailActionHandler.handleChannelTap(
                  channel: channel,
                  homeController: homeController,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildSubscriptionShimmer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: 6,
      ),
      child: Shimmer.fromColors(
        baseColor: modernDarkProfessionalTheme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        highlightColor: modernDarkProfessionalTheme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment:
              isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 16),
              Container(height: 16, width: 120, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionMessage(
    BuildContext context,
    String message,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: 16,
      ),
      child: isCompact
          ? Icon(
              icon,
              size: 24,
              color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
            )
          : Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: modernDarkProfessionalTheme.textTheme.bodyMedium
                        ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Modern channel list item widget used in the side navigation rail.
class ModernChannelListItem extends StatelessWidget {
  const ModernChannelListItem({
    required this.channel,
    required this.onTap,
    required this.isCompact,
    super.key,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : 16,
            vertical: 8,
          ),
          child: isCompact
              ? _buildCompactItem(context)
              : _buildFullItem(context),
        ),
      ),
    );
  }

  Widget _buildCompactItem(BuildContext context) {
    return Tooltip(
      message: channel.channelName,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ModernChannelAvatar(
            imageUrl: channel.avatarUrl,
            radius: 16,
            placeholderText:
                _safeSubstring(channel.channelName, 0, 1).toUpperCase(),
          ),
          const SizedBox(height: 4),
          Text(
            channel.channelName,
            style: modernDarkProfessionalTheme.textTheme.labelSmall?.copyWith(
              color: modernDarkProfessionalTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFullItem(BuildContext context) {
    return Row(
      children: [
        ModernChannelAvatar(
          imageUrl: channel.avatarUrl,
          radius: 16,
          placeholderText:
              _safeSubstring(channel.channelName, 0, 1).toUpperCase(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            channel.channelName,
            style: modernDarkProfessionalTheme.textTheme.bodyMedium?.copyWith(
              color: modernDarkProfessionalTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _safeSubstring(String str, int start, int end) {
    if (str.isEmpty) return str;
    if (end > str.length) end = str.length;
    return str.substring(start, end);
  }
}

/// Circular avatar with network cache and initials placeholder.
class ModernChannelAvatar extends StatelessWidget {
  const ModernChannelAvatar({
    required this.radius,
    this.imageUrl,
    this.placeholderText,
    super.key,
  });

  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            modernDarkProfessionalTheme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                          .toInt(),
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        placeholderText ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

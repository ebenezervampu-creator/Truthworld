import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ==========================================================================
// YOUTUBE THEME COLORS
// ==========================================================================
const Color ytBackground = AppColors.bgPage;
const Color ytSurface = Color(0xFF1A1A1A);
const Color ytSurfaceLight = Color(0xFF262626);
const Color ytTextPrimary = AppColors.textPrimary;
const Color ytTextSecondary = AppColors.textSecondary;
const Color ytTextTertiary = AppColors.textTertiary;
const Color ytSubscribeBtn = AppColors.textPrimary;
const Color ytSubscribeBtnText = AppColors.bgPage;
const Color ytSubscribedBtn = Color(0xFF262626);
const Color ytLinkBlue = AppColors.textLink;
const Color ytBorder = AppColors.searchBorder;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================
const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

// ==========================================================================
// SLIVER APP BAR DELEGATE
// ==========================================================================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.child, {required this.maxHeight});
  final Widget child;
  final double maxHeight;

  @override
  double get minExtent => maxHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: ytBackground, child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// ==========================================================================
// CHANNEL DETAILS PAGE - YOUTUBE STYLE
// ==========================================================================
class ChannelDetailsPage extends GetView<ChannelController> {
  const ChannelDetailsPage({super.key, this.channel, this.isDashboard = false});
  final Channel? channel;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ChannelController>()) {
      Get.put(ChannelController());
    }
    final args = Get.arguments;
    final targetChannel =
        channel ??
        (args != null && args is Map && args['channel'] is Channel ? args['channel'] as Channel : null);

    if (targetChannel != null) {
      controller.initForChannelDetails(targetChannel);
    } else {
      final channelTarget =
          Get.parameters['channelId'] ??
          Get.parameters['handle'] ??
          Get.parameters['id'];
      if (channelTarget != null && channelTarget.isNotEmpty) {
        controller.loadChannelFromDeepLink(channelTarget);
      }
    }

    controller.startPageAnimations();

    return Obx(() {
      final currentChannel = controller.selectedChannel.value;
      if (currentChannel == null) {
        return const ShimmerChannelDetailsScreen();
      }

      return FadeTransition(
        opacity: controller.pageFadeAnimation,
        child: _buildResponsiveLayout(context, currentChannel),
      );
    });
  }

  Widget _buildResponsiveLayout(BuildContext context, Channel channel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context, channel);
        } else if (isTablet) {
          return _buildTabletLayout(context, channel);
        } else {
          return _buildMobileLayout(context, channel);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 8,
              child: _buildMainContent(context, channel, isDesktop: true),
            ),
            Expanded(flex: 2, child: _buildChannelSidebar(context, channel)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: _buildMainContent(context, channel, isTablet: true),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: _buildMainContent(context, channel),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final activeTabs = controller.activeTabs;
    final tabCount = activeTabs.length;

    return DefaultTabController(
      key: ValueKey(
        'tab-controller-${channel.channelId}-${activeTabs.join(",")}',
      ),
      length: tabCount,
      child: NestedScrollView(
        controller: controller.scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildBanner(
                channel,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildChannelHeader(
                context,
                channel,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                _buildYouTubeTabBar(activeTabs),
                maxHeight: 48,
              ),
            ),
          ];
        },
        body: TabBarView(
          children: activeTabs.map((tabName) {
            switch (tabName) {
              case 'Home':
                return _buildHomeTab(
                  context,
                  channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Videos':
                return _buildVideosTab(
                  context,
                  channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Topics':
                return _buildTopicsTab(
                  context,
                  channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Playlists':
                return _buildPlaylistsTab(
                  context,
                  channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Posts':
                return _buildPostsTab(
                  context,
                  channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              default:
                return const SizedBox.shrink();
            }
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================================================
  // BANNER
  // ==========================================================================
  Widget _buildBanner(
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final bannerHeight = isDesktop ? 220.0 : (isTablet ? 170.0 : 130.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24.0 : (isTablet ? 16.0 : 0.0),
        vertical: isDesktop || isTablet ? 16.0 : 0.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop || isTablet ? 16.0 : 0.0),
        child: SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: Builder(
            builder: (context) => Stack(
              children: [
                if (channel.bannerImageUrl.isNotEmpty) ...[
                  // Ambient background backdrop with blur for dynamic banner aspect ratios
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: channel.bannerImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const ColoredBox(color: ytSurface),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ),
                  // Primary full-bleed banner cover
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: channel.bannerImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: ytSurface,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ytTextSecondary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: ytSurface,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: ytTextTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Positioned.fill(
                    child: ColoredBox(
                      color: ytSurface,
                      child: Center(
                        child: Icon(
                          Icons.image_rounded,
                          color: ytTextTertiary,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                if (isDashboard || Navigator.of(context).canPop())
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Back',
                        onPressed: () {
                          if (isDashboard &&
                              Get.isRegistered<HomeController>()) {
                            Get.find<HomeController>().goBackFromSpecialPage(
                              HomeController.indexDiscover,
                            );
                          } else {
                            Get.back();
                          }
                        },
                      ),
                    ),
                  ),
                Builder(
                  builder: (context) {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null ||
                        channel.ownerId != currentUser.uid) {
                      return const SizedBox.shrink();
                    }

                    return Obx(() {
                      final status = controller.detailsBannerStatus.value;
                      if (status.isEmpty || status == 'APPROVED') {
                        return const SizedBox.shrink();
                      }

                      var overlayColor = AppColors.bgPage54;
                      var badgeColor = const Color(0xFF3B82F6);
                      var text = 'Banner Verification Pending';
                      var icon = Icons.sync_rounded;
                      final isPending = status == 'PENDING';

                      if (status == 'REJECTED') {
                        overlayColor = AppColors.bgPage.withValues(alpha: 0.8);
                        badgeColor = const Color(0xFFEF4444);
                        text =
                            "Banner Rejected: ${controller.detailsBannerReason.value.isNotEmpty ? controller.detailsBannerReason.value : 'Violated Community Guidelines'}";
                        icon = Icons.error_outline_rounded;
                      } else if (status == 'FLAGGED') {
                        overlayColor = AppColors.bgPage.withValues(alpha: 0.7);
                        badgeColor = const Color(0xFFF59E0B);
                        text =
                            'Banner Review Needed: ${controller.detailsBannerReason.value}';
                        icon = Icons.warning_amber_rounded;
                      }

                      return Positioned.fill(
                        child: Container(
                          color: overlayColor,
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: badgeColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPending)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.textPrimary,
                                            ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      icon,
                                      color: AppColors.textPrimary,
                                      size: 18,
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CHANNEL HEADER
  // ==========================================================================
  Widget _buildChannelHeader(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final avatarSize = isDesktop ? 120.0 : (isTablet ? 100.0 : 80.0);

    return Container(
      color: ytBackground,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'channel-avatar-${channel.channelId}',
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ytSurfaceLight),
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: channel.avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => ColoredBox(
                              color: ytSurface,
                              child: Icon(
                                Icons.person,
                                color: ytTextTertiary,
                                size: avatarSize * 0.4,
                              ),
                            ),
                            errorWidget: (context, url, error) => ColoredBox(
                              color: ytSurface,
                              child: Icon(
                                Icons.person,
                                color: ytTextTertiary,
                                size: avatarSize * 0.4,
                              ),
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null ||
                                channel.ownerId != currentUser.uid) {
                              return const SizedBox.shrink();
                            }

                            return Obx(() {
                              final status =
                                  controller.detailsAvatarStatus.value;
                              if (status.isEmpty || status == 'APPROVED') {
                                return const SizedBox.shrink();
                              }

                              var overlayColor = AppColors.bgPage54;
                              var badgeColor = const Color(0xFF3B82F6);
                              var icon = Icons.sync_rounded;
                              final isPending = status == 'PENDING';

                              if (status == 'REJECTED') {
                                overlayColor = AppColors.bgPage.withValues(
                                  alpha: 0.8,
                                );
                                badgeColor = const Color(0xFFEF4444);
                                icon = Icons.error_outline_rounded;
                              } else if (status == 'FLAGGED') {
                                overlayColor = AppColors.bgPage.withValues(
                                  alpha: 0.7,
                                );
                                badgeColor = const Color(0xFFF59E0B);
                                icon = Icons.warning_amber_rounded;
                              }

                              return Positioned.fill(
                                child: ColoredBox(
                                  color: overlayColor,
                                  child: Tooltip(
                                    message: status == 'REJECTED'
                                        ? 'Avatar Rejected: ${controller.detailsAvatarReason.value}'
                                        : (status == 'FLAGGED'
                                              ? 'Review Needed: ${controller.detailsAvatarReason.value}'
                                              : 'Avatar Verification Pending'),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isPending
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(AppColors.textPrimary),
                                                ),
                                              )
                                            : Icon(
                                                icon,
                                                color: AppColors.textPrimary,
                                                size: 14,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 24.0 : 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            channel.channelName,
                            style: TextStyle(
                              fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                              fontWeight: FontWeight.w700,
                              color: ytTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (channel.isVerified) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            color: ytTextSecondary,
                            size: isDesktop ? 24 : 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      final currentChannel =
                          controller.selectedChannel.value ?? channel;
                      final handle = currentChannel.handle.isNotEmpty
                          ? currentChannel.handle
                          : '@${currentChannel.channelName.toLowerCase().replaceAll(' ', '')}';
                      final count = controller.channelVideoCount.value > 0
                          ? controller.channelVideoCount.value
                          : currentChannel.videoCount;
                      return Text(
                        '$handle • ${controller.formattedSubscribers} subscribers • $count videos',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: ytTextSecondary,
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    _buildExpandableDescription(channel, isDesktop: isDesktop),
                    const SizedBox(height: 8),
                    if ((channel.socialLinks?.isNotEmpty ?? false) ||
                        channel.websiteUrl.isNotEmpty)
                      _buildChannelLinks(channel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubscribeRow(
            context,
            channel,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDescription(
    Channel channel, {
    bool isDesktop = false,
  }) {
    final text = channel.description.isEmpty
        ? 'No description available'
        : channel.description;
    final isLongText = text.length > 50 || text.contains('\n');

    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
      child: Obx(() {
        final isExpanded = controller.isDescriptionExpanded.value;

        return InkWell(
          onTap: isLongText
              ? () => controller.isDescriptionExpanded.toggle()
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClickableUrlText(
                text: text,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: ytTextSecondary),
              ),
              if (isLongText) ...[
                const SizedBox(height: 2),
                Text(
                  isExpanded ? '...less' : '...more',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ytTextPrimary,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildChannelLinks(Channel channel) {
    if (channel.websiteUrl.isEmpty) return const SizedBox.shrink();

    final uri = Uri.tryParse(channel.websiteUrl);
    final domain = uri?.host.replaceAll('www.', '') ?? channel.websiteUrl;

    return InkWell(
      onTap: () => _launchURL(channel.websiteUrl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            domain,
            style: const TextStyle(fontSize: 12, color: ytLinkBlue),
          ),
          if (channel.socialLinks?.isNotEmpty ?? false) ...[
            Text(
              ' and ${channel.socialLinks!.length} more links',
              style: const TextStyle(fontSize: 12, color: ytTextSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscribeRow(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Row(
      children: [
        Obx(() {
          final isSubscribed = controller.isSubscribed.value;
          final notificationsEnabled = controller.notificationsEnabled.value;
          final notificationOption = controller.notificationOption.value;
          return AnimatedSubscribeButton(
            isSubscribed: isSubscribed,
            notificationsEnabled: notificationsEnabled,
            notificationOption: notificationOption,
            onNotificationTap: () => _showNotificationsDialog(context, channel),
            onPressed: !AuthService.to.isAuthenticated.value
                ? () => AuthService.to.signInWithGoogle()
                : () async {
                    if (isSubscribed) {
                      _showNotificationsDialog(context, channel);
                    } else {
                      await controller.toggleSubscription(
                        channel.channelId,
                      );
                    }
                  },
          );
        }),
        const SizedBox(width: 8),
        // Join Channel Membership Button
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: ytSurfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ytTextPrimary.withValues(alpha: 0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ChannelMembershipJoinSheet.show(
                context,
                channelId: channel.channelId,
                channel: channel,
              ),
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      color: ytTextPrimary,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Join',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ytTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: ytSurfaceLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.shareChannel(channel.channelId),
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.share, color: ytTextPrimary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ytTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // YOUTUBE TAB BAR
  // ==========================================================================
  Widget _buildYouTubeTabBar(List<String> activeTabs) {
    return ColoredBox(
      color: ytBackground,
      child: TabBar(
        isScrollable: true,
        indicatorColor: ytTextPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: ytTextPrimary,
        unselectedLabelColor: ytTextSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: activeTabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  void _showUnsubscribeConfirmation(BuildContext context, Channel channel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: ytSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unsubscribe from ${channel.channelName}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: ytTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You will no longer see this channel's content in your feed.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ytTextSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: ytTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        controller.toggleSubscription(channel.channelId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ytTextPrimary,
                        foregroundColor: ytBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Unsubscribe',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB BUILDERS
  // ==========================================================================
  Widget _buildHomeTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return RefreshIndicator(
      onRefresh: () => controller.loadInitialVideos(),
      color: ytTextPrimary,
      backgroundColor: ytSurface,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('For you'),
              const SizedBox(height: 16),
              _buildFeaturedVideoCard(context, isDesktop: isDesktop),
              const SizedBox(height: 24),
              _buildSectionTitle('Recent uploads'),
              const SizedBox(height: 16),
              _buildVideoGrid(
                context,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              const SizedBox(height: 24),
              _buildPlaylistsSection(
                context,
                channel,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideosTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return RefreshIndicator(
      onRefresh: () => controller.loadInitialVideos(),
      color: ytTextPrimary,
      backgroundColor: ytSurface,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(context),
              const SizedBox(height: 16),
              _buildVideoGrid(
                context,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getPlaylistsStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerGrid(isDesktop: isDesktop, isTablet: isTablet);
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading playlists: ${snapshot.error}',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.playlist_play,
            title: 'No playlists yet',
            subtitle: "This channel hasn't created any playlists",
          );
        }

        final playlists = snapshot.data!.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .where((p) => p.thumbnailUrl.trim().isNotEmpty)
            .toList();

        if (playlists.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.playlist_play,
            title: 'No playlists yet',
            subtitle: "This channel hasn't created any playlists",
          );
        }

        return _buildPlaylistGrid(
          context,
          playlists,
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
      },
    );
  }

  Widget _buildTopicsTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSubscribed = controller.isSubscribed.value;
    final isOwner = currentUser != null && currentUser.uid == channel.ownerId;
    final isMobile = !isDesktop && !isTablet;

    return StreamBuilder<QuerySnapshot>(
      stream: controller.getTopicsStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHorizontalVideoSkeleton(isMobile);
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading topics: ${snapshot.error}',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.topic_outlined,
            title: 'No topics yet',
            subtitle: "This channel hasn't created any topics",
          );
        }

        final topics = snapshot.data!.docs
            .map(Topic.fromDocumentSnapshot)
            .where((topic) {
              if (!topic.isValidTopic || topic.videoCount <= 0) return false;
              if (isOwner) return true;
              if (topic.visibilityType == TopicVisibilityType.public) return true;
              if (topic.visibilityType == TopicVisibilityType.channelOnly && isSubscribed) return true;
              return false;
            })
            .toList();

        topics.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (topics.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.topic_outlined,
            title: 'No topics yet',
            subtitle: "This channel hasn't created any topics",
          );
        }

        for (final topic in topics) {
          controller.fetchVideosForChannelTopic(topic);
          controller.fetchPostsForChannelTopic(topic);
        }

        return Obx(() {
          final selected = controller.selectedChannelTopic.value;
          var displayTopics = topics;
          if (selected != null && topics.any((t) => t.id == selected.id)) {
            displayTopics = [selected];
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopicPills(topics),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayTopics.length,
                  itemBuilder: (context, index) {
                    final topic = displayTopics[index];
                    return _buildTopicVideoSection(
                      context,
                      topic,
                      isMobile: isMobile,
                      isTablet: isTablet,
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        });
      },
    );
  }

  void _navigateToTopicDetails(Topic topic) {
    Get.toNamed<void>(
      topic.topicRoute,
      arguments: {
        'slug': topic.slug,
        'fromCard': true,
        'topic': topic,
      },
    );
  }

  Widget _buildTopicPills(List<Topic> topics) {
    return Obx(() {
      final selected = controller.selectedChannelTopic.value;

      return Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: topics.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final isAllSelected = selected == null;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.selectChannelTopic(null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isAllSelected
                          ? AppColors.textPrimary
                          : const Color(0xFF272727),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All Topics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isAllSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isAllSelected
                            ? AppColors.bgPage
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final topic = topics[index - 1];
            final isSelected = selected?.id == topic.id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (isSelected) {
                    _navigateToTopicDetails(topic);
                  } else {
                    controller.selectChannelTopic(topic);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  constraints: const BoxConstraints(maxWidth: 240),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary
                        : const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.bgPage
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.bgPage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildTopicVideoSection(
    BuildContext context,
    Topic topic, {
    bool isMobile = false,
    bool isTablet = false,
  }) {
    final key = topic.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToTopicDetails(topic),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          topic.title,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: const Color(0xFF212121),
                onSelected: (value) {
                  if (value == 'view_topic') {
                    _navigateToTopicDetails(topic);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view_topic',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'View Topic Details',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Obx(() {
          final isLoading = controller.isLoadingVideosMap[key] ?? false;
          final videos = controller.topicVideosMap[key];

          if (isLoading && (videos == null || videos.isEmpty)) {
            return _buildHorizontalVideoSkeleton(isMobile);
          }

          if (videos == null || videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GestureDetector(
                onTap: () => _navigateToTopicDetails(topic),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.topic_rounded,
                        color: AppColors.textPrimary,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap to view topic details page',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final sectionHeight = isMobile ? 260.0 : (isTablet ? 290.0 : 310.0);
          final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);

          return SizedBox(
            height: sectionHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return _buildHorizontalVideoCard(
                  context,
                  topic,
                  video,
                  isMobile,
                  cardWidth,
                );
              },
            ),
          );
        }),

        Obx(() {
          final posts = controller.topicPostsMap[key];
          final isLoadingPosts = controller.isLoadingPostsMap[key] ?? false;

          if (isLoadingPosts && (posts == null || posts.isEmpty)) {
            return const SizedBox.shrink();
          }

          if (posts == null || posts.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.forum_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Community Posts',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: posts.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CommunityPostCard(post: posts[index]),
                  );
                },
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHorizontalVideoCard(
    BuildContext context,
    Topic topic,
    Video video,
    bool isMobile,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              MiniplayerNavigationHelper.navigateToVideoScreen(
                video: video,
                routeArguments: {
                  'video': video,
                  'heroTag': 'channel_topic_${topic.id}_${video.id}',
                },
              );
            },
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF272727),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: Color(0xFF272727),
                        child: Icon(
                          Icons.videocam_off_rounded,
                          color: AppColors.textTertiary,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => _navigateToTopicDetails(topic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.topic_rounded,
                            color: AppColors.textPrimary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            topic.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (video.isFactChecked)
                  Positioned(
                    top: 36,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.textPrimary,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => VideoOptionsSheet.show(context, video),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            video.channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${FormatUtils.formatCount(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalVideoSkeleton(bool isMobile) {
    final cardWidth = isMobile ? 280.0 : 320.0;
    return SizedBox(
      height: isMobile ? 260 : 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFF272727),
              highlightColor: const Color(0xFF3F3F3F),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 140,
                    height: 12,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 12,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSubscribed = controller.isSubscribed.value;
    final isOwner = currentUser != null && currentUser.uid == channel.ownerId;
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getCommunityStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerGrid(isDesktop: isDesktop, isTablet: isTablet);
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            'Error loading posts: ${snapshot.error}',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTabState(
            icon: Icons.chat_bubble_outline,
            title: 'Posts',
            subtitle: 'Community posts from this channel will appear here',
          );
        }

        final posts = snapshot.data!.docs
            .map(
              (doc) => CommunityPostModel.fromMap(
                doc.data()! as Map<String, dynamic>,
              ),
            )
            .where((post) {
              if (isOwner) return true;
              final vis = post.visibility.toLowerCase();
              if (vis == 'public') return true;
              if (vis == 'subscribers' && isSubscribed) return true;
              if (vis == 'members' && (isOwner || isSubscribed)) return true;
              return false;
            })
            .toList();

        // Sort posts by uploadedAt descending
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        final horizontalPadding = isDesktop ? 64.0 : (isTablet ? 32.0 : 12.0);
        final maxContentWidth = isDesktop
            ? 720.0
            : (isTablet ? 600.0 : double.infinity);

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return CommunityPostCard(
                  post: posts[index],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ytTextPrimary,
      ),
    );
  }

  Widget _buildFeaturedVideoCard(
    BuildContext context, {
    bool isDesktop = false,
  }) {
    return Obx(() {
      if (controller.videos.isEmpty) return const SizedBox.shrink();

      final video = controller.videos.first;
      return InkWell(
        onTap: () {
          MiniplayerNavigationHelper.navigateToVideoScreen(
            video: video,
            routeArguments: {'video': video},
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ytSurface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: ytSurfaceLight),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: ytTextSecondary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: ytTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatViews(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ytTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildVideoGrid(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Obx(() {
      if (controller.isLoadingVideos.value) {
        return _buildShimmerGrid(isDesktop: isDesktop, isTablet: isTablet);
      }

      if (controller.videos.isEmpty) {
        return _buildEmptyTabState(
          icon: Icons.videocam_off,
          title: 'No videos yet',
          subtitle: "This channel hasn't uploaded any videos",
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.videos.length,
        itemBuilder: (context, index) {
          final video = controller.videos[index];
          return _buildVideoListCard(context, video, isDesktop: isDesktop);
        },
      );
    });
  }

  Widget _buildVideoListCard(
    BuildContext context,
    Video video, {
    bool isDesktop = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          MiniplayerNavigationHelper.navigateToVideoScreen(
            video: video,
            routeArguments: {'video': video},
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: isDesktop ? 280 : 160,
                    height: (isDesktop ? 280 : 160) * 9 / 16,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: ytSurfaceLight),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: ytSurfaceLight,
                      child: Icon(
                        Icons.play_circle_outline,
                        color: ytTextSecondary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ytTextPrimary,
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatViews(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
                    style: const TextStyle(
                      color: ytTextSecondary,
                      fontSize: 12,
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

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['Latest', 'Popular', 'Oldest'];

    return Obx(
      () => Wrap(
        spacing: 8,
        children: filters.map((filter) {
          final isSelected = controller.videoSortFilter.value == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) controller.setVideoSortFilter(filter);
            },
            backgroundColor: ytSurface,
            selectedColor: ytTextPrimary,
            labelStyle: TextStyle(
              color: isSelected ? ytBackground : ytTextPrimary,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? ytTextPrimary : ytSurfaceLight,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlaylistsSection(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getPlaylistsStream(channel.channelId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final playlists = snapshot.data!.docs
            .take(5)
            .map(PlaylistModel.fromDocumentSnapshot)
            .where((p) => p.thumbnailUrl.trim().isNotEmpty)
            .toList();

        if (playlists.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Created playlists'),
            const SizedBox(height: 16),
            SizedBox(
              height: isDesktop ? 200 : (isTablet ? 180 : 160),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) => _buildPlaylistCard(
                  context,
                  playlists[index],
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context,
    PlaylistModel playlist, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Container(
      width: isDesktop ? 200 : (isTablet ? 180 : 160),
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          Get.toNamed('/playlist-detail', arguments: {'playlist': playlist});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: ytSurface,
                ),
                child: Stack(
                  children: [
                    _buildPlaylistThumbnailImage(playlist),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.bgPage.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 40,
                        color: AppColors.bgPage.withValues(alpha: 0.6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.playlist_play,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            Text(
                              '${playlist.videoIds.length}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.playlistName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            const Text(
              'View full playlist',
              style: TextStyle(fontSize: 12, color: ytTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistThumbnailImage(PlaylistModel playlist) {
    if (playlist.thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: playlist.thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (context, url, error) => _buildThumbnailFallback(),
        ),
      );
    } else if (playlist.videoIds.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(playlist.videoIds.first)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final videoThumb = data?['thumbnailUrl'] as String?;
            if (videoThumb != null && videoThumb.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: videoThumb,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) =>
                      _buildThumbnailFallback(),
                ),
              );
            }
          }
          return _buildThumbnailFallback();
        },
      );
    }
    return _buildThumbnailFallback();
  }

  Widget _buildThumbnailFallback() {
    return Container(
      decoration: BoxDecoration(
        color: ytSurfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.playlist_play_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(
    BuildContext context,
    List<PlaylistModel> playlists, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) => _buildPlaylistCard(
        context,
        playlists[index],
        isDesktop: isDesktop,
        isTablet: isTablet,
      ),
    );
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: ytTextTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: ytTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: ytTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid({bool isDesktop = false, bool isTablet = false}) {
    return Shimmer.fromColors(
      baseColor: ytSurface,
      highlightColor: ytSurfaceLight,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 280 : 160,
                height: (isDesktop ? 280 : 160) * 9 / 16,
                decoration: BoxDecoration(
                  color: ytSurfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, color: ytSurfaceLight),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: ytSurfaceLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSidebar(BuildContext context, Channel channel) {
    return ColoredBox(
      color: ytSurface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(Icons.analytics_outlined, color: ytTextPrimary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: ytTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: ytBorder, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Obx(() {
                final currentChannel =
                    controller.selectedChannel.value ?? channel;
                return Column(
                  children: [
                    _buildStatItem(
                      icon: Icons.people_outline,
                      label: 'Subscribers',
                      value: controller.formattedSubscribers,
                    ),
                    const SizedBox(height: 16),
                    _buildStatItem(
                      icon: Icons.video_library_outlined,
                      label: 'Videos',
                      value:
                          (controller.channelVideoCount.value > 0
                                  ? controller.channelVideoCount.value
                                  : currentChannel.videoCount)
                              .toString(),
                    ),
                    const SizedBox(height: 16),
                    _buildStatItem(
                      icon: Icons.visibility_outlined,
                      label: 'Views',
                      value: _formatViews(
                        currentChannel.viewCount > 0
                            ? currentChannel.viewCount
                            : (controller.videos.isNotEmpty
                                ? controller.videos.fold<int>(
                                    0,
                                    (sum, v) => sum + v.viewCount,
                                  )
                                : 0),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: ytTextSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: ytTextSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ytTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: ytTextSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: ytTextSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: ytTextPrimary,
              foregroundColor: ytBackground,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================
  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('Error', 'Could not launch $url');
    }
  }

  void _showNotificationsDialog(BuildContext context, Channel targetChannel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ytSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ytTextTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final option = controller.notificationOption.value;
              final isAll = option == 'all';
              final isPersonalized = option == 'personalized';
              final isNone =
                  option == 'none' || !controller.notificationsEnabled.value;

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      'All',
                      style: TextStyle(
                        color: isAll ? AppColors.brand : ytTextPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get all notifications",
                      style: TextStyle(fontSize: 12, color: ytTextSecondary),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateNotificationPreference(
                        targetChannel.channelId,
                        'all',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      'Personalized',
                      style: TextStyle(
                        color: isPersonalized ? AppColors.brand : ytTextPrimary,
                        fontWeight: isPersonalized
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get personalized notifications",
                      style: TextStyle(fontSize: 12, color: ytTextSecondary),
                    ),
                    trailing: isPersonalized
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateNotificationPreference(
                        targetChannel.channelId,
                        'personalized',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_off_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: isNone ? AppColors.brand : ytTextPrimary,
                        fontWeight: isNone
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off all notifications',
                      style: TextStyle(fontSize: 12, color: ytTextSecondary),
                    ),
                    trailing: isNone
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateNotificationPreference(
                        targetChannel.channelId,
                        'none',
                      );
                    },
                  ),
                  const Divider(color: ytBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.person_remove_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Unsubscribe',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showUnsubscribeConfirmation(context, targetChannel);
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

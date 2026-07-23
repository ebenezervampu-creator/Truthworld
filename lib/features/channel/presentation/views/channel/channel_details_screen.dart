import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
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
    Get.put(ChannelController());
    final args = Get.arguments;
    final Channel? targetChannel = channel ?? (args != null && args['channel'] is Channel ? args['channel'] : null);
    if (targetChannel == null) {
      return Scaffold(
        backgroundColor: ytBackground,
        body: _buildErrorState('Channel data is missing.', Get.back),
      );
    }

    controller.initForChannelDetails(targetChannel);
    controller.startPageAnimations();

    return AnimatedBuilder(
      animation: controller.pageFadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: controller.pageFadeAnimation,
          child: _buildChannelContent(context, targetChannel),
        );
      },
    );
  }

  Widget _buildChannelContent(BuildContext context, Channel channel) {
    return Obx(() {
      if (controller.selectedChannel.value == null) {
        return const Scaffold(
          backgroundColor: ytBackground,
          body: Center(child: CircularProgressIndicator(color: ytTextPrimary)),
        );
      }
      final channel = controller.selectedChannel.value;
      return _buildResponsiveLayout(context, channel!);
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
    return Obx(() {
      final activeTabs = controller.activeTabs;
      final tabCount = activeTabs.length;

      return DefaultTabController(
        key: ValueKey('tab-controller-${channel.channelId}-${activeTabs.join(",")}'),
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
    });
  }

  // ==========================================================================
  // BANNER
  // ==========================================================================
  Widget _buildBanner(
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final bannerHeight = isDesktop ? 200.0 : (isTablet ? 180.0 : 120.0);

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
                        child: Icon(Icons.image_not_supported, color: ytTextTertiary),
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
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        tooltip: 'Back',
                        onPressed: () {
                          if (isDashboard && Get.isRegistered<HomeController>()) {
                            Get.find<HomeController>().goBackFromSpecialPage(HomeController.indexDiscover);
                          } else {
                            Get.back();
                          }
                        },
                      ),
                    ),
                  ),
                Obx(() {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null || channel.ownerId != currentUser.uid) {
                    return const SizedBox.shrink();
                  }

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
                    text = "Banner Rejected: ${controller.detailsBannerReason.value.isNotEmpty ? controller.detailsBannerReason.value : 'Violated Community Guidelines'}";
                    icon = Icons.error_outline_rounded;
                  } else if (status == 'FLAGGED') {
                    overlayColor = AppColors.bgPage.withValues(alpha: 0.7);
                    badgeColor = const Color(0xFFF59E0B);
                    text = 'Banner Review Needed: ${controller.detailsBannerReason.value}';
                    icon = Icons.warning_amber_rounded;
                  }

                  return Positioned.fill(
                    child: Container(
                      color: overlayColor,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                                  ),
                                )
                              else
                                Icon(icon, color: AppColors.textPrimary, size: 18),
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
                }),
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
                        Obx(() {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null || channel.ownerId != currentUser.uid) {
                            return const SizedBox.shrink();
                          }

                          final status = controller.detailsAvatarStatus.value;
                          if (status.isEmpty || status == 'APPROVED') {
                            return const SizedBox.shrink();
                          }

                          var overlayColor = AppColors.bgPage54;
                          var badgeColor = const Color(0xFF3B82F6);
                          var icon = Icons.sync_rounded;
                          final isPending = status == 'PENDING';

                          if (status == 'REJECTED') {
                            overlayColor = AppColors.bgPage.withValues(alpha: 0.8);
                            badgeColor = const Color(0xFFEF4444);
                            icon = Icons.error_outline_rounded;
                          } else if (status == 'FLAGGED') {
                            overlayColor = AppColors.bgPage.withValues(alpha: 0.7);
                            badgeColor = const Color(0xFFF59E0B);
                            icon = Icons.warning_amber_rounded;
                          }

                          return Positioned.fill(
                            child: ColoredBox(
                              color: overlayColor,
                              child: Tooltip(
                                message: status == 'REJECTED'
                                    ? 'Avatar Rejected: ${controller.detailsAvatarReason.value}'
                                    : (status == 'FLAGGED' ? 'Review Needed: ${controller.detailsAvatarReason.value}' : 'Avatar Verification Pending'),
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
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                                            ),
                                          )
                                        : Icon(icon, color: AppColors.textPrimary, size: 14),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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
                      final handle = channel.handle.isNotEmpty
                          ? channel.handle
                          : '@${channel.channelName.toLowerCase().replaceAll(' ', '')}';
                      return Text(
                        '$handle • ${controller.formattedSubscribers} subscribers • ${channel.videoCount} videos',
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

    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: text,
              style: const TextStyle(fontSize: 12, color: ytTextSecondary),
            ),
            if (text.length > 80)
              const TextSpan(
                text: ' ...more',
                style: TextStyle(
                  fontSize: 12,
                  color: ytTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
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
          return AnimatedSubscribeButton(
            isSubscribed: isSubscribed,
            notificationsEnabled: notificationsEnabled,
            onPressed: FirebaseAuth.instance.currentUser == null
                ? () {}
                : () async {
                    if (isSubscribed) {
                      _showUnsubscribeConfirmation(context, channel);
                    } else {
                      await controller.toggleSubscription(
                        channel.channelId,
                      );
                    }
                  },
          );
        }),
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
      stream: FirebaseFirestore.instance
          .collection('public_playlists')
          .where('channelId', isEqualTo: channel.channelId)
          .snapshots(),
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
            .toList();

        return _buildPlaylistGrid(
          context,
          playlists,
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
      },
    );
  }

  Widget _buildPostsTab(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == channel.ownerId;
    final baseQuery = FirebaseFirestore.instance
        .collection('Community')
        .where('channelId', isEqualTo: channel.channelId);

    final query = isOwner
        ? baseQuery.where('ownerId', isEqualTo: currentUser.uid)
        : baseQuery.where('visibility', isEqualTo: 'Public');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
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
            .map((doc) => CommunityPostModel.fromMap(doc.data()! as Map<String, dynamic>))
            .toList();

        // Sort posts by uploadedAt descending
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
        final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

        return GridView.builder(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isDesktop ? 1.1 : (isTablet ? 1.0 : 1.2),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return CommunityPostCard(
              post: posts[index],
            );
          },
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
      stream: FirebaseFirestore.instance
          .collection('public_playlists')
          .where('channelId', isEqualTo: channel.channelId)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final playlists = snapshot.data!.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .toList();

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
          // Check if HomeController is available (we're in home screen context)
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.navigateToPlaylistDetail(playlist);
          } else {
            // Navigate to home first, then show playlist detail
            Get.toNamed('/', arguments: {'openPlaylist': playlist});
          }
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
                    if (playlist.thumbnailUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: playlist.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
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
              child: Column(
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
                    value: channel.videoCount.toString(),
                  ),
                  const SizedBox(height: 16),
                  _buildStatItem(
                    icon: Icons.visibility_outlined,
                    label: 'Views',
                    value: _formatViews(channel.viewCount),
                  ),
                ],
              ),
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

  void _showNotificationsDialog(BuildContext context) {
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
              'Notification settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ytTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final isAll = controller.notificationsEnabled.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: isAll ? AppColors.brand : ytTextPrimary,
                    ),
                    title: Text(
                      'All notifications',
                      style: TextStyle(
                        color: isAll ? AppColors.brand : ytTextPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isAll ? const Icon(Icons.check, color: AppColors.brand) : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateNotificationPreference(channel!.channelId, true);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off,
                      color: !isAll ? AppColors.brand : ytTextPrimary,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: !isAll ? AppColors.brand : ytTextPrimary,
                        fontWeight: !isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: !isAll ? const Icon(Icons.check, color: AppColors.brand) : null,
                    onTap: () {
                      Navigator.pop(context);
                      controller.updateNotificationPreference(channel!.channelId, false);
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






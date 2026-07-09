import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/components/ui/user_avatar.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS
// ==========================================================================

final Color bgColor = Colors.black;
final Color surfaceColor = AppColors.bgPage;
final Color cardColor = Color(0xFF1E1E1E);
final Color primaryText = Colors.white;
final Color secondaryText = AppColors.textSecondary;
final Color accentColor = Colors.white;
final Color buttonBg = AppColors.bgSurfaceHover;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1000.0;
const double kDesktopBreakpoint = 1200.0;

// ==========================================================================
// MODERNIZED LIBRARY SCREEN
// ==========================================================================

class LibraryScreen extends StatefulWidget {
  final bool isDashboard;
  const LibraryScreen({super.key, this.isDashboard = false});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  final int previewItemCount = 4;
  final _playlistController = Get.find<PlaylistController>();
  final _watchHistoryController = Get.put(WatchHistoryController());

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Start animations
    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildResponsiveLayout(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final bool isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        // final bool isMobile = constraints.maxWidth < kMobileBreakpoint; // isMobile is the else case

        if (isDesktop) {
          return _buildDesktopLayout(context);
        } else if (isTablet) {
          return _buildTabletLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context, isDesktop: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // Main Content
          Expanded(
            flex: 7,
            child: _buildMainContent(context, userId, isDesktop: true),
          ),
          // Sidebar with Quick Actions
          if (!widget.isDashboard)
            Expanded(flex: 3, child: _buildSidebar(context, userId)),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context, isTablet: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: !widget.isDashboard ? _buildModernAppBar(context, isTablet: true) : null,
      body: _buildMainContent(context, userId, isTablet: true),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: _buildMainContent(context, userId),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isTablet = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.video_library_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Text(
            "Your Library",
            style: GoogleFonts.roboto(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.search_rounded,
          onPressed: () => _showSearchDialog(context),
          tooltip: 'Search Library',
        ),
        _buildAppBarAction(
          icon: Icons.more_vert_rounded,
          onPressed: () => _showMoreOptions(context),
          tooltip: 'More Options',
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Material(
        color: buttonBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(10),
            child: Icon(icon, color: secondaryText, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedState(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(isDesktop ? 40 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUnauthenticatedIcon(),
              SizedBox(height: 32),
              _buildUnauthenticatedTitle(),
              SizedBox(height: 16),
              _buildUnauthenticatedSubtitle(),
              SizedBox(height: 40),
              _buildSignInButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedIcon() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline_rounded,
                color: primaryText,
                size: 60,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedTitle() {
    return Text(
      "Access Your Personal Video Library",
      textAlign: TextAlign.center,
      style: GoogleFonts.roboto(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryText,
      ),
    );
  }

  Widget _buildUnauthenticatedSubtitle() {
    return Text(
      "Sign in to view your saved videos, watch history, and custom playlists. Your content is waiting!",
      textAlign: TextAlign.center,
      style: GoogleFonts.roboto(fontSize: 16, color: secondaryText),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        Get.toNamed('/auth');
      },
      icon: Icon(Icons.login_rounded, color: Colors.black),
      label: Text(
        "Sign In to Continue",
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    String userId, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Profile Header
          SliverToBoxAdapter(
            child: _buildProfileHeader(userId),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 2. History Section
                _buildHistorySection(userId),
                const SizedBox(height: 24),
                // 3. Playlists Section
                _buildPlaylistsSection(userId),
                const SizedBox(height: 24),

                // Following Topics Section
                _buildFollowingTopicsSection(userId),
                const SizedBox(height: 24),
                // 4. Liked Videos Section
                _buildLikedVideosSection(userId),
                const SizedBox(height: 24),

                // 5. Clips Section
                _buildClipsSection(userId),
                const SizedBox(height: 24),

                // 6. Your Videos Section
                _buildYourVideosSection(userId),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String userId) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? "User";
    final email = user?.email ?? "";
    final handle = email.isNotEmpty ? "@${email.split('@')[0]}" : "@user";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                radius: 40,
                photoUrl: user?.photoURL,
                displayName: displayName,
                backgroundColor: buttonBg,
                textColor: primaryText,
                fontSize: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          handle,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            // Navigate to channel
                          },
                          child: Text(
                            "View channel",
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: secondaryText,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildHeaderButton(
                icon: Icons.account_circle_outlined,
                label: "Switch account",
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: Icons.account_box_outlined,
                label: "Google Account",
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: primaryText),
        label: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: primaryText,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: buttonBg,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }


  Widget _buildSectionHeader({
    required String title,
    VoidCallback? onViewAll,
    VoidCallback? onAdd,
    bool showArrows = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const Spacer(),
          if (onAdd != null)
            IconButton(
              icon: Icon(Icons.add, color: primaryText),
              onPressed: onAdd,
            ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Text(
                "View all",
                style: GoogleFonts.roboto(
                  color: primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (showArrows) ...[
            const SizedBox(width: 8),
            // Mock arrows for design fidelity
            const Icon(Icons.chevron_left, color: Colors.white24, size: 24),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "History",
          onViewAll: () => Get.toNamed('/watchhistory'),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('watch_history')
              .orderBy('watchedAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Videos you watch will show up here.",
                  style: GoogleFonts.roboto(color: secondaryText, fontSize: 14),
                ),
              );
            }
            final videos = snapshot.data!.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();
            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return _buildYouTubeVideoCard(videos[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYouTubeVideoCard(Video video) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => Get.toNamed('/watch?v=${video.id}', arguments: {'video': video}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    height: 90,
                    width: 160,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: buttonBg),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${video.channelName} • ${video.views} views",
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Playlists",
          onAdd: () => _showCreatePlaylistDialog(context),
          onViewAll: () => Get.toNamed('/playlistscreen'),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('playlists')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final playlists = snapshot.data!.docs
                .map((doc) => PlaylistModel.fromDocumentSnapshot(doc))
                .toList();

            return SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  return _buildYouTubePlaylistCard(playlists[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYouTubePlaylistCard(PlaylistModel playlist) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
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
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 110,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  width: 125,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: playlist.thumbnailUrl,
                    height: 80,
                    width: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: buttonBg),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.playlist_play, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "${playlist.videoIds.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playlist.playlistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Playlist",
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingTopicsSection(String userId) {
    if (!Get.isRegistered<FollowingTopicsController>()) {
      Get.put(FollowingTopicsController());
    }
    final controller = Get.find<FollowingTopicsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Following Topics",
          onViewAll: () {
            if (Get.isRegistered<HomeController>()) {
              final homeController = Get.find<HomeController>();
              homeController.sideNavSelectedIndex.value = HomeController.indexFollowingTopics;
            } else {
              Get.toNamed('/following-topics');
            }
          },
          showArrows: true,
        ),
        Obx(() {
          if (controller.isLoading.value) {
            return SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: primaryText),
              ),
            );
          }
          if (controller.followedTopics.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Topics you follow will show up here.",
                style: GoogleFonts.roboto(color: secondaryText, fontSize: 14),
              ),
            );
          }
          return SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.followedTopics.length,
              itemBuilder: (context, index) {
                final topic = controller.followedTopics[index];
                return _buildLibraryTopicCard(topic);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLibraryTopicCard(Topic topic) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () {
          Get.toNamed(
            topic.topicRoute,
            arguments: {
              'slug': topic.slug,
              'topic': topic,
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: topic.coverImage ?? topic.thumbnailUrl ?? 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop',
                    height: 80,
                    width: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: buttonBg),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "${topic.followerCount}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Topic • ${topic.videoCount} videos",
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedVideosSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Liked videos",
          onViewAll: () => Get.toNamed('/likedvideos'),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('videos')
              .where("likedBy", arrayContains: userId)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final videos = snapshot.data!.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();
            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return _buildYouTubeVideoCard(videos[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClipsSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Clips",
          onViewAll: () {},
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('clips')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "No clips yet.",
                  style: GoogleFonts.roboto(color: secondaryText, fontSize: 14),
                ),
              );
            }
            final clips = snapshot.data!.docs
                .map((doc) => VideoClip.fromDocumentSnapshot(doc))
                .toList();
            return SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: clips.length,
                itemBuilder: (context, index) {
                  return _buildClipCard(clips[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClipCard(VideoClip clip) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          final videoShell = Video(
            id: clip.videoId,
            title: clip.videoTitle,
            thumbnailUrl: clip.thumbnailUrl,
            channelName: clip.channelName,
            ownerId: clip.userId, // Use clip.userId as ownerId
            category: 'Clips',
            tags: [],
            description: 'Clip from ${clip.videoTitle}',
            views: '0',
            likes: 0,
            uploadedAt: Timestamp.fromDate(clip.createdAt),
            videoUrl: '',
            channelId: '',
            channelImage: '',
            duration: '0:00',
          );
          Get.toNamed('/watch?v=${videoShell.id}', arguments: {
            'video': videoShell,
            'clip': clip,
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: clip.thumbnailUrl,
                    height: 180,
                    width: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: buttonBg),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.content_cut_rounded, color: Colors.white, size: 14),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(clip.endTime - clip.startTime).toStringAsFixed(0)}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              clip.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              clip.videoTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourVideosSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Your videos",
          onViewAll: () => Get.toNamed('/myvideos'),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('videos')
              .where('ownerId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "You haven't uploaded any videos yet.",
                  style: GoogleFonts.roboto(color: secondaryText, fontSize: 14),
                ),
              );
            }
            final videos = snapshot.data!.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();
            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return _buildYouTubeVideoCard(videos[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }



  // Dialog Methods (Preserved and enhanced)
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Search Library',
          style: GoogleFonts.roboto(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          style: GoogleFonts.roboto(color: primaryText),
          decoration: InputDecoration(
            hintText: 'Search videos, playlists...',
            hintStyle: GoogleFonts.roboto(color: secondaryText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: buttonBg),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: Text('Search', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Playlist',
          style: GoogleFonts.roboto(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.roboto(color: primaryText),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.roboto(color: secondaryText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: buttonBg),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _playlistController.createPlayList(controller.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryText,
              foregroundColor: bgColor,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            _buildMoreOption(
              icon: Icons.settings_rounded,
              title: 'Library Settings',
              onTap: () => Navigator.pop(context),
            ),
            _buildMoreOption(
              icon: Icons.download_rounded,
              title: 'Downloads',
              onTap: () => Navigator.pop(context),
            ),
            _buildMoreOption(
              icon: Icons.history_rounded,
              title: 'Clear All History',
              onTap: () {
                Navigator.pop(context);
                _showClearHistoryDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: secondaryText),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear History',
          style: GoogleFonts.roboto(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to clear your watch history? This action cannot be undone.',
          style: GoogleFonts.roboto(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _watchHistoryController.clearAllHistory();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 32),
          _buildSidebarSearch(),
          const SizedBox(height: 40),
          _buildSidebarQuickActions(),
          const SizedBox(height: 40),
          Expanded(child: _buildSidebarPlaylists(userId)),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        UserAvatar(
          radius: 24,
          photoUrl: user?.photoURL,
          displayName: user?.displayName ?? "User",
          backgroundColor: buttonBg,
          textColor: Colors.white,
          fontSize: 18,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? "User",
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Text(
                user?.email ?? "",
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        style: GoogleFonts.roboto(color: primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search in library...",
          hintStyle: GoogleFonts.roboto(color: secondaryText),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: secondaryText, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSidebarQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildSidebarAction(
          icon: Icons.add_box_rounded,
          title: "New Playlist",
          onTap: () => _showCreatePlaylistDialog(context),
        ),
        _buildSidebarAction(
          icon: Icons.history_rounded,
          title: "Watch History",
          onTap: () => Get.toNamed('/watchhistory'),
        ),
        _buildSidebarAction(
          icon: Icons.video_library_rounded,
          title: "My Videos",
          onTap: () => Get.toNamed('/myvideos'),
        ),
        _buildSidebarAction(
          icon: Icons.thumb_up_rounded,
          title: "Liked Videos",
          onTap: () => Get.toNamed('/likedvideos'),
        ),
        _buildSidebarAction(
          icon: Icons.settings_rounded,
          title: "Settings",
          onTap: () => Get.toNamed('/settings'),
        ),
      ],
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: primaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarPlaylists(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PLAYLISTS",
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('playlists')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  "No playlists yet",
                  style: GoogleFonts.roboto(color: secondaryText, fontSize: 13),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final playlist = PlaylistModel.fromDocumentSnapshot(docs[index]);
                  return _buildSidebarPlaylistTile(playlist);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarPlaylistTile(PlaylistModel playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(6),
          image: playlist.thumbnailUrl.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(playlist.thumbnailUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {},
                )
              : null,
        ),
        child: playlist.thumbnailUrl.isEmpty
            ? const Icon(Icons.playlist_play, color: Colors.white, size: 16)
            : null,
      ),
      title: Text(
        playlist.playlistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.roboto(
          fontSize: 14,
          color: primaryText,
        ),
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}







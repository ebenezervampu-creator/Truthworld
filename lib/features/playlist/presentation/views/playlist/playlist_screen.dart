import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/playlist_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

const kPrimaryDark = AppColors.brand;
const kSecondaryDark = AppColors.brandVariant;
const kBorderRadius = 16.0;
const kSmallPadding = 8.0;
const kMediumPadding = 16.0;
const kLargePadding = 24.0;
const kDarkBackground = AppColors.bgPage;
const kDarkSurface = AppColors.bgSurface;
const kDarksurfaceContainerHighest = AppColors.bgSurfaceHover;

// ==========================================================================
// REGENERATED MODERN PLAYLIST SCREEN UI
// ==========================================================================

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    this.videoId,
    this.videoThumbnail,
    this.videoTitle,
    this.isDashboard = false,
  });
  final String? videoId;
  final String? videoThumbnail;
  final String? videoTitle;

  final bool isDashboard;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with TickerProviderStateMixin {
  final TextEditingController playListNameController = TextEditingController();
  final PlaylistController _playlistController = Get.find<PlaylistController>();
  final TextEditingController _searchController = TextEditingController();
  final RxString _selectedPlaylistType = 'private'.obs;

  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start animations
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fabAnimationController.forward();
    });
    _searchController.addListener(() {
      _playlistController.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    playListNameController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlaylists() async {
    _playlistController.refreshPlaylistsTick();
    await Future.delayed(const Duration(seconds: 1));
  }

  void _toggleView() => _playlistController.toggleView();
  void _setSortBy(String sortBy) => _playlistController.setSortBy(sortBy);

  void showCreatePlaylistModal() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Initialize selected videos in controller
    _playlistController.selectedVideoIds.clear();
    if (widget.videoId != null) {
      _playlistController.selectedVideoIds.add(widget.videoId!);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        return Obx(
          () {
            final isPublic = _selectedPlaylistType.value == 'public';

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kDarkBackground, Color(0xFF000000)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  minHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: isTablet ? 32 : 24,
                  right: isTablet ? 32 : 24,
                  top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modern drag handle with improved design
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Header with better typography
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                kPrimaryDark.withValues(alpha: 0.2),
                                kSecondaryDark.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: kPrimaryDark.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: kPrimaryDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Playlist',
                                style: GoogleFonts.roboto(
                                  fontSize: isTablet ? 26 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Organize your videos into collections',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Enhanced playlist name input
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: playListNameController,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Playlist Name',
                          labelStyle: GoogleFonts.roboto(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                          hintText: 'Enter a descriptive name...',
                          hintStyle: GoogleFonts.roboto(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.title_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: kPrimaryDark,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: kDarksurfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Modern section header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), kPrimaryDark],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Select Videos',
                          style: GoogleFonts.roboto(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: kPrimaryDark.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${_playlistController.selectedVideoIds.length} selected',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kPrimaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Enhanced video list with modern cards
                    Flexible(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(FirestoreCollections.videos)
                            .where(
                              'ownerId',
                              isEqualTo:
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                            )
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: kPrimaryDark.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const CircularProgressIndicator(
                                      color: kPrimaryDark,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading your videos...',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: kDarkSurface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.video_library_outlined,
                                          size: 48,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No videos yet',
                                          style: GoogleFonts.roboto(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Upload some videos first to add them to playlists',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.roboto(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final videos = snapshot.data!.docs
                              .map(Video.fromDocumentSnapshot)
                              .toList();

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: videos.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final video = videos[index];
                              final isSelected = _playlistController
                                  .selectedVideoIds
                                  .contains(
                                    video.id,
                                  );

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    key: ValueKey(video.id),
                                    onTap: () {
                                      _playlistController.toggleVideoSelection(
                                        video.id,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [
                                                  kPrimaryDark.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  kPrimaryDark.withValues(
                                                    alpha: 0.05,
                                                  ),
                                                ],
                                              )
                                            : null,
                                        color: !isSelected
                                            ? kDarksurfaceContainerHighest
                                            : null,
                                        border: Border.all(
                                          color: isSelected
                                              ? kPrimaryDark
                                              : Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: kPrimaryDark
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Enhanced thumbnail with selection indicator
                                          Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: CachedNetworkImage(
                                                  imageUrl: video.thumbnailUrl,
                                                  width: isTablet ? 140 : 120,
                                                  height: isTablet ? 80 : 70,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                        width: isTablet
                                                            ? 140
                                                            : 120,
                                                        height: isTablet
                                                            ? 80
                                                            : 70,
                                                        decoration: BoxDecoration(
                                                          color: kPrimaryDark,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.image_outlined,
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? kPrimaryDark
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: isSelected
                                                        ? null
                                                        : Border.all(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            width: 1.5,
                                                          ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    isSelected
                                                        ? Icons.check_rounded
                                                        : Icons.add_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),

                                          // Enhanced content with better typography
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  video.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.roboto(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: isTablet
                                                        ? 16
                                                        : 14,
                                                    color: Colors.white,
                                                    letterSpacing: -0.2,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.tv_rounded,
                                                      size: 14,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        video.channelName,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.roboto(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.visibility_outlined,
                                                      size: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${video.views} views',
                                                      style: GoogleFonts.roboto(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.schedule_outlined,
                                                      size: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        _formatDate(
                                                          video.uploadedAt
                                                              .toDate(),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.roboto(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Modern create button with enhanced design
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE50914), kPrimaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryDark.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 20 : 18,
                            horizontal: 24,
                          ),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'CREATE PLAYLIST',
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w700,
                            fontSize: isTablet ? 17 : 16,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () {
                          if (playListNameController.text.trim().isEmpty) {
                            Get.snackbar(
                              'Missing Information',
                              'Please enter a playlist name',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: const Color(0xFFEF4444),
                              colorText: Colors.white,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                              icon: const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                            );
                            return;
                          }

                          _playlistController.createPlayList(
                            playListNameController.text.trim(),
                            isPublic: isPublic,
                            videoIds: _playlistController.selectedVideoIds
                                .toList(),
                          );

                          playListNameController.clear();
                          Navigator.pop(context);

                          // Success feedback
                          Get.snackbar(
                            'Success',
                            'Playlist created successfully!',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: kPrimaryDark,
                            colorText: Colors.white,
                            borderRadius: 12,
                            margin: const EdgeInsets.all(16),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to format dates nicely
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildTypeSelectionCards() {
    return Obx(() {
      final selected = _selectedPlaylistType.value;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Playlist Type',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildSelectionCard(
              type: 'private',
              isSelected: selected == 'private',
              icon: Icons.lock_outline_rounded,
              title: 'Private Playlists',
              subtitle: 'Personal saved playlists & private videos',
              onTap: () => _selectedPlaylistType.value = 'private',
            ),
            const SizedBox(height: 12),
            _buildSelectionCard(
              type: 'public',
              isSelected: selected == 'public',
              icon: Icons.public_rounded,
              title: 'Public Playlists',
              subtitle: 'Public playlists hosted on your channel',
              onTap: () => _selectedPlaylistType.value = 'public',
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSelectionCard({
    required String type,
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.searchBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.2)
                    : AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.brand : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.brand : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isSelected ? AppColors.brand : AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCreator = AuthService.to.hasChannel.value;
      final refreshTick = _playlistController.refreshTick.value;

      final colorScheme = Theme.of(context).colorScheme;
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1200;
      final isDesktop = screenWidth >= 1200;

      final isPublic = isCreator && _selectedPlaylistType.value == 'public';

      return Scaffold(
        backgroundColor: kDarkBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Modern Header matching MyVideos (AppBar kept 100% intact)
            SliverToBoxAdapter(
              child: _buildHeader(isMobile),
            ),
            // Option cards for channel users (First image uploaded)
            if (isCreator)
              SliverToBoxAdapter(
                child: _buildTypeSelectionCards(),
              ),

            // Playlists Grid content (No tabs, no random category chips)
            SliverFillRemaining(
              child: RefreshIndicator(
                key: ValueKey(refreshTick),
                color: kPrimaryDark,
                backgroundColor: colorScheme.surface,
                onRefresh: _refreshPlaylists,
                child: _buildPlaylistsTab(
                  isPublic: isPublic,
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: kDarksurfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sort Playlists',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSortOption(
                      'index',
                      'Custom Order',
                      Icons.format_list_numbered_rounded,
                    ),
                    _buildSortOption(
                      'recent',
                      'Recent',
                      Icons.access_time_rounded,
                    ),
                    _buildSortOption(
                      'name',
                      'Name',
                      Icons.sort_by_alpha_rounded,
                    ),
                    _buildSortOption(
                      'videos',
                      'Videos',
                      Icons.video_library_rounded,
                    ),
                    _buildSortOption(
                      'created',
                      'Created',
                      Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _playlistController.sortBy.value == value;

    return InkWell(
      onTap: () {
        _setSortBy(value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? kPrimaryDark.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: kPrimaryDark) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? kPrimaryDark
                  : Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: isSelected ? kPrimaryDark : Colors.white,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                _playlistController.isAscending.value
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: kPrimaryDark,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isDropdown = false}) {
    return Obx(() {
      final isSelected = _playlistController.selectedCategory.value == label;
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => _playlistController.setCategory(label),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (isDropdown) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isSelected ? Colors.black : Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPlaylistsTab({
    required bool isPublic,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return Obx(() {
      final isLoaded = isPublic
          ? (_playlistController.user.isEmpty ||
                _playlistController.isPublicPlaylistsLoaded.value)
          : (_playlistController.user.isEmpty ||
                _playlistController.isPlaylistsLoaded.value);

      if (!isLoaded) {
        return _buildLoadingState(isMobile, isTablet, isDesktop);
      }

      final sourcePlaylists = isPublic
          ? _playlistController.publicPlaylists
          : _playlistController.playlists;

      if (sourcePlaylists.isEmpty) {
        return _buildEmptyStateWidget(context, isPublic);
      }

      // Copy list to avoid mutating the controller's reactive list on sort
      var playlists = sourcePlaylists
          .where((p) => p.thumbnailUrl.trim().isNotEmpty)
          .toList();

      // Apply search filter
      if (_playlistController.searchQuery.value.isNotEmpty) {
        playlists = playlists.where((playlist) {
          return playlist.playlistName.toLowerCase().contains(
            _playlistController.searchQuery.value.toLowerCase(),
          );
        }).toList();
      }

      // Apply sorting
      playlists = _sortPlaylists(playlists);

      if (playlists.isEmpty) {
        return _buildNoResultsWidget();
      }

      return _buildPlaylistGrid(playlists, isMobile, isTablet, isDesktop);
    });
  }

  Widget _buildLoadingState(bool isMobile, bool isTablet, bool isDesktop) {
    final crossAxisCount = isMobile
        ? 1
        : isTablet
        ? 2
        : 3;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: _playlistController.isListView.value || isMobile
          ? ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => _buildShimmerCard(isGrid: false),
            )
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => _buildShimmerCard(isGrid: true),
            ),
    );
  }

  Widget _buildShimmerCard({required bool isGrid}) {
    return Shimmer.fromColors(
      baseColor: kDarksurfaceContainerHighest,
      highlightColor: kDarkSurface,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isGrid
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: kDarksurfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: kDarksurfaceContainerHighest,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    color: kDarksurfaceContainerHighest,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: kDarksurfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          color: kDarksurfaceContainerHighest,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          color: kDarksurfaceContainerHighest,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 80,
                          color: kDarksurfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyStateWidget(BuildContext context, bool isPublic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryDark.withValues(alpha: 0.25),
                    kSecondaryDark.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                isPublic
                    ? Icons.public_off_rounded
                    : Icons.playlist_add_rounded,
                size: 60,
                color: kPrimaryDark,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPublic ? 'No public playlists' : 'No playlists yet',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPublic
                  ? 'Discover playlists shared by other creators'
                  : 'Create your first playlist to organize your favorite videos',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kDarksurfaceContainerHighest,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No playlists found',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(
    List<PlaylistModel> playlists,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final crossAxisCount = isMobile
        ? 2
        : isTablet
        ? 3
        : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 0.82 : 0.92,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return PlaylistCard(
          playlist: playlist,
          onTap: () {
            Get.toNamed('/playlist-detail', arguments: {'playlist': playlist});
          },
          onOptionsTap: () {
            _showPlaylistOptionsFor(context, playlist);
          },
        );
      },
    );
  }

  void _showPlaylistOptionsFor(BuildContext context, PlaylistModel playlist) {
    final playlistController = Get.find();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.playlistName,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildOptionItem(
                      icon: Icons.share_rounded,
                      title: 'Share Playlist',
                      onTap: () {
                        Navigator.pop(context);
                        playlistController.sharePlaylist(playlist.id);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Playlist',
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        playlistController.deletePlaylist(
                          playlist.id,
                          playlist.isPublic,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<PlaylistModel> _sortPlaylists(List<PlaylistModel> playlists) {
    switch (_playlistController.sortBy.value) {
      case 'index':
        playlists.sort(
          (a, b) => _playlistController.isAscending.value
              ? a.sortIndex.compareTo(b.sortIndex)
              : b.sortIndex.compareTo(a.sortIndex),
        );
      case 'name':
        playlists.sort(
          (a, b) => _playlistController.isAscending.value
              ? a.playlistName.compareTo(b.playlistName)
              : b.playlistName.compareTo(a.playlistName),
        );
      case 'videos':
        playlists.sort(
          (a, b) => _playlistController.isAscending.value
              ? a.videoIds.length.compareTo(b.videoIds.length)
              : b.videoIds.length.compareTo(a.videoIds.length),
        );
      case 'created':
        playlists.sort(
          (a, b) => _playlistController.isAscending.value
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
      case 'recent':
      default:
        playlists.sort(
          (a, b) => _playlistController.isAscending.value
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
    }
    return playlists;
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => _playlistController.isSearchExpanded.value
                ? Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: kDarkSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _playlistController.updateSearchQuery,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search playlists...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: () {
                              _playlistController.isSearchExpanded.value =
                                  false;
                              _searchController.clear();
                              _playlistController.updateSearchQuery('');
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (widget.isDashboard) {
                            Get.find<HomeController>()
                                    .sideNavSelectedIndex
                                    .value =
                                HomeController.indexLibrary;
                          } else {
                            Get.back();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Playlists',
                        style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              Obx(
                () => !_playlistController.isSearchExpanded.value
                    ? IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            _playlistController.isSearchExpanded.value = true,
                      )
                    : const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: showCreatePlaylistModal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('Recently added', isDropdown: true),
          ..._playlistController.categories.map(_buildFilterChip),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : Colors.white,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.roboto(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: kDarkBackground,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Enhanced Playlist Item Widget
class EnhancedPlaylistItem extends StatefulWidget {
  const EnhancedPlaylistItem({
    required this.playlist,
    required this.index,
    required this.isGridView,
    super.key,
    this.videoId,
  });
  final PlaylistModel playlist;
  final String? videoId;
  final int index;
  final bool isGridView;

  @override
  State<EnhancedPlaylistItem> createState() => _EnhancedPlaylistItemState();
}

class _EnhancedPlaylistItemState extends State<EnhancedPlaylistItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  final RxBool _isHovered = false.obs;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(
      begin: 1,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme.copyWith(
      surface: kDarkSurface,
      surfaceContainerHighest: kDarksurfaceContainerHighest,
    );

    return MouseRegion(
      onEnter: (_) {
        _isHovered.value = true;
        _hoverController.forward();
      },
      onExit: (_) {
        _isHovered.value = false;
        _hoverController.reverse();
      },
      child: ScaleTransition(
        scale: _hoverAnimation,
        child: Obx(
          () => Container(
            margin: EdgeInsets.only(bottom: widget.isGridView ? 0 : 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isHovered.value ? 0.15 : 0.08,
                  ),
                  blurRadius: _isHovered.value ? 20 : 10,
                  offset: Offset(0, _isHovered.value ? 8 : 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                final firstVideoId = widget.playlist.videoIds.isNotEmpty
                    ? widget.playlist.videoIds.first
                    : '';
                Get.toNamed(
                  '/watch?v=$firstVideoId',
                  arguments: {'playlist': widget.playlist},
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: widget.isGridView
                    ? _buildGridContent(colorScheme)
                    : _buildListContent(colorScheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModerationStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'active':
        return const SizedBox.shrink();
      case 'verificationRejected':
        color = Colors.redAccent;
        icon = Icons.error_outline_rounded;
        label = 'Rejected';
      case 'underReview':
      default:
        color = Colors.amber;
        icon = Icons.hourglass_empty_rounded;
        label = 'Under Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(ColorScheme colorScheme) {
    final status = widget.playlist.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked Thumbnail Effect
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: StackedThumbnail(
                  thumbnailUrl: widget.playlist.thumbnailUrl,
                  videoCount: widget.playlist.videoCount,
                  isPodcast: widget.playlist.playlistName
                      .toLowerCase()
                      .contains('podcast'),
                ),
              ),
              if (status != 'active')
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildModerationStatusBadge(status),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Playlist metadata
        Text(
          widget.playlist.playlistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${widget.playlist.isPublic ? 'Public' : 'Private'} • ${widget.playlist.playlistName.toLowerCase().contains('podcast') ? 'Podcast' : 'Playlist'}",
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Updated today', // Mocked as per image, can be real date
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            final firstVideoId = widget.playlist.videoIds.isNotEmpty
                ? widget.playlist.videoIds.first
                : '';
            Get.toNamed(
              '/watch?v=$firstVideoId',
              arguments: {'playlist': widget.playlist},
            );
          },
          child: Text(
            "View full ${widget.playlist.playlistName.toLowerCase().contains('podcast') ? 'podcast' : 'playlist'}",
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(ColorScheme colorScheme) {
    final status = widget.playlist.status;
    return Row(
      children: [
        // Playlist thumbnail
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kPrimaryDark.withValues(alpha: 0.8),
                kSecondaryDark.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: CachedNetworkImageProvider(widget.playlist.thumbnailUrl),
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {},
            ),
          ),
          child: Stack(
            children: [
              // Dark overlay for better text contrast
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.playlist_play_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.playlist.videoCount}',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Privacy indicator
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.playlist.isPublic
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Playlist info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.playlist.playlistName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${widget.playlist.videoCount} videos',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (status != 'active') ...[
                    const SizedBox(width: 8),
                    _buildModerationStatusBadge(status),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              /*Text(
                _formatDate(widget.playlist.createdAt),
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),*/
            ],
          ),
        ),

        // More options
        IconButton(
          icon: Icon(
            Icons.more_vert_rounded,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          onPressed: () => _showPlaylistOptions(context),
        ),
      ],
    );
  }

  void _showPlaylistOptions(BuildContext context) {
    final playlistController = Get.find();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.playlistName,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.playlist.status != 'active') ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              (widget.playlist.status == 'verificationRejected'
                                      ? Colors.redAccent
                                      : Colors.amber)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (widget.playlist.status ==
                                            'verificationRejected'
                                        ? Colors.redAccent
                                        : Colors.amber)
                                    .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  widget.playlist.status ==
                                          'verificationRejected'
                                      ? Icons.error_outline_rounded
                                      : Icons.hourglass_empty_rounded,
                                  color:
                                      widget.playlist.status ==
                                          'verificationRejected'
                                      ? Colors.redAccent
                                      : Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.playlist.status ==
                                          'verificationRejected'
                                      ? 'REJECTED'
                                      : 'UNDER REVIEW',
                                  style: GoogleFonts.roboto(
                                    color:
                                        widget.playlist.status ==
                                            'verificationRejected'
                                        ? Colors.redAccent
                                        : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.playlist.moderationReason != null &&
                                widget
                                    .playlist
                                    .moderationReason!
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.playlist.moderationReason!,
                                style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    _buildOptionItem(
                      icon: Icons.edit_rounded,
                      title: 'Edit Playlist',
                      onTap: () {
                        Navigator.pop(context);
                        _showEditPlaylistDialog(context);
                      },
                    ),
                    _buildOptionItem(
                      icon: Icons.share_rounded,
                      title: 'Share Playlist',
                      onTap: () {
                        Navigator.pop(context);
                        playlistController.sharePlaylist(widget.playlist.id);
                      },
                    ),
                    // ======================================================
                    // MODIFIED: Add video to playlist functionality
                    // ======================================================
                    if (widget.videoId != null)
                      _buildOptionItem(
                        icon: Icons.playlist_add_rounded,
                        title: 'Add video to this playlist',
                        onTap: () {
                          Navigator.pop(context);
                          playlistController.addVideoToPlaylist(
                            widget.playlist.id,
                            widget.videoId!,
                            widget.playlist.isPublic,
                          );
                          Get.snackbar(
                            'Success',
                            "Video added to '${widget.playlist.playlistName}'",
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: kPrimaryDark,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(20),
                            borderRadius: 16,
                          );
                        },
                      ),
                    // ======================================================
                    if (widget.videoId == null)
                      _buildOptionItem(
                        icon: Icons.video_library_rounded,
                        title: 'Manage Videos',
                        onTap: () {
                          Navigator.pop(context);
                          _showManageVideosSheet(context);
                        },
                      ),
                    _buildOptionItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Playlist',
                      isDestructive: true,
                      onTap: () {
                        playlistController.deletePlaylist(
                          widget.playlist.id,
                          widget.playlist.isPublic,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManageVideosSheet(BuildContext context) {
    final playlistController = Get.find();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: kDarkSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Manage Videos',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Video>>(
                      future: playlistController.fetchVideos(
                        widget.playlist.videoIds,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: kPrimaryDark,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading videos',
                              style: GoogleFonts.roboto(color: Colors.white),
                            ),
                          );
                        }
                        final videos = snapshot.data ?? [];
                        if (videos.isEmpty) {
                          return Center(
                            child: Text(
                              'No videos in this playlist',
                              style: GoogleFonts.roboto(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        width: 80,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          width: 80,
                                          height: 45,
                                          color: Colors.grey[800],
                                        ),
                                      )
                                    : Container(
                                        width: 80,
                                        height: 45,
                                        color: Colors.grey[800],
                                      ),
                              ),
                              title: Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  playlistController.removeVideoFromPlaylist(
                                    widget.playlist.id,
                                    video.id,
                                    widget.playlist.isPublic,
                                  );
                                  Navigator.pop(
                                    context,
                                  ); // Close sheet so they can reopen with fresh data
                                  Get.snackbar(
                                    'Removed',
                                    'Video removed from playlist',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: kPrimaryDark,
                                    colorText: Colors.white,
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPlaylistDialog(BuildContext context) {
    final editController = TextEditingController(
      text: widget.playlist.playlistName,
    );
    final playlistController = Get.find<PlaylistController>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kDarkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Playlist',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: editController,
            style: GoogleFonts.roboto(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Playlist Name',
              labelStyle: GoogleFonts.roboto(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              hintText: 'Enter new name',
              hintStyle: GoogleFonts.roboto(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: kDarksurfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryDark, width: 2),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (editController.text.trim().isNotEmpty) {
                  playlistController.editPlaylist(
                    widget.playlist.id,
                    editController.text.trim(),
                    widget.playlist.isPublic,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? AppTokens.colors.error
                  : Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.roboto(
                color: isDestructive ? AppTokens.colors.error : Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return "${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago";
    } else if (difference.inDays > 30) {
      return "${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago";
    } else if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago";
    } else {
      return 'Just now';
    }
  }
}

// ==========================================================================
// CUSTOM WIDGETS
// ==========================================================================

class StackedThumbnail extends StatelessWidget {
  const StackedThumbnail({
    required this.thumbnailUrl,
    required this.videoCount,
    super.key,
    this.isPodcast = false,
  });
  final String thumbnailUrl;
  final int videoCount;
  final bool isPodcast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom-most layer
            Positioned(
              top: -8,
              left: width * 0.08,
              right: width * 0.08,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Middle layer
            Positioned(
              top: -4,
              left: width * 0.04,
              right: width * 0.04,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Main layer (top)
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Thumbnail
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: kDarksurfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.image, color: Colors.white24),
                        ),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: kDarksurfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.error, color: Colors.white24),
                        ),
                      ),
                    ),
                    // Overlay for contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Badge (Bottom Right)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPodcast
                                  ? Icons.podcasts_rounded
                                  : Icons.playlist_play_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$videoCount ${isPodcast ? 'episodes' : 'videos'}",
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          ],
        );
      },
    );
  }
}

// App Theme (preserve original theme structure)
class AppTheme {
  static final darkTheme = ThemeData.dark().copyWith(
    // Preserve original theme configuration
  );
}

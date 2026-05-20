import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:truthworld/theme/app_theme.dart';

import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/video.dart';

// ==========================================================================
// RESPONSIVE UTILITIES
// ==========================================================================

class ResponsiveUtils {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return EdgeInsets.all(16);
    if (isTablet(context)) return EdgeInsets.all(24);
    return EdgeInsets.all(32);
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }
}

// ==========================================================================
// ADAPTIVE WIDGETS
// ==========================================================================

class AdaptiveText extends StatelessWidget {
  final String text;
  final double mobileFontSize;
  final double tabletFontSize;
  final double desktopFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;

  const AdaptiveText(
    this.text, {
    super.key,
    required this.mobileFontSize,
    required this.tabletFontSize,
    required this.desktopFontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          mobile: mobileFontSize,
          tablet: tabletFontSize,
          desktop: desktopFontSize,
        ),
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}

class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final BorderRadius? borderRadius;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? ResponsiveUtils.getResponsivePadding(context),
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

// ==========================================================================
// CONTROLLER
// ==========================================================================

class MyVideosController extends GetxController {
  var searchQuery = ''.obs;
  var isSearching = false.obs;
  var isSearchExpanded = false.obs;
  var sortBy = 'recent'.obs;
  var isAscending = false.obs;
  var videos = <Video>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedCategory = 'All'.obs;

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToVideos();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToVideos() {
    isLoading.value = true;
    errorMessage.value = '';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      errorMessage.value = 'User not authenticated';
      isLoading.value = false;
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection("videos")
        .where('ownerId', isEqualTo: currentUser.uid);

    // SERVER-SIDE SORTING: Requires composite indexes (ownerId + field)
    switch (sortBy.value) {
      case 'recent':
        query = query.orderBy('uploadedAt', descending: !isAscending.value);
        break;
      case 'views':
        query = query.orderBy('views', descending: !isAscending.value);
        break;
      case 'likes':
        query = query.orderBy('likeCount', descending: !isAscending.value);
        break;
      case 'title':
        query = query.orderBy('title', descending: !isAscending.value);
        break;
    }

    _subscription?.cancel();
    _subscription = query.snapshots().listen(
      (snapshot) {
        videos.value = snapshot.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList();
        isLoading.value = false;
      },
      onError: (error) {
        errorMessage.value = error.toString();
        isLoading.value = false;
        debugPrint('MyVideos Firestore Error: $error');
      },
    );
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
    HapticFeedback.lightImpact();
  }

  void setSortBy(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }

    // RE-FETCH with new server-side sorting
    _listenToVideos();
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void retryFetch() {
    _subscription?.cancel();
    _listenToVideos();
    HapticFeedback.mediumImpact();
  }

  Future<void> toggleVideoVisibility(Video video) async {
    try {
      final newVisibility = video.visibility == 'public' ? 'private' : 'public';
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .update({'visibility': newVisibility});

      Get.snackbar(
        'Success',
        'Video is now ${newVisibility.capitalizeFirst}.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update video visibility: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    }
  }

  /// Deletes a video from Firestore.
  Future<void> deleteVideo(Video video) async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .delete();
      Get.snackbar(
        'Video Deleted',
        '"${video.title}" was successfully deleted.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF6366F1),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete video: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    }
  }

  List<Video> get filteredAndSortedVideos {
    var filtered = videos.toList();

    // Apply search filter (Client-side)
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((video) {
        return video.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.description.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            video.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.tags.any(
              (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
            );
      }).toList();
    }

    // Sorting is now handled server-side in _listenToVideos
    return filtered;
  }

  String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, List<Video>> groupVideosByDate(List<Video> videos) {
    final Map<String, List<Video>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var video in videos) {
      final uploadDate = video.uploadedAt.toDate();
      final date = DateTime(uploadDate.year, uploadDate.month, uploadDate.day);
      String key;
      if (date == today) {
        key = 'Today';
      } else if (date == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(video);
    }
    return groups;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

// ==========================================================================
// MAIN WIDGET
// ==========================================================================

class MyVideos extends StatefulWidget {
  final bool isDashboard;
  const MyVideos({super.key, this.isDashboard = false});

  @override
  State<MyVideos> createState() => _MyVideosState();
}

class _MyVideosState extends State<MyVideos> with TickerProviderStateMixin {
  final controller = Get.put(MyVideosController());

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: _buildNotLoggedInWidget(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _buildMainContent(userId),
    );
  }

  Widget _buildMainContent(String userId) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => controller.isSearchExpanded.value
                      ? Expanded(
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.bgDivider.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: TextField(
                              onChanged: (value) =>
                                  controller.searchQuery.value = value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search your videos...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    controller.isSearchExpanded.value = false;
                                    controller.searchQuery.value = '';
                                  },
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'My videos',
                          style: GoogleFonts.roboto(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
                Row(
                  children: [
                    Obx(
                      () => !controller.isSearchExpanded.value
                          ? IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  controller.isSearchExpanded.value = true,
                            )
                          : const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Get.toNamed('/uploadscreen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        Obx(() {
          if (controller.isLoading.value) {
            return const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brand,
                ),
              ),
            );
          }

          if (controller.errorMessage.isNotEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error: ${controller.errorMessage.value}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final videos = controller.filteredAndSortedVideos;
          if (videos.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No videos found',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          // Apply local category filtering
          List<Video> displayVideos = List.from(videos);
          if (controller.selectedCategory.value != 'All') {
            final catLower = controller.selectedCategory.value.toLowerCase();
            displayVideos = displayVideos
                .where((v) {
                  return v.category.toLowerCase() == catLower ||
                         v.title.toLowerCase().contains(catLower) ||
                         v.tags.any((t) => t.toLowerCase().contains(catLower));
                })
                .toList();
          }

          final groupedVideos = controller.groupVideosByDate(displayVideos);

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final dateKey = groupedVideos.keys.elementAt(index);
              final dateVideos = groupedVideos[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Text(
                      dateKey,
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...dateVideos.map(
                    (video) =>
                        _MyVideoListCard(video: video, controller: controller),
                  ),
                ],
              );
            }, childCount: groupedVideos.length),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Podcasts', 'Music', 'Gaming', 'News'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Obx(() {
            final isSelected = controller.selectedCategory.value == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.setCategory(category);
                },
                selectedColor: Colors.white,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: GoogleFonts.roboto(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                showCheckmark: false,
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildNotLoggedInWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_rounded,
            size: 80,
            color: AppColors.brand,
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in to see your videos',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Get.toNamed('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class _MyVideoListCard extends StatelessWidget {
  final Video video;
  final MyVideosController controller;
  const _MyVideoListCard({required this.video, required this.controller});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.toNamed('/videoscreen', arguments: {'video': video});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 160,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppTheme.secondaryBackground),
                    errorWidget: (context, url, error) =>
                        Container(color: AppTheme.secondaryBackground),
                  ),
                ),
                // Duration overlay
                Positioned(
                  bottom: 4,
                  right: 4,
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
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Visibility indicator (green for public, orange for private)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      video.visibility == 'public' ? Icons.public : Icons.lock,
                      size: 14,
                      color: video.visibility == 'public'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _showOptions(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.views} views • ${controller.formatTimeAgo(video.uploadedAt.toDate())}',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${video.likeCount}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.comment_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${video.commentCount}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.brand.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Text(
                          video.visibility.toUpperCase(),
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
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
    );
  }

  void _showOptions(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionItem(
              icon: Icons.edit_outlined,
              label: 'Edit details',
              onTap: () {
                Get.back();
                // Navigate to edit
              },
            ),
            _buildOptionItem(
              icon: video.visibility == 'public'
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              label: video.visibility == 'public'
                  ? 'Make private'
                  : 'Make public',
              onTap: () {
                Get.back();
                controller.toggleVideoVisibility(video);
              },
            ),
            _buildOptionItem(
              icon: Icons.analytics_outlined,
              label: 'View analytics',
              onTap: () {
                Get.back();
              },
            ),
            _buildOptionItem(
              icon: Icons.delete_outline,
              label: 'Delete video',
              color: Colors.red,
              onTap: () {
                Get.back();
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final textColor = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.brand).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? AppColors.textSecondary, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.roboto(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Delete video?',
          style: GoogleFonts.roboto(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}"? This action cannot be undone.',
          style: GoogleFonts.roboto(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteVideo(video);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}







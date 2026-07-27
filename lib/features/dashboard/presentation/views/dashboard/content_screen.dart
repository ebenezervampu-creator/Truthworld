import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.searchQuery = '',
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          toolbarHeight: 0, // Hide the app bar title portion, only keep TabBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Posts'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildVideosTab(context, controller),
            _buildPostsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosTab(
    BuildContext context,
    VideoManagementController controller,
  ) {
    return StreamBuilder<List<Video>>(
      stream: controller.fetchChannelVideos(channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.brand,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 72,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Content Yet',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your first video to get started!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        var videos = snapshot.data!;

        // Filter videos based on search query
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          videos = videos
              .where(
                (video) =>
                    video.title.toLowerCase().contains(query) ||
                    video.description.toLowerCase().contains(query) ||
                    video.tags.any(
                      (tag) => tag.toLowerCase().contains(query),
                    ),
              )
              .toList();
        }

        if (videos.isEmpty && searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 72,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching content found',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return _buildVideoContentCard(context, video, controller);
          },
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Community')
          .where('channelId', isEqualTo: channelId)
          .where(
            'ownerId',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.brand,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoPostsYetWidget();
        }

        final docs = snapshot.data!.docs;
        var posts = docs
            .map(
              (doc) => CommunityPostModel.fromMap(
                doc.data()! as Map<String, dynamic>,
              ),
            )
            .toList();

        // Filter posts based on search query
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          posts = posts
              .where(
                (post) =>
                    post.title.toLowerCase().contains(query) ||
                    post.description.toLowerCase().contains(query),
              )
              .toList();
        }

        if (posts.isEmpty && searchQuery.isNotEmpty) {
          return _buildNoPostsYetWidget(isSearchFiltered: true);
        }

        // Sort posts chronologically descending
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CommunityPostCard(
              key: ValueKey(post.id),
              post: post,
            );
          },
        );
      },
    );
  }



  Widget _buildNoPostsYetWidget({bool isSearchFiltered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchFiltered
                ? Icons.search_off_rounded
                : Icons.chat_bubble_outline,
            size: 72,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchFiltered
                ? 'No matching posts found'
                : 'No Community Posts Yet',
            style: AppTextStyles.pageTitle.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchFiltered
                ? 'Try searching with different keywords'
                : 'Create your first post in the community section!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContentCard(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showVideoActionOptionsModal(context, video),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail container with 16:9 ratio (Compact 96x54)
              InkWell(
                onTap: () => _showVideoActionOptionsModal(context, video),
                child: Container(
                  width: 96,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.bgInput,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.movie_outlined,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Video Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.videoTitleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Metadata wrap row with flexible text - resolves right overflow
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.views} views',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(video.uploadedAt.toDate()),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Menu
              PopupMenuButton<String>(
                color: AppColors.bgSurface,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.bgDivider),
                ),
                onSelected: (value) {
                  if (value == 'watch') {
                    MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
                  } else if (value == 'content_details') {
                    Get.to<dynamic>(
                      () => VideoContentDetailsScreen(
                        video: video,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  } else if (value == 'edit') {
                    Get.to<dynamic>(() => EditVideoScreen(video: video));
                  } else if (value == 'ai_features') {
                    _showGenerateAIFeaturesDialog(context, video, controller);
                  } else if (value == 'delete') {
                    _showDeleteVideoDialog(context, video, controller);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'watch',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 18,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Watch Video',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'content_details',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Video Content Details',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text('Edit Video', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'ai_features',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generate AI Features',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoActionOptionsModal(BuildContext context, Video video) {
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 56,
                    height: 32,
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) => const ColoredBox(
                        color: AppColors.bgInput,
                        child: Icon(Icons.movie_outlined, size: 16, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.brand,
                  size: 24,
                ),
              ),
              title: Text(
                'Watch Video',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Navigate to player and watch this video',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Get.back<void>();
                MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
              },
            ),
            const Divider(height: 16, color: AppColors.bgDivider),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.info,
                  size: 22,
                ),
              ),
              title: Text(
                'Video Content Details',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Moderation, Thumbnail Safety, AI Metadata & Pipeline Stages',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Get
                  ..back<void>()
                  ..to<dynamic>(
                    () => VideoContentDetailsScreen(
                      video: video,
                      isDarkMode: isDarkMode,
                    ),
                  );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }



  void _showDeleteVideoDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Video?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete '${video.title}'? This action cannot be undone.",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back<void>,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.buttonText.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      controller.deleteVideo(video);
                      Get.back<void>();
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showGenerateAIFeaturesDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final selectedLangs = <String>{'te', 'hi'}.obs;
    final selectedFeatures = <String>{'subtitles', 'dubbing', 'factcheck', 'summary', 'chapters'}.obs;
    final isAccuracyMode = true.obs;
    final showAdvanced = false.obs;

    final availableLangs = [
      {'code': 'te', 'name': 'Telugu (తెలుగు)'},
      {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
      {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
      {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
      {'code': 'es', 'name': 'Spanish'},
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.brand,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AI Features & Advanced Settings',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                          onPressed: Get.back<void>,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generate subtitles, dubbed audio tracks, fact-checking, AI summaries, and chapters anytime on demand.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 24),

                    // Section 1: Target Languages
                    Text(
                      'Select Target Languages',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableLangs.map((lang) {
                        final code = lang['code']!;
                        final name = lang['name']!;
                        final isSelected = selectedLangs.contains(code);
                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: AppColors.brand.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.brand,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.brand : AppColors.textPrimary,
                          ),
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(code);
                            } else {
                              if (selectedLangs.length > 1) {
                                selectedLangs.remove(code);
                              }
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: AI Capabilities
                    Text(
                      'Select AI Features to Generate',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildFeatureCheckbox(
                      title: 'Subtitles & Closed Captions (SRT/VTT)',
                      subtitle: 'Generate native subtitles in selected target languages',
                      icon: Icons.subtitles_outlined,
                      value: selectedFeatures.contains('subtitles'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('subtitles');
                        } else {
                          selectedFeatures.remove('subtitles');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'AI Audio Dubbing Tracks',
                      subtitle: 'Generate natural AI voice tracks in Telugu, Hindi, etc.',
                      icon: Icons.record_voice_over_outlined,
                      value: selectedFeatures.contains('dubbing'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('dubbing');
                        } else {
                          selectedFeatures.remove('dubbing');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'Fact-Checking & Truth Score Report',
                      subtitle: 'Extract claims & verify truthfulness with citations',
                      icon: Icons.fact_check_outlined,
                      value: selectedFeatures.contains('factcheck'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('factcheck');
                        } else {
                          selectedFeatures.remove('factcheck');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'AI Video Summary & Key Takeaways',
                      subtitle: 'Generate concise summary of video content',
                      icon: Icons.auto_stories_outlined,
                      value: selectedFeatures.contains('summary'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('summary');
                        } else {
                          selectedFeatures.remove('summary');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'Timestamped Auto-Chapters',
                      subtitle: 'Detect topics and create chapter timestamps',
                      icon: Icons.bookmarks_outlined,
                      value: selectedFeatures.contains('chapters'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('chapters');
                        } else {
                          selectedFeatures.remove('chapters');
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Advanced Settings Accordion
                    InkWell(
                      onTap: () => showAdvanced.value = !showAdvanced.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Settings',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              showAdvanced.value ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showAdvanced.value) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Priority Mode',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      isAccuracyMode.value
                                          ? 'Accuracy Mode (Universal-3 Pro + Grounding)'
                                          : 'Fast Mode (Draft)',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: isAccuracyMode.value,
                                  activeTrackColor: AppColors.brand,
                                  onChanged: (val) => isAccuracyMode.value = val,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: Get.back<void>,
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.buttonText.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(
                            'Generate AI Features',
                            style: AppTextStyles.buttonText.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: selectedFeatures.isEmpty
                              ? null
                              : () {
                                  Get.back<void>();
                                  controller.triggerAIFeatures(
                                    videoId: video.id,
                                    features: selectedFeatures.toList(),
                                    targetLanguages: selectedLangs.toList(),
                                    priorityMode: isAccuracyMode.value ? 'accuracy' : 'speed',
                                    autoChapters: selectedFeatures.contains('chapters'),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCheckbox({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.brand,
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: value ? AppColors.brand : AppColors.textTertiary, size: 22),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

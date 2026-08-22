import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/theme/app_theme.dart';

class UserClipsController extends BaseController {
  final RxList<VideoClip> clips = <VideoClip>[].obs;
  final RxBool rxIsLoading = true.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearchExpanded = false.obs;
  final RxBool isListView = true.obs;
  final RxString selectedCategory = 'All'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchClips();
  }

  Future<void> fetchClips() async {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      rxIsLoading.value = false;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('clips')
          .orderBy('createdAt', descending: true)
          .get();

      clips.assignAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return VideoClip.fromMap(data);
        }).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching clips: $e');
      rxErrorMessage.value = e.toString();
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> deleteClip(String clipId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('clips')
          .doc(clipId)
          .delete();
      clips.removeWhere((c) => c.id == clipId);
      Get.snackbar(
        'Deleted',
        'Clip removed from library',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.brand,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete clip: $e');
    }
  }

  void toggleView() {
    isListView.value = !isListView.value;
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void playClip(VideoClip clip) {
    Get.toNamed<void>('/watch?v=${clip.videoId}', arguments: {'clip': clip});
  }

  List<VideoClip> get filteredClips {
    var result = clips.toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((c) {
        return c.title.toLowerCase().contains(q) ||
            c.videoTitle.toLowerCase().contains(q) ||
            c.channelName.toLowerCase().contains(q);
      }).toList();
    }
    return result;
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

  Map<String, List<VideoClip>> groupClipsByDate(List<VideoClip> clipsList) {
    final groups = <String, List<VideoClip>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final clip in clipsList) {
      final date = clip.createdAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      String key;
      if (dateOnly == today) {
        key = 'Today';
      } else if (dateOnly == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(clip);
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

class ClipsPage extends StatelessWidget {
  const ClipsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  UserClipsController get controller =>
      Get.isRegistered<UserClipsController>()
          ? Get.find<UserClipsController>()
          : Get.put(UserClipsController());

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _buildMainContent(context, controller),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    UserClipsController controller,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, isDashboard ? 16 : 48, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Obx(
                    () => controller.isSearchExpanded.value
                        ? Container(
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
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search clips...',
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
                          )
                        : Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.textPrimary,
                                ),
                                onPressed: () {
                                  if (isDashboard) {
                                    if (Get.isRegistered<HomeController>()) {
                                      Get.find<HomeController>()
                                              .sideNavSelectedIndex
                                              .value =
                                          HomeController.indexLibrary;
                                    }
                                  } else {
                                    Get.back<void>();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Your Clips',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Obx(
                  () => !controller.isSearchExpanded.value
                      ? IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () =>
                              controller.isSearchExpanded.value = true,
                        )
                      : const SizedBox.shrink(),
                ),
                IconButton(
                  icon: Obx(
                    () => Icon(
                      controller.isListView.value
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onPressed: () => controller.toggleView(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategoryChips(controller)),
        Obx(() {
          if (controller.rxIsLoading.value) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brand,
                ),
              ),
            );
          }

          if (controller.rxErrorMessage.isNotEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error: ${controller.rxErrorMessage.value}',
                    style: const TextStyle(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final clips = controller.filteredClips;
          if (clips.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            );
          }

          if (!controller.isListView.value) {
            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: clips.length,
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  return _ClipVideoGridCard(clip: clip, controller: controller);
                },
              ),
            );
          }

          final groupedClips = controller.groupClipsByDate(clips);

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final dateKey = groupedClips.keys.elementAt(index);
              final dateClips = groupedClips[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Text(
                      dateKey,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...dateClips.map(
                    (clip) =>
                        _ClipVideoListCard(clip: clip, controller: controller),
                  ),
                ],
              );
            }, childCount: groupedClips.length),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryChips(UserClipsController controller) {
    final categories = ['All', 'Recent'];
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
                selectedColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.content_cut_rounded,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No clips yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find your favorite moments and clip them!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipVideoListCard extends StatelessWidget {
  const _ClipVideoListCard({required this.clip, required this.controller});
  final VideoClip clip;
  final UserClipsController controller;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = (clip.endTime - clip.startTime).toInt();
    final durationText = FormatUtils.formatDuration(
      Duration(seconds: durationSeconds),
    );

    return InkWell(
      onTap: () => controller.playClip(clip),
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
                    imageUrl: clip.thumbnailUrl,
                    width: 160,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppTheme.secondaryBackground),
                    errorWidget: (context, url, error) =>
                        Container(color: AppTheme.secondaryBackground),
                  ),
                ),
                // Clip Duration badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_cut,
                          color: AppColors.textPrimary,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                          clip.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.textPrimary,
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
                    clip.channelName.isNotEmpty
                        ? '${clip.channelName} • ${clip.videoTitle}'
                        : clip.videoTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Clip ($durationText) • Created ${controller.formatTimeAgo(clip.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

  void _showOptions(BuildContext context) {
    final encodedTitle = Uri.encodeComponent(clip.title);
    final clipUrl =
        'https://www.truthworld.in/watch?v=${clip.videoId}&start=${clip.startTime.toInt()}&end=${clip.endTime.toInt()}&clipTitle=$encodedTitle';
    final durationSec = (clip.endTime - clip.startTime).toInt();

    Get.bottomSheet<void>(
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
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionItem(
              icon: Icons.play_arrow_rounded,
              label: 'Play Clip',
              onTap: () {
                Get.back<void>();
                controller.playClip(clip);
              },
            ),
            _buildOptionItem(
              icon: Icons.bookmark_added_rounded,
              label: 'Saved in your Clips',
              onTap: () {
                Get.back<void>();
                Get.snackbar(
                  'Saved',
                  'This clip is saved in your library',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.bgSurface,
                  colorText: AppColors.textPrimary,
                );
              },
            ),
            _buildOptionItem(
              icon: Icons.share_rounded,
              label: 'Share clip with Truthworld Watermark',
              onTap: () {
                Get.back<void>();
                ShareBottomSheet.show(
                  title: clip.title,
                  url: clipUrl,
                  thumbnailUrl: clip.thumbnailUrl,
                  subtitle:
                      '🎬 Watch clip: "${clip.title}" [${clip.startTime.toInt()}s - ${clip.endTime.toInt()}s]\n'
                      '✨ Truthworld Watermark\n'
                      '👇 Tap to watch in Truthworld App:\n'
                      '$clipUrl',
                  channelName: clip.channelName,
                  durationMs: durationSec * 1000,
                  type: 'clip',
                  clipStartTime: clip.startTime,
                  clipEndTime: clip.endTime,
                  videoId: clip.videoId,
                  videoTitle: clip.videoTitle,
                );
              },
            ),
            _buildOptionItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete from clips',
              color: AppColors.error,
              onTap: () {
                Get.back<void>();
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
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
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
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text(
          'Delete clip?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${clip.title}" from your clips?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back<void>();
              controller.deleteClip(clip.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
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

class _ClipVideoGridCard extends StatelessWidget {
  const _ClipVideoGridCard({required this.clip, required this.controller});
  final VideoClip clip;
  final UserClipsController controller;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = (clip.endTime - clip.startTime).toInt();
    final durationText = FormatUtils.formatDuration(
      Duration(seconds: durationSeconds),
    );

    return InkWell(
      onTap: () => controller.playClip(clip),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: clip.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppTheme.secondaryBackground),
                      errorWidget: (context, url, error) =>
                          Container(color: AppTheme.secondaryBackground),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_cut,
                          color: AppColors.textPrimary,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationText,
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
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => _showOptions(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clip.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clip.videoTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Clip ($durationText) • ${controller.formatTimeAgo(clip.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final encodedTitle = Uri.encodeComponent(clip.title);
    final clipUrl =
        'https://www.truthworld.in/watch?v=${clip.videoId}&start=${clip.startTime.toInt()}&end=${clip.endTime.toInt()}&clipTitle=$encodedTitle';
    final durationSec = (clip.endTime - clip.startTime).toInt();

    Get.bottomSheet<void>(
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
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Play Clip',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Get.back<void>();
                controller.playClip(clip);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bookmark_added_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Saved in your Clips',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Get.back<void>();
                Get.snackbar(
                  'Saved',
                  'This clip is saved in your library',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.bgSurface,
                  colorText: AppColors.textPrimary,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Share clip with Truthworld Watermark',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Get.back<void>();
                ShareBottomSheet.show(
                  title: clip.title,
                  url: clipUrl,
                  thumbnailUrl: clip.thumbnailUrl,
                  subtitle:
                      '🎬 Watch clip: "${clip.title}" [${clip.startTime.toInt()}s - ${clip.endTime.toInt()}s]\n✨ Truthworld Watermark\n👇 Tap to watch in Truthworld App:\n$clipUrl',
                  channelName: clip.channelName,
                  durationMs: durationSec * 1000,
                  type: 'clip',
                  clipStartTime: clip.startTime,
                  clipEndTime: clip.endTime,
                  videoId: clip.videoId,
                  videoTitle: clip.videoTitle,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text(
                'Delete from clips',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Get.back<void>();
                controller.deleteClip(clip.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

class TrashRestoreController extends GetxController {
  TrashRestoreController({required this.channelId});
  final String channelId;

  final RxString selectedFilter =
      'All'.obs; // 'All', 'Channel', 'Video', 'Topic', 'Playlist'
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> trashItems = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadTrashItems();
  }

  Future<void> loadTrashItems() async {
    isLoading.value = true;

    try {
      final loadedItems = <Map<String, dynamic>>[];
      final firestore = FirebaseFirestore.instance;

      // 1. Check if the current channel itself is deletion_pending
      if (channelId.isNotEmpty) {
        final channelSnap = await firestore
            .collection('channels')
            .doc(channelId)
            .get();
        if (channelSnap.exists) {
          final data = channelSnap.data();
          if (data != null && data['status'] == 'deletion_pending') {
            loadedItems.add({
              'id': channelSnap.id,
              'type': 'Channel',
              'title':
                  data['channelName'] ?? data['name'] ?? 'Untitled Channel',
              'imageUrl': data['avatarUrl'] ?? '',
              'deletedAt':
                  (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              'ref': channelSnap.reference,
            });
          }
        }
      }

      // 2. Fetch deleted videos belonging to this channel
      if (channelId.isNotEmpty) {
        final videosSnap = await firestore
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (final doc in videosSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Video',
            'title': data['title'] ?? 'Untitled Video',
            'imageUrl': data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 3. Fetch deleted topics belonging to this channel
      if (channelId.isNotEmpty) {
        final topicsSnap = await firestore
            .collection('topics')
            .where('channelId', isEqualTo: channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (final doc in topicsSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Topic',
            'title': data['title'] ?? 'Untitled Topic',
            'imageUrl': data['coverImage'] ?? data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 4. Fetch deleted playlists belonging to this channel
      if (channelId.isNotEmpty) {
        final playlistsSnap = await firestore
            .collection('playlists')
            .where('channelId', isEqualTo: channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (final doc in playlistsSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Playlist',
            'title': data['name'] ?? 'Untitled Playlist',
            'imageUrl': data['imageUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // Sort by deletion requested time (newest deleted first)
      loadedItems.sort(
        (a, b) =>
            (b['deletedAt'] as DateTime).compareTo(a['deletedAt'] as DateTime),
      );

      trashItems.value = loadedItems;
    } catch (e) {
      debugPrint('Error loading trash items: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> restoreItem(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference;
    final type = item['type'] as String;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      barrierDismissible: false,
    );

    try {
      final updateFields = <String, dynamic>{
        'deletionRequestedAt': FieldValue.delete(),
      };

      if (type == 'Channel') {
        updateFields['status'] = 'active';
      } else if (type == 'Video') {
        updateFields['status'] = 'ready';
      } else if (type == 'Topic') {
        updateFields['status'] = 'active';
        updateFields['visibilityType'] = 'public';
      } else if (type == 'Playlist') {
        updateFields['status'] = 'active';
      }

      await docRef.update(updateFields);

      // Close loading dialog
      Get.back();

      AppSnackbar.show(
        'Item Restored',
        '${item['title']} has been successfully restored.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Reload list
      loadTrashItems();
    } catch (e) {
      Get.back(); // Close loading dialog
      AppSnackbar.show(
        'Restoration Failed',
        'Failed to restore item: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  int getRemainingDays(DateTime deletedAt) {
    final difference = DateTime.now().difference(deletedAt);
    final remaining = 30 - difference.inDays;
    return remaining.clamp(0, 30);
  }
}

class TrashRestoreScreen extends StatelessWidget {
  const TrashRestoreScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      TrashRestoreController(channelId: channelId),
      tag: channelId,
    );

    return Container(
      color: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trash & Restoration',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deleted channels, videos, topics, and playlists are retained for 30 days before permanent deletion.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: controller.loadTrashItems,
                tooltip: 'Refresh Trash Bin',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Row
          _buildFiltersRow(controller),
          const SizedBox(height: 16),

          // Content Area
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                );
              }

              final filteredList = controller.trashItems.where((item) {
                if (controller.selectedFilter.value == 'All') return true;
                return item['type'] == controller.selectedFilter.value;
              }).toList();

              if (filteredList.isEmpty) {
                return _buildEmptyState();
              }

              return _buildTrashItemsList(controller, filteredList);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(TrashRestoreController controller) {
    final filters = ['All', 'Channel', 'Video', 'Topic', 'Playlist'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          return Obx(() {
            final isSelected = controller.selectedFilter.value == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    controller.selectedFilter.value = filter;
                  }
                },
                selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : AppColors.textDisabled,
                ),
                backgroundColor: Colors.transparent,
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFF818CF8)
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 72,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Trash is Empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No recently deleted items match the selected filter.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashItemsList(
    TrashRestoreController controller,
    List<Map<String, dynamic>> items,
  ) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final type = item['type'] as String;
        final title = item['title'] as String;
        final imageUrl = item['imageUrl'] as String;
        final deletedAt = item['deletedAt'] as DateTime;
        final remainingDays = controller.getRemainingDays(deletedAt);

        // Icon based on type
        var typeIcon = Icons.video_library_rounded;
        Color typeColor = Colors.teal;
        if (type == 'Channel') {
          typeIcon = Icons.account_box_rounded;
          typeColor = Colors.indigo;
        } else if (type == 'Topic') {
          typeIcon = Icons.topic_rounded;
          typeColor = AppColors.warning;
        } else if (type == 'Playlist') {
          typeIcon = Icons.playlist_play_rounded;
          typeColor = AppColors.brand;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              // Image / Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 48,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.bgDivider),
                          errorWidget: (context, url, error) => ColoredBox(
                            color: typeColor.withValues(alpha: 0.1),
                            child: Icon(typeIcon, color: typeColor, size: 24),
                          ),
                        )
                      : ColoredBox(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(typeIcon, color: typeColor, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deleted on ${DateFormat('MMM d, yyyy').format(deletedAt)}',
                          style: TextStyle(
                            color: isDarkMode
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$remainingDays days left before permanent deletion',
                      style: TextStyle(
                        color: remainingDays <= 5
                            ? AppColors.error
                            : AppColors.brandHover,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Restore Button
              TextButton.icon(
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restore'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF818CF8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
                onPressed: () => controller.restoreItem(item),
              ),
            ],
          ),
        );
      },
    );
  }
}

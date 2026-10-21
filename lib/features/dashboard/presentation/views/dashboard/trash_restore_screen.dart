import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/theme/app_theme.dart';

class TrashRestoreController extends BaseController {
  TrashRestoreController({required this.channelId});
  final String channelId;

  final RxString selectedFilter =
      'All'.obs; // 'All', 'Video', 'Topic', 'Playlist'
  final RxBool rxIsLoading = false.obs;
  final RxList<Map<String, dynamic>> trashItems = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadTrashItems();
  }

  void clearData() {
    trashItems.clear();
    rxIsLoading.value = false;
  }

  @override
  void onClose() {
    clearData();
    super.onClose();
  }

  Future<void> loadTrashItems() async {
    rxIsLoading.value = true;

    try {
      final loadedItems = <Map<String, dynamic>>[];
      final firestore = FirebaseFirestore.instance;
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final targetChannelId = channelId.isNotEmpty ? channelId : currentUid;

      // 1. Fetch deleted videos belonging to this channel or creator
      if (targetChannelId.isNotEmpty) {
        final videoDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        try {
          final videosSnap = await firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: targetChannelId)
              .where('status', whereIn: ['deletion_pending', 'trashed'])
              .get();
          for (final doc in videosSnap.docs) {
            videoDocs[doc.id] = doc;
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadChannelVideos');
        }

        if (currentUid.isNotEmpty && currentUid != targetChannelId) {
          try {
            final ownerVideosSnap = await firestore
                .collection(FirestoreCollections.videos)
                .where('ownerId', isEqualTo: currentUid)
                .where('status', whereIn: ['deletion_pending', 'trashed'])
                .get();
            for (final doc in ownerVideosSnap.docs) {
              videoDocs[doc.id] = doc;
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadOwnerVideos');
          }
        }

        for (final doc in videoDocs.values) {
          final data = doc.data() ?? {};
          loadedItems.add({
            'id': doc.id,
            'type': 'Video',
            'title': data['title'] ?? 'Untitled Video',
            'imageUrl': data['thumbnailUrl'] ?? '',
            'videoUrl': data['videoUrl'] ?? '',
            'originalUrl': data['originalUrl'] ?? '',
            'isShort': data['isShort'] == true,
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                (data['updatedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 2. Fetch deleted topics belonging to this channel
      if (targetChannelId.isNotEmpty) {
        final topicDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        try {
          final topicsSnap = await firestore
              .collection(FirestoreCollections.topics)
              .where('channelId', isEqualTo: targetChannelId)
              .where('status', isEqualTo: 'deletion_pending')
              .get();
          for (final doc in topicsSnap.docs) {
            topicDocs[doc.id] = doc;
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadChannelTopics');
        }

        if (currentUid.isNotEmpty && currentUid != targetChannelId) {
          try {
            final ownerTopicsSnap = await firestore
                .collection(FirestoreCollections.topics)
                .where('ownerId', isEqualTo: currentUid)
                .where('status', isEqualTo: 'deletion_pending')
                .get();
            for (final doc in ownerTopicsSnap.docs) {
              topicDocs[doc.id] = doc;
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadOwnerTopics');
          }
        }

        for (final doc in topicDocs.values) {
          final data = doc.data() ?? {};
          loadedItems.add({
            'id': doc.id,
            'type': 'Topic',
            'title': data['title'] ?? 'Untitled Topic',
            'imageUrl': data['coverImage'] ?? data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                (data['updatedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 3. Fetch deleted playlists belonging to this channel
      if (targetChannelId.isNotEmpty) {
        final playlistDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        try {
          final playlistsSnap = await firestore
              .collection(FirestoreCollections.playlists)
              .where('channelId', isEqualTo: targetChannelId)
              .where('status', isEqualTo: 'deletion_pending')
              .get();
          for (final doc in playlistsSnap.docs) {
            playlistDocs[doc.id] = doc;
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadChannelPlaylists');
        }

        if (currentUid.isNotEmpty && currentUid != targetChannelId) {
          try {
            final ownerPlaylistsSnap = await firestore
                .collection(FirestoreCollections.playlists)
                .where('ownerId', isEqualTo: currentUid)
                .where('status', isEqualTo: 'deletion_pending')
                .get();
            for (final doc in ownerPlaylistsSnap.docs) {
              playlistDocs[doc.id] = doc;
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadOwnerPlaylists');
          }
        }

        for (final doc in playlistDocs.values) {
          final data = doc.data() ?? {};
          loadedItems.add({
            'id': doc.id,
            'type': 'Playlist',
            'title': data['name'] ?? 'Untitled Playlist',
            'imageUrl': data['imageUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                (data['updatedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 4. Fetch deleted community posts belonging to this channel
      if (targetChannelId.isNotEmpty) {
        final postDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        try {
          final postsSnap = await firestore
              .collection(FirestoreCollections.community)
              .where('channelId', isEqualTo: targetChannelId)
              .where('status', whereIn: ['deletion_pending', 'trashed'])
              .get();
          for (final doc in postsSnap.docs) {
            postDocs[doc.id] = doc;
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadChannelPosts');
        }

        if (currentUid.isNotEmpty && currentUid != targetChannelId) {
          try {
            final ownerPostsSnap = await firestore
                .collection(FirestoreCollections.community)
                .where('ownerId', isEqualTo: currentUid)
                .where('status', whereIn: ['deletion_pending', 'trashed'])
                .get();
            for (final doc in ownerPostsSnap.docs) {
              postDocs[doc.id] = doc;
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadOwnerPosts');
          }
        }

        for (final doc in postDocs.values) {
          final data = doc.data() ?? {};
          var postImg = '';
          if (data['images'] is List && (data['images'] as List).isNotEmpty) {
            postImg = (data['images'] as List).first.toString();
          } else if (data['image'] != null && (data['image'] as String).isNotEmpty) {
            postImg = data['image'].toString();
          }

          final rawTitle = (data['title'] as String?)?.trim() ?? '';
          final rawDesc = (data['description'] as String?)?.trim() ?? '';
          final displayTitle = rawTitle.isNotEmpty
              ? rawTitle
              : (rawDesc.isNotEmpty ? rawDesc : 'Untitled Post');

          loadedItems.add({
            'id': doc.id,
            'type': 'Post',
            'title': displayTitle,
            'imageUrl': postImg,
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                (data['updatedAt'] as Timestamp?)?.toDate() ??
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TrashRestoreController.loadTrashItems',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> restoreItem(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference;
    final type = item['type'] as String;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      barrierDismissible: false,
    );

    try {
      final updateFields = <String, dynamic>{
        'deletionRequestedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (type == 'Channel') {
        updateFields['status'] = 'active';
      } else if (type == 'Video') {
        updateFields['status'] = 'ready';
        updateFields['visibility'] = 'public';
        if (item['isShort'] == true) {
          try {
            await FirebaseFirestore.instance
                .collection('shorts')
                .doc(item['id'] as String)
                .update({
              'status': 'ready',
              'visibility': 'public',
              'deletionRequestedAt': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.restoreShort');
          }
        }
      } else if (type == 'Topic') {
        final docSnap = await docRef.get();
        final topicData = docSnap.data() as Map<String, dynamic>? ?? {};
        final vCount = (topicData['videoCount'] as num?)?.toInt() ?? 0;
        final featVids = topicData['featuredVideoIds'] as List? ?? [];
        final slug = (topicData['slug'] as String? ?? '').trim();

        if (vCount <= 0 && featVids.isEmpty) {
          final existingVideos = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('topics', arrayContains: slug)
              .limit(1)
              .get();

          if (existingVideos.docs.isEmpty) {
            Get.back();
            AppSnackbar.show(
              'Restoration Blocked',
              'Cannot restore this topic because it contains 0 videos. Topics must contain at least 1 video.',
              backgroundColor: AppColors.error,
              colorText: AppColors.textPrimary,
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          } else {
            updateFields['videoCount'] = existingVideos.docs.length;
          }
        }
        updateFields['status'] = 'active';
        updateFields['visibilityType'] = 'public';
      } else if (type == 'Playlist') {
        updateFields['status'] = 'active';
      } else if (type == 'Post') {
        updateFields['status'] = 'published';
        updateFields['visibility'] = 'Public';
      }

      await docRef.update(updateFields);

      // Close loading dialog
      Get.back();

      AppSnackbar.success(
        '${item['title']} has been successfully restored.',
      );

      // Reload list
      loadTrashItems();
    } catch (e) {
      Get.back(); // Close loading dialog
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to restore item. Please try again.',
      );
    }
  }

  void confirmPermanentDelete(BuildContext context, Map<String, dynamic> item) {
    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Permanently?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to permanently delete '${item['title']}'? This action cannot be undone and media assets will be destroyed.",
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Get.back<void>();
                      permanentlyDeleteItem(item);
                    },
                    child: const Text(
                      'Delete Forever',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Future<void> permanentlyDeleteItem(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference;
    final type = item['type'] as String;
    final id = item['id'] as String;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      barrierDismissible: false,
    );

    try {
      await docRef.delete();

      if (type == 'Video') {
        if (item['isShort'] == true) {
          try {
            await FirebaseFirestore.instance.collection('shorts').doc(id).delete();
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.deleteShort');
          }
        }
        await VideoManagementController.safeDeleteStorageUrl(
          item['videoUrl'] as String? ?? '',
        );
        await VideoManagementController.safeDeleteStorageUrl(
          item['imageUrl'] as String? ?? '',
        );
        final origUrl = item['originalUrl'] as String? ?? '';
        if (origUrl.isNotEmpty) {
          await VideoManagementController.safeDeleteStorageUrl(origUrl);
        }
      } else if (type == 'Post') {
        final img = item['imageUrl'] as String? ?? '';
        if (img.isNotEmpty) {
          await VideoManagementController.safeDeleteStorageUrl(img);
        }
      }

      Get.back(); // Close loading dialog
      AppSnackbar.success(
        "'${item['title']}' has been permanently deleted.",
      );
      loadTrashItems();
    } catch (e, s) {
      Get.back();
      ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.permanentlyDeleteItem');
      AppSnackbar.error(
        'Unable to permanently delete item. Please try again.',
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
    this.searchQuery = '',
    this.showBackButton = false,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;
  final String searchQuery;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      TrashRestoreController(channelId: channelId),
      tag: channelId,
    );

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (showBackButton && Navigator.canPop(context)) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trash & Restoration',
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deleted videos, community posts, topics, and playlists are retained for 30 days before permanent deletion.',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
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
                  if (controller.rxIsLoading.value && controller.trashItems.isEmpty) {
                    return const StudioLoadingIndicator(
                      message: 'Loading trash items...',
                      isFullScreen: false,
                    );
                  }

                  final filteredList = controller.trashItems.where((item) {
                    if (controller.selectedFilter.value != 'All' &&
                        item['type'] != controller.selectedFilter.value) {
                      return false;
                    }
                    if (searchQuery.isNotEmpty) {
                      final title = (item['title'] ?? '').toString().toLowerCase();
                      if (!title.contains(searchQuery.toLowerCase())) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildTrashItemsList(controller, filteredList);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersRow(TrashRestoreController controller) {
    final filters = ['All', 'Video', 'Post', 'Topic', 'Playlist'];
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
                selectedColor: AppColors.bgSurfaceHigh,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.bgDivider,
                ),
                backgroundColor: AppColors.bgSurface,
                labelStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  color: isSelected
                      ? Colors.white
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
              color: AppColors.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 72,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Trash is Empty',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No recently deleted items match the selected filter.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 14,
              color: AppColors.textSecondary,
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
        var typeColor = AppColors.success;
        if (type == 'Channel') {
          typeIcon = Icons.account_box_rounded;
          typeColor = AppColors.info;
        } else if (type == 'Topic') {
          typeIcon = Icons.topic_rounded;
          typeColor = AppColors.warning;
        } else if (type == 'Playlist') {
          typeIcon = Icons.playlist_play_rounded;
          typeColor = AppColors.brandVariant;
        } else if (type == 'Post') {
          typeIcon = Icons.article_rounded;
          typeColor = AppColors.info;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : AppColors.brandVariant,
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
                            child: Icon(typeIcon, color: Colors.white, size: 24),
                          ),
                        )
                      : ColoredBox(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(typeIcon, color: Colors.white, size: 24),
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
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
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
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
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
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$remainingDays days left before permanent deletion',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        color: remainingDays <= 5
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.restore_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Restore',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.bgDivider),
                      backgroundColor: AppColors.bgSurfaceHover,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => controller.restoreItem(item),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Delete Forever',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () =>
                        controller.confirmPermanentDelete(context, item),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

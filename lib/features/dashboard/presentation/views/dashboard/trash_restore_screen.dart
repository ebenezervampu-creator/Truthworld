import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/theme/app_theme.dart';

class TrashRestoreController extends BaseController {
  TrashRestoreController({
    required String channelId,
    bool isConsumer = false,
  })  : _channelId = channelId,
        isConsumer = isConsumer.obs;

  final String _channelId;
  final RxBool isConsumer;

  void switchScope(bool consumer) {
    if (isConsumer.value == consumer) return;
    isConsumer.value = consumer;
    selectedFilter.value = 'All';
    loadTrashItems();
  }

  String get channelId {
    if (_channelId.isNotEmpty) return _channelId;
    if (Get.isRegistered<DashboardController>()) {
      final id = Get.find<DashboardController>().channelId;
      if (id.isNotEmpty) return id;
    }
    if (Get.isRegistered<AuthService>()) {
      final ch = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
      if (ch != null && ch.id.isNotEmpty) return ch.id;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  final RxString selectedFilter =
      'All'.obs; // 'All', 'Video', 'Topic', 'Playlist'
  final RxBool rxIsLoading = false.obs;
  final RxList<Map<String, dynamic>> trashItems = <Map<String, dynamic>>[].obs;
  final Set<String> _activeItemKeys = <String>{};
  bool _isEmptyingTrash = false;

  @override
  void onInit() {
    super.onInit();
    loadTrashItems();
  }

  void clearData() {
    trashItems.clear();
    rxIsLoading.value = false;
    _activeItemKeys.clear();
    _isEmptyingTrash = false;
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

      if (isConsumer.value) {
        // --- CONSUMER APP TRASH (Personal Library Scope) ---
        if (currentUid.isNotEmpty) {
          // 1. Fetch user's private playlists
          try {
            final userPlaylistsSnap = await firestore
                .collection(FirestoreCollections.users)
                .doc(currentUid)
                .collection(FirestoreCollections.playlists)
                .where('status', whereIn: ['deletion_pending', 'trashed'])
                .get();

            for (final doc in userPlaylistsSnap.docs) {
              if (doc.id == 'watchlater' ||
                  doc.id.toLowerCase().trim() == 'watch later') {
                continue;
              }
              final data = doc.data();
              loadedItems.add({
                'id': doc.id,
                'type': 'Playlist',
                'title': data['name'] ?? data['title'] ?? 'Untitled Playlist',
                'imageUrl': data['imageUrl'] ?? data['thumbnailUrl'] ?? '',
                'isPublic': false,
                'isUserPlaylist': true,
                'deletedAt':
                    (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                    (data['deletionPendingAt'] as Timestamp?)?.toDate() ??
                    (data['updatedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                'ref': doc.reference,
              });
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadUserPlaylists');
          }

          // 2. Fetch user's public playlists
          try {
            final publicPlaylistsSnap = await firestore
                .collection(FirestoreCollections.playlists)
                .where('ownerId', isEqualTo: currentUid)
                .where('status', whereIn: ['deletion_pending', 'trashed'])
                .get();

            for (final doc in publicPlaylistsSnap.docs) {
              if (doc.id == 'watchlater' ||
                  doc.id.toLowerCase().trim() == 'watch later') {
                continue;
              }
              if (loadedItems.any((item) => item['id'] == doc.id)) continue;
              final data = doc.data();
              loadedItems.add({
                'id': doc.id,
                'type': 'Playlist',
                'title': data['name'] ?? data['title'] ?? 'Untitled Playlist',
                'imageUrl': data['imageUrl'] ?? data['thumbnailUrl'] ?? '',
                'isPublic': true,
                'isUserPlaylist': false,
                'deletedAt':
                    (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                    (data['deletionPendingAt'] as Timestamp?)?.toDate() ??
                    (data['updatedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                'ref': doc.reference,
              });
            }
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.loadPublicPlaylists');
          }
        }
      } else {
        // --- CREATOR STUDIO TRASH (Channel & Creator Scope) ---
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
            if (doc.id == 'watchlater' ||
                doc.id.toLowerCase().trim() == 'watch later') {
              continue;
            }
            final data = doc.data() ?? {};
            loadedItems.add({
              'id': doc.id,
              'type': 'Playlist',
              'title': data['name'] ?? 'Untitled Playlist',
              'imageUrl': data['imageUrl'] ?? '',
              'isPublic': true,
              'isUserPlaylist': false,
              'deletedAt':
                  (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                  (data['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              'ref': doc.reference,
            });
          }
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

  /// Pushes a dedicated blocking loading dialog and returns an idempotent closer
  /// that removes only this dialog route (immune to open GetX snackbars).
  VoidCallback _openLoadingDialog() {
    final overlayCtx = Get.overlayContext;
    if (overlayCtx == null) return () {};
    final navigator = Navigator.of(overlayCtx, rootNavigator: true);
    final route = DialogRoute<void>(
      context: overlayCtx,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
    );
    navigator.push(route);
    var closed = false;
    return () {
      if (closed || !route.isActive) return;
      closed = true;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    };
  }

  void _showConfirmDeleteDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    Get.dialog<void>(
      Builder(
        builder: (dialogContext) => Dialog(
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
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.brandFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
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
                        Navigator.of(dialogContext).pop();
                        onConfirm();
                      },
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
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
      ),
    );
  }

  Future<void> _permanentlyDeleteEntry(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference?;
    final type = item['type'] as String? ?? '';
    final id = item['id'] as String? ?? '';

    if (type == 'Video') {
      await VideoManagementController.permanentlyDeleteVideoDoc(
        videoId: id,
        isShort: item['isShort'] == true,
        videoUrl: item['videoUrl'] as String? ?? '',
        thumbnailUrl: item['imageUrl'] as String? ?? '',
        originalUrl: item['originalUrl'] as String? ?? '',
      );
    } else if (docRef != null) {
      await docRef.delete();
      if (type == 'Playlist' && item['isUserPlaylist'] == true) {
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.playlists)
              .doc(id)
              .delete();
        } catch (_) {}
      } else if (type == 'Post') {
        final img = item['imageUrl'] as String? ?? '';
        if (img.isNotEmpty) {
          await VideoManagementController.safeDeleteStorageUrl(img);
        }
      }
    }
  }

  Future<void> restoreItem(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference;
    final type = item['type'] as String;
    final id = item['id'] as String? ?? '';
    final itemKey = '${type}_$id';
    if (_isEmptyingTrash || !_activeItemKeys.add(itemKey)) return;

    final closeLoading = _openLoadingDialog();

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
            closeLoading();
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
        final isUserPlaylist = item['isUserPlaylist'] == true;
        updateFields['status'] = isUserPlaylist ? 'private' : 'active';
        updateFields['deletionPendingAt'] = FieldValue.delete();
        updateFields['deletionRequestedAt'] = FieldValue.delete();
        updateFields['permanentDeletionAt'] = FieldValue.delete();

        if (isUserPlaylist) {
          try {
            await FirebaseFirestore.instance
                .collection(FirestoreCollections.playlists)
                .doc(item['id'] as String)
                .update({
              'status': 'active',
              'deletionRequestedAt': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      } else if (type == 'Post') {
        updateFields['status'] = 'published';
        updateFields['visibility'] = 'Public';
      }

      await docRef.update(updateFields);
      trashItems.removeWhere((e) => e['id'] == id && e['type'] == type);

      closeLoading();

      AppSnackbar.success(
        '${item['title']} has been successfully restored.',
      );

      // Reload list
      loadTrashItems();
    } catch (e) {
      closeLoading();
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to restore item. Please try again.',
      );
    } finally {
      _activeItemKeys.remove(itemKey);
      closeLoading();
    }
  }

  void confirmPermanentDelete(BuildContext context, Map<String, dynamic> item) {
    final itemKey = '${item['type']}_${item['id']}';
    if (_isEmptyingTrash || _activeItemKeys.contains(itemKey)) return;

    _showConfirmDeleteDialog(
      title: 'Delete Permanently?',
      message:
          "Are you sure you want to permanently delete '${item['title']}'? This action cannot be undone and media assets will be destroyed.",
      confirmLabel: 'Delete Forever',
      onConfirm: () => permanentlyDeleteItem(item),
    );
  }

  Future<void> permanentlyDeleteItem(Map<String, dynamic> item) async {
    final type = item['type'] as String? ?? '';
    final id = item['id'] as String? ?? '';
    final itemKey = '${type}_$id';
    if (_isEmptyingTrash || !_activeItemKeys.add(itemKey)) return;

    final closeLoading = _openLoadingDialog();

    try {
      await _permanentlyDeleteEntry(item);
      trashItems.removeWhere((e) => e['id'] == id && e['type'] == type);

      closeLoading();
      AppSnackbar.success(
        "'${item['title']}' has been permanently deleted.",
      );
      loadTrashItems();
    } catch (e, s) {
      closeLoading();
      ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.permanentlyDeleteItem');
      AppSnackbar.error(
        'Unable to permanently delete item. Please try again.',
      );
    } finally {
      _activeItemKeys.remove(itemKey);
      closeLoading();
    }
  }

  Future<void> emptyAllTrash() async {
    if (trashItems.isEmpty || _isEmptyingTrash) return;
    _isEmptyingTrash = true;

    final closeLoading = _openLoadingDialog();

    try {
      final itemsToDelete = List<Map<String, dynamic>>.from(trashItems);
      for (final item in itemsToDelete) {
        await _permanentlyDeleteEntry(item);
      }
      trashItems.clear();

      closeLoading();
      AppSnackbar.success('All trash items have been permanently deleted.');
      loadTrashItems();
    } catch (e, s) {
      closeLoading();
      ErrorHandler.log(e, stackTrace: s, tag: 'TrashRestore.emptyAllTrash');
      AppSnackbar.error('Unable to empty trash completely. Please try again.');
      loadTrashItems();
    } finally {
      _isEmptyingTrash = false;
      closeLoading();
    }
  }

  void confirmEmptyTrash(BuildContext context) {
    if (trashItems.isEmpty || _isEmptyingTrash) return;

    _showConfirmDeleteDialog(
      title: 'Empty ${isConsumer.value ? "Personal Trash" : "Trash"}?',
      message:
          'Are you sure you want to permanently delete all ${trashItems.length} items in ${isConsumer.value ? "Personal Trash" : "trash"}? This action cannot be undone.',
      confirmLabel: 'Empty Trash',
      onConfirm: emptyAllTrash,
    );
  }

  int getRemainingDays(DateTime deletedAt) {
    final difference = DateTime.now().difference(deletedAt);
    final remaining = 30 - difference.inDays;
    return remaining.clamp(0, 30);
  }
}

class TrashRestoreScreen extends StatelessWidget {
  const TrashRestoreScreen({
    this.channelId = '',
    this.isDarkMode = true,
    this.isConsumer = false,
    this.searchQuery = '',
    this.showBackButton = false,
    this.isStudioContentTab = false,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;
  final bool isConsumer;
  final String searchQuery;
  final bool showBackButton;
  final bool isStudioContentTab;

  @override
  Widget build(BuildContext context) {
    final effectiveIsConsumer = !isStudioContentTab && isConsumer;
    final tag = channelId.isNotEmpty
        ? channelId
        : (effectiveIsConsumer ? 'consumer_trash' : 'studio_trash');
    final controller = Get.isRegistered<TrashRestoreController>(tag: tag)
        ? Get.find<TrashRestoreController>(tag: tag)
        : Get.put(
            TrashRestoreController(
              channelId: channelId,
              isConsumer: effectiveIsConsumer,
            ),
            tag: tag,
          );

    if (isStudioContentTab && controller.isConsumer.value) {
      controller.switchScope(false);
    }

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, pageConstraints) {
            final isMobile = pageConstraints.maxWidth < 600;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isStudioContentTab) ...[
                    // Responsive Header
                    Obx(() {
                      final isCons = controller.isConsumer.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (showBackButton && Navigator.canPop(context)) ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.arrow_back_rounded,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  isCons
                                                      ? 'Personal Trash'
                                                      : 'Creator Studio Trash',
                                                  style: TextStyle(
                                                    fontFamily: TWTypography.brandFamily,
                                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                                    fontSize: isMobile ? 22 : 26,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? AppColors.textPrimary
                                                        : Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isCons
                                                      ? AppColors.info.withValues(alpha: 0.15)
                                                      : AppColors.brandVariant.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isCons
                                                        ? AppColors.info.withValues(alpha: 0.4)
                                                        : AppColors.brandVariant.withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Text(
                                                  isCons ? 'Personal Library' : 'Creator Studio',
                                                  style: TextStyle(
                                                    fontFamily: TWTypography.uiFamily,
                                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                                    color: isCons ? AppColors.info : AppColors.brandVariant,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isCons
                                                ? 'Playlists and items deleted from your personal library are retained for 30 days before permanent deletion.'
                                                : 'Deleted videos, community posts, topics, and playlists are retained for 30 days before permanent deletion.',
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              fontFamilyFallback: TWTypography.fallbackFamilies,
                                              fontSize: isMobile ? 13 : 14,
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (controller.trashItems.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_sweep_rounded,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () => controller.confirmEmptyTrash(context),
                                      tooltip: 'Empty All Trash',
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    onPressed: controller.loadTrashItems,
                                    tooltip: 'Refresh Trash Bin',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildScopeSwitcher(controller),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Filters Row
                  _buildFiltersRow(controller, context),
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
                        return _buildEmptyState(controller);
                      }

                      return _buildTrashItemsList(controller, filteredList);
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScopeSwitcher(TrashRestoreController controller) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScopeTabButton(
              label: 'Personal Library Trash',
              icon: Icons.person_outline_rounded,
              isSelected: controller.isConsumer.value,
              onTap: () => controller.switchScope(true),
            ),
            const SizedBox(width: 4),
            _buildScopeTabButton(
              label: 'Creator Studio Trash',
              icon: Icons.video_settings_rounded,
              isSelected: !controller.isConsumer.value,
              onTap: () => controller.switchScope(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final fgColor = isSelected
        ? (isDarkMode ? Colors.black87 : Colors.white)
        : (isDarkMode ? AppColors.textSecondary : Colors.black54);
    final bgColor = isSelected
        ? (isDarkMode ? Colors.white : Colors.black87)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow(TrashRestoreController controller, BuildContext context) {
    return Obx(() {
      final filters = controller.isConsumer.value
          ? ['All', 'Playlist']
          : ['All', 'Video', 'Post', 'Topic', 'Playlist'];

      final filterChips = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
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
          }).toList(),
        ),
      );

      if (!isStudioContentTab) {
        return filterChips;
      }

      return Row(
        children: [
          Expanded(child: filterChips),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.trashItems.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.error,
                  ),
                  onPressed: () => controller.confirmEmptyTrash(context),
                  tooltip: 'Empty All Trash',
                ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: controller.loadTrashItems,
                tooltip: 'Refresh Trash Bin',
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildEmptyState(TrashRestoreController controller) {
    final isCons = controller.isConsumer.value;
    final emptyTitle = isCons
        ? 'Personal Trash is Empty'
        : (isStudioContentTab ? 'Trash is Empty' : 'Creator Studio Trash is Empty');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgSurface : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 72,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            emptyTitle,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isCons
                  ? 'No deleted playlists found in your personal library. Playlists moved to trash will appear here for 30 days.'
                  : 'No recently deleted videos, topics, posts, or channel playlists match the selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 14,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;

              // Build Thumbnail
              final thumbnailWidget = ClipRRect(
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
                            child: Icon(
                              typeIcon,
                              color: isDarkMode ? Colors.white : Colors.black87,
                              size: 24,
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(
                            typeIcon,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                        ),
                ),
              );

              // Build Details Column
              final detailsWidget = Column(
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
                          item['isUserPlaylist'] == true
                              ? 'Personal Playlist'
                              : type,
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
                      Expanded(
                        child: Text(
                          'Deleted on ${DateFormat('MMM d, yyyy').format(deletedAt)}',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            color: isDarkMode
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    maxLines: 2,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );

              // Build Action Buttons
              final actionButtons = <Widget>[
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.restore_rounded,
                    size: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  label: Text(
                    'Restore',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                    side: BorderSide(
                      color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                    ),
                    backgroundColor: isDarkMode ? AppColors.bgSurfaceHover : Colors.grey.shade100,
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
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        thumbnailWidget,
                        const SizedBox(width: 12),
                        Expanded(child: detailsWidget),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actionButtons,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  thumbnailWidget,
                  const SizedBox(width: 16),
                  Expanded(child: detailsWidget),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actionButtons,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

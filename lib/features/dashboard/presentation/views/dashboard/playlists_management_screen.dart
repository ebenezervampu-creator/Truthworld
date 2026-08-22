import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaylistsManagementScreen extends StatefulWidget {
  const PlaylistsManagementScreen({
    super.key,
    this.channelId,
    this.isDarkMode = true,
  });

  final String? channelId;
  final bool isDarkMode;

  @override
  State<PlaylistsManagementScreen> createState() =>
      _PlaylistsManagementScreenState();
}

class _PlaylistsManagementScreenState extends State<PlaylistsManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  String get activeChannelId {
    if (widget.channelId != null && widget.channelId!.isNotEmpty) {
      return widget.channelId!;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Stream<List<PlaylistModel>> _playlistsStream() {
    if (activeChannelId.isEmpty) return const Stream.empty();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return _firestore
        .collection(FirestoreCollections.playlists)
        .where('channelId', isEqualTo: activeChannelId)
        .snapshots()
        .asyncMap((channelSnap) async {
          final itemsMap = <String, PlaylistModel>{};
          for (final doc in channelSnap.docs) {
            itemsMap[doc.id] = PlaylistModel.fromDocumentSnapshot(doc);
          }

          if (currentUid.isNotEmpty && currentUid != activeChannelId) {
            final ownerSnap = await _firestore
                .collection(FirestoreCollections.playlists)
                .where('ownerId', isEqualTo: currentUid)
                .get();
            for (final doc in ownerSnap.docs) {
              itemsMap[doc.id] = PlaylistModel.fromDocumentSnapshot(doc);
            }
          }

          final list = itemsMap.values.toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textSecondary,
      appBar: AppBar(
        title: Text(
          'Playlists Management',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context, isDarkMode),
              icon: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text('New Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _searchQuery.value = val.trim().toLowerCase(),
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Search playlists by name or description...',
                hintStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black,
                ),
                suffixIcon: Obx(
                  () => _searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery.value = '';
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),

          // Playlist List Stream
          Expanded(
            child: StreamBuilder<List<PlaylistModel>>(
              stream: _playlistsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading playlists: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final allPlaylists = snapshot.data ?? [];

                return Obx(() {
                  final query = _searchQuery.value;
                  final playlists = query.isEmpty
                      ? allPlaylists
                      : allPlaylists
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(query) ||
                                  p.description.toLowerCase().contains(query),
                            )
                            .toList();

                  if (playlists.isEmpty) {
                    return _buildEmptyState(isDarkMode, query.isNotEmpty);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: playlists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return _buildPlaylistCard(playlist, isDarkMode);
                    },
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(PlaylistModel playlist, bool isDarkMode) {
    final visibilityColor = playlist.visibility == PlaylistVisibility.public
        ? Colors.green
        : (playlist.visibility == PlaylistVisibility.unlisted
              ? Colors.orange
              : Colors.grey);

    return Card(
      elevation: 0,
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail / Icon
            Container(
              width: 90,
              height: 60,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgInput : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: playlist.thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.playlist_play_rounded,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name.isNotEmpty
                        ? playlist.name
                        : 'Untitled Playlist',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.description.isNotEmpty
                        ? playlist.description
                        : 'No description provided.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: visibilityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: visibilityColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          playlist.visibility.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: visibilityColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${playlist.videoIds.length} videos',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
              onSelected: (action) {
                if (action == 'edit') {
                  _showEditPlaylistDialog(context, playlist, isDarkMode);
                } else if (action == 'videos') {
                  _showManageVideosDialog(context, playlist, isDarkMode);
                } else if (action == 'delete') {
                  _confirmDeletePlaylist(context, playlist);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Edit Metadata'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'videos',
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_collection_outlined,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Manage & Reorder Videos'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete Playlist',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, bool isSearch) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_play_rounded,
            size: 64,
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch
                ? 'No matching playlists found'
                : 'No playlists created yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Try searching with a different term.'
                : 'Group your channel videos into playlists to help viewers discover your content.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isSearch) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context, isDarkMode),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Create Your First Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, bool isDarkMode) {
    Get.toNamed('/create-playlist');
  }

  void _showEditPlaylistDialog(
    BuildContext context,
    PlaylistModel playlist,
    bool isDarkMode,
  ) {
    final titleController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description);
    final selectedVisibility = playlist.visibility.obs;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Obx(() {
          return AlertDialog(
            backgroundColor: isDarkMode
                ? AppColors.bgSurface
                : AppColors.textPrimary,
            title: Text(
              'Edit Playlist',
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Playlist Name',
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgInput
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgInput
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlaylistVisibility>(
                  value: selectedVisibility.value,
                  dropdownColor: isDarkMode
                      ? AppColors.bgSurface
                      : AppColors.textPrimary,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Visibility',
                    labelStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgInput
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: PlaylistVisibility.values.map((vis) {
                    return DropdownMenuItem(
                      value: vis,
                      child: Text(vis.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedVisibility.value = val;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
                ElevatedButton(
                  onPressed: () async {
                    final name = titleController.text.trim();
                    if (name.isEmpty) return;

                    final nameVal = ContentValidator.validate(
                      name,
                      fieldName: 'Playlist Name',
                    );
                    if (!nameVal.isValid) {
                      Get.snackbar(
                        'Inappropriate Content',
                        nameVal.message,
                        backgroundColor: AppColors.error,
                        colorText: AppColors.textPrimary,
                      );
                      return;
                    }

                    final description = descController.text.trim();
                    if (description.isNotEmpty) {
                      final descVal = ContentValidator.validate(
                        description,
                        fieldName: 'Playlist Description',
                      );
                      if (!descVal.isValid) {
                        Get.snackbar(
                          'Inappropriate Content',
                          descVal.message,
                          backgroundColor: AppColors.error,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }
                    }

                    await _firestore
                        .collection(FirestoreCollections.playlists)
                        .doc(playlist.id)
                        .update({
                          'name': name,
                          'playlistName': name,
                          'description': description,
                          'visibility': selectedVisibility.value.name,
                          'isPublic':
                              selectedVisibility.value == PlaylistVisibility.public,
                          'updatedAt': Timestamp.now(),
                        });

                    if (context.mounted) Navigator.pop(ctx);
                    Get.snackbar(
                      'Updated',
                      'Playlist updated successfully.',
                      backgroundColor: AppColors.success,
                      colorText: AppColors.textPrimary,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageVideosDialog(
    BuildContext context,
    PlaylistModel playlist,
    bool isDarkMode,
  ) {
    final rxVideoIds = List<String>.from(playlist.videoIds).obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final videoIds = rxVideoIds.toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reorder & Manage Videos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Drag items to reorder or remove videos from "${playlist.name}".',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (videoIds.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No videos currently added to this playlist.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: videoIds.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = rxVideoIds.removeAt(oldIndex);
                        rxVideoIds.insert(newIndex, item);
                      },
                      itemBuilder: (context, index) {
                        final vId = videoIds[index];
                        return Card(
                          key: ValueKey(vId),
                          color: isDarkMode
                              ? AppColors.bgInput
                              : const Color(0xFFF1F5F9),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.drag_handle_rounded,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black,
                            ),
                            title: Text(
                              'Video ID: $vId',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                rxVideoIds.removeAt(index);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _firestore
                          .collection(FirestoreCollections.playlists)
                          .doc(playlist.id)
                          .update({
                            'videoIds': rxVideoIds.toList(),
                            'videoCount': rxVideoIds.length,
                            'updatedAt': Timestamp.now(),
                          });
                      if (context.mounted) Navigator.pop(ctx);
                      Get.snackbar(
                        'Saved',
                        'Playlist order updated successfully.',
                        backgroundColor: AppColors.success,
                        colorText: AppColors.textPrimary,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Order & Changes'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistModel playlist) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        title: Text(
          'Delete Playlist?',
          style: TextStyle(
            color: widget.isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
          style: TextStyle(
            color: widget.isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore
                  .collection(FirestoreCollections.playlists)
                  .doc(playlist.id)
                  .delete();
              if (context.mounted) Navigator.pop(ctx);
              Get.snackbar(
                'Deleted',
                'Playlist deleted.',
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

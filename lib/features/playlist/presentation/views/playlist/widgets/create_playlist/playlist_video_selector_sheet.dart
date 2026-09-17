import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for browsing and selecting videos to add to a playlist.
class PlaylistVideoSelectorSheet extends StatelessWidget {
  PlaylistVideoSelectorSheet({
    required this.currentlySelected,
    required this.onConfirm,
    super.key,
  }) {
    _selectedVideos.assignAll(currentlySelected);
    _fetchUserVideos();
  }

  final List<Video> currentlySelected;
  final ValueChanged<List<Video>> onConfirm;

  final RxList<Video> _selectedVideos = <Video>[].obs;
  final RxList<Video> _allVideos = <Video>[].obs;
  final RxBool _isLoading = true.obs;
  final RxString _searchQuery = ''.obs;

  Future<void> _fetchUserVideos() async {
    _isLoading.value = true;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final userChannelId = Get.isRegistered<AuthService>()
          ? (AuthService.to.userChannel?.id ?? '')
          : '';

      final targetIds = <String>{};
      if (currentUid.isNotEmpty) targetIds.add(currentUid);
      if (userChannelId.isNotEmpty) targetIds.add(userChannelId);

      final videos = <Video>[];
      final seenIds = <String>{};

      void addVideoDocs(Iterable<QueryDocumentSnapshot> docs) {
        for (final doc in docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            try {
              final video = Video.fromDocumentSnapshot(doc);
              videos.add(video);
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'PlaylistVideoSelectorSheet.parseVideoDoc',
              );
            }
          }
        }
      }

      for (final id in targetIds) {
        try {
          final q1 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: id)
              .get();
          addVideoDocs(q1.docs);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'PlaylistVideoSelectorSheet.queryChannelVideos',
          );
        }

        try {
          final q2 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: id)
              .get();
          addVideoDocs(q2.docs);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'PlaylistVideoSelectorSheet.queryOwnerVideos',
          );
        }

        try {
          final q3 = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: id)
              .get();
          addVideoDocs(q3.docs);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'PlaylistVideoSelectorSheet.queryUserVideos',
          );
        }

        try {
          final qSub = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .doc(id)
              .collection(FirestoreCollections.videos)
              .get();
          addVideoDocs(qSub.docs);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'PlaylistVideoSelectorSheet.querySubcollectionVideos',
          );
        }
      }

      // Sort newest videos first
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _allVideos.assignAll(videos);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistVideoSelectorSheet.loadUserVideos',
      );
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Videos',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Row(
                children: [
                  Obx(() {
                    if (_allVideos.isEmpty) return const SizedBox.shrink();
                    final allSelected =
                        _selectedVideos.length == _allVideos.length;
                    return TextButton(
                      onPressed: () {
                        if (allSelected) {
                          _selectedVideos.clear();
                        } else {
                          _selectedVideos.assignAll(_allVideos);
                        }
                      },
                      child: Text(
                        allSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      onConfirm(_selectedVideos.toList());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Obx(() {
                      return Text(
                        'Done (${_selectedVideos.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => _searchQuery.value = val.trim().toLowerCase(),
            inputFormatters: [TruthworldTextInputFormatters.englishOnly],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search videos...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              fillColor: const Color(0xFF161618),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final query = _searchQuery.value;
              final displayVideos = query.isEmpty
                  ? _allVideos
                  : _allVideos
                      .where((v) =>
                          v.title.toLowerCase().contains(query) ||
                          v.description.toLowerCase().contains(query))
                      .toList();

              if (displayVideos.isEmpty) {
                return const Center(
                  child: Text(
                    'No videos found in your channel',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: displayVideos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final video = displayVideos[index];
                  return Obx(() {
                    final isChecked =
                        _selectedVideos.any((v) => v.id == video.id);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isChecked) {
                            _selectedVideos
                                .removeWhere((v) => v.id == video.id);
                          } else {
                            _selectedVideos.add(video);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? const Color(0xFF222226)
                                : const Color(0xFF161618),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChecked
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isChecked ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        width: 60,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 60,
                                          height: 36,
                                          color: Colors.grey[800],
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 36,
                                        color: Colors.grey[800],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      video.duration.isNotEmpty
                                          ? video.duration
                                          : '${video.views} views',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? const Color(0xFF27272A)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isChecked
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

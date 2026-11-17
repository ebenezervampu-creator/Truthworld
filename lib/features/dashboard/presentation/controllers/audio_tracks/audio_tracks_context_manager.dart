import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Manages creator video context, real-time Firestore listeners, search filtering, and active video pointer.
class AudioTracksContextManager {
  static const String _tag = 'AudioTracksContextManager';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Active Context
  final RxString channelId = ''.obs;

  // Video feed stream states
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;
  final Rxn<Video> selectedVideo = Rxn<Video>();

  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _channelVideosSubscription;
  final Map<String, Video> _ownerVideosMap = {};
  final Map<String, Video> _channelVideosMap = {};

  /// Injects or updates channel navigation workspace context dynamically.
  void setChannelContext(
    String id, {
    required void Function(ViewState state) onViewStateChanged,
  }) {
    if (id.isNotEmpty && channelId.value != id) {
      channelId.value = id;
      listenToChannelVideos(onViewStateChanged: onViewStateChanged);
    }
  }

  /// Initializes base context by resolving channel for authenticated user.
  Future<void> initializeContext({
    required void Function(ViewState state) onViewStateChanged,
    required void Function(String error) onError,
  }) async {
    onViewStateChanged(ViewState.loading);
    final user = _auth.currentUser;
    if (user == null) {
      onError('User not authenticated');
      return;
    }

    _firestore
        .collection(FirestoreCollections.channels)
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            channelId.value = snapshot.docs.first.id;
          }
          listenToChannelVideos(onViewStateChanged: onViewStateChanged);
        })
        .catchError((e) {
          logger.error(
            'Failed to load base creator channel for audio tracks',
            error: e,
            tag: _tag,
          );
          listenToChannelVideos(onViewStateChanged: onViewStateChanged);
        });
  }

  /// Listens to owner and channel video documents and applies chronological sorting.
  void listenToChannelVideos({
    required void Function(ViewState state) onViewStateChanged,
  }) {
    final currentUser = _auth.currentUser;
    final targetOwnerId = currentUser?.uid ?? '';
    final targetChannelId = channelId.value;

    if (targetOwnerId.isEmpty && targetChannelId.isEmpty) {
      onViewStateChanged(ViewState.empty);
      return;
    }

    onViewStateChanged(ViewState.loading);
    _videosSubscription?.cancel();
    _channelVideosSubscription?.cancel();
    _ownerVideosMap.clear();
    _channelVideosMap.clear();

    void updateVideosList() {
      final combinedMap = <String, Video>{
        ..._ownerVideosMap,
        ..._channelVideosMap,
      };
      final loadedList = combinedMap.values.toList();

      // Stable local chronological sorting by upload recency
      loadedList.sort((a, b) {
        final tA = a.uploadedAt.toDate();
        final tB = b.uploadedAt.toDate();
        return tB.compareTo(tA);
      });

      videos.value = loadedList;
      applySearchFilter();

      // Maintain active video pointer synchronization across snapshot sync events
      if (selectedVideo.value != null) {
        final updatedPointer = loadedList.firstWhereOrNull(
          (v) => v.id == selectedVideo.value!.id,
        );
        if (updatedPointer != null) {
          selectedVideo.value = updatedPointer;
        }
      }

      onViewStateChanged(
        loadedList.isEmpty ? ViewState.empty : ViewState.success,
      );
    }

    if (targetOwnerId.isNotEmpty) {
      _videosSubscription = _firestore
          .collection(FirestoreCollections.videos)
          .where('ownerId', isEqualTo: targetOwnerId)
          .snapshots()
          .listen(
            (snapshot) {
              _ownerVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                _ownerVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error(
                'Failed streaming owner items for audio tracks module',
                error: e,
                tag: _tag,
              );
              if (_channelVideosMap.isEmpty) {
                onViewStateChanged(ViewState.error);
              }
            },
          );
    }

    if (targetChannelId.isNotEmpty && targetChannelId != targetOwnerId) {
      _channelVideosSubscription = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: targetChannelId)
          .snapshots()
          .listen(
            (snapshot) {
              _channelVideosMap.clear();
              for (final doc in snapshot.docs) {
                final video = Video.fromDocumentSnapshot(doc);
                _channelVideosMap[video.id] = video;
              }
              updateVideosList();
            },
            onError: (e) {
              logger.error(
                'Failed streaming channel items for audio tracks module',
                error: e,
                tag: _tag,
              );
            },
          );
    }
  }

  /// Sets search query and applies filter.
  void setSearchQuery(String query) {
    searchQuery.value = query;
    applySearchFilter();
  }

  /// Filters videos by title, description, or tags based on search query.
  void applySearchFilter() {
    if (searchQuery.value.trim().isEmpty) {
      filteredVideos.value = videos;
      return;
    }
    final q = searchQuery.value.toLowerCase().trim();
    filteredVideos.value =
        videos.where((v) {
          return v.title.toLowerCase().contains(q) ||
              v.description.toLowerCase().contains(q) ||
              v.tags.any((t) => t.toLowerCase().contains(q));
        }).toList();
  }

  /// Selects active video for editing session.
  Future<void> selectVideo(
    Video? video, {
    required Future<void> Function(Video? video) onVideoSelected,
    bool force = false,
  }) async {
    if (!force && video != null && selectedVideo.value?.id == video.id) {
      return;
    }
    selectedVideo.value = video;
    await onVideoSelected(video);
  }

  /// Cancels video streams.
  void dispose() {
    unawaited(_videosSubscription?.cancel());
    unawaited(_channelVideosSubscription?.cancel());
    _videosSubscription = null;
    _channelVideosSubscription = null;
  }
}

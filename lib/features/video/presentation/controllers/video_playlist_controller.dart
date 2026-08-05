import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

class VideoPlaylistController extends BaseController {
  final Rx<PlaylistModel?> currentPlaylist = Rx<PlaylistModel?>(null);
  final RxList<Video> playlistVideos = <Video>[].obs;
  final RxInt currentPlaylistIndex = 0.obs;
  final RxBool isPlaylistLooping = false.obs;
  final RxBool isPlaylistShuffled = false.obs;
  final RxBool showPlaylistDrawer = true.obs;

  void togglePlaylistLoop() {
    isPlaylistLooping.value = !isPlaylistLooping.value;
  }

  void togglePlaylistShuffle() {
    isPlaylistShuffled.value = !isPlaylistShuffled.value;
  }

  void togglePlaylistDrawer() {
    showPlaylistDrawer.value = !showPlaylistDrawer.value;
  }

  Future<void> loadPlaylist(PlaylistModel playlist) async {
    currentPlaylist.value = playlist;
    await fetchPlaylistVideos();
  }

  Future<void> fetchPlaylistVideos() async {
    if (currentPlaylist.value == null || currentPlaylist.value!.videoIds.isEmpty) {
      return;
    }

    try {
      final ids = currentPlaylist.value!.videoIds;
      final fetchedVideos = <Video>[];

      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        fetchedVideos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
      }

      // Restore original playlist order
      fetchedVideos.sort(
        (a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)),
      );

      playlistVideos.value = fetchedVideos;

      if (Get.isRegistered<VideoController>()) {
        final videoController = Get.find<VideoController>();
        final activeIndex = fetchedVideos.indexWhere((v) => v.id == videoController.video.id);
        currentPlaylistIndex.value = activeIndex != -1 ? activeIndex : 0;
      } else {
        currentPlaylistIndex.value = 0;
      }
    } catch (e) {
      debugPrint('Error fetching full playlist videos: $e');
    }
  }

  void playNextPlaylistVideo() {
    if (playlistVideos.isEmpty) return;

    int nextIndex;
    if (isPlaylistShuffled.value && playlistVideos.length > 1) {
      final random = DateTime.now().millisecondsSinceEpoch;
      final seed = random % 1000000;
      final rng = (seed * 1103515245 + 12345) & 0x7fffffff;
      nextIndex = rng % playlistVideos.length;

      if (nextIndex == currentPlaylistIndex.value) {
        nextIndex = (nextIndex + 1) % playlistVideos.length;
      }
    } else {
      nextIndex = currentPlaylistIndex.value + 1;
      if (nextIndex >= playlistVideos.length) {
        if (isPlaylistLooping.value) {
          nextIndex = 0;
        } else {
          return; // Reached the end
        }
      }
    }
    playPlaylistVideoAtIndex(nextIndex);
  }

  void playPreviousPlaylistVideo() {
    if (playlistVideos.isNotEmpty && currentPlaylistIndex.value > 0) {
      final prevIndex = currentPlaylistIndex.value - 1;
      playPlaylistVideoAtIndex(prevIndex);
    }
  }

  void playPlaylistVideoAtIndex(int index) {
    if (index < 0 || index >= playlistVideos.length) return;

    currentPlaylistIndex.value = index;
    final nextVideo = playlistVideos[index];

    if (Get.isRegistered<VideoController>()) {
      final videoController = Get.find<VideoController>();
      videoController.rxVideo.value = nextVideo;
      videoController.handleVideoTransition(nextVideo);
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Fetches videos belonging to a playlist using Firestore batches in ordered sequence.
Future<List<Video>> fetchPlaylistVideos(PlaylistModel playlist) async {
  try {
    var videoIds = <String>[];

    if (Get.isRegistered<PlaylistController>()) {
      final playlistController = Get.find<PlaylistController>();
      videoIds = await playlistController.fetchPlaylistVideoIds(
        playlist.id,
        playlist.isPublic,
        ownerId: playlist.ownerId,
      );
    }

    if (videoIds.isEmpty && playlist.videoIds.isNotEmpty) {
      videoIds = playlist.videoIds;
    }

    if (videoIds.isEmpty) return [];

    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += batchSize) {
      batches.add(videoIds.skip(i).take(batchSize).toList());
    }

    final snapshots = await Future.wait(
      batches.map(
        (batch) => FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: batch)
            .getCacheFirst(),
      ),
    );

    final videos = <Video>[];
    for (final snapshot in snapshots) {
      videos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
    }

    final videoMap = {for (final v in videos) v.id: v};
    return videoIds.map((id) => videoMap[id]).whereType<Video>().toList();
  } catch (e, s) {
    ErrorHandler.log(
      e,
      stackTrace: s,
      tag: 'PlaylistDetailScreen._fetchPlaylistVideos',
    );
    return [];
  }
}

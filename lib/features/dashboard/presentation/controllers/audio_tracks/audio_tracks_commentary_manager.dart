import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Manages batch uploading and deletion of multi-angle, director/actor commentaries, and BTS tracks.
class AudioTracksCommentaryManager with ContentValidationMixin {
  static const String _tag = 'AudioTracksCommentaryManager';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads multiple commentary and multi-track files together in a batch.
  Future<bool> uploadMultipleTrackFiles({
    required List<BatchTrackUploadConfig> items,
    required Video? selectedVideo,
    required void Function(double progress) onProgressUpdate,
    required void Function(String status) onStatusUpdate,
    required void Function(List<CommentaryTrackItem> list) onCommentaryUpdated,
    required void Function(String langCode, Map<String, String> audioMap)
    onLanguageSynced,
    required VoidCallback onVideoRefreshed,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    final video = selectedVideo;
    if (video == null) {
      onShowError('No video selected.');
      return false;
    }

    if (items.isEmpty) {
      onShowError('No files selected for batch upload.');
      return false;
    }

    // Validation check on all titles
    for (final item in items) {
      final validationResult = await validateContent(
        item.title,
        fieldName: 'Track Title',
      );
      if (!validationResult.isValid) {
        onShowError('Item "${item.title}": ${validationResult.message}');
        return false;
      }
    }

    onProgressUpdate(0.0);
    onStatusUpdate('Preparing batch upload of ${items.length} track(s)...');

    var completed = 0;
    final total = items.length;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final updatedCommentaryMap = Map<String, Map<String, String>>.from(
        cachedLoc?.commentaryVideos ?? {},
      );
      final updatedAudioMap = Map<String, String>.from(
        cachedLoc?.audioTracks ?? video.audioTracks,
      );
      final updatedDubbedMap = Map<String, String>.from(
        cachedLoc?.dubbedVideos ?? video.dubbedVideos,
      );

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        item.status = 'Uploading...';
        onStatusUpdate('Uploading (${i + 1}/$total): ${item.title}');

        final file = item.file;
        final fileBytes =
            file.bytes ??
            (file.path != null ? await file.xFile.readAsBytes() : null);
        if (fileBytes == null) {
          item.status = 'Failed (read error)';
          continue;
        }

        final ext = file.extension ?? (item.type == 'Audio' ? 'mp3' : 'mp4');
        final fileName =
            '${item.langCode}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final storageRef = FirebaseStorage.instance.ref().child(
          'videos/${video.id}/tracks/$fileName',
        );

        final metadata = SettableMetadata(
          contentType: item.type == 'Audio' ? 'audio/$ext' : 'video/$ext',
          customMetadata: {
            'uploaderId': ?currentUid,
            'title': item.title,
            'role': item.role,
            'langCode': item.langCode,
            'type': item.type,
          },
        );

        final uploadTask = storageRef.putData(fileBytes, metadata);
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.totalBytes > 0) {
              item.progress = snapshot.bytesTransferred / snapshot.totalBytes;
              final overallProgress = (completed + item.progress) / total;
              onProgressUpdate(overallProgress);
            }
          },
          onError: (error, stackTrace) {
            logger.error(
              'Batch upload snapshot event failed',
              error: error,
              stackTrace: stackTrace,
              tag: _tag,
            );
          },
        );

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        final trackId = 'track_${DateTime.now().millisecondsSinceEpoch}_$i';

        if (item.role.toLowerCase().contains('commentary') ||
            item.role.toLowerCase().contains('behind') ||
            item.role.toLowerCase().contains('angle') ||
            item.role.toLowerCase().contains('reaction') ||
            item.role.toLowerCase().contains('actor') ||
            item.role.toLowerCase().contains('director')) {
          updatedCommentaryMap[trackId] = {
            'id': trackId,
            'title': item.title,
            'role': item.role,
            'videoUrl': item.type == 'Video' ? downloadUrl : '',
            'audioUrl': item.type == 'Audio' ? downloadUrl : '',
            'langCode': item.langCode,
            'uploadedAt': DateTime.now().toIso8601String(),
            'fileSizeMB': (file.size / (1024 * 1024)).toStringAsFixed(2),
          };
        } else if (item.type == 'Audio') {
          updatedAudioMap[item.langCode] = downloadUrl;
        } else {
          updatedDubbedMap[item.langCode] = downloadUrl;
        }

        item.status = 'Completed';
        completed++;
        onProgressUpdate(completed / total);
      }

      onStatusUpdate('Saving references to cloud...');

      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': video.mediaSubtitles,
            'dubbedVideos': updatedDubbedMap,
            'audioTracks': updatedAudioMap,
            'commentaryVideos': updatedCommentaryMap,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: video.mediaSubtitles,
        dubbedVideos: updatedDubbedMap,
        audioTracks: updatedAudioMap,
        commentaryVideos: updatedCommentaryMap,
      );

      final commentaryList = <CommentaryTrackItem>[];
      updatedCommentaryMap.forEach((key, map) {
        commentaryList.add(CommentaryTrackItem.fromMap(key, map));
      });
      onCommentaryUpdated(commentaryList);

      for (final item in items) {
        onLanguageSynced(item.langCode, updatedAudioMap);
      }

      onVideoRefreshed();
      onShowSuccess('Successfully uploaded $completed track(s) in batch!');
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed executing batch upload',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      onShowError('Unable to complete batch upload. Please try again.');
      return false;
    }
  }

  /// Removes an attached commentary or perspective video track.
  Future<void> deleteCommentaryTrack({
    required String trackId,
    required Video? selectedVideo,
    required void Function(List<CommentaryTrackItem> list) onCommentaryUpdated,
    required VoidCallback onVideoRefreshed,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    final video = selectedVideo;
    if (video == null) return;
    try {
      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final updatedCommentaryMap = Map<String, Map<String, String>>.from(
        cachedLoc?.commentaryVideos ?? {},
      );
      updatedCommentaryMap.remove(trackId);

      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'commentaryVideos': updatedCommentaryMap,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (VideoMediaService.localizationCache[video.id] != null) {
        VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
          subtitles: VideoMediaService.localizationCache[video.id]!.subtitles,
          dubbedVideos:
              VideoMediaService.localizationCache[video.id]!.dubbedVideos,
          audioTracks:
              VideoMediaService.localizationCache[video.id]!.audioTracks,
          commentaryVideos: updatedCommentaryMap,
        );
      }

      final commentaryList = <CommentaryTrackItem>[];
      updatedCommentaryMap.forEach((key, map) {
        commentaryList.add(CommentaryTrackItem.fromMap(key, map));
      });
      onCommentaryUpdated(commentaryList);
      onVideoRefreshed();
      onShowSuccess('Commentary track removed successfully.');
    } catch (e, stack) {
      logger.error(
        'Failed to remove commentary track',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      onShowError('Unable to remove commentary track. Please try again.');
    }
  }
}

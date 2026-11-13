import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Manages single audio track uploads and multilingual audio dubbing pipelines.
class AudioTracksUploadManager with ContentValidationMixin {
  static const String _tag = 'AudioTracksUploadManager';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload state
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;
  final RxString uploadingLanguageCode = ''.obs;

  /// Uploads a single audio or video track file with content validation and progress tracking.
  Future<bool> uploadTrackFile({
    required PlatformFile file,
    required String title,
    required String langCode,
    required String type, // 'Audio' or 'Video'
    required Video? selectedVideo,
    required void Function(String langCode) onLanguageSynced,
    required VoidCallback onVideoRefreshed,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    final video = selectedVideo;
    if (video == null) {
      onShowError('No video selected.');
      return false;
    }

    // 1. Validation check
    final validationResult = await validateContent(
      title,
      fieldName: 'Track Title',
    );
    if (!validationResult.isValid) {
      onShowError(validationResult.message);
      return false;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Preparing upload...';
    uploadingLanguageCode.value = langCode;

    try {
      final fileBytes =
          file.bytes ??
          (file.path != null ? await file.xFile.readAsBytes() : null);
      if (fileBytes == null) {
        onShowError('Could not read file bytes.');
        return false;
      }

      final extension = file.extension ?? (type == 'Audio' ? 'mp3' : 'mp4');
      final fileName =
          '${langCode}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'videos/${video.id}/tracks/$fileName',
      );

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: type == 'Audio' ? 'audio/$extension' : 'video/$extension',
        customMetadata: {
          'uploaderId': ?currentUid,
          'title': title,
          'langCode': langCode,
          'type': type,
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            uploadProgress.value =
                snapshot.bytesTransferred / snapshot.totalBytes;
            uploadStatus.value =
                'Uploading... ${(uploadProgress.value * 100).toStringAsFixed(0)}%';
          }
        },
        onError: (error, stackTrace) {
          logger.error(
            'Upload snapshot event failed',
            error: error,
            stackTrace: stackTrace,
            tag: _tag,
          );
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      uploadStatus.value = 'Saving track reference...';

      // 2. Save reference to Firestore and local model cache
      if (type == 'Audio') {
        final updatedAudioMap = Map<String, String>.from(video.audioTracks);
        updatedAudioMap[langCode] = downloadUrl;

        await _firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .collection('media')
            .doc('localization')
            .set({
              'subtitles': video.mediaSubtitles,
              'dubbedVideos': video.dubbedVideos,
              'audioTracks': updatedAudioMap,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
          subtitles: video.mediaSubtitles,
          dubbedVideos: video.dubbedVideos,
          audioTracks: updatedAudioMap,
        );
      } else {
        final updatedDubbedMap = Map<String, String>.from(video.dubbedVideos);
        updatedDubbedMap[langCode] = downloadUrl;

        await _firestore
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .collection('media')
            .doc('localization')
            .set({
              'subtitles': video.mediaSubtitles,
              'dubbedVideos': updatedDubbedMap,
              'audioTracks': video.audioTracks,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
          subtitles: video.mediaSubtitles,
          dubbedVideos: updatedDubbedMap,
          audioTracks: video.audioTracks,
        );
      }

      onLanguageSynced(langCode);
      onVideoRefreshed();
      onShowSuccess('$type track "$title" uploaded successfully!');
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed to upload track file',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      onShowError('Unable to upload audio file. Please try again.');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
      uploadingLanguageCode.value = '';
    }
  }

  /// Uploads a single dubbed audio file directly for a specific language.
  Future<bool> uploadSingleAudioDubForLanguage({
    required String langCode,
    required PlatformFile file,
    required Video? selectedVideo,
    required void Function(String langCode, Map<String, String> audioMap)
    onLanguageSynced,
    required VoidCallback onVideoRefreshed,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    final video = selectedVideo;
    if (video == null) return false;

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadingLanguageCode.value = langCode;
    uploadStatus.value =
        'Uploading ${getSupportedLanguageName(langCode)} dubbed audio...';

    try {
      final fileBytes =
          file.bytes ??
          (file.path != null ? await file.xFile.readAsBytes() : null);
      if (fileBytes == null) {
        onShowError('Failed to read file.');
        return false;
      }

      final ext = file.extension ?? 'mp3';
      final fileName =
          '${langCode}_dub_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(
        'videos/${video.id}/tracks/$fileName',
      );

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: 'audio/$ext',
          customMetadata: {'uploaderId': ?currentUid},
        ),
      );

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            uploadProgress.value =
                snapshot.bytesTransferred / snapshot.totalBytes;
          }
        },
        onError: (error, stackTrace) {
          logger.error(
            'Voice track upload snapshot event failed',
            error: error,
            stackTrace: stackTrace,
            tag: _tag,
          );
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final updatedAudioMap = Map<String, String>.from(
        cachedLoc?.audioTracks ?? video.audioTracks,
      );
      updatedAudioMap[langCode] = downloadUrl;

      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'audioTracks': updatedAudioMap,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (VideoMediaService.localizationCache[video.id] != null) {
        VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
          subtitles: VideoMediaService.localizationCache[video.id]!.subtitles,
          dubbedVideos:
              VideoMediaService.localizationCache[video.id]!.dubbedVideos,
          audioTracks: updatedAudioMap,
          commentaryVideos:
              VideoMediaService.localizationCache[video.id]!.commentaryVideos,
        );
      }

      onLanguageSynced(langCode, updatedAudioMap);
      onVideoRefreshed();
      onShowSuccess(
        '${getSupportedLanguageName(langCode)} dubbed audio uploaded successfully!',
      );
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed uploading dub for $langCode',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      onShowError('Unable to upload audio dub. Please try again.');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
      uploadingLanguageCode.value = '';
    }
  }

  /// Updates audio dub URL for a language directly in Firestore.
  Future<void> updateDubUrlForLanguage({
    required String langCode,
    required String url,
    required Video? selectedVideo,
    required void Function(String langCode, Map<String, String> audioMap)
    onLanguageSynced,
    required VoidCallback onVideoRefreshed,
  }) async {
    final video = selectedVideo;
    if (video == null) return;

    final cleanCode = langCode.trim().toLowerCase();
    final cachedLoc = VideoMediaService.localizationCache[video.id];
    final updatedAudioMap = Map<String, String>.from(
      cachedLoc?.audioTracks ?? video.audioTracks,
    );
    final isDeleting = url.trim().isEmpty;
    if (isDeleting) {
      updatedAudioMap.remove(cleanCode);
      updatedAudioMap.remove(langCode);
    } else {
      updatedAudioMap[cleanCode] = url.trim();
    }

    final locRef = _firestore
        .collection(FirestoreCollections.videos)
        .doc(video.id)
        .collection('media')
        .doc('localization');

    final locSnap = await locRef.get();
    if (locSnap.exists) {
      await locRef.update({
        'audioTracks': updatedAudioMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await locRef.set({
        'audioTracks': updatedAudioMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final videoRef = _firestore
        .collection(FirestoreCollections.videos)
        .doc(video.id);

    final videoSnap = await videoRef.get();
    if (videoSnap.exists) {
      final vData = videoSnap.data() ?? {};
      final videoUpdates = <String, dynamic>{
        'audioTracks': updatedAudioMap,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (vData['media'] is Map) {
        videoUpdates['media.audioTracks'] = updatedAudioMap;
      }
      await videoRef.update(videoUpdates);
    } else {
      await videoRef.set({
        'audioTracks': updatedAudioMap,
        'media': {
          'audioTracks': updatedAudioMap,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (isDeleting) {
      final flatDeletes = <String, dynamic>{
        'audioTracks.$cleanCode': FieldValue.delete(),
        'audioTracks.$langCode': FieldValue.delete(),
        'media.audioTracks.$cleanCode': FieldValue.delete(),
        'media.audioTracks.$langCode': FieldValue.delete(),
      };
      await videoRef.set(flatDeletes, SetOptions(merge: true)).catchError((_) {});
      await locRef.set(flatDeletes, SetOptions(merge: true)).catchError((_) {});

      try {
        final jobRef = _firestore.collection('video_jobs').doc(video.id);
        final jobSnap = await jobRef.get();
        if (jobSnap.exists) {
          final jData = jobSnap.data() ?? {};
          final jobUpdates = <String, dynamic>{};
          final outputs = jData['outputs'];
          if (outputs is Map && outputs['audioTracks'] is Map) {
            final curOut = Map<String, dynamic>.from(outputs['audioTracks'] as Map);
            curOut.remove(cleanCode);
            curOut.remove(langCode);
            jobUpdates['outputs.audioTracks'] = curOut;
          }
          if (jData['audioTracks'] is Map) {
            final curAud = Map<String, dynamic>.from(jData['audioTracks'] as Map);
            curAud.remove(cleanCode);
            curAud.remove(langCode);
            jobUpdates['audioTracks'] = curAud;
          }
          final stages = jData['stages'];
          if (stages is Map) {
            if (stages.containsKey('dubbing_$cleanCode')) {
              jobUpdates['stages.dubbing_$cleanCode'] = FieldValue.delete();
            }
            if (stages.containsKey('dubbing_$langCode')) {
              jobUpdates['stages.dubbing_$langCode'] = FieldValue.delete();
            }
          }
          if (jobUpdates.isNotEmpty) {
            await jobRef.update(jobUpdates).catchError((_) {});
          }
        }
      } catch (_) {}
    }

    if (VideoMediaService.localizationCache[video.id] != null) {
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: VideoMediaService.localizationCache[video.id]!.subtitles,
        dubbedVideos:
            VideoMediaService.localizationCache[video.id]!.dubbedVideos,
        audioTracks: updatedAudioMap,
        commentaryVideos:
            VideoMediaService.localizationCache[video.id]!.commentaryVideos,
      );
    }

    onLanguageSynced(langCode, updatedAudioMap);
    onVideoRefreshed();
  }
}

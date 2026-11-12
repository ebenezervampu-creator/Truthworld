import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Manages audio tracks workspace preview, URL adjustments, clipboard exports, downloads, and cloud commits.
class AudioTracksEditorManager {
  static const String _tag = 'AudioTracksEditorManager';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<AudioTrackItem> currentTracks = <AudioTrackItem>[].obs;
  final RxList<CommentaryTrackItem> commentaryTracks =
      <CommentaryTrackItem>[].obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingTracks = false.obs;
  final RxBool hasUnsavedChanges = false.obs;

  /// Parses all configured audio tracks for the video into currentTracks.
  Future<void> parseAllAudioTracks({
    required Video video,
    required List<String> availableLanguages,
    required Map<String, String> entireAudioMap,
    Set<String> generatingLanguages = const {},
    String Function(String code)? languageNameResolver,
  }) async {
    isLoadingTracks.value = true;
    final tracksList = <AudioTrackItem>[];
    final baseLang = video.language.isNotEmpty ? video.language : 'en';
    final resolveName = languageNameResolver ?? getSupportedLanguageName;

    // 1. Primary / Base Track
    var baseUrl = entireAudioMap[baseLang] ?? '';
    if (baseUrl.isEmpty) {
      baseUrl = video.videoUrl;
    }
    tracksList.add(
      AudioTrackItem(
        id: '${video.id}_$baseLang',
        languageCode: baseLang,
        languageName: '${resolveName(baseLang)} (Original)',
        audioUrl: baseUrl,
        isBaseTrack: true,
        isResolved: baseUrl.isNotEmpty,
        role: 'Original video audio',
      ),
    );

    // 2. Dubbed Tracks
    // Merge available languages with any actively generating languages so that
    // in-flight dubbing jobs are never dropped when switching tabs or re-selecting videos.
    final mergedLanguages = <String>{...availableLanguages, ...generatingLanguages};

    for (final langCode in mergedLanguages) {
      if (langCode == baseLang) continue;
      final rawUrl = entireAudioMap[langCode] ?? '';
      final isGenerating =
          generatingLanguages.contains(langCode) && rawUrl.trim().isEmpty;

      final String trackStatus;
      if (rawUrl.trim().isNotEmpty) {
        trackStatus = 'Published';
      } else if (isGenerating) {
        trackStatus = 'Generating...';
      } else {
        trackStatus = 'Not added';
      }

      tracksList.add(
        AudioTrackItem(
          id: '${video.id}_$langCode',
          languageCode: langCode,
          languageName: resolveName(langCode),
          audioUrl: rawUrl,
          isResolved: rawUrl.isNotEmpty,
          status: trackStatus,
        ),
      );
    }

    currentTracks.value = tracksList;
    isLoadingTracks.value = false;
  }

  /// Parses and prepares audio tracks for the specified language.
  Future<void> parseAudioTracksForLanguage(
    String langCode,
    Map<String, String> entireAudioMap, {
    required String? selectedVideoId,
    String? baseLanguage,
  }) async {
    isLoadingTracks.value = true;
    final tracksList = <AudioTrackItem>[];

    var rawUrl = entireAudioMap[langCode] ?? '';
    var resolvedState = false;

    // Resolve gs:// and storage.googleapis.com links to direct download URLs
    if (rawUrl.startsWith('gs://') ||
        rawUrl.contains('storage.googleapis.com')) {
      try {
        final resolved = await StorageUtils.resolveUrl(rawUrl);
        if (resolved.isNotEmpty) {
          rawUrl = resolved;
          resolvedState = true;
        }
      } catch (e) {
        logger.error(
          'Failed resolving audio track link: $rawUrl',
          error: e,
          tag: _tag,
        );
      }
    } else if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      resolvedState = true;
    } else if (rawUrl.isEmpty) {
      resolvedState = false;
    }

    final resolvedBaseLang = baseLanguage?.isNotEmpty == true ? baseLanguage! : 'en';

    tracksList.add(
      AudioTrackItem(
        id: '${selectedVideoId}_$langCode',
        languageCode: langCode,
        languageName: getSupportedLanguageName(langCode),
        audioUrl: rawUrl,
        isBaseTrack: langCode == resolvedBaseLang,
        isResolved: resolvedState,
      ),
    );

    currentTracks.value = tracksList;
    isLoadingTracks.value = false;
  }

  /// Updates audio track URL and flags unsaved changes.
  void updateTrackUrl(int index, String newStorageLink) {
    if (index < 0 || index >= currentTracks.length) return;
    if (currentTracks[index].audioUrl != newStorageLink) {
      currentTracks[index].audioUrl = newStorageLink;
      currentTracks[index].isResolved =
          newStorageLink.startsWith('http://') ||
          newStorageLink.startsWith('https://');
      hasUnsavedChanges.value = true;
      currentTracks.refresh();
    }
  }

  /// Copies stream URL to system clipboard.
  void exportTrackLinkToClipboard(
    String linkUrl, {
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) {
    if (linkUrl.isEmpty) {
      onShowError('No audio stream URL available to export.');
      return;
    }
    Clipboard.setData(ClipboardData(text: linkUrl));
    onShowSuccess('Copied target Audio Stream Link to clipboard natively!');
  }

  /// Initiates native file download for audio track.
  Future<void> downloadAudioTrack(
    AudioTrackItem track, {
    required Video? selectedVideo,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    var url = track.audioUrl;
    final video = selectedVideo;
    if (url.isEmpty && video != null) {
      url = video.videoUrl;
    }

    if (url.isEmpty) {
      onShowError('No audio track URL available to download.');
      return;
    }

    var downloadUrl = url;
    try {
      final resolved = await StorageUtils.resolveUrl(url);
      if (resolved.isNotEmpty) {
        downloadUrl = resolved;
      }
    } catch (e) {
      logger.error(
        'Failed resolving audio track download URL: $url',
        error: e,
        tag: _tag,
      );
    }

    final rawTitle = video?.title ?? 'audio';
    final videoTitle = rawTitle
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_${track.languageCode}_audio.mp3';

    DownloadHelper.downloadFromUrl(downloadUrl, fileName);
    onShowSuccess('Downloading ${track.languageName} Audio Track: $fileName');
  }

  /// Initiates native file download for commentary track.
  Future<void> downloadCommentaryTrack(
    CommentaryTrackItem track, {
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
  }) async {
    final url = track.audioUrl.isNotEmpty ? track.audioUrl : track.videoUrl;
    if (url.isEmpty) {
      onShowError('No media URL available to download.');
      return;
    }

    var downloadUrl = url;
    if (url.startsWith('gs://')) {
      try {
        downloadUrl =
            await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      } catch (e) {
        logger.error(
          'Failed resolving gs:// commentary track reference: $url',
          error: e,
          tag: _tag,
        );
      }
    }

    final safeTitle = track.title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final ext = track.audioUrl.isNotEmpty ? 'mp3' : 'mp4';
    final fileName = '${safeTitle}_${track.langCode}.$ext';

    DownloadHelper.downloadFromUrl(downloadUrl, fileName);
    onShowSuccess('Downloading ${track.role} Track: $fileName');
  }

  /// Commits current audio tracks configuration to Firestore media/localization document.
  Future<void> saveCurrentAudioTracks({
    required Video? selectedVideo,
    required String selectedLanguage,
    required void Function(String msg) onShowSuccess,
    required void Function(String err) onShowError,
    required VoidCallback onVideoRefreshed,
  }) async {
    final video = selectedVideo;
    if (video == null || currentTracks.isEmpty) return;

    isSaving.value = true;
    try {
      // Build cumulative multi-language mappings from all tracks in workspace
      final updatedAudioMap = <String, String>{};
      for (final track in currentTracks) {
        if (!track.isBaseTrack && track.audioUrl.trim().isNotEmpty) {
          updatedAudioMap[track.languageCode] = track.audioUrl.trim();
        }
      }

      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final previousMap = Map<String, String>.from(
        cachedLoc?.audioTracks ?? video.audioTracks,
      );

      // Detect removed languages
      final removedLangs = previousMap.keys
          .where((k) => !updatedAudioMap.containsKey(k))
          .toList();

      // Save to media/localization subcollection
      final locRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization');

      final locSnap = await locRef.get();
      if (locSnap.exists) {
        await locRef.update({
          'subtitles': video.mediaSubtitles,
          'dubbedVideos': video.dubbedVideos,
          'audioTracks': updatedAudioMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await locRef.set({
          'subtitles': video.mediaSubtitles,
          'dubbedVideos': video.dubbedVideos,
          'audioTracks': updatedAudioMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save to main video document
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

      // Clean any legacy flat keys for removed tracks
      if (removedLangs.isNotEmpty) {
        final flatDeletes = <String, dynamic>{};
        for (final rLang in removedLangs) {
          flatDeletes['audioTracks.$rLang'] = FieldValue.delete();
          flatDeletes['media.audioTracks.$rLang'] = FieldValue.delete();
        }
        await videoRef.set(flatDeletes, SetOptions(merge: true)).catchError((_) {});
        await locRef.set(flatDeletes, SetOptions(merge: true)).catchError((_) {});
      }

      // Clean video_jobs for removed tracks so pipeline fallbacks never resurrect them
      if (removedLangs.isNotEmpty) {
        try {
          final jobRef = _firestore.collection('video_jobs').doc(video.id);
          final jobSnap = await jobRef.get();
          if (jobSnap.exists) {
            final jData = jobSnap.data() ?? {};
            final jobUpdates = <String, dynamic>{};
            final outputs = jData['outputs'];
            if (outputs is Map && outputs['audioTracks'] is Map) {
              final curOut = Map<String, dynamic>.from(outputs['audioTracks'] as Map);
              for (final rLang in removedLangs) {
                curOut.remove(rLang);
              }
              jobUpdates['outputs.audioTracks'] = curOut;
            }
            if (jData['audioTracks'] is Map) {
              final curAud = Map<String, dynamic>.from(jData['audioTracks'] as Map);
              for (final rLang in removedLangs) {
                curAud.remove(rLang);
              }
              jobUpdates['audioTracks'] = curAud;
            }
            final stages = jData['stages'];
            if (stages is Map) {
              for (final rLang in removedLangs) {
                if (stages.containsKey('dubbing_$rLang')) {
                  jobUpdates['stages.dubbing_$rLang'] = FieldValue.delete();
                }
                if (stages.containsKey('translating_$rLang')) {
                  jobUpdates['stages.translating_$rLang'] = FieldValue.delete();
                }
              }
            }
            if (jobUpdates.isNotEmpty) {
              await jobRef.update(jobUpdates);
            }
          }
        } catch (_) {}
      }

      // Update static cache to reflect changes immediately
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: video.mediaSubtitles,
        dubbedVideos: video.dubbedVideos,
        audioTracks: updatedAudioMap,
        commentaryVideos: cachedLoc?.commentaryVideos ?? const {},
      );

      hasUnsavedChanges.value = false;
      onVideoRefreshed();
      onShowSuccess('Audio tracks configuration saved successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed executing cloud commit for active audio tracks',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      onShowError('Failed persisting localized secondary audio streams.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Clears tracks when video is deselected.
  void clear() {
    currentTracks.clear();
    commentaryTracks.clear();
    hasUnsavedChanges.value = false;
  }
}

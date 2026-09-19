import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
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

  /// Parses and prepares audio tracks for the specified language.
  Future<void> parseAudioTracksForLanguage(
    String langCode,
    Map<String, String> entireAudioMap, {
    required String? selectedVideoId,
  }) async {
    isLoadingTracks.value = true;
    final tracksList = <AudioTrackItem>[];

    var rawUrl = entireAudioMap[langCode] ?? '';
    var resolvedState = false;

    // Resolve gs:// links to direct download URLs
    if (rawUrl.startsWith('gs://')) {
      try {
        rawUrl =
            await FirebaseStorage.instance.refFromURL(rawUrl).getDownloadURL();
        resolvedState = true;
      } catch (e) {
        logger.error(
          'Failed resolving base gs:// reference for audio track link: $rawUrl',
          error: e,
          tag: _tag,
        );
      }
    } else if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      resolvedState = true;
    } else if (rawUrl.isEmpty) {
      resolvedState = false;
    }

    tracksList.add(
      AudioTrackItem(
        id: '${selectedVideoId}_$langCode',
        languageCode: langCode,
        languageName: getSupportedLanguageName(langCode),
        audioUrl: rawUrl,
        isBaseTrack: langCode == 'en',
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
    if (url.startsWith('gs://')) {
      try {
        downloadUrl =
            await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      } catch (e) {
        logger.error(
          'Failed resolving gs:// audio track reference: $url',
          error: e,
          tag: _tag,
        );
      }
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
    final lang = selectedLanguage;
    if (video == null || lang.isEmpty || currentTracks.isEmpty) return;

    isSaving.value = true;
    try {
      final payloadLink = currentTracks.first.audioUrl;

      // Construct cumulative multi-language mappings
      final updatedAudioMap = Map<String, String>.from(video.audioTracks);
      updatedAudioMap[lang] = payloadLink;

      // Save to media/localization subcollection
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

      // Update static cache to reflect changes immediately
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: video.mediaSubtitles,
        dubbedVideos: video.dubbedVideos,
        audioTracks: updatedAudioMap,
      );

      onVideoRefreshed();
      hasUnsavedChanges.value = false;
      onShowSuccess(
        '${getSupportedLanguageName(lang)} Audio Track configuration stored successfully!',
      );
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

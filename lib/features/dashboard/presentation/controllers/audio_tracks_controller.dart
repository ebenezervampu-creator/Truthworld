import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_barrel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

export 'audio_tracks/audio_tracks_barrel.dart';

/// Industry-Standard Multi-Language Audio Tracks & Dubs Management Coordinator
class AudioTracksController extends BaseController with ContentValidationMixin {
  static const String _tag = 'AudioTracksController';

  final AudioTracksContextManager _contextManager = AudioTracksContextManager();
  final AudioTracksLanguageManager _languageManager =
      AudioTracksLanguageManager();
  final AudioTracksEditorManager _editorManager = AudioTracksEditorManager();
  final AudioTracksUploadManager _uploadManager = AudioTracksUploadManager();
  final AudioTracksCommentaryManager _commentaryManager =
      AudioTracksCommentaryManager();

  // Sub-manager accessors for advanced modular usage
  AudioTracksContextManager get contextManager => _contextManager;
  AudioTracksLanguageManager get languageManager => _languageManager;
  AudioTracksEditorManager get editorManager => _editorManager;
  AudioTracksUploadManager get uploadManager => _uploadManager;
  AudioTracksCommentaryManager get commentaryManager => _commentaryManager;

  // Upload state delegation
  RxBool get isUploading => _uploadManager.isUploading;
  RxDouble get uploadProgress => _uploadManager.uploadProgress;
  RxString get uploadStatus => _uploadManager.uploadStatus;

  // Active Context delegation
  RxString get channelId => _contextManager.channelId;
  RxList<Video> get videos => _contextManager.videos;
  RxList<Video> get filteredVideos => _contextManager.filteredVideos;
  RxString get searchQuery => _contextManager.searchQuery;
  Rxn<Video> get selectedVideo => _contextManager.selectedVideo;
  late final TextEditingController searchController = trackTextController(TextEditingController());

  // Language & Tab delegation
  RxString get activeTab => _languageManager.activeTab;
  RxList<String> get availableLanguages => _languageManager.availableLanguages;
  RxString get selectedLanguage => _languageManager.selectedLanguage;
  RxList<LanguageRequest> get languageRequests =>
      _languageManager.languageRequests;
  RxList<LanguageRequest> get clientLanguageRequests =>
      _languageManager.clientLanguageRequests;
  RxBool get isLoadingRequests => _languageManager.isLoadingRequests;
  RxBool get showRequestsPanel => _languageManager.showRequestsPanel;

  // Editor delegation
  RxList<AudioTrackItem> get currentTracks => _editorManager.currentTracks;
  RxList<CommentaryTrackItem> get commentaryTracks =>
      _editorManager.commentaryTracks;
  RxBool get isSaving => _editorManager.isSaving;
  RxBool get isLoadingTracks => _editorManager.isLoadingTracks;
  RxBool get hasUnsavedChanges => _editorManager.hasUnsavedChanges;

  List<({String code, String name})> get supportedLanguages =>
      kSupportedLanguages;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    unawaited(
      _contextManager.initializeContext(
        onViewStateChanged: setViewState,
        onError: setError,
      ),
    );
  }

  @override
  void onClose() {
    _contextManager.dispose();
    _languageManager.dispose();
    super.onClose();
  }

  void setActiveTab(String tab) => _languageManager.setActiveTab(tab);

  void toggleRequestsPanel() => _languageManager.toggleRequestsPanel();

  void setChannelContext(String id) =>
      _contextManager.setChannelContext(id, onViewStateChanged: setViewState);

  void setSearchQuery(String query) => _contextManager.setSearchQuery(query);

  /// Selects active video and bootstraps localization tracks, commentaries, and request streams.
  Future<void> selectVideo(Video? video) async {
    await _contextManager.selectVideo(
      video,
      onVideoSelected: (v) async {
        _editorManager.hasUnsavedChanges.value = false;
        if (v == null) {
          _languageManager.clear();
          _editorManager.clear();
          return;
        }

        logger.info(
          'Selected video for audio tracks editing session: ${v.title}',
          tag: _tag,
        );

        _languageManager.listenToLanguageRequests(v.id);

        final localization = await VideoMediaService().getLocalization(v.id);

        // Extract commentary items
        final commentaryList = <CommentaryTrackItem>[];
        localization.commentaryVideos.forEach((key, map) {
          commentaryList.add(CommentaryTrackItem.fromMap(key, map));
        });
        _editorManager.commentaryTracks.value = commentaryList;

        // Extract audio tracks
        final audioMap =
            localization.audioTracks.isNotEmpty
                ? localization.audioTracks
                : v.audioTracks;
        final langs = audioMap.keys.toList();
        if (!langs.contains('en')) {
          langs.insert(0, 'en');
        }

        _languageManager.availableLanguages.value = langs;
        _languageManager.selectedLanguage.value = langs.first;

        await _editorManager.parseAudioTracksForLanguage(
          langs.first,
          audioMap,
          selectedVideoId: v.id,
        );
        selectedVideo.refresh();
      },
    );
  }

  /// Switches active editing language track.
  void switchLanguageTrack(String langCode) {
    _languageManager.switchLanguageTrack(
      langCode,
      onLanguageSwitched: (code) {
        _editorManager.hasUnsavedChanges.value = false;
        final audioMap = selectedVideo.value?.audioTracks ?? {};
        _editorManager.parseAudioTracksForLanguage(
          code,
          audioMap,
          selectedVideoId: selectedVideo.value?.id,
        );
      },
    );
  }

  /// Adds a new language layer to the available languages catalog.
  void addLanguageLayer(String langCode) {
    _languageManager.addLanguageLayer(
      langCode,
      onLanguageAdded: (code) {
        _editorManager.hasUnsavedChanges.value = true;
        final audioMap = selectedVideo.value?.audioTracks ?? {};
        _editorManager.parseAudioTracksForLanguage(
          code,
          audioMap,
          selectedVideoId: selectedVideo.value?.id,
        );
      },
      onShowSuccess: showSuccess,
    );
  }

  void updateTrackUrl(int index, String newStorageLink) =>
      _editorManager.updateTrackUrl(index, newStorageLink);

  void exportTrackLinkToClipboard(String linkUrl) =>
      _editorManager.exportTrackLinkToClipboard(
        linkUrl,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> downloadAudioTrack(AudioTrackItem track) =>
      _editorManager.downloadAudioTrack(
        track,
        selectedVideo: selectedVideo.value,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> downloadCommentaryTrack(CommentaryTrackItem track) =>
      _editorManager.downloadCommentaryTrack(
        track,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> saveCurrentAudioTracks() =>
      _editorManager.saveCurrentAudioTracks(
        selectedVideo: selectedVideo.value,
        selectedLanguage: selectedLanguage.value,
        onShowSuccess: showSuccess,
        onShowError: handleError,
        onVideoRefreshed: () => selectedVideo.refresh(),
      );

  Future<bool> uploadTrackFile({
    required PlatformFile file,
    required String title,
    required String langCode,
    required String type,
  }) => _uploadManager.uploadTrackFile(
    file: file,
    title: title,
    langCode: langCode,
    type: type,
    selectedVideo: selectedVideo.value,
    onLanguageSynced: (code) {
      if (!availableLanguages.contains(code)) {
        availableLanguages.add(code);
      }
      selectedLanguage.value = code;
      final videoId = selectedVideo.value?.id;
      if (videoId != null &&
          VideoMediaService.localizationCache[videoId] != null) {
        _editorManager.parseAudioTracksForLanguage(
          code,
          VideoMediaService.localizationCache[videoId]!.audioTracks,
          selectedVideoId: videoId,
        );
      }
    },
    onVideoRefreshed: () => selectedVideo.refresh(),
    onShowSuccess: showSuccess,
    onShowError: showError,
  );

  Future<bool> uploadMultipleTrackFiles({
    required List<BatchTrackUploadConfig> items,
  }) async {
    isUploading.value = true;
    try {
      return await _commentaryManager.uploadMultipleTrackFiles(
        items: items,
        selectedVideo: selectedVideo.value,
        onProgressUpdate: (val) => uploadProgress.value = val,
        onStatusUpdate: (val) => uploadStatus.value = val,
        onCommentaryUpdated: (list) => commentaryTracks.value = list,
        onLanguageSynced: (code, audioMap) {
          if (!availableLanguages.contains(code)) {
            availableLanguages.add(code);
          }
          _editorManager.parseAudioTracksForLanguage(
            selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
            audioMap,
            selectedVideoId: selectedVideo.value?.id,
          );
        },
        onVideoRefreshed: () => selectedVideo.refresh(),
        onShowSuccess: showSuccess,
        onShowError: showError,
      );
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  Future<void> deleteCommentaryTrack(String trackId) =>
      _commentaryManager.deleteCommentaryTrack(
        trackId: trackId,
        selectedVideo: selectedVideo.value,
        onCommentaryUpdated: (list) => commentaryTracks.value = list,
        onVideoRefreshed: () => selectedVideo.refresh(),
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<bool> uploadSingleAudioDubForLanguage({
    required String langCode,
    required PlatformFile file,
  }) => _uploadManager.uploadSingleAudioDubForLanguage(
    langCode: langCode,
    file: file,
    selectedVideo: selectedVideo.value,
    onLanguageSynced: (code, audioMap) {
      if (!availableLanguages.contains(code)) {
        availableLanguages.add(code);
      }
      _editorManager.parseAudioTracksForLanguage(
        selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
        audioMap,
        selectedVideoId: selectedVideo.value?.id,
      );
    },
    onVideoRefreshed: () => selectedVideo.refresh(),
    onShowSuccess: showSuccess,
    onShowError: showError,
  );

  Future<void> updateDubUrlForLanguage(String langCode, String url) async {
    await _uploadManager.updateDubUrlForLanguage(
      langCode: langCode,
      url: url,
      selectedVideo: selectedVideo.value,
      onLanguageSynced: (code, audioMap) {
        if (!availableLanguages.contains(code) && url.trim().isNotEmpty) {
          availableLanguages.add(code);
        }
        _editorManager.parseAudioTracksForLanguage(
          selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
          audioMap,
          selectedVideoId: selectedVideo.value?.id,
        );
      },
      onVideoRefreshed: () => selectedVideo.refresh(),
    );
  }

  Future<void> removeDubForLanguage(String langCode) async {
    await updateDubUrlForLanguage(langCode, '');
    showSuccess('${getLanguageName(langCode)} dubbed audio removed.');
  }

  String getLanguageName(String code) => getSupportedLanguageName(code);
}

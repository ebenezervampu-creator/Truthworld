import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Internal Audio Track layout representation for the studio preview editor
class AudioTrackItem {
  String id;
  String languageCode;
  String languageName;
  String audioUrl;
  bool isBaseTrack;
  bool isResolved;

  AudioTrackItem({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.audioUrl,
    this.isBaseTrack = false,
    this.isResolved = false,
  });
}

/// Industry-Standard Multi-Language Audio Tracks & Dubs Management Controller
class AudioTracksController extends BaseController {
  static const String _tag = 'AudioTracksController';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Active Context
  final channelId = ''.obs;

  // Video feed stream states
  final videos = <Video>[].obs;
  final filteredVideos = <Video>[].obs;
  final searchQuery = ''.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;

  // Active Workspace layer state
  final selectedVideo = Rxn<Video>();
  final availableLanguages = <String>[].obs;
  final selectedLanguage = ''.obs;
  final currentTracks = <AudioTrackItem>[].obs;
  final isSaving = false.obs;
  final isLoadingTracks = false.obs;
  final hasUnsavedChanges = false.obs;

  // Pre-configured multi-language code dictionary mapping
  final supportedLanguages = const [
    (code: 'en', name: 'English (Base)'),
    (code: 'es', name: 'Spanish (Español)'),
    (code: 'hi', name: 'Hindi (हिन्दी)'),
    (code: 'fr', name: 'French (Français)'),
    (code: 'te', name: 'Telugu (తెలుగు)'),
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeContext();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    super.onClose();
  }

  /// Inject or update channel navigation workspace context dynamically
  void setChannelContext(String newChannelId) {
    if (newChannelId.isEmpty || newChannelId == channelId.value) return;
    logger.info(
      'Updating Audio Tracks dynamic workspace context to channel: $newChannelId',
      tag: _tag,
    );
    channelId.value = newChannelId;
    selectVideo(null);
    _listenToChannelVideos();
  }

  void _initializeContext() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Load active creator channel mapping directly
    _firestore
        .collection('channels')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            channelId.value = snapshot.docs.first.id;
            _listenToChannelVideos();
          } else {
            setState(ViewState.empty);
          }
        })
        .catchError((e) {
          logger.error(
            'Failed to load base creator channel for audio tracks',
            error: e,
            tag: _tag,
          );
          setState(ViewState.error);
        });
  }

  void _listenToChannelVideos() {
    if (channelId.value.isEmpty) return;

    setState(ViewState.loading);
    _videosSubscription?.cancel();

    // Stream uploaded items sorted client-side to strictly avoid composite index configuration failures
    _videosSubscription = _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId.value)
        .snapshots()
        .listen(
          (snapshot) {
            final loadedList = snapshot.docs
                .map((doc) => Video.fromDocumentSnapshot(doc))
                .toList();

            // Perform stable local chronological sorting by upload recency
            loadedList.sort((a, b) {
              final tA = (a.uploadedAt).toDate();
              final tB = (b.uploadedAt).toDate();
              return tB.compareTo(tA);
            });

            videos.value = loadedList;
            _applySearchFilter();

            // Maintain active video pointer synchronization across snapshot sync events
            if (selectedVideo.value != null) {
              final updatedPointer = loadedList.firstWhereOrNull(
                (v) => v.id == selectedVideo.value!.id,
              );
              if (updatedPointer != null) {
                selectedVideo.value = updatedPointer;
              }
            }

            setState(loadedList.isEmpty ? ViewState.empty : ViewState.success);
          },
          onError: (e) {
            logger.error(
              'Failed streaming channel items for audio tracks module',
              error: e,
              tag: _tag,
            );
            setState(ViewState.error);
          },
        );
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (searchQuery.value.trim().isEmpty) {
      filteredVideos.value = videos;
      return;
    }
    final q = searchQuery.value.toLowerCase().trim();
    filteredVideos.value = videos.where((v) {
      return v.title.toLowerCase().contains(q) ||
          v.description.toLowerCase().contains(q) ||
          v.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void selectVideo(Video? video) {
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    if (video == null) {
      availableLanguages.clear();
      selectedLanguage.value = '';
      currentTracks.clear();
      return;
    }

    logger.info(
      'Selected video for audio tracks editing session: ${video.title}',
      tag: _tag,
    );

    // Extract pre-existing secondary audio map layouts
    final audioMap = video.audioTracks;
    final langs = audioMap.keys.toList();

    // Ensure base track is systematically populated if absent
    if (!langs.contains('en')) {
      langs.insert(0, 'en');
    }

    availableLanguages.value = langs;
    selectedLanguage.value = langs.first;
    _parseAudioTracksForLanguage(langs.first, audioMap);
  }

  void switchLanguageTrack(String langCode) {
    if (!availableLanguages.contains(langCode)) return;
    selectedLanguage.value = langCode;
    hasUnsavedChanges.value = false;
    final audioMap = selectedVideo.value?.audioTracks ?? {};
    _parseAudioTracksForLanguage(langCode, audioMap);
  }

  Future<void> _parseAudioTracksForLanguage(
    String langCode,
    Map<String, String> entireAudioMap,
  ) async {
    isLoadingTracks.value = true;
    final tracksList = <AudioTrackItem>[];

    // Check if mapping exists
    String rawUrl = entireAudioMap[langCode] ?? '';
    bool resolvedState = false;

    // Simulate premium out-of-the-box storage URL resolution to convert static gs:// assets directly
    if (rawUrl.startsWith('gs://')) {
      try {
        rawUrl = await FirebaseStorage.instance
            .refFromURL(rawUrl)
            .getDownloadURL();
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
      // No audio track assigned
      resolvedState = false;
    }

    tracksList.add(
      AudioTrackItem(
        id: '${selectedVideo.value?.id}_$langCode',
        languageCode: langCode,
        languageName: getLanguageName(langCode),
        audioUrl: rawUrl,
        isBaseTrack: langCode == 'en',
        isResolved: resolvedState,
      ),
    );

    currentTracks.value = tracksList;
    isLoadingTracks.value = false;
  }

  void addLanguageLayer(String langCode) {
    if (availableLanguages.contains(langCode)) {
      switchLanguageTrack(langCode);
      return;
    }
    availableLanguages.add(langCode);
    selectedLanguage.value = langCode;
    hasUnsavedChanges.value = true;

    // Automatically provision localized simulated layout track
    final audioMap = selectedVideo.value?.audioTracks ?? {};
    _parseAudioTracksForLanguage(langCode, audioMap);
    showSuccess(
      'Added new secondary audio target layer: ${getLanguageName(langCode)}',
    );
  }

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


  void exportTrackLinkToClipboard(String linkUrl) {
    if (linkUrl.isEmpty) {
      showError('No audio stream URL available to export.');
      return;
    }
    Clipboard.setData(ClipboardData(text: linkUrl));
    showSuccess('Copied target Audio Stream Link to clipboard natively!');
  }

  Future<void> saveCurrentAudioTracks() async {
    final video = selectedVideo.value;
    final lang = selectedLanguage.value;
    if (video == null || lang.isEmpty || currentTracks.isEmpty) return;

    isSaving.value = true;
    try {
      final payloadLink = currentTracks.first.audioUrl;

      // Construct cumulative multi-language mappings ensuring un-modified tracks remain fully pristine
      final updatedAudioMap = Map<String, String>.from(video.audioTracks);
      updatedAudioMap[lang] = payloadLink;

      await _firestore.collection('videos').doc(video.id).update({
        'media.audioTracks': updatedAudioMap,
        'audioTracks': updatedAudioMap, // Keep fallback object synchronized
      });

      // Update active loaded model instance inline immediately
      selectedVideo.value = Video.fromMap({
        ...video.toMap(),
        'media': {
          'subtitles': video.mediaSubtitles,
          'dubbedVideos': video.dubbedVideos,
          'audioTracks': updatedAudioMap,
          'factCheckUrl': video.factCheckUrl,
        },
        'audioTracks': updatedAudioMap,
      }, video.id);

      hasUnsavedChanges.value = false;
      showSuccess(
        '${getLanguageName(lang)} Audio Track configuration stored successfully!',
      );
    } catch (e, stack) {
      logger.error(
        'Failed executing cloud commit for active audio tracks',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      handleError('Failed persisting localized secondary audio streams.');
    } finally {
      isSaving.value = false;
    }
  }

  String getLanguageName(String code) {
    final match = supportedLanguages.firstWhereOrNull((l) => l.code == code);
    return match?.name ?? code.toUpperCase();
  }
}





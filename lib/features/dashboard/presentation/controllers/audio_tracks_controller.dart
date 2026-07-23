import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Internal Audio Track layout representation for the studio preview editor
class AudioTrackItem {

  AudioTrackItem({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.audioUrl,
    this.isBaseTrack = false,
    this.isResolved = false,
  });
  String id;
  String languageCode;
  String languageName;
  String audioUrl;
  bool isBaseTrack;
  bool isResolved;
}

/// Industry-Standard Multi-Language Audio Tracks & Dubs Management Controller
class AudioTracksController extends BaseController with ContentValidationMixin {
  static const String _tag = 'AudioTracksController';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload state
  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;
  final uploadStatus = ''.obs;

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

  // Language requests states
  final languageRequests = <LanguageRequest>[].obs;
  final clientLanguageRequests = <LanguageRequest>[].obs; // backing field
  final isLoadingRequests = false.obs;
  final showRequestsPanel = false.obs;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

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
    initializeContentFilters();
    _initializeContext();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    _requestsSubscription?.cancel();
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
            setViewState(ViewState.empty);
          }
        })
        .catchError((e) {
          logger.error(
            'Failed to load base creator channel for audio tracks',
            error: e,
            tag: _tag,
          );
          setViewState(ViewState.error);
        });
  }

  void _listenToChannelVideos() {
    if (channelId.value.isEmpty) return;

    setViewState(ViewState.loading);
    _videosSubscription?.cancel();

    // Stream uploaded items sorted client-side to strictly avoid composite index configuration failures
    _videosSubscription = _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId.value)
        .snapshots()
        .listen(
          (snapshot) {
            final loadedList = snapshot.docs
                .map(Video.fromDocumentSnapshot)
                .toList();

            // Perform stable local chronological sorting by upload recency
            loadedList.sort((a, b) {
              final tA = a.uploadedAt.toDate();
              final tB = b.uploadedAt.toDate();
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

            setViewState(loadedList.isEmpty ? ViewState.empty : ViewState.success);
          },
          onError: (e) {
            logger.error(
              'Failed streaming channel items for audio tracks module',
              error: e,
              tag: _tag,
            );
            setViewState(ViewState.error);
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

  Future<void> selectVideo(Video? video) async {
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    _requestsSubscription?.cancel();
    if (video == null) {
      availableLanguages.clear();
      selectedLanguage.value = '';
      currentTracks.clear();
      languageRequests.clear();
      return;
    }

    logger.info(
      'Selected video for audio tracks editing session: ${video.title}',
      tag: _tag,
    );

    _listenToLanguageRequests(video.id);

    // Lazy-load localization from subcollection first
    await VideoMediaService().getLocalization(video.id);

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
    selectedVideo.refresh();
  }

  void _listenToLanguageRequests(String videoId) {
    _requestsSubscription?.cancel();
    isLoadingRequests.value = true;
    _requestsSubscription = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('language_requests')
        .snapshots()
        .listen((snapshot) {
      final reqs = snapshot.docs.map((doc) => LanguageRequest.fromMap(doc.data(), doc.id)).toList();
      reqs.sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return a.language.compareTo(b.language);
      });
      languageRequests.value = reqs;
      isLoadingRequests.value = false;
    }, onError: (e) {
      logger.error('Error listening to language requests', error: e, tag: _tag);
      isLoadingRequests.value = false;
    });
  }

  void toggleRequestsPanel() {
    showRequestsPanel.value = !showRequestsPanel.value;
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
    var rawUrl = entireAudioMap[langCode] ?? '';
    var resolvedState = false;

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

      // Save to media/localization subcollection
      await _firestore
          .collection('videos')
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

      // Force reactive notification
      selectedVideo.refresh();

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

  Future<bool> uploadTrackFile({
    required PlatformFile file,
    required String title,
    required String langCode,
    required String type, // 'Audio' or 'Video'
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return false;
    }

    // 1. Profanity check / validation
    final validationResult = await validateContent(title, fieldName: 'Track Title');
    if (!validationResult.isValid) {
      showError(validationResult.message);
      return false;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Preparing upload...';

    try {
      final fileBytes = file.bytes ?? (file.path != null ? await file.xFile.readAsBytes() : null);
      if (fileBytes == null) {
        showError('Could not read file bytes.');
        return false;
      }

      final extension = file.extension ?? (type == 'Audio' ? 'mp3' : 'mp4');
      final fileName = '${langCode}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/${video.id}/tracks/$fileName');

      final metadata = SettableMetadata(
        contentType: type == 'Audio' ? 'audio/$extension' : 'video/$extension',
        customMetadata: {
          'title': title,
          'langCode': langCode,
          'type': type,
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
          uploadStatus.value = 'Uploading... ${(uploadProgress.value * 100).toStringAsFixed(0)}%';
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      uploadStatus.value = 'Saving track reference...';

      // 2. Save reference to Firestore and local model cache
      if (type == 'Audio') {
        // Save to audioTracks
        final updatedAudioMap = Map<String, String>.from(video.audioTracks);
        updatedAudioMap[langCode] = downloadUrl;

        await _firestore
            .collection('videos')
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
        // Save to dubbedVideos
        final updatedDubbedMap = Map<String, String>.from(video.dubbedVideos);
        updatedDubbedMap[langCode] = downloadUrl;

        await _firestore
            .collection('videos')
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

      // Sync active language selection and track view
      if (!availableLanguages.contains(langCode)) {
        availableLanguages.add(langCode);
      }
      selectedLanguage.value = langCode;
      _parseAudioTracksForLanguage(langCode, VideoMediaService.localizationCache[video.id]!.audioTracks);

      selectedVideo.refresh();
      showSuccess('$type track "$title" uploaded successfully!');
      return true;
    } catch (e, stack) {
      logger.error('Failed to upload track file', error: e, stackTrace: stack, tag: _tag);
      showError('Failed to upload file: $e');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  String getLanguageName(String code) {
    final match = supportedLanguages.firstWhereOrNull((l) => l.code == code);
    return match?.name ?? code.toUpperCase();
  }
}





import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
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

/// Commentary & Multi-Video track metadata item
class CommentaryTrackItem {
  CommentaryTrackItem({
    required this.id,
    required this.title,
    required this.role,
    required this.videoUrl,
    required this.langCode,
    this.audioUrl = '',
    this.uploadedAt = '',
    this.fileSizeMB = 0.0,
  });

  String id;
  String title;
  String
  role; // 'Director Commentary', 'Actors Commentary', 'Behind the Scenes', 'Alternate Angle', 'Dubbed Video', 'Voiceover Track'
  String videoUrl;
  String audioUrl;
  String langCode;
  String uploadedAt;
  double fileSizeMB;

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'role': role,
    'videoUrl': videoUrl,
    'audioUrl': audioUrl,
    'langCode': langCode,
    'uploadedAt': uploadedAt,
    'fileSizeMB': fileSizeMB.toString(),
  };

  factory CommentaryTrackItem.fromMap(String key, Map<String, String> map) =>
      CommentaryTrackItem(
        id: map['id'] ?? key,
        title: map['title'] ?? 'Commentary Track',
        role: map['role'] ?? 'Director Commentary',
        videoUrl: map['videoUrl'] ?? '',
        audioUrl: map['audioUrl'] ?? '',
        langCode: map['langCode'] ?? 'en',
        uploadedAt: map['uploadedAt'] ?? '',
        fileSizeMB: double.tryParse(map['fileSizeMB'] ?? '0') ?? 0.0,
      );
}

/// Configuration entry for batch uploading multi-video and audio tracks
class BatchTrackUploadConfig {
  BatchTrackUploadConfig({
    required this.file,
    required this.title,
    required this.role,
    required this.type,
    required this.langCode,
    this.progress = 0.0,
    this.status = 'Pending',
  });

  PlatformFile file;
  String title;
  String
  role; // e.g. 'Director Commentary', 'Actors Commentary', 'Behind the Scenes', 'Alternate Angle', 'Dubbed Video'
  String type; // 'Video' or 'Audio'
  String langCode;
  double progress;
  String status;
}

/// Industry-Standard Multi-Language Audio Tracks & Dubs Management Controller
class AudioTracksController extends BaseController with ContentValidationMixin {
  static const String _tag = 'AudioTracksController';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload state
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  // Active Context
  final RxString channelId = ''.obs;

  // Video feed stream states
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> filteredVideos = <Video>[].obs;
  final RxString searchQuery = ''.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _channelVideosSubscription;
  final Map<String, Video> _ownerVideosMap = {};
  final Map<String, Video> _channelVideosMap = {};

  // Active Workspace layer state
  final Rxn<Video> selectedVideo = Rxn<Video>();
  final RxString activeTab = 'tracks'.obs; // 'tracks' or 'languages'
  final RxList<String> availableLanguages = <String>[].obs;
  final RxString selectedLanguage = ''.obs;
  final RxList<AudioTrackItem> currentTracks = <AudioTrackItem>[].obs;
  final RxList<CommentaryTrackItem> commentaryTracks =
      <CommentaryTrackItem>[].obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingTracks = false.obs;
  final RxBool hasUnsavedChanges = false.obs;

  void setActiveTab(String tab) {
    activeTab.value = tab;
  }

  // Language requests states
  final RxList<LanguageRequest> languageRequests = <LanguageRequest>[].obs;
  final RxList<LanguageRequest> clientLanguageRequests =
      <LanguageRequest>[].obs; // backing field
  final RxBool isLoadingRequests = false.obs;
  final RxBool showRequestsPanel = false.obs;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  // Pre-configured multi-language code dictionary mapping
  final List<({String code, String name})> supportedLanguages = const [
    (code: 'en', name: 'English (Base)'),
    (code: 'es', name: 'Spanish (Español)'),
    (code: 'hi', name: 'Hindi (हिन्दी)'),
    (code: 'fr', name: 'French (Français)'),
    (code: 'te', name: 'Telugu (తెలుగు)'),
    (code: 'ta', name: 'Tamil (தமிழ்)'),
    (code: 'ml', name: 'Malayalam (മലയാളം)'),
    (code: 'kn', name: 'Kannada (കന്നഡ)'),
    (code: 'bn', name: 'Bengali (বাংলা)'),
    (code: 'mr', name: 'Marathi (मराठी)'),
    (code: 'ja', name: 'Japanese (日本語)'),
    (code: 'ko', name: 'Korean (한국어)'),
    (code: 'de', name: 'German (Deutsch)'),
    (code: 'pt', name: 'Portuguese (Português)'),
    (code: 'it', name: 'Italian (Italiano)'),
    (code: 'ar', name: 'Arabic (العربية)'),
    (code: 'ru', name: 'Russian (Русский)'),
    (code: 'zh', name: 'Chinese (中文)'),
  ];

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    unawaited(_initializeContext());
  }

  @override
  void onClose() {
    unawaited(_videosSubscription?.cancel());
    unawaited(_channelVideosSubscription?.cancel());
    unawaited(_requestsSubscription?.cancel());
    super.onClose();
  }

  /// Inject or update channel navigation workspace context dynamically
  void setChannelContext(String id) {
    if (id.isNotEmpty && channelId.value != id) {
      channelId.value = id;
      _listenToChannelVideos();
    }
  }

  Future<void> _initializeContext() async {
    setViewState(ViewState.loading);
    final user = _auth.currentUser;
    if (user == null) {
      setError('User not authenticated');
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
          _listenToChannelVideos();
        })
        .catchError((e) {
          logger.error(
            'Failed to load base creator channel for audio tracks',
            error: e,
            tag: _tag,
          );
          _listenToChannelVideos();
        });
  }

  void _listenToChannelVideos() {
    final currentUser = _auth.currentUser;
    final targetOwnerId = currentUser?.uid ?? '';
    final targetChannelId = channelId.value;

    if (targetOwnerId.isEmpty && targetChannelId.isEmpty) {
      setViewState(ViewState.empty);
      return;
    }

    setViewState(ViewState.loading);
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
                setViewState(ViewState.error);
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
      commentaryTracks.clear();
      languageRequests.clear();
      return;
    }

    logger.info(
      'Selected video for audio tracks editing session: ${video.title}',
      tag: _tag,
    );

    _listenToLanguageRequests(video.id);

    // Lazy-load localization from subcollection first
    final localization = await VideoMediaService().getLocalization(video.id);

    // Extract commentary video items
    final commentaryMap = localization.commentaryVideos;
    final commentaryList = <CommentaryTrackItem>[];
    commentaryMap.forEach((key, map) {
      commentaryList.add(CommentaryTrackItem.fromMap(key, map));
    });
    commentaryTracks.value = commentaryList;

    // Extract pre-existing secondary audio map layouts
    final audioMap = localization.audioTracks.isNotEmpty
        ? localization.audioTracks
        : video.audioTracks;
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
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('language_requests')
        .snapshots()
        .listen(
          (snapshot) {
            final reqs = snapshot.docs
                .map((doc) => LanguageRequest.fromMap(doc.data(), doc.id))
                .toList();
            reqs.sort((a, b) {
              final countCompare = b.count.compareTo(a.count);
              if (countCompare != 0) return countCompare;
              return a.language.compareTo(b.language);
            });
            languageRequests.value = reqs;
            isLoadingRequests.value = false;
          },
          onError: (e) {
            logger.error(
              'Error listening to language requests',
              error: e,
              tag: _tag,
            );
            isLoadingRequests.value = false;
          },
        );
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

  Future<void> downloadAudioTrack(AudioTrackItem track) async {
    var url = track.audioUrl;
    final video = selectedVideo.value;
    if (url.isEmpty && video != null) {
      url = video.videoUrl;
    }

    if (url.isEmpty) {
      showError('No audio track URL available to download.');
      return;
    }

    var downloadUrl = url;
    if (url.startsWith('gs://')) {
      try {
        downloadUrl = await FirebaseStorage.instance
            .refFromURL(url)
            .getDownloadURL();
      } catch (e) {
        logger.error('Failed resolving gs:// audio track reference: $url', error: e, tag: _tag);
      }
    }

    final rawTitle = video?.title ?? 'audio';
    final videoTitle = rawTitle
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_${track.languageCode}_audio.mp3';

    DownloadHelper.downloadFromUrl(downloadUrl, fileName);
    showSuccess('Downloading ${track.languageName} Audio Track: $fileName');
  }

  Future<void> downloadCommentaryTrack(CommentaryTrackItem track) async {
    final url = track.audioUrl.isNotEmpty ? track.audioUrl : track.videoUrl;
    if (url.isEmpty) {
      showError('No media URL available to download.');
      return;
    }

    var downloadUrl = url;
    if (url.startsWith('gs://')) {
      try {
        downloadUrl = await FirebaseStorage.instance
            .refFromURL(url)
            .getDownloadURL();
      } catch (e) {
        logger.error('Failed resolving gs:// commentary track reference: $url', error: e, tag: _tag);
      }
    }

    final safeTitle = track.title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final ext = track.audioUrl.isNotEmpty ? 'mp3' : 'mp4';
    final fileName = '${safeTitle}_${track.langCode}.$ext';

    DownloadHelper.downloadFromUrl(downloadUrl, fileName);
    showSuccess('Downloading ${track.role} Track: $fileName');
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
    final validationResult = await validateContent(
      title,
      fieldName: 'Track Title',
    );
    if (!validationResult.isValid) {
      showError(validationResult.message);
      return false;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Preparing upload...';

    try {
      final fileBytes =
          file.bytes ??
          (file.path != null ? await file.xFile.readAsBytes() : null);
      if (fileBytes == null) {
        showError('Could not read file bytes.');
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
        // Save to audioTracks
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
        // Save to dubbedVideos
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

      // Sync active language selection and track view
      if (!availableLanguages.contains(langCode)) {
        availableLanguages.add(langCode);
      }
      selectedLanguage.value = langCode;
      _parseAudioTracksForLanguage(
        langCode,
        VideoMediaService.localizationCache[video.id]!.audioTracks,
      );

      selectedVideo.refresh();
      showSuccess('$type track "$title" uploaded successfully!');
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed to upload track file',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      showError('Unable to upload audio file. Please try again.');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  /// Upload multiple track files (Director's Commentary, Actors' Commentary, BTS, Voiceovers) together
  Future<bool> uploadMultipleTrackFiles({
    required List<BatchTrackUploadConfig> items,
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return false;
    }

    if (items.isEmpty) {
      showError('No files selected for batch upload.');
      return false;
    }

    // Validation check on all titles
    for (final item in items) {
      final validationResult = await validateContent(
        item.title,
        fieldName: 'Track Title',
      );
      if (!validationResult.isValid) {
        showError('Item "${item.title}": ${validationResult.message}');
        return false;
      }
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value =
        'Preparing batch upload of ${items.length} track(s)...';

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
        uploadStatus.value = 'Uploading (${i + 1}/$total): ${item.title}';

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
              uploadProgress.value = overallProgress;
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
        uploadProgress.value = completed / total;
      }

      uploadStatus.value = 'Saving references to cloud...';

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
      commentaryTracks.value = commentaryList;

      for (final item in items) {
        if (!availableLanguages.contains(item.langCode)) {
          availableLanguages.add(item.langCode);
        }
      }
      _parseAudioTracksForLanguage(
        selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
        updatedAudioMap,
      );

      selectedVideo.refresh();
      showSuccess('Successfully uploaded $completed track(s) in batch!');
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed executing batch upload',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      showError('Unable to complete batch upload. Please try again.');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  /// Remove an attached commentary or perspective video track
  Future<void> deleteCommentaryTrack(String trackId) async {
    final video = selectedVideo.value;
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
      commentaryTracks.value = commentaryList;
      selectedVideo.refresh();
      showSuccess('Commentary track removed successfully.');
    } catch (e, stack) {
      logger.error(
        'Failed to remove commentary track',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      showError('Unable to remove commentary track. Please try again.');
    }
  }

  /// Upload a single dubbed audio file directly for a specific language
  Future<bool> uploadSingleAudioDubForLanguage({
    required String langCode,
    required PlatformFile file,
  }) async {
    final video = selectedVideo.value;
    if (video == null) return false;

    isUploading.value = true;
    uploadProgress.value = 0.0;
    uploadStatus.value =
        'Uploading ${getLanguageName(langCode)} dubbed audio...';

    try {
      final fileBytes =
          file.bytes ??
          (file.path != null ? await file.xFile.readAsBytes() : null);
      if (fileBytes == null) {
        showError('Failed to read file.');
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
          customMetadata: {
            'uploaderId': ?currentUid,
          },
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

      if (!availableLanguages.contains(langCode)) {
        availableLanguages.add(langCode);
      }

      _parseAudioTracksForLanguage(
        selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
        updatedAudioMap,
      );

      selectedVideo.refresh();
      showSuccess(
        '${getLanguageName(langCode)} dubbed audio uploaded successfully!',
      );
      return true;
    } catch (e, stack) {
      logger.error(
        'Failed uploading dub for $langCode',
        error: e,
        stackTrace: stack,
        tag: _tag,
      );
      showError('Unable to upload audio dub. Please try again.');
      return false;
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  /// Update audio dub URL for a language directly
  Future<void> updateDubUrlForLanguage(String langCode, String url) async {
    final video = selectedVideo.value;
    if (video == null) return;

    final cachedLoc = VideoMediaService.localizationCache[video.id];
    final updatedAudioMap = Map<String, String>.from(
      cachedLoc?.audioTracks ?? video.audioTracks,
    );
    if (url.trim().isEmpty) {
      updatedAudioMap.remove(langCode);
    } else {
      updatedAudioMap[langCode] = url.trim();
    }

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

    if (!availableLanguages.contains(langCode) && url.trim().isNotEmpty) {
      availableLanguages.add(langCode);
    }

    _parseAudioTracksForLanguage(
      selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
      updatedAudioMap,
    );
    selectedVideo.refresh();
  }

  /// Remove dubbed audio track for a language
  Future<void> removeDubForLanguage(String langCode) async {
    await updateDubUrlForLanguage(langCode, '');
    showSuccess('${getLanguageName(langCode)} dubbed audio removed.');
  }

  String getLanguageName(String code) {
    final match = supportedLanguages.firstWhereOrNull((l) => l.code == code);
    return match?.name ?? code.toUpperCase();
  }
}

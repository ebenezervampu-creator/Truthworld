import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:multi_lang_bad_words_filter/multi_lang_bad_words_filter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/verification_cache_service.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/repositories/storage_video_upload_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

class UploadController extends BaseController with ContentValidationMixin {
  UploadController({VideoUploadRepository? uploadRepository})
      : _uploadRepository = uploadRepository ?? StorageVideoUploadRepository();

  final VideoUploadRepository _uploadRepository;

  Future<String?> uploadThumbnailWithRepo(Uint8List bytes, String fileName) async {
    final result = await _uploadRepository.uploadThumbnailBytes(imageBytes: bytes, fileName: fileName);
    return result.when(
      success: (url) => url,
      failure: (err) => null,
    );
  }

  final _imageVerificationService = ImageVerificationService();
  final _cacheService = VerificationCacheService();
  StreamSubscription? _thumbnailModerationSubscription;
  StreamSubscription? _communityImageModerationSubscription;

  /// Returns the upload progress as a formatted percentage string (e.g., '42%')
  String get uploadProgressPercent =>
      '${(uploadProgress.value * 100).toStringAsFixed(0)}%';

  /// Real-time video upload progress (0.0 - 1.0)
  RxDouble videoUploadProgress = 0.0.obs;

  /// Real-time image upload progress (0.0 - 1.0)
  RxDouble imageUploadProgress = 0.0.obs;

  /// Current upload progress (0.0 - 1.0) - maintained for backward compatibility with UI
  RxDouble uploadProgress = 0.0.obs;
  RxString selectedCategory = 'Other'.obs;

  /// Categories that are non-factual/creative where fact-checking is not needed
  static const Set<String> categoriesWithoutFactCheck = {
    'Music',
    'Entertainment',
    'Comedy',
    'Animation',
    'Movies',
    'Lifestyle',
    'Sports',
    'Pets & Animals',
    'Fashion',
    'Food & Cooking',
    'DIY & How-to',
  };

  /// Check whether fact checking is relevant for a given category name
  bool isFactCheckNeededForCategory(String category) {
    return !categoriesWithoutFactCheck.contains(category);
  }

  /// Whether Fact Checking is relevant for the currently selected category
  bool get isFactCheckRelevant =>
      isFactCheckNeededForCategory(selectedCategory.value);

  /// Select a category and handle fact check toggle availability
  void selectCategory(String cat) {
    selectedCategory.value = cat;
    if (!isFactCheckRelevant) {
      aiFactCheckEnabled.value = false;
    }
  }

  Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  RxString selectedVisibility = 'Public'.obs;
  RxBool isKidFriendly = false.obs;
  RxBool isShort = false.obs;
  RxString uploadQuality = 'Auto'.obs;
  RxBool enableComments = true.obs;
  RxBool allowRatings = false.obs;
  RxString selectedPlaylist = ''.obs;
  RxString selectedTopicId = ''.obs;
  RxList<Topic> availableTopics = <Topic>[].obs;
  RxBool isTopicsLoading = false.obs;
  RxString topicsError = ''.obs;
  RxString topicSearchQuery = ''.obs;
  final RxMap<String, Map<String, String>> channelMetadataCache =
      <String, Map<String, String>>{}.obs;
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  RxBool isScheduled = false.obs;
  Rx<DateTime> scheduledDate = DateTime.now().add(const Duration(days: 1)).obs;
  final RxString finalstatus = ''.obs;
  final RxString finalstatusReason = ''.obs;
  final RxString titleValidationStatus = 'UNKNOWN'.obs;
  final RxString titleValidationReason = ''.obs;
  final RxString descriptionValidationStatus = 'UNKNOWN'.obs;
  final RxString descriptionValidationReason = ''.obs;

  /// Mandatory creator copyright & rights ownership declaration
  final RxBool hasConfirmedCopyrightDeclaration = false.obs;

  // ══════════════════════════════════════════════════════════════
  // VIDEO CONTENT MODERATION STATE (Gemini Audio Analysis)
  // ══════════════════════════════════════════════════════════════
  final RxString videoModerationStatus = 'PENDING'.obs;
  final RxString videoModerationReason = ''.obs;
  final RxString videoModerationSummary = ''.obs;

  /// Whether the video content has been approved by Gemini moderation
  bool get isVideoContentApproved => videoModerationStatus.value == 'APPROVED';

  /// Whether the video was rejected (blocks Publish button)
  bool get isVideoContentRejected => videoModerationStatus.value == 'REJECTED';

  // ══════════════════════════════════════════════════════════════
  // AI FEATURE SELECTION STATE
  // ══════════════════════════════════════════════════════════════
  RxBool aiTranscriptEnabled = true.obs; // Always on
  RxBool aiChaptersEnabled = false.obs;
  RxBool aiGenerateSubtitles = false.obs;
  RxBool aiGenerateDubbing = false.obs;
  RxBool aiDiarizationEnabled = false.obs;
  RxBool aiSummaryEnabled = false.obs;
  RxList<String> aiTranslationLanguages = <String>[].obs;
  RxList<String> aiDubbingLanguages = <String>[].obs;
  RxBool aiTTSEnabled = false.obs;
  RxString aiTTSVoiceType = 'default'.obs; // "default" | "cloned"
  RxBool aiFactCheckEnabled = false.obs;
  Rx<PlatformFile?> voiceSampleFile = Rx<PlatformFile?>(null);

  /// Channel-provided sources & citation links for Credibility System
  RxList<String> providedSources = <String>[].obs;

  /// Whether sources validation passes (if fact checking is enabled, at least 1 source is required)
  bool get isFactCheckSourcesValid =>
      !aiFactCheckEnabled.value || providedSources.isNotEmpty;

  /// Add a source URL provided by the channel
  void addProvidedSource(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isNotEmpty && !providedSources.contains(cleanUrl)) {
      providedSources.add(cleanUrl);
    }
  }

  /// Remove a provided source at given index
  void removeProvidedSource(int index) {
    if (index >= 0 && index < providedSources.length) {
      providedSources.removeAt(index);
    }
  }

  /// Toggle subtitle language selection.
  /// Selecting in Subtitles does NOT select for Dubbing.
  void toggleSubtitleLanguage(String lang) {
    if (aiTranslationLanguages.contains(lang)) {
      aiTranslationLanguages.remove(lang);
      if (aiDubbingLanguages.contains(lang)) {
        aiDubbingLanguages.remove(lang);
      }
    } else {
      aiTranslationLanguages.add(lang);
    }
  }

  /// Toggle dubbing language selection.
  /// When selected in Dubbing, AUTOMATICALLY select it for Subtitles as well.
  void toggleDubbingLanguage(String lang) {
    if (aiDubbingLanguages.contains(lang)) {
      aiDubbingLanguages.remove(lang);
    } else {
      aiDubbingLanguages.add(lang);
      if (!aiTranslationLanguages.contains(lang)) {
        aiTranslationLanguages.add(lang);
      }
    }
  }

  /// Build the AI features map for Firestore.
  Map<String, dynamic> buildFeaturesMap({String? pipelineStage}) {
    final map = AIFeatures(
      genLangSubs: aiGenerateSubtitles.value,
      generateDubbing: aiGenerateDubbing.value,
      translationLanguages: List<String>.from(aiTranslationLanguages),
      tts: TTSConfig(
        enabled: aiGenerateDubbing.value,
        voiceType: aiTTSVoiceType.value == 'cloned'
            ? 'voice_clone'
            : 'standard',
      ),
      factChecking: aiFactCheckEnabled.value,
      diarization: aiDiarizationEnabled.value,
      summary: aiSummaryEnabled.value,
      autoChapters: aiChaptersEnabled.value,
      pipelineStage: pipelineStage,
    ).toMap();
    map['providedSources'] = List<String>.from(providedSources);
    map['dubbingLanguages'] = List<String>.from(aiDubbingLanguages);
    return map;
  }

  /// Pick a voice sample for TTS cloning.
  Future<void> pickVoiceSample() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        voiceSampleFile.value = result.files.first;
        Get.snackbar(
          'Success',
          'Voice sample selected: ${result.files.first.name}',
        );
      }
    } catch (e) {
      Get.snackbar('Error', r'Failed to pick voice sample: $e');
    }
  }

  VideoPlayerController? videoPlayerController;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final tagController = TextEditingController();

  List<String> videoCategories = [
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Technology',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion',
    'Food & Cooking',
    'Business & Finance',
    'Animation',
    'Short Films',
    'Motivation',
    'History',
    'Art & Design',
    'Automotive',
    'Animals & Pets',
    'Spirituality',
    'Nature & Wildlife',
    'Kids & Family',
  ];

  // ══════════════════════════════════════════════════════════════
  // DAILY UPLOAD QUOTA STATE (Standard Channel 20 min/day limit)
  // ══════════════════════════════════════════════════════════════
  /// Total video duration in seconds uploaded today by the currently selected channel
  final RxInt todayUploadedDurationSeconds = 0.obs;

  /// Remaining video duration in seconds available for today (max 1200s for standard)
  final RxInt remainingDailyDurationSeconds = 1200.obs;

  /// Whether today's daily upload limit (20 mins) has been reached
  final RxBool isDailyLimitReached = false.obs;

  /// Whether quota is currently being fetched
  final RxBool isQuotaLoading = false.obs;

  /// Human-readable string for today's uploaded duration (e.g., "15m 00s")
  String get todayUploadedDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        todayUploadedDurationSeconds.value,
      );

  /// Human-readable string for remaining daily duration (e.g., "5m 00s")
  String get remainingDailyDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        remainingDailyDurationSeconds.value,
      );

  /// Progress ratio (0.0 to 1.0) of today's 20-minute daily limit used
  double get dailyQuotaUsedRatio =>
      (todayUploadedDurationSeconds.value / 1200.0).clamp(0.0, 1.0);

  /// Fetches the total duration in seconds of videos uploaded today by the given channel
  Future<int> getTodayUploadedDurationSeconds(String channelId) async {
    if (channelId.trim().isEmpty) return 0;

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      var totalDurationSeconds = 0;
      for (final doc in snapshot.docs) {
        // Do not double count the active draft currently being resumed/edited
        if (_currentVideoId != null && doc.id == _currentVideoId) continue;

        final data = doc.data();
        final status = (data['status'] as String?)?.toLowerCase();
        // Exclude deleted, rejected, uncompleted drafts, and uploading placeholders
        if (status == 'deleted' ||
            status == 'rejected' ||
            status == 'draft' ||
            status == 'uploading') {
          continue;
        }

        final rawDate =
            data['uploadedAt'] ?? data['publishedAt'] ?? data['createdAt'];
        if (rawDate == null) continue;

        final uploadTime = TimestampUtils.parse(rawDate).toDate();
        if (uploadTime.isAfter(startOfToday) ||
            uploadTime.isAtSameMomentAs(startOfToday)) {
          var durSecs = 0;
          if (data['durationMs'] != null) {
            final ms = (data['durationMs'] as num).toInt();
            durSecs = (ms / 1000).round();
          } else if (data['duration'] != null) {
            final raw = (data['duration'] as num).toInt();
            durSecs = raw > 86400 ? (raw / 1000).round() : raw;
          }

          // Legacy correction: If an old video doc got assigned the 600s default without durationMs
          if (durSecs == 600 &&
              data['durationMs'] == null &&
              data['codec'] == 'unknown') {
            final fileSize = (data['fileSize'] as num?)?.toInt() ?? 0;
            if (fileSize > 0) {
              // Estimate duration based on standard 1080p/720p bitrate (~1.5 MB/sec)
              durSecs = (fileSize / (1024 * 1024 * 1.5)).clamp(30, 300).round();
            } else {
              durSecs = 120; // 2 minutes safe fallback
            }
          }

          totalDurationSeconds += durSecs;
        }
      }
      return totalDurationSeconds;
    } catch (e) {
      debugPrint('⚠️ Error fetching today uploaded duration: $e');
      return 0;
    }
  }

  /// Refreshes the daily upload quota for the selected channel
  Future<void> refreshDailyUploadQuota() async {
    final channel = selectedChannel.value;
    if (channel == null) return;

    if (channel.channelType != ChannelType.standard) {
      todayUploadedDurationSeconds.value = 0;
      remainingDailyDurationSeconds.value = 86400; // 24 hours
      isDailyLimitReached.value = false;
      return;
    }

    try {
      isQuotaLoading.value = true;
      final usedSeconds = await getTodayUploadedDurationSeconds(channel.id);
      todayUploadedDurationSeconds.value = usedSeconds;
      remainingDailyDurationSeconds.value = (1200 - usedSeconds).clamp(0, 1200);
      isDailyLimitReached.value = usedSeconds >= 1200;
      debugPrint(
        '📊 [UploadController] Daily quota for ${channel.channelName}: ${usedSeconds}s / 1200s used (${remainingDailyDurationSeconds.value}s remaining)',
      );
    } finally {
      isQuotaLoading.value = false;
    }
  }

  void selectChannel(Channel channel) {
    selectedChannel.value = channel;
    refreshDailyUploadQuota();
  }

  void selectPlaylist(String id) {
    selectedPlaylist.value = id;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  RxList<Video> videos = <Video>[].obs;
  RxList<Video> searchedVideos = <Video>[].obs;
  RxList<Channel> channels = <Channel>[].obs;

  Rx<PlatformFile?> pickedImage = Rx<PlatformFile?>(null);
  Rx<PlatformFile?> pickedCommunityImage = Rx<PlatformFile?>(null);
  Rx<PlatformFile?> pickedVideo = Rx<PlatformFile?>(null);

  // Storage for upload tasks and URLs
  UploadTask? _videoUploadTask;
  RxString videoUrl = ''.obs;
  RxString thumbnailUrl = ''.obs;
  RxString communityImageUrl = ''.obs;
  RxString communityImageStatus = ''.obs;
  RxString communityImageStatusReason = ''.obs;
  RxBool isUploading = false.obs;
  RxBool isCommunityPostUploading = false.obs;
  String?
  _currentVideoId; // Store the current video ID for linking storage and firestore

  /// Public getter for the current video ID being uploaded
  String? get currentVideoId => _currentVideoId;

  /// Holds the resumed video draft when editing from Creator Studio
  final Rx<Video?> resumedVideoDraft = Rx<Video?>(null);

  // Channel Loading State
  RxBool isChannelsLoading = true.obs;
  RxString channelsError = ''.obs;
  StreamSubscription<QuerySnapshot>? _channelsSubscription;

  // ══════════════════════════════════════════════════════════════
  // MULTI-STAGE UPLOAD STATE MANAGEMENT
  // ══════════════════════════════════════════════════════════════
  RxInt uploadStage = 0.obs; // 0: Media, 1: Details, 2: Settings, 3: Publish
  RxString uploadStageLabel = 'Upload Media'.obs;
  RxBool canAdvanceStage = false.obs;

  // UI Processing State
  RxBool isProcessing = false.obs;
  RxString processingMessage = ''.obs;
  RxBool isFormValid = false.obs;

  double get overallProgress => (uploadStage.value + 1) / 4.0;

  void setFormValid(bool valid) {
    if (isFormValid.value != valid) {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isClosed) {
            isFormValid.value = valid;
          }
        });
      } else {
        isFormValid.value = valid;
      }
    }
  }

  // Store video metadata between stages
  Map<String, dynamic> _videoMetadata = {};

  // Validation constants
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxTags = 5;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    fetchChannelsWithRetry();
    fetchAvailableTopics();

    // Every video doesn't have video rating only when user enabled Factchecking
    ever(aiFactCheckEnabled, (enabled) {
      allowRatings.value = enabled;
    });
  }

  @override
  void onClose() {
    videoPlayerController?.dispose();
    titleController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    _thumbnailModerationSubscription?.cancel();
    _communityImageModerationSubscription?.cancel();
    super.onClose();
  }

  // ==========================================================================
  // AUTHENTICATION & TOKEN MANAGEMENT
  // ==========================================================================

  /// Refresh the current user's auth token to ensure it's fresh
  Future<bool> _refreshAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return false;
      }

      // Force a token refresh with explicit caching invalidation
      final idToken = await user.getIdToken(true);

      // For web: ensure the token is persisted to localStorage
      if (kIsWeb) {
        debugPrint('🌐 Web platform detected - ensuring token persistence');
        // Token is automatically persisted by Firebase Auth SDK on web
      }

      debugPrint('✅ Auth token refreshed successfully');
      debugPrint('🔑 Token obtained (${idToken?.substring(0, 30)}...)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to refresh auth token: $e');
      return false;
    }
  }

  /// Verify user is authenticated and token is valid
  Future<bool> _verifyAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Refresh token to ensure it's valid
      final refreshed = await _refreshAuthToken();
      if (!refreshed) {
        throw Exception('Failed to refresh authentication token');
      }

      debugPrint('✅ Authentication verified for user: ${user.uid}');
      return true;
    } catch (e) {
      debugPrint('❌ Authentication verification failed: $e');
      Get.snackbar(
        'Authentication Error',
        'Please log in again to continue uploading',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  // ==========================================================================
  // MULTI-STAGE UPLOAD MANAGEMENT
  // ==========================================================================

  /// Update the current upload stage
  void setUploadStage(int stage) {
    uploadStage.value = stage;
    final stages = ['Upload Media', 'All Details', 'Settings', 'Publish'];
    uploadStageLabel.value = stages[stage];
    debugPrint('📍 Moved to stage $stage: ${stages[stage]}');
  }

  /// Check if current stage is complete and valid
  bool _isCurrentStageValid() {
    switch (uploadStage.value) {
      case 0: // Upload Media
        return pickedVideo.value != null && videoUrl.value.isNotEmpty;
      case 1: // All Details
        return _videoMetadata.containsKey('title') &&
            _videoMetadata['title'].toString().isNotEmpty;
      case 2: // Settings
        return _videoMetadata.containsKey('category');
      case 3: // Publish
        return true;
      default:
        return false;
    }
  }

  /// Advance to the next stage
  Future<bool> advanceUploadStage() async {
    if (!_isCurrentStageValid()) {
      Get.snackbar(
        'Incomplete Stage',
        'Please complete the current stage before advancing',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (uploadStage.value < 3) {
      setUploadStage(uploadStage.value + 1);
      return true;
    }
    return false;
  }

  /// Load an existing video draft from Firestore into UploadController
  void loadFromVideo(Video video) {
    resumedVideoDraft.value = video;
    _currentVideoId = video.id;

    videoUrl.value = video.originalUrl.isNotEmpty
        ? video.originalUrl
        : video.videoUrl;
    thumbnailUrl.value = video.thumbnailUrl;
    isUploading.value = false;
    isProcessing.value = false;
    uploadProgress.value = 1.0;
    videoUploadProgress.value = 1.0;

    // Title pre-fill: if generic 'Uploading...' or empty
    if (video.title.isNotEmpty &&
        video.title != 'Uploading...' &&
        video.title != 'Untitled' &&
        video.title != 'Untitled Draft') {
      titleController.text = video.title;
    }

    // Description pre-fill: if generic 'Processing...'
    if (video.description.isNotEmpty && video.description != 'Processing...') {
      descriptionController.text = video.description;
    }

    if (video.category.isNotEmpty) {
      selectedCategory.value = video.category;
    }

    if (video.visibility.isNotEmpty &&
        video.visibility.toLowerCase() != 'draft') {
      selectedVisibility.value = video.visibility;
    }

    if (video.tags.isNotEmpty) {
      tagController.text = video.tags.join(', ');
    }

    if (video.topics.isNotEmpty) {
      selectedTopicId.value = video.topics.first;
    }

    // Match channel
    if (video.channelId.isNotEmpty && channels.isNotEmpty) {
      final matching = channels.firstWhereOrNull(
        (c) => c.channelId == video.channelId || c.id == video.channelId,
      );
      if (matching != null) {
        selectedChannel.value = matching;
      }
    }

    if (video.geminiApproved != null && video.geminiApproved!) {
      videoModerationStatus.value = 'APPROVED';
    }

    isFormValid.value = titleController.text.trim().length >= 5;
    canAdvanceStage.value = true;
    uploadStage.value = 1; // Details stage

    debugPrint(
      '🎬 Video draft loaded into controller: ${video.id} (title: "${titleController.text}")',
    );
  }

  /// Load an existing video draft by document ID from Firestore
  Future<void> loadVideoById(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (doc.exists && doc.data() != null) {
        final v = Video.fromMap(doc.data()!, doc.id);
        loadFromVideo(v);
        final rawFileName = doc.data()!['fileName'] as String?;
        final moderation = doc.data()!['moderation'] as Map<String, dynamic>?;

        if (titleController.text.isEmpty &&
            rawFileName != null &&
            rawFileName.isNotEmpty) {
          final cleanName = rawFileName
              .replaceAll(
                RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
                '',
              )
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
          titleController.text = cleanName;
        }

        if (descriptionController.text.isEmpty && moderation != null) {
          final summary = moderation['summary'] as String?;
          if (summary != null && summary.isNotEmpty) {
            descriptionController.text = summary;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading video draft $videoId: $e');
    }
  }

  /// Ensure auth context is ready for Storage operations on web
  Future<void> _ensureStorageAuthReady() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the ID token and ensure it's fresh
      await user.getIdToken(true);

      // On web, add a small delay to ensure Firebase Storage SDK picks it up
      if (kIsWeb) {
        debugPrint('⏳ Waiting for Storage auth context sync...');
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('✅ Storage auth context synchronized');
      }

      debugPrint('✅ Storage auth ready for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Failed to prepare Storage auth: $e');
      throw Exception('Storage auth preparation failed: $e');
    }
  }

  // validateContent is now provided by ContentValidationMixin

  // validateTags is now provided by ContentValidationMixin

  // ==========================================================================
  // CHANNEL AND FILE MANAGEMENT
  // ==========================================================================

  Future<void> fetchChannelsWithRetry() async {
    isChannelsLoading.value = true;
    channelsError.value = '';
    fetchChannels();
  }

  // Fetch channels with robust multi-tier fallback (ownerId, userId, user doc, in-memory)
  void fetchChannels() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isChannelsLoading.value = false;
      channelsError.value = 'User not logged in';
      return;
    }

    debugPrint('🔍 Fetching channels for user: ${user.uid}');

    // Cancel existing subscription
    _channelsSubscription?.cancel();

    _channelsSubscription = _firestore
        .collection('channels')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint('✅ Channels loaded by ownerId: ${snapshot.docs.length}');

            var loadedChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((channel) => channel.status != ChannelStatus.deleted)
                .toList();

            // Fallback 1: Query by userId if ownerId returned 0 channels
            if (loadedChannels.isEmpty) {
              try {
                final userSnap = await _firestore
                    .collection('channels')
                    .where('userId', isEqualTo: user.uid)
                    .get();
                loadedChannels = userSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((channel) => channel.status != ChannelStatus.deleted)
                    .toList();
              } catch (e) {
                debugPrint('⚠️ Fetching channels by userId fallback: $e');
              }
            }

            // Fallback 2: Check user document for channelId reference
            if (loadedChannels.isEmpty) {
              try {
                final userDoc = await _firestore.collection('users').doc(user.uid).get();
                final chId = userDoc.data()?['channelId'] as String?;
                if (chId != null && chId.isNotEmpty) {
                  final chDoc = await _firestore.collection('channels').doc(chId).get();
                  if (chDoc.exists && chDoc.data() != null) {
                    final ch = Channel.fromDocumentSnapshot(chDoc);
                    if (ch.status != ChannelStatus.deleted) {
                      loadedChannels = [ch];
                    }
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Fetching channel by userDoc fallback: $e');
              }
            }

            // Fallback 3: In-memory AuthService channel
            if (loadedChannels.isEmpty && AuthService.to.userChannel != null) {
              final authCh = AuthService.to.userChannel!;
              if (authCh.status != ChannelStatus.deleted) {
                loadedChannels = [authCh];
              }
            }

            channels.value = loadedChannels;
            isChannelsLoading.value = false;
            channelsError.value = '';

            // Auto-select first channel if none selected or if selected channel changed
            if (channels.isNotEmpty) {
              if (selectedChannel.value == null ||
                  !channels.any((c) => c.id == selectedChannel.value!.id)) {
                selectedChannel.value = channels.first;
                refreshDailyUploadQuota();
                debugPrint(
                  'Auto-selected channel: ${channels.first.channelName}',
                );
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Error fetching channels: $error');
            if (AuthService.to.userChannel != null) {
              channels.value = [AuthService.to.userChannel!];
              selectedChannel.value = AuthService.to.userChannel;
              isChannelsLoading.value = false;
              channelsError.value = '';
            } else {
              isChannelsLoading.value = false;
              channelsError.value = 'Failed to load channels: $error';
            }
          },
        );
  }

  Future<void> pickImage({required bool forCommunity}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final extension = pickedFile.extension?.toLowerCase();
        const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif'};
        if (extension == null || !allowedExtensions.contains(extension)) {
          Get.snackbar(
            'Error',
            'Unsupported image format. Allowed formats: JPG, JPEG, PNG, GIF.',
          );
          return;
        }

        // Validate size (2MB limit for video thumbnails, 10MB limit for community posts)
        final maxSize = forCommunity ? 10 * 1024 * 1024 : 2 * 1024 * 1024;
        if (pickedFile.size > maxSize) {
          final sizeLimitMB = forCommunity ? '10MB' : '2MB';
          Get.snackbar(
            'Error',
            'Selected image exceeds the $sizeLimitMB limit.',
          );
          return;
        }

        if (forCommunity) {
          pickedCommunityImage.value = pickedFile;
        } else {
          pickedImage.value = pickedFile;
        }
        await _startImageUpload(pickedFile, forCommunity: forCommunity);
      } else {
        Get.snackbar('Info', 'No image selected.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        const maxSizeInBytes = 2 * 1024 * 1024 * 1024; // 2GB
        if (pickedFile.size > maxSizeInBytes) {
          Get.snackbar('Error', 'Selected video exceeds the 2GB limit.');
          return;
        }

        final extension = pickedFile.extension?.toLowerCase();
        const allowedExtensions = {
          'mp4',
          'mov',
          'avi',
          'wmv',
          'webm',
          'flv',
          '3gpp',
          '3gp',
          'mpeg',
          'mpg',
          'mkv',
          'mpegps',
          'm4v',
          'dnxhr',
          'prores',
          'cineform',
          'hevc',
        };
        if (extension == null || !allowedExtensions.contains(extension)) {
          Get.snackbar(
            'Error',
            'Unsupported video format. YouTube allowed formats are supported.',
          );
          return;
        }

        const maxDurationSeconds = 60 * 60; // 60 minutes

        int duration;
        if (kIsWeb) {
          final blob = html.Blob([pickedFile.bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final video = html.VideoElement()
            ..src = url
            ..preload = 'metadata';

          await video.onLoadedMetadata.first;
          duration = video.duration.floor();
          html.Url.revokeObjectUrl(url);
        } else {
          final file = io.File(pickedFile.path!);
          final controller = VideoPlayerController.file(file);

          await controller.initialize();
          duration = controller.value.duration.inSeconds;
          await controller.dispose();
        }

        // Validate Daily Upload Limit & Video Duration against selected channel
        final channel = selectedChannel.value;
        if (channel != null) {
          final todayUsed = await getTodayUploadedDurationSeconds(channel.id);
          todayUploadedDurationSeconds.value = todayUsed;
          remainingDailyDurationSeconds.value =
              (1200 - todayUsed).clamp(0, 1200);
          isDailyLimitReached.value = todayUsed >= 1200;

          final validation = validateChannelVideoUpload(
            channel,
            durationSeconds: duration,
            dailyUploadedDurationSeconds: todayUsed,
          );

          if (!validation.isValid) {
            Get.snackbar(
              'Upload Limit Exceeded',
              validation.message,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
              duration: const Duration(seconds: 6),
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }
        } else {
          if (duration > maxDurationSeconds) {
            Get.snackbar('Error', 'Video exceeds 60 minute limit.');
            return;
          }
        }

        pickedVideo.value = pickedFile;
        Get.snackbar('Success', 'Video selected successfully!');

        await initializeVideoPlayer();
        await _startVideoUpload(pickedVideo.value!);
      } else {
        Get.snackbar('Info', 'No video selected.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick video: $e');
    }
  }

  Future<void> initializeVideoPlayer() async {
    if (pickedVideo.value == null) return;

    final file = pickedVideo.value!;

    if (videoPlayerController != null) {
      await videoPlayerController!.dispose();
      videoPlayerController = null;
    }

    if (kIsWeb) {
      if (file.bytes == null) return;
      final blob = html.Blob([file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      if (file.path == null || !File(file.path!).existsSync()) return;
      videoPlayerController = VideoPlayerController.file(File(file.path!));
    }

    await videoPlayerController!.initialize();
    videoPlayerController!.setLooping(true);

    // Auto-detect if video is a Short (duration <= 60 seconds and vertical aspect ratio)
    final size = videoPlayerController!.value.size;
    final duration = videoPlayerController!.value.duration;
    isShort.value = size.height > size.width && duration.inSeconds <= 60;
    debugPrint(
      '🎥 Auto-detected isShort: ${isShort.value} (size: $size, duration: ${duration.inSeconds}s)',
    );

    update();
  }

  Future<String> getVideoDurationFormatted(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        final durationInSeconds = await videoElement.onLoadedMetadata.first
            .then((_) => videoElement.duration);

        html.Url.revokeObjectUrl(url);

        final duration = Duration(seconds: durationInSeconds.floor());
        return _formatDuration(duration);
      } else {
        final File tempFile;
        if (videoFile.path != null && File(videoFile.path!).existsSync()) {
          tempFile = File(videoFile.path!);
        } else {
          final tempDir = await getTemporaryDirectory();
          tempFile = File('${tempDir.path}/${videoFile.name}');
          if (videoFile.bytes != null) {
            await tempFile.writeAsBytes(videoFile.bytes!);
          }
        }

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();

        return _formatDuration(duration);
      }
    } catch (e) {
      throw Exception('Failed to get video duration: $e');
    }
  }

  Future<int> getVideoDurationMs(PlatformFile videoFile) async {
    try {
      if (kIsWeb) {
        if (videoFile.bytes == null) {
          return videoPlayerController?.value.duration.inMilliseconds ?? 0;
        }
        final blob = html.Blob([videoFile.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final videoElement = html.VideoElement()
          ..src = url
          ..preload = 'metadata';

        try {
          await videoElement.onLoadedMetadata.first.timeout(
            const Duration(seconds: 4),
          );
        } catch (_) {
          // Timeout or metadata load failure handled by fallback below
        }

        final durationInSeconds = videoElement.duration;

        html.Url.revokeObjectUrl(url);

        if (durationInSeconds.isNaN ||
            durationInSeconds.isInfinite ||
            durationInSeconds <= 0) {
          return videoPlayerController?.value.duration.inMilliseconds ?? 0;
        }

        return (durationInSeconds * 1000).floor();
      } else {
        if (videoPlayerController != null &&
            videoPlayerController!.value.isInitialized &&
            videoPlayerController!.value.duration.inMilliseconds > 0) {
          return videoPlayerController!.value.duration.inMilliseconds;
        }
        if (videoFile.bytes == null && videoFile.path == null) {
          return 0;
        }
        final File tempFile;
        if (videoFile.path != null && File(videoFile.path!).existsSync()) {
          tempFile = File(videoFile.path!);
        } else {
          final tempDir = await getTemporaryDirectory();
          tempFile = File('${tempDir.path}/${videoFile.name}');
          if (videoFile.bytes != null) {
            await tempFile.writeAsBytes(videoFile.bytes!);
          }
        }

        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        final durationMs = controller.value.duration.inMilliseconds;
        await controller.dispose();

        return durationMs;
      }
    } catch (e) {
      debugPrint('⚠️ Non-fatal error getting video duration: $e');
      return videoPlayerController?.value.duration.inMilliseconds ?? 0;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _startVideoUpload(PlatformFile videoFile) async {
    // Cancel any previous upload
    if (isUploading.value) {
      await _videoUploadTask?.cancel();
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;
    setUploadStage(0); // Start at Media upload stage

    StreamSubscription<DocumentSnapshot>? statusListener;

    try {
      // ✅ STEP 0: REFRESH AUTHENTICATION TOKEN
      debugPrint('🔐 Refreshing authentication token...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception('Authentication failed. Please log in again.');
      }

      debugPrint('🔐 Verifying authentication before upload...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userId = currentUser.uid;
      final uniqueId = const Uuid().v4();
      _currentVideoId = uniqueId;
      debugPrint('✅ Authenticated user: $userId');
      debugPrint('🆔 Generated video ID: $uniqueId');

      var preExtractDurationMs = 0;
      try {
        preExtractDurationMs = await getVideoDurationMs(videoFile);
      } catch (e) {
        debugPrint('⚠️ Could not extract duration before upload: $e');
      }
      final preExtractDurationSecs = preExtractDurationMs ~/ 1000;

      // Validate Daily Upload Quota before starting upload
      if (selectedChannel.value != null) {
        try {
          final used =
              await getTodayUploadedDurationSeconds(selectedChannel.value!.id);
          todayUploadedDurationSeconds.value = used;
          remainingDailyDurationSeconds.value =
              (1200 - used).clamp(0, 1200);
          isDailyLimitReached.value = used >= 1200;

          final validation = validateChannelVideoUpload(
            selectedChannel.value!,
            durationSeconds: preExtractDurationSecs,
            dailyUploadedDurationSeconds: used,
          );
          if (!validation.isValid) {
            throw Exception(validation.message);
          }
        } catch (e) {
          if (e.toString().contains('Daily') ||
              e.toString().contains('Standard channel')) {
            rethrow;
          }
          debugPrint('⚠️ Non-fatal error during video duration pre-check: $e');
        }
      }

      // --------------------------------------------------------
      // 1️⃣ Create initial Firestore document (with AI features)
      // --------------------------------------------------------
      final initialData = {
        'id': uniqueId,
        'ownerId': userId,
        'userId': userId,
        'channelId': selectedChannel.value?.channelId ?? userId,
        'status': 'uploading', // Will change via Cloud Function
        'uploadedAt': Timestamp.now(),
        'duration': preExtractDurationSecs,
        'durationMs': preExtractDurationMs,
        'title': 'Uploading...',
        'description': 'Processing...',
        'videoUrl': '',
        'thumbnailUrl': '',
        'likes': 0,
        'likeCount': 0,
        'dislikes': 0,
        'dislikeCount': 0,
        'views': 0,
        'viewCount': 0,
        'shareCount': 0,
        'downloads': 0,
        'reportCount': 0,
        'isBlocked': false,
        'visibility': selectedVisibility.value,
        'category': selectedCategory.value,
        'tags': [],
        'fileName': videoFile.name,
        // AI Processing features (read by backend pipeline)
        'aiFeatures': buildFeaturesMap(pipelineStage: 'draft'),
        'storage': {'videoPath': 'videos/$uniqueId/original.mp4'},
      };

      debugPrint('📄 Creating Firestore placeholder with AI features...');
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(uniqueId)
          .set(initialData);
      debugPrint(
        '✅ Placeholder created with features: ${initialData['features']}',
      );

      // --------------------------------------------------------
      // 2️⃣ Listen for Firestore status updates (from Cloud Function)
      // --------------------------------------------------------
      statusListener = FirebaseFirestore.instance
          .collection('videos')
          .doc(uniqueId)
          .snapshots()
          .listen((snapshot) {
            final data = snapshot.data();
            if (data == null) return;
            final status = data['status'] as String?;
            debugPrint('📡 Firestore status update: $status');

            // ── Video Content Moderation Status ──────────────────────
            final moderation = data['moderation'] as Map<String, dynamic>?;
            if (moderation != null) {
              final modStatus =
                  (moderation['status'] as String?)?.toUpperCase() ?? 'PENDING';
              final modReason = moderation['reason'] as String? ?? '';
              final modSummary = moderation['summary'] as String? ?? '';

              // Only show snackbar on status transition
              if (modStatus != videoModerationStatus.value) {
                videoModerationStatus.value = modStatus;
                videoModerationReason.value = modReason;
                videoModerationSummary.value = modSummary;

                if (modStatus == 'APPROVED') {
                  debugPrint('✅ Video content APPROVED by Verification System moderation');
                  Get.snackbar(
                    'Content Approved',
                    '✅ Your video complies with Community Guidelines',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(
                      0xFF10B981,
                    ).withValues(alpha: 0.15),
                  );
                } else if (modStatus == 'REJECTED') {
                  debugPrint('❌ Video content REJECTED: $modReason');
                  Get.snackbar(
                    'Content Rejected',
                    '❌ $modReason',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.15),
                    duration: const Duration(seconds: 5),
                  );
                } else if (modStatus == 'PROCESSING') {
                  debugPrint('🔍 Video content moderation in progress...');
                }
              }
            }

            // Sync URLs from backend if they exist
            if (data['videoUrl'] != null &&
                (data['videoUrl'] as String).isNotEmpty) {
              videoUrl.value = data['videoUrl'] as String;
            }
            if (data['thumbnailUrl'] != null &&
                (data['thumbnailUrl'] as String).isNotEmpty) {
              thumbnailUrl.value = data['thumbnailUrl'] as String;
            }

            if (status == 'processed') {
              debugPrint('✅ Processing completed successfully!');
              videoUploadProgress.value = 1.0;
              uploadProgress.value = 1.0;
              isUploading.value = false;

              // Final check on URLs to ensure UI is ready
              if (data['videoUrl'] != null) {
                videoUrl.value = data['videoUrl'] as String;
              }
              if (data['thumbnailUrl'] != null) {
                thumbnailUrl.value = data['thumbnailUrl'] as String;
              }

              Get.snackbar(
                'Success',
                'Video processed and ready to publish!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF10B981),
                colorText: AppColors.textPrimary,
              );
              statusListener?.cancel();
            } else if (status == 'rejected') {
              final reason =
                  data['rejectionReason'] ??
                  'Content violates Community Guidelines';
              debugPrint('❌ Video REJECTED by moderation: $reason');
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;
              Get.snackbar(
                'Video Rejected',
                '$reason',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444),
                colorText: AppColors.textPrimary,
                duration: const Duration(seconds: 5),
              );
              statusListener?.cancel();
            } else if (status == 'failed') {
              final error = data['error'] ?? 'Unknown processing error';
              debugPrint('❌ Processing failed: $error');
              isUploading.value = false;
              videoUploadProgress.value = 0.0;
              uploadProgress.value = 0.0;
              Get.snackbar(
                'Error',
                'Video processing failed: $error',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444),
                colorText: AppColors.textPrimary,
              );
              statusListener?.cancel();
            }
          });

      // --------------------------------------------------------
      // 3️⃣ Upload video to Firebase Storage
      // --------------------------------------------------------
      debugPrint('☁️ Uploading video to Firebase Storage...');

      // 🔑 CRITICAL: Ensure Storage auth context is ready on web
      debugPrint('🔐 Preparing Storage auth context...');
      await _ensureStorageAuthReady();

      // Upload to nested path: videos/{id}/original.mp4 (pipeline structure)
      final videoRef = FirebaseStorage.instance.ref().child(
        'videos/$uniqueId/original.mp4',
      );
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploaderId': userId,
          'duration': '$preExtractDurationSecs',
          'durationMs': '$preExtractDurationMs',
        },
      );
      if (kIsWeb) {
        if (videoFile.bytes == null) {
          throw Exception('Video file bytes are missing on web');
        }
        _videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);
      } else {
        if (videoFile.path != null && io.File(videoFile.path!).existsSync()) {
          _videoUploadTask = videoRef.putFile(io.File(videoFile.path!), metadata);
        } else if (videoFile.bytes != null) {
          _videoUploadTask = videoRef.putData(videoFile.bytes!, metadata);
        } else {
          throw Exception('Video file is missing both path and bytes');
        }
      }

      // Upload voice sample if Dubbing with cloning is selected
      if (aiGenerateDubbing.value &&
          aiTTSVoiceType.value == 'cloned' &&
          voiceSampleFile.value != null) {
        final sampleRef = FirebaseStorage.instance.ref().child(
          'videos/$uniqueId/voice_sample.mp3',
        );
        final sampleMeta = SettableMetadata(
          contentType: 'audio/mpeg',
          customMetadata: {
            'uploaderId': userId,
          },
        );
        final sampleFile = voiceSampleFile.value!;
        if (kIsWeb) {
          if (sampleFile.bytes != null) {
            await sampleRef.putData(sampleFile.bytes!, sampleMeta);
          }
        } else {
          if (sampleFile.path != null && io.File(sampleFile.path!).existsSync()) {
            await sampleRef.putFile(io.File(sampleFile.path!), sampleMeta);
          } else if (sampleFile.bytes != null) {
            await sampleRef.putData(sampleFile.bytes!, sampleMeta);
          }
        }
        debugPrint('🎙️ Voice sample uploaded for cloning');
      }

      _videoUploadTask!.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            // Report full upload progress (0.0 - 1.0). Do not cap at 90%.
            final progress = event.bytesTransferred / event.totalBytes;
            videoUploadProgress.value = progress;
            uploadProgress.value = progress;
            if (progress % 0.1 < 0.01) {
              debugPrint(
                '📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
              );
            }
          }
        },
        onError: (e) {
          debugPrint('Video upload stream error: $e');
        },
      );

      final snapshot = await _videoUploadTask!.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Video uploaded successfully');
      debugPrint('🔗 Video URL: $downloadUrl');
      videoUrl.value = downloadUrl;

      // --------------------------------------------------------
      // 4️⃣ Update Firestore with video URL
      // --------------------------------------------------------
      try {
        final latestDoc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(uniqueId)
            .get();
        final latestData = latestDoc.data();
        final targetStatus = latestData?['targetStatus'] as String?;
        final targetVisibility = latestData?['targetVisibility'] as String?;

        await FirebaseFirestore.instance
            .collection('videos')
            .doc(uniqueId)
            .update({
              'videoUrl': downloadUrl,
              'status': targetStatus == 'draft'
                  ? 'draft'
                  : 'processing', // Optional: hint for Cloud Function
              'visibility': ?targetVisibility,
            });
      } catch (e) {
        debugPrint('⚠️ Error syncing upload completion to Firestore: $e');
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(uniqueId)
            .update({
              'videoUrl': downloadUrl,
              'status': 'processing',
            });
      }

      // --------------------------------------------------------
      // 5️⃣ Notify user that processing is in progress
      // --------------------------------------------------------
      // Upload finished — show mostly-complete but not 100% so UI doesn't show published.
      // Keep a small gap while server-side processing completes.
      videoUploadProgress.value = 0.99;
      uploadProgress.value = 0.99;
      // Allow new uploads while processing continues server-side.
      isUploading.value = false;
      Get.snackbar(
        'Processing',
        'Upload complete! Processing video...',
        snackPosition: SnackPosition.BOTTOM,
      );

      debugPrint('⏳ Waiting for Cloud Function to complete processing...');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase error: ${e.message}');
      debugPrint('🔥 Firebase error code: ${e.code}');
      debugPrint('🔥 Firebase plugin: ${e.plugin}');
      debugPrint('🔥 Full exception: $e');
      isUploading.value = false;
      uploadProgress.value = 0.0;

      if (_currentVideoId != null) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(_currentVideoId)
            .delete();
        debugPrint('🗑️ Cleaned up failed Firestore document');
      }

      // Handle specific auth errors with web-specific diagnostics
      var errorMessage = 'Upload failed';
      if (e.code.contains('permission-denied') ||
          e.code.contains('unauthorized') ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage =
            'Authorization error. Please try:\n'
            '1. Clear browser cache (Ctrl+Shift+Del)\n'
            '2. Log out completely\n'
            '3. Log back in\n'
            '4. Try uploading again';
        debugPrint('⚠️ AUTH ERROR DETECTED');
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
        debugPrint('   Plugin: ${e.plugin}');
        debugPrint('   Platform: ${kIsWeb ? "Web (Flutter)" : "Native"}');
      } else if (e.code.contains('unauthenticated')) {
        errorMessage = 'Authentication expired. Please log in again.';
        debugPrint('⚠️ SESSION EXPIRED - Redirecting to login');
      } else {
        errorMessage = 'Failed to upload video: ${e.message}';
      }

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during upload: $e\n$stackTrace');
      isUploading.value = false;
      uploadProgress.value = 0.0;
      statusListener?.cancel();

      if (_currentVideoId != null) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(_currentVideoId)
            .delete();
      }

      Get.snackbar(
        'Error',
        'Unexpected error: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Separate refs/tasks for video thumbnails vs community post images
  Reference? _currentImageRefVideo;
  Reference? _currentImageRefCommunity;

  UploadTask? _currentUploadTaskVideo;
  UploadTask? _currentUploadTaskCommunity;

  // Keep track of moderation listeners for all uploaded images

  // Track uploaded doc ids (both video and community)
  List<String> uploadedDocIds = [];

  Future<void> _startImageUpload(
    PlatformFile imageFile, {
    bool forCommunity = false,
  }) async {
    uploadProgress.value = 0.0;

    // Determine which task/ref to use
    final activeTask = forCommunity
        ? _currentUploadTaskCommunity
        : _currentUploadTaskVideo;
    final existingRef = forCommunity
        ? _currentImageRefCommunity
        : _currentImageRefVideo;

    // 1️⃣ Cancel previous upload if running for this type
    if (activeTask != null) {
      try {
        await activeTask.cancel();
        debugPrint(
          "Previous ${forCommunity ? 'community' : 'video'} upload cancelled",
        );
      } catch (e) {
        debugPrint(
          "Failed to cancel previous ${forCommunity ? 'community' : 'video'} upload: $e",
        );
      }
    }

    // 2️⃣ Delete previous image from storage (if exists and uploaded) for this type
    if (existingRef != null) {
      try {
        await existingRef.getMetadata();
        await existingRef.delete();
        debugPrint(
          "Previous ${forCommunity ? 'community' : 'video'} image deleted from storage",
        );
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
          debugPrint('Previous image does not exist, skipping delete');
        } else {
          debugPrint('Failed to delete previous image: $e');
        }
      }
    }

    try {
      // 3️⃣ Generate unique file name (normalize extension for consistency)
      final extension = (imageFile.extension ?? 'jpg').toLowerCase();
      final uniqueFileName = '${_uuid.v4()}.$extension';
      final storagePath = forCommunity
          ? 'community_images/$uniqueFileName'
          : 'thumbnails/$uniqueFileName';
      final imageRef = _firebaseStorage.ref().child(storagePath);

      // Save ref in the correct slot
      if (forCommunity) {
        _currentImageRefCommunity = imageRef;
      } else {
        _currentImageRefVideo = imageRef;
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/${imageFile.extension}',
        customMetadata: {
          'uploaderId': ?currentUid,
        },
      );
      final UploadTask uploadTask;
      if (kIsWeb) {
        if (imageFile.bytes == null) {
          throw Exception('Image file bytes are missing on web');
        }
        uploadTask = imageRef.putData(imageFile.bytes!, metadata);
      } else {
        if (imageFile.path != null && io.File(imageFile.path!).existsSync()) {
          uploadTask = imageRef.putFile(io.File(imageFile.path!), metadata);
        } else if (imageFile.bytes != null) {
          uploadTask = imageRef.putData(imageFile.bytes!, metadata);
        } else {
          throw Exception('Image file is missing both path and bytes');
        }
      }
      if (forCommunity) {
        _currentUploadTaskCommunity = uploadTask;
      } else {
        _currentUploadTaskVideo = uploadTask;
      }

      // Track progress
      uploadTask.snapshotEvents.listen(
        (event) {
          if (event.totalBytes > 0) {
            imageUploadProgress.value =
                event.bytesTransferred / event.totalBytes;
          }
        },
        onError: (e) {
          debugPrint('Image upload stream error: $e');
        },
      );

      // 5️⃣ Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update UI with the latest image URL for the correct flow
      if (forCommunity) {
        communityImageUrl.value = downloadUrl;
      } else {
        thumbnailUrl.value = downloadUrl;
      }
      debugPrint('Image uploaded successfully: $downloadUrl');

      // 6️⃣ Track moderation for this image
      final docId = uniqueFileName;
      uploadedDocIds.add(docId);

      _startImageVerification(docId, forCommunity: forCommunity);
    } catch (e) {
      uploadProgress.value = 0.0;
      Get.snackbar('Error', 'Failed to upload image: $e');
    }
  }

  void _startImageVerification(String docId, {required bool forCommunity}) {
    final subscription = _imageVerificationService
        .streamVerificationStatus(docId)
        .listen(
          (result) {
            final status = result.status.name.toUpperCase();
            final reason = result.reason;

            if (forCommunity) {
              communityImageStatus.value = status;
              communityImageStatusReason.value = reason;
            } else {
              finalstatus.value = status;
              finalstatusReason.value = reason;
            }

            // Cache the result for future reference
            _cacheService.setVerification(docId, result);

            debugPrint(
              '🔍 [VERIFICATION UPDATE] $docId: $status (community=$forCommunity)',
            );
            debugPrint('   Reason: $reason');

            if (status == 'REJECTED') {
              Get.snackbar(
                'Rejected',
                'Your image was rejected: $reason',
                backgroundColor: Get.theme.colorScheme.error.withValues(
                  alpha: 0.1,
                ),
                duration: const Duration(seconds: 4),
              );
            } else if (status == 'FLAGGED') {
              Get.snackbar(
                'Review',
                'Your image needs review: $reason',
                backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                duration: const Duration(seconds: 4),
              );
            } else if (status == 'APPROVED') {
              Get.snackbar(
                'Approved',
                '✅ Your image was approved!',
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              );
            }

            if (status == 'APPROVED' || status == 'REJECTED') {
              Future.delayed(const Duration(seconds: 2), () {
                if (forCommunity) {
                  _communityImageModerationSubscription?.cancel();
                } else {
                  _thumbnailModerationSubscription?.cancel();
                }
              });
            }
          },
          onError: (error) {
            debugPrint('❌ [VERIFICATION ERROR] $error');
            if (forCommunity) {
              communityImageStatus.value = 'ERROR';
              communityImageStatusReason.value =
                  'Verification service error: $error';
            } else {
              finalstatus.value = 'ERROR';
              finalstatusReason.value = 'Verification service error: $error';
            }
            Get.snackbar(
              'Verification Error',
              'Failed to verify image: $error',
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
              duration: const Duration(seconds: 4),
            );
            if (forCommunity) {
              _communityImageModerationSubscription?.cancel();
            } else {
              _thumbnailModerationSubscription?.cancel();
            }
          },
        );

    if (forCommunity) {
      _communityImageModerationSubscription = subscription;
    } else {
      _thumbnailModerationSubscription = subscription;
    }
  }

  List<String> _generateKeywords(String title) {
    final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = cleanTitle
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final keywords = <String>{};
    for (final word in words) {
      keywords.add(word);
      for (var i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    return keywords.toList();
  }

  Future<void> refreshTitleDescriptionValidation(
    String title,
    String description,
  ) async {
    if (title.trim().isEmpty && description.trim().isEmpty) {
      titleValidationStatus.value = 'UNKNOWN';
      descriptionValidationStatus.value = 'UNKNOWN';
      titleValidationReason.value = '';
      descriptionValidationReason.value = '';
      return;
    }

    titleValidationStatus.value = 'PENDING';
    titleValidationReason.value = 'Checking title content...';
    descriptionValidationStatus.value = 'PENDING';
    descriptionValidationReason.value = 'Checking description content...';

    try {
      final titleResult = await validateContent(title, fieldName: 'Title');
      if (titleResult.isValid) {
        titleValidationStatus.value = 'APPROVED';
        titleValidationReason.value =
            'Title passed profanity and content validation checks.';
      } else {
        titleValidationStatus.value = 'REJECTED';
        titleValidationReason.value = titleResult.message;
      }
    } catch (e) {
      titleValidationStatus.value = 'REJECTED';
      titleValidationReason.value =
          'Unable to validate title content at this time.';
      debugPrint('❌ Title validation failed: $e');
    }

    try {
      final descriptionResult = await validateContent(
        description,
        fieldName: 'Description',
        checkPhoneNumbers: true,
      );

      if (descriptionResult.isValid) {
        descriptionValidationStatus.value = 'APPROVED';
        descriptionValidationReason.value =
            'Description passed profanity and content validation checks.';
      } else {
        descriptionValidationStatus.value = 'REJECTED';
        descriptionValidationReason.value = descriptionResult.message;
      }
    } catch (e) {
      descriptionValidationStatus.value = 'REJECTED';
      descriptionValidationReason.value =
          'Unable to validate description content at this time.';
      debugPrint('❌ Description validation failed: $e');
    }
  }

  Future<void> uploadVideo(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
    List<String> selectedLanguages, {
    bool isDraft = false,
  }) async {
    debugPrint('Starting final video metadata update (isDraft: $isDraft)...');

    // Store metadata for multi-stage flow
    _videoMetadata = {
      'title': title,
      'description': description,
      'channelName': channelName,
      'channelId': channelId,
      'channelImage': channelImage,
      'tags': tags,
      'languages': selectedLanguages,
    };

    if (pickedVideo.value == null && resumedVideoDraft.value == null) {
      Get.snackbar('Error', 'Please select a video.');
      throw Exception('Please select a video.');
    }

    final isStillUploading = videoUrl.value.isEmpty &&
        (isUploading.value || pickedVideo.value != null);

    // All your validations...
    if (title.isEmpty || title.length > maxTitleLength) {
      Get.snackbar('Error', 'Invalid title.');
      throw Exception(
        'Invalid title (length must be between 1 and $maxTitleLength characters).',
      );
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      Get.snackbar('Error', titleValidation.message);
      throw Exception(titleValidation.message);
    }

    // Description validation
    if (description.isEmpty || description.length > maxDescriptionLength) {
      Get.snackbar('Error', 'Invalid description.');
      throw Exception('Invalid description.');
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      Get.snackbar('Error', descValidation.message);
      throw Exception(descValidation.message);
    }

    // Tags validation
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        Get.snackbar('Error', tagsValidation.message);
        throw Exception(tagsValidation.message);
      }
    }

    if (channelName.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Selected channel name is missing. Please select a valid channel.',
      );
      throw Exception(
        'Selected channel name is missing. Please select a valid channel.',
      );
    }

    if (channelId.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Selected channel ID is missing. Please select a valid channel.',
      );
      throw Exception(
        'Selected channel ID is missing. Please select a valid channel.',
      );
    }

    try {
      // 🔑 REFRESH TOKEN BEFORE FINAL PUBLISH
      debugPrint('🔐 Refreshing token before final publish...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception('Authentication failed before publishing');
      }

      debugPrint('🔐 Checking authentication...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      final userId = currentUser.uid;
      debugPrint('✅ User authenticated: $userId');

      // Get video duration in milliseconds
      var durationMs = 0;
      if (pickedVideo.value != null) {
        durationMs = await getVideoDurationMs(pickedVideo.value!);
      } else if (resumedVideoDraft.value != null) {
        durationMs = resumedVideoDraft.value!.durationMs > 0
            ? resumedVideoDraft.value!.durationMs
            : resumedVideoDraft.value!.durationValue.inMilliseconds;
      }

      // Validate daily quota for selected channel before publishing
      final currentChan = selectedChannel.value;
      if (currentChan != null && !isDraft) {
        final durationSeconds = durationMs ~/ 1000;
        final used = await getTodayUploadedDurationSeconds(currentChan.id);
        final validation = validateChannelVideoUpload(
          currentChan,
          durationSeconds: durationSeconds,
          dailyUploadedDurationSeconds: used,
        );
        if (!validation.isValid) {
          Get.snackbar(
            'Upload Limit Exceeded',
            validation.message,
            backgroundColor: const Color(0xFFEF4444),
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
          );
          throw Exception(validation.message);
        }
      }

      // Upload thumbnail if needed
      if (thumbnailUrl.value.isEmpty && pickedImage.value != null) {
        await _startImageUpload(pickedImage.value!);
      }
      if (thumbnailUrl.value.isEmpty) {
        thumbnailUrl.value =
            'https://via.placeholder.com/1280x720.png?text=No+Thumbnail';
      }

      final validLanguages = selectedLanguages.whereType<String>().toList();

      // Use the ID that was created during video upload or generate a new one
      _currentVideoId ??= const Uuid().v4();
      final videoId = _currentVideoId!;

      debugPrint('📄 Video ID: $videoId');
      debugPrint('👤 Owner ID: $userId');

      // CHECK IF DOCUMENT EXISTS FIRST
      debugPrint('🔍 Checking if document exists...');
      final docRef = _firestore.collection('videos').doc(videoId);
      final docSnapshot = await docRef.get();

      // Prepare update data
      final updateData = {
        'title': title.trim(),
        'description': description.trim(),
        'keywords': _generateKeywords(title.trim()),
        'videoUrl': videoUrl.value.isNotEmpty
            ? videoUrl.value
            : (docSnapshot.data()?['videoUrl'] as String? ?? ''),
        'thumbnailUrl': thumbnailUrl.value.isNotEmpty
            ? thumbnailUrl.value
            : (docSnapshot.data()?['thumbnailUrl'] as String? ?? ''),
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'category': selectedCategory.value.isEmpty
            ? 'Uncategorized'
            : selectedCategory.value,
        'tags': validTags,
        'languages': validLanguages,
        'visibility': isDraft ? 'private' : selectedVisibility.value,
        'targetVisibility': isDraft ? 'private' : selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
        'isShort': isShort.value,
        'uploadQuality': uploadQuality.value.isEmpty
            ? 'Auto'
            : uploadQuality.value,
        'enableComments': enableComments.value,
        'allowRatings': allowRatings.value,
        'durationMs': durationMs > 0
            ? durationMs
            : ((docSnapshot.data()?['duration'] as int?) != null
                ? (docSnapshot.data()!['duration'] as int) * 1000
                : durationMs),
        'fileName': pickedVideo.value?.name ??
            (docSnapshot.data()?['fileName'] as String? ?? 'unnamed_video.mp4'),
        'status': isDraft
            ? 'draft'
            : (isStillUploading
                ? 'uploading'
                : (isScheduled.value ? 'scheduled' : 'published')),
        'targetStatus': isDraft
            ? 'draft'
            : (isScheduled.value ? 'scheduled' : 'published'),
        'aiFeatures': buildFeaturesMap(
          pipelineStage: isDraft ? 'draft' : 'published',
        ),
      };

      if (!docSnapshot.exists) {
        debugPrint('📄 Creating initial Firestore document with metadata...');
        await docRef.set({
          'id': videoId,
          'ownerId': userId,
          'userId': userId,
          'uploadedAt': Timestamp.now(),
          'likes': 0,
          'likeCount': 0,
          'dislikes': 0,
          'dislikeCount': 0,
          'views': 0,
          'viewCount': 0,
          'shareCount': 0,
          'downloads': 0,
          'reportCount': 0,
          'isBlocked': false,
          ...updateData,
        });
      } else {
        // Verify ownership if document exists
        final existingOwnerId = docSnapshot.data()?['ownerId'];
        if (existingOwnerId != null && existingOwnerId != userId) {
          debugPrint('❌ OWNERSHIP MISMATCH!');
          debugPrint('   Document ownerId: $existingOwnerId');
          debugPrint('   Current user ID: $userId');
          throw Exception('Ownership verification failed');
        }
        await docRef.update(updateData);
      }

      debugPrint('✅ Document updated with creator metadata');

      // Handle inline topic creation if needed
      if (newTopicData.isNotEmpty) {
        debugPrint('🆕 Creating new inline topic: ${newTopicData['title']}');

        final newTitle = (newTopicData['title'] as String?) ?? '';
        final newDescription = (newTopicData['description'] as String?) ?? '';
        final newCategory = (newTopicData['category'] as String?) ?? 'Science & Technology';
        final newVisibility =
            (newTopicData['visibilityType'] as TopicVisibilityType?) ??
            TopicVisibilityType.public;
        final newAccessCode = newTopicData['accessCode'] as String?;
        final thumbnailSource =
            (newTopicData['thumbnailSource'] as String?) ?? 'video';

        String? finalThumbnailUrl;
        if (thumbnailSource == 'custom' &&
            newTopicData['customThumbnailBytes'] != null) {
          final bytes = newTopicData['customThumbnailBytes'] as Uint8List;
          final customName = (newTopicData['customThumbnailName'] as String?) ?? 'thumb.jpg';
          final fileName = 'topic_${const Uuid().v4().substring(0, 8)}_$customName';
          finalThumbnailUrl = await uploadTopicCustomThumbnail(bytes, fileName);
        } else {
          // Use first video's thumbnail
          finalThumbnailUrl = thumbnailUrl.value;
        }

        final newSlug = newTitle
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');

        final existingSlug = await _firestore
            .collection('topics')
            .where('slug', isEqualTo: newSlug)
            .limit(1)
            .get();

        var finalSlug = newSlug;
        if (existingSlug.docs.isNotEmpty) {
          finalSlug = '$newSlug-${const Uuid().v4().substring(0, 6)}';
        }

        final rawHandle = (newTopicData['handle'] as String?) ?? '';
        var cleanHandle = rawHandle.trim();
        if (cleanHandle.startsWith('T/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        if (cleanHandle.startsWith('t/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        cleanHandle = cleanHandle
            .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp('-+'), '-');
        if (cleanHandle.isEmpty) {
          cleanHandle = finalSlug;
        }
        final finalHandle = 'T/$cleanHandle';
        final finalHandleLowercase = finalHandle.toLowerCase();

        final newTopicRef = _firestore.collection('topics').doc();
        final newTopic = Topic(
          id: newTopicRef.id,
          title: newTitle,
          slug: finalSlug,
          handle: finalHandle,
          handleLowercase: finalHandleLowercase,
          description: newDescription,
          category: newCategory,
          thumbnailUrl: finalThumbnailUrl,
          channelId: channelId.trim(),
          creatorId: userId,
          visibilityType: newVisibility,
          accessCode: newVisibility == TopicVisibilityType.private
              ? newAccessCode
              : null,
          videoCount: 1, // First video linked
          featuredVideoIds: [videoId],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'underReview',
        );

        await newTopicRef.set(newTopic.toMap());
        debugPrint(
          '✅ Inline topic created with slug: $finalSlug and handle: $finalHandle',
        );

        selectedTopicId.value = finalSlug;
        newTopicData.clear();
      }

      // Link video to topic if selected
      if (selectedTopicId.value.isNotEmpty && selectedTopicId.value != 'new_topic_draft') {
        debugPrint('🔗 Linking video to topic: ${selectedTopicId.value}');
        // Resolve canonical slug and increment video count on topic
        DocumentSnapshot? topicDoc;
        final bySlugQuery = await _firestore
            .collection('topics')
            .where('slug', isEqualTo: selectedTopicId.value)
            .limit(1)
            .get();
        if (bySlugQuery.docs.isNotEmpty) {
          topicDoc = bySlugQuery.docs.first;
        } else {
          final byIdDoc = await _firestore.collection('topics').doc(selectedTopicId.value).get();
          if (byIdDoc.exists) {
            topicDoc = byIdDoc;
          }
        }

        var finalTopicSlug = selectedTopicId.value;
        if (topicDoc != null && topicDoc.exists && topicDoc.data() != null) {
          final tData = topicDoc.data()! as Map<String, dynamic>;
          finalTopicSlug = (tData['slug'] as String?) ?? selectedTopicId.value;
          final topicCreatedAt = (tData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          if (DateTime.now().difference(topicCreatedAt).inSeconds > 5) {
            await topicDoc.reference.update({
              'videoCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Incremented videoCount for existing topic: $finalTopicSlug');
          }
        }

        updateData['topicId'] = finalTopicSlug;
        updateData['topics'] = [finalTopicSlug];
      }

      if (isScheduled.value) {
        updateData['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      debugPrint('📝 Updating document with metadata...');
      debugPrint('Update data keys: ${updateData.keys.toList()}');

      // IMPORTANT: Use update() not set() to preserve Cloud Function data
      await docRef.update(updateData);

      // Scan for handle mentions and notify
      final fullMetadataText = '${title.trim()} ${description.trim()}';
      try {
        await MentionsHelper.processAndNotifyMentions(
          text: fullMetadataText,
          videoId: videoId,
          videoTitle: title.trim(),
          videoThumbnailUrl: thumbnailUrl.value,
          videoChannelId: channelId.trim(),
        );
      } catch (e) {
        debugPrint('⚠️ Error processing mentions for video upload: $e');
      }

      debugPrint('✅ Document updated successfully!');

      // Add to playlist if selected
      if (selectedPlaylist.value.isNotEmpty) {
        debugPrint('📂 Adding to playlist: ${selectedPlaylist.value}');
        try {
          final playlistController = Get.isRegistered<PlaylistController>()
              ? Get.find<PlaylistController>()
              : Get.put(PlaylistController());

          final playlist = playlistController.allUserPlaylists.firstWhereOrNull((p) => p.id == selectedPlaylist.value)
              ?? playlistController.playlists.firstWhereOrNull((p) => p.id == selectedPlaylist.value)
              ?? playlistController.publicPlaylists.firstWhereOrNull((p) => p.id == selectedPlaylist.value);
          final isPublic = playlist?.isPublic ?? true;

          await playlistController.addVideoToPlaylist(
            selectedPlaylist.value,
            videoId,
            isPublic,
          );
          debugPrint(
            '✅ Successfully added video to playlist via PlaylistController',
          );
        } catch (e) {
          debugPrint('⚠️ Error adding to playlist via controller: $e');
          // Resilient direct Firestore update fallback
          try {
            final publicDoc = await _firestore.collection('public_playlists').doc(selectedPlaylist.value).get();
            if (publicDoc.exists) {
              await _firestore.collection('public_playlists').doc(selectedPlaylist.value).update({
                'videoIds': FieldValue.arrayUnion([videoId]),
                'videoCount': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              await _firestore.collection('public_playlists').doc(selectedPlaylist.value).collection('items').doc(videoId).set({
                'videoId': videoId,
                'addedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } else {
              await _firestore
                  .collection(FirestoreCollections.users)
                  .doc(userId)
                  .collection(FirestoreCollections.playlists)
                  .doc(selectedPlaylist.value)
                  .update({
                    'videoIds': FieldValue.arrayUnion([videoId]),
                    'videoCount': FieldValue.increment(1),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              await _firestore
                  .collection(FirestoreCollections.users)
                  .doc(userId)
                  .collection(FirestoreCollections.playlists)
                  .doc(selectedPlaylist.value)
                  .collection('items')
                  .doc(videoId)
                  .set({
                    'videoId': videoId,
                    'addedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
            }
          } catch (fallbackErr) {
            debugPrint('⚠️ Direct Firestore update also encountered: $fallbackErr');
          }
        }
      }

      // Move to publish stage
      setUploadStage(3);

      if (isStillUploading) {
        debugPrint('🎉 Video metadata updated! Video is uploading in background...');
        Get.snackbar(
          isDraft ? 'Draft Saved' : 'Publishing in Background',
          isDraft
              ? 'Your video was saved as a draft successfully.'
              : 'Video details saved! Uploading in background; it will be published automatically once processing completes.',
          backgroundColor: const Color(0xFF10B981),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 5),
        );
      } else {
        debugPrint('🎉 Upload completed successfully!');
        Get.snackbar(
          isDraft ? 'Draft Saved' : 'Success',
          isDraft
              ? 'Your video was saved as a draft successfully.'
              : 'Video uploaded successfully!',
          backgroundColor: const Color(0xFF10B981),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
        );
      }

      uploadProgress.value = 0.0;
      _resetUploads();
      if (Get.currentRoute != '/studio') {
        Get.offAllNamed('/studio');
      }
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException caught:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Plugin: ${e.plugin}');

      var errorMessage = 'Failed to update video: ';
      if (e.code == 'permission-denied' ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage +=
            'Permission denied. Please log in again and try uploading.';
        debugPrint('⚠️ AUTH ERROR - User needs to re-authenticate');
      } else {
        errorMessage += e.message ?? e.code;
      }

      Get.snackbar('Error', errorMessage);
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR: Upload failed');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      Get.snackbar('Error', 'Failed to complete video upload: $e');
      rethrow;
    }
  }
  // ==========================================================================
  // COMMUNITY POST UPLOAD WITH CONTENT VALIDATION
  // ==========================================================================

  Future<void> uploadCommunityPost(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
  ) async {
    if (isCommunityPostUploading.value) {
      Get.snackbar(
        'Please wait',
        'A community post is already being published.',
      );
      return;
    }

    // Check Moderation Status
    /* Images are now approved by default for smoother creation
    if (finalstatus.value == "REJECTED" || finalstatus.value == "FLAGGED") {
      Get.snackbar(
        "Moderation Blocked",
        "Your community post image was rejected. Please upload a compliant image.",
      );
      return;
    }
    if (finalstatus.value == "PENDING") {
      Get.snackbar("Processing", "Image is still being verified. Please wait.");
      return;
    }
    */
    if (pickedCommunityImage.value == null) {
      Get.snackbar('Error', 'Please select an image.');
      return;
    }

    if (communityImageUrl.value.isEmpty) {
      Get.snackbar('Error', 'Image upload not complete.');
      return;
    }

    // CONTENT VALIDATION - Title
    if (title.isEmpty) {
      Get.snackbar('Error', 'Title cannot be empty.');
      return;
    }

    if (title.length > maxTitleLength) {
      Get.snackbar('Error', 'Title cannot exceed $maxTitleLength characters.');
      return;
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      Get.snackbar('Error', titleValidation.message);
      return;
    }

    // CONTENT VALIDATION - Description
    if (description.isEmpty) {
      Get.snackbar('Error', 'Description cannot be empty.');
      return;
    }

    if (description.length > maxDescriptionLength) {
      Get.snackbar(
        'Error',
        'Description cannot exceed $maxDescriptionLength characters.',
      );
      return;
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      Get.snackbar('Error', descValidation.message);
      return;
    }

    // CONTENT VALIDATION - Tags
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        Get.snackbar('Error', tagsValidation.message);
        return;
      }
    }

    try {
      // 🔑 REFRESH TOKEN BEFORE COMMUNITY POST
      debugPrint('🔐 Refreshing token before community post...');
      final authValid = await _verifyAuthentication();
      if (!authValid) {
        throw Exception(
          'Authentication failed before uploading community post',
        );
      }

      isUploading.value = true;
      isCommunityPostUploading.value = true;
      final DocumentReference docRef = _firestore.collection('Community').doc();
      debugPrint('Attempting to publish community post with ID: ${docRef.id}');

      final data = <String, dynamic>{
        'id': docRef.id,
        'title': title.trim(),
        'description': description.trim(),
        'images': [communityImageUrl.value],
        'image': communityImageUrl.value,
        'likes': 0,
        'likeCount': 0,
        'dislikes': 0,
        'dislikeCount': 0,
        'commentCount': 0,
        'views': 0,
        'viewCount': 0,
        'shareCount': 0,
        'downloads': 0,
        'uploadedAt': Timestamp.now(),
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'selectedCategory': selectedCategory.value,
        'tags': validTags,
        'processed': false,
        'visibility': selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
      };

      if (isScheduled.value) {
        data['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      await docRef.set(data);
      debugPrint('Community post published successfully!');

      Get.snackbar('Success', 'Community Post uploaded successfully!');
      uploadProgress.value = 0.0;
      _resetUploads();
      if (Get.currentRoute != '/studio') {
        Get.offAllNamed('/studio');
      }
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException: ${e.code} - ${e.message}');
      var errorMessage = 'Failed to upload community post: ';
      if (e.code == 'permission-denied' ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage += 'Authentication failed. Please log in again.';
      } else {
        errorMessage += e.message ?? e.code;
      }
      Get.snackbar('Upload Failed', errorMessage);
    } catch (e) {
      debugPrint('CRITICAL: Failed to publish community post: $e');
      Get.snackbar(
        'Upload Failed',
        'Failed to publish post: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isUploading.value = false;
      isCommunityPostUploading.value = false;
    }
  }

  void _resetUploads() {
    videoUrl.value = '';
    thumbnailUrl.value = '';
    communityImageUrl.value = '';
    communityImageStatus.value = '';
    communityImageStatusReason.value = '';
    videoUploadProgress.value = 0.0;
    imageUploadProgress.value = 0.0;
    uploadProgress.value = 0.0;
    isCommunityPostUploading.value = false;
    isShort.value = false;
    _videoUploadTask = null;
    _currentUploadTaskVideo = null;
    _currentUploadTaskCommunity = null;
    _communityImageModerationSubscription?.cancel();
    _communityImageModerationSubscription = null;
    _thumbnailModerationSubscription?.cancel();
    _thumbnailModerationSubscription = null;
    pickedVideo.value = null;
    pickedImage.value = null;
    pickedCommunityImage.value = null;
    videoPlayerController?.dispose();
    videoPlayerController = null;
    selectedPlaylist.value = '';
    selectedTopicId.value = '';
    newTopicData.clear();
    isScheduled.value = false;
    _currentVideoId = null;
  }

  Future<void> fetchAvailableTopics() async {
    isTopicsLoading.value = true;
    topicsError.value = '';
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          AuthService.to.currentUser.value?.uid ??
          '';

      final snap = await _firestore
          .collection('topics')
          .where('status', isEqualTo: 'active')
          .get();

      final fetched = <Topic>[];
      for (final doc in snap.docs) {
        try {
          final t = Topic.fromDocumentSnapshot(doc);
          if (!t.isValidTopic || t.videoCount <= 0) continue;
          if (t.visibilityType == TopicVisibilityType.public ||
              (currentUserId.isNotEmpty && t.creatorId == currentUserId) ||
              (selectedChannel.value != null &&
                  t.channelId == selectedChannel.value!.id)) {
            fetched.add(t);
            // Pre-fetch channel metadata for public topics asynchronously
            if (t.channelId != null && t.channelId!.isNotEmpty) {
              fetchChannelMetadata(t.channelId!);
            }
          }
        } catch (e) {
          debugPrint('Error parsing topic doc: $e');
        }
      }

      availableTopics.value = fetched;
      debugPrint(
        'Fetched ${availableTopics.length} available topics for upload screen',
      );
    } catch (e) {
      debugPrint('Error fetching topics: $e');
      topicsError.value = e.toString();
    } finally {
      isTopicsLoading.value = false;
    }
  }

  /// Dynamically computes and ranks topic recommendations based on video details
  List<TopicRelevanceResult> getRankedTopicsForCurrentVideo({
    String? overrideTitle,
    String? overrideCategory,
    String? overrideDescription,
  }) {
    final title = (overrideTitle ?? titleController.text).trim();
    final category = (overrideCategory ?? selectedCategory.value).trim();
    final desc = (overrideDescription ?? descriptionController.text).trim();

    final results = <TopicRelevanceResult>[];

    Set<String> tokenizeText(String text) {
      if (text.isEmpty) return {};
      const stopWords = {
        'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
        'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
        'to', 'was', 'were', 'will', 'with', 'video', 'how', 'what'
      };
      final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
      return cleaned
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toSet();
    }

    final videoTokens = tokenizeText('$title $category $desc');
    final titleTokens = tokenizeText(title);
    final catClean = category.toLowerCase();

    for (final topic in availableTopics) {
      double score = 10;
      final reasons = <String>[];

      final topicCatClean = topic.category.toLowerCase();
      if (catClean.isNotEmpty &&
          topicCatClean.isNotEmpty &&
          (catClean == topicCatClean ||
              catClean.contains(topicCatClean) ||
              topicCatClean.contains(catClean))) {
        score += 45;
        reasons.add('Category match (${topic.category})');
      }

      final topicTitleTokens = tokenizeText('${topic.title} ${topic.handle}');
      var titleMatches = 0;
      for (final token in titleTokens) {
        if (topicTitleTokens.contains(token)) {
          titleMatches++;
          score += 15;
        }
      }
      if (titleMatches > 0) {
        reasons.add('$titleMatches matching title keywords');
      }

      final topicDescTokens = tokenizeText(topic.description);
      for (final token in videoTokens) {
        if (topicDescTokens.contains(token)) {
          score += 4;
        }
      }

      final popBonus = (topic.videoCount * 0.1 + topic.followerCount * 0.05).clamp(0.0, 10.0);
      score += popBonus;

      final rawPct = ((score / 110.0) * 100).round().clamp(62, 98);
      final reason = reasons.isNotEmpty
          ? reasons.join(' • ')
          : 'Relevant topic knowledge hub';

      results.add(
        TopicRelevanceResult(
          topic: topic,
          matchPercentage: rawPct,
          recommendationReason: reason,
          score: score,
        ),
      );
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Resolves and caches channel metadata (name, handle, avatar) for a given channelId
  Future<void> fetchChannelMetadata(String channelId) async {
    if (channelId.isEmpty || channelMetadataCache.containsKey(channelId)) {
      return;
    }

    // Check in user's own channels first
    for (final c in channels) {
      if (c.id == channelId) {
        channelMetadataCache[channelId] = {
          'name': c.channelName,
          'handle': c.handle,
          'avatarUrl': c.avatarUrl,
        };
        return;
      }
    }

    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name =
            (data['channelName'] ?? data['name'] ?? 'TruthWorld Channel')
                .toString();
        final handle = (data['handle'] ?? '').toString();
        final avatarUrl = (data['avatarUrl'] ?? '').toString();
        channelMetadataCache[channelId] = {
          'name': name,
          'handle': handle,
          'avatarUrl': avatarUrl,
        };
      } else {
        channelMetadataCache[channelId] = {
          'name': 'Channel',
          'handle': '',
          'avatarUrl': '',
        };
      }
    } catch (e) {
      debugPrint('Error fetching channel metadata for $channelId: $e');
    }
  }

  /// Synchronously retrieve cached channel metadata for a channelId or trigger async fetch
  Map<String, String>? getChannelMetadata(String channelId) {
    if (channelId.isEmpty) return null;
    if (channelMetadataCache.containsKey(channelId)) {
      return channelMetadataCache[channelId];
    }
    for (final c in channels) {
      if (c.id == channelId) {
        final meta = {
          'name': c.channelName,
          'handle': c.handle,
          'avatarUrl': c.avatarUrl,
        };
        channelMetadataCache[channelId] = meta;
        return meta;
      }
    }
    fetchChannelMetadata(channelId);
    return null;
  }

  void selectTopic(String id) {
    selectedTopicId.value = id;
  }

  Future<bool> unlockPrivateTopic(String slug, String passcode) async {
    try {
      final query = await _firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        Get.snackbar(
          'Error',
          'Topic not found with slug: $slug',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }

      final topicDoc = query.docs.first;
      final topic = Topic.fromDocumentSnapshot(topicDoc);

      if (!topic.isValidTopic || topic.videoCount <= 0) {
        Get.snackbar(
          'Error',
          'This private topic is inactive or has no videos',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }

      if (topic.visibilityType == TopicVisibilityType.private) {
        if (topic.accessCode != passcode) {
          Get.snackbar(
            'Error',
            'Incorrect passcode for private topic',
            backgroundColor: AppColors.error,
            colorText: AppColors.textPrimary,
          );
          return false;
        }
      }

      if (!availableTopics.any((t) => t.slug == topic.slug)) {
        availableTopics.add(topic);
      }
      selectedTopicId.value = topic.slug;
      Get.snackbar(
        'Success',
        'Successfully unlocked private topic: ${topic.title}',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to unlock topic: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }
  }

  Future<String?> uploadTopicCustomThumbnail(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      await _ensureStorageAuthReady();
      final ref = FirebaseStorage.instance.ref().child(
        'thumbnails/topics/$fileName',
      );
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
          'uploaded': DateTime.now().toString(),
        },
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading topic custom thumbnail: $e');
      return null;
    }
  }
}

// ==========================================================================
// CONTENT VALIDATION RESULT CLASS
// ==========================================================================

// ContentValidationResult is now provided by content_validation_mixin.dart

// ==========================================================================
// VIDEO REPOSITORY WITH REPORT SYSTEM
// ==========================================================================

class VideoReportRepository {
  VideoReportRepository() {
    _initializeFilters();
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int reportThresholdToBlock = 5;

  // Multi-layer profanity filtering for reports
  final ProfanityFilter _profanityFilter = ProfanityFilter();
  late final BadWordFilter _multiLangFilter;

  void _initializeFilters() {
    _multiLangFilter = BadWordFilter(
      languages: ['en', 'fa', 'ar', 'tr', 'de', 'fr', 'es', 'ru'],
      includeSensitiveTopics: true,
      matchInsideWords: true,
    );
  }

  /// Validate report details for inappropriate content
  Future<ContentValidationResult> validateReportDetails(String details) async {
    if (details.trim().isEmpty) {
      return const ContentValidationResult(isValid: true, message: 'Valid');
    }

    // Check for profanity in report details
    if (_profanityFilter.hasProfanity(details)) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate language.',
      );
    }

    final filteredText = _multiLangFilter.filterText(details);
    if (filteredText != details) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate content.',
      );
    }

    final containsBadWord = [
      'xxx',
      'nsfw',
      'porn',
      'sex',
      'nude',
    ].any((word) => details.toLowerCase().contains(word));

    if (containsBadWord) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Report details contain inappropriate language.',
      );
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  Future<void> addReport({
    required String videoId,
    required String reporterId,
    required String reportType,
    String? details,
  }) async {
    // Validate report details if provided
    if (details != null && details.trim().isNotEmpty) {
      final validation = await validateReportDetails(details);
      if (!validation.isValid) {
        throw Exception(validation.message);
      }
    }

    final videoRef = _firestore.collection('videos').doc(videoId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(videoRef);

        if (!snapshot.exists) {
          throw Exception('Video not found.');
        }

        final videoData = snapshot.data()!;
        final reports = (videoData['reports'] as List<dynamic>?) ?? [];
        var reportCount = (videoData['reportCount'] as num?)?.toInt() ?? 0;

        var isUpdated = false;

        // Check for existing report from the same reporter
        for (var i = 0; i < reports.length; i++) {
          final report = reports[i] as Map<String, dynamic>?;
          if (report != null && report['reporterId'] == reporterId) {
            reports[i] = {
              'reporterId': reporterId,
              'reportType': reportType,
              'details': details?.trim(),
              'uploadedAt': Timestamp.now(),
            };
            isUpdated = true;
            break;
          }
        }

        if (!isUpdated) {
          reports.add({
            'reporterId': reporterId,
            'reportType': reportType,
            'details': details?.trim(),
            'uploadedAt': Timestamp.now(),
          });
          reportCount++;
        }

        final shouldBlock = reportCount >= reportThresholdToBlock;

        transaction.update(videoRef, {
          'reports': reports,
          'reportCount': reportCount,
          'isBlocked': shouldBlock,
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}

/// Data model for topic recommendation relevance results
class TopicRelevanceResult {
  const TopicRelevanceResult({
    required this.topic,
    required this.matchPercentage,
    required this.recommendationReason,
    required this.score,
  });

  final Topic topic;
  final int matchPercentage;
  final String recommendationReason;
  final double score;
}

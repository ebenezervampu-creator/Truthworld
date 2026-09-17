import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/verification_cache_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/repositories/storage_video_upload_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_mixins.dart';
import 'package:video_player/video_player.dart';

// Re-export extracted models & repositories for 100% backward compatibility
export 'package:truthworld/features/video/data/models/topic_relevance_result.dart';
export 'package:truthworld/features/video/data/repositories/video_report_repository.dart';
export 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_mixins.dart';

class UploadController extends UploadControllerBase
    with
        UploadQuotaMixin,
        UploadAiFeaturesMixin,
        UploadMediaPickerMixin,
        UploadTopicsMixin,
        UploadPipelineMixin,
        UploadWizardMixin,
        UploadSubmissionMixin {
  UploadController({VideoUploadRepository? uploadRepository})
      : _uploadRepository = uploadRepository ?? StorageVideoUploadRepository();

  // Core Services
  final VideoUploadRepository _uploadRepository;
  @override
  VideoUploadRepository get uploadRepository => _uploadRepository;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  FirebaseFirestore get firestore => _firestore;

  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  @override
  FirebaseStorage get firebaseStorage => _firebaseStorage;

  final ImageVerificationService _imageVerificationService =
      ImageVerificationService();
  @override
  ImageVerificationService get imageVerificationService =>
      _imageVerificationService;

  final VerificationCacheService _cacheService = VerificationCacheService();
  @override
  VerificationCacheService get cacheService => _cacheService;

  final UserNotificationService _userNotificationService =
      UserNotificationService();
  @override
  UserNotificationService get userNotificationService =>
      _userNotificationService;

  // Channel Selection & Channels List
  @override
  final Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  @override
  final RxList<Channel> channels = <Channel>[].obs;
  @override
  final RxBool isChannelsLoading = true.obs;
  @override
  final RxString channelsError = ''.obs;
  @override
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? channelsSubscription;

  // Daily Upload Quota (Standard Channel 20 min/day limit)
  @override
  final RxInt todayUploadedDurationSeconds = 0.obs;
  @override
  final RxInt remainingDailyDurationSeconds = 1200.obs;
  @override
  final RxBool isDailyLimitReached = false.obs;
  @override
  final RxBool isQuotaLoading = false.obs;

  // Media
  @override
  final Rx<PlatformFile?> pickedVideo = Rx<PlatformFile?>(null);
  @override
  final Rx<PlatformFile?> pickedImage = Rx<PlatformFile?>(null);
  @override
  final Rx<PlatformFile?> pickedCommunityImage = Rx<PlatformFile?>(null);
  @override
  VideoPlayerController? videoPlayerController;
  @override
  final RxBool isVideoPlayerInitialized = false.obs;
  @override
  final RxBool isVideoPlaying = false.obs;
  @override
  final Rx<Duration> currentVideoPosition = Duration.zero.obs;
  @override
  final Rx<Duration> videoDuration = Duration.zero.obs;
  @override
  final RxInt videoDurationSeconds = 0.obs;

  // URLs & Progress
  @override
  final RxString videoUrl = ''.obs;
  @override
  final RxString thumbnailUrl = ''.obs;
  @override
  final RxString communityImageUrl = ''.obs;
  @override
  final RxString communityImageStatus = ''.obs;
  @override
  final RxString communityImageStatusReason = ''.obs;
  @override
  final RxDouble videoUploadProgress = 0.0.obs;
  @override
  final RxDouble imageUploadProgress = 0.0.obs;
  @override
  final RxDouble uploadProgress = 0.0.obs;
  @override
  final RxBool isUploading = false.obs;
  @override
  final RxBool isCommunityPostUploading = false.obs;
  @override
  String? currentVideoId;

  // Tasks & Subscriptions
  @override
  UploadTask? videoUploadTask;
  @override
  UploadTask? currentUploadTaskVideo;
  @override
  UploadTask? currentUploadTaskCommunity;
  @override
  StreamSubscription? communityImageModerationSubscription;
  @override
  StreamSubscription? thumbnailModerationSubscription;
  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? statusListener;

  // Category & Metadata
  @override
  final RxString selectedCategory = 'Other'.obs;
  @override
  final RxString selectedVisibility = 'Public'.obs;
  @override
  final RxBool isKidFriendly = false.obs;
  @override
  final RxBool isShort = false.obs;
  @override
  final RxString uploadQuality = 'Auto'.obs;
  @override
  final RxBool enableComments = true.obs;
  @override
  final RxBool allowRatings = false.obs;
  @override
  final RxString selectedPlaylist = ''.obs;
  @override
  final RxBool isScheduled = false.obs;
  @override
  final Rx<DateTime> scheduledDate =
      DateTime.now().add(const Duration(days: 1)).obs;

  // Validation
  @override
  final RxString finalstatus = ''.obs;
  @override
  final RxString finalstatusReason = ''.obs;
  @override
  final RxString titleValidationStatus = 'UNKNOWN'.obs;
  @override
  final RxString titleValidationReason = ''.obs;
  @override
  final RxString descriptionValidationStatus = 'UNKNOWN'.obs;
  @override
  final RxString descriptionValidationReason = ''.obs;
  @override
  final RxBool hasConfirmedCopyrightDeclaration = false.obs;
  @override
  final RxString videoModerationStatus = 'PENDING'.obs;
  @override
  final RxString videoModerationReason = ''.obs;
  @override
  final RxString videoModerationSummary = ''.obs;

  // AI Features
  @override
  final RxBool aiTranscriptEnabled = true.obs;
  @override
  final RxBool aiChaptersEnabled = false.obs;
  @override
  final RxBool aiGenerateSubtitles = false.obs;
  @override
  final RxBool aiGenerateDubbing = false.obs;
  @override
  final RxBool aiDiarizationEnabled = false.obs;
  @override
  final RxBool aiSummaryEnabled = false.obs;
  @override
  final RxList<String> aiTranslationLanguages = <String>[].obs;
  @override
  final RxList<String> aiDubbingLanguages = <String>[].obs;
  @override
  final RxBool aiTTSEnabled = false.obs;
  @override
  final RxString aiTTSVoiceType = 'default'.obs;
  @override
  final RxBool aiFactCheckEnabled = false.obs;
  @override
  final Rx<PlatformFile?> voiceSampleFile = Rx<PlatformFile?>(null);
  @override
  final RxList<String> providedSources = <String>[].obs;

  // Topics
  @override
  final RxString selectedTopicId = ''.obs;
  @override
  final RxList<Topic> availableTopics = <Topic>[].obs;
  @override
  final RxBool isTopicsLoading = false.obs;
  @override
  final RxString topicsError = ''.obs;
  @override
  final RxString topicSearchQuery = ''.obs;
  @override
  final RxMap<String, Map<String, String>> channelMetadataCache =
      <String, Map<String, String>>{}.obs;
  @override
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;

  // Wizard Stage
  @override
  final RxInt uploadStage = 0.obs;
  @override
  final RxString uploadStageLabel = 'Upload Media'.obs;
  @override
  final RxBool canAdvanceStage = false.obs;
  @override
  final RxBool isProcessing = false.obs;
  @override
  final RxString processingMessage = ''.obs;
  @override
  final RxBool isFormValid = false.obs;
  @override
  final Rx<Video?> resumedVideoDraft = Rx<Video?>(null);
  @override
  Map<String, dynamic> videoMetadata = {};

  // Text Controllers
  @override
  final TextEditingController titleController = TextEditingController();
  @override
  final TextEditingController descriptionController = TextEditingController();
  @override
  final TextEditingController tagController = TextEditingController();

  // Additional public fields & collections
  final RxList<Video> videos = <Video>[].obs;
  final RxList<Video> searchedVideos = <Video>[].obs;
  final List<String> videoCategories = [
    'General',
    'News & Politics',
    'Technology & Science',
    'Business & Finance',
    'Health & Wellness',
    'Education & Learning',
    'Entertainment',
    'Music',
    'Gaming',
    'Sports',
    'Comedy',
    'Animation',
    'Movies',
    'Lifestyle',
    'Pets & Animals',
    'Fashion',
    'Food & Cooking',
    'DIY & How-to',
    'Travel & Events',
    'Automotive',
    'Art & Design',
    'Other',
  ];

  // Helper getters & aliases
  @override
  String get uploadProgressPercent =>
      '%';

  bool get isVideoContentApproved => videoModerationStatus.value == 'APPROVED';
  bool get isVideoContentRejected => videoModerationStatus.value == 'REJECTED';

  void selectPlaylist(String id) {
    selectedPlaylist.value = id;
  }

  // Backwards compatibility aliases for private references
  UploadTask? get _videoUploadTask => videoUploadTask;
  set _videoUploadTask(UploadTask? t) => videoUploadTask = t;

  StreamSubscription? get _thumbnailModerationSubscription =>
      thumbnailModerationSubscription;
  set _thumbnailModerationSubscription(StreamSubscription? s) =>
      thumbnailModerationSubscription = s;

  StreamSubscription? get _communityImageModerationSubscription =>
      communityImageModerationSubscription;
  set _communityImageModerationSubscription(StreamSubscription? s) =>
      communityImageModerationSubscription = s;

  String? get _currentVideoId => currentVideoId;
  set _currentVideoId(String? id) => currentVideoId = id;

  Map<String, dynamic> get _videoMetadata => videoMetadata;
  set _videoMetadata(Map<String, dynamic> m) => videoMetadata = m;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      get _channelsSubscription => channelsSubscription;
  set _channelsSubscription(
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? s,
  ) =>
      channelsSubscription = s;

  void _resetUploads() => resetUploads();
  Future<void> _startImageUpload(
    PlatformFile file, {
    required bool forCommunity,
  }) =>
      startImageUpload(file, forCommunity: forCommunity);
  Future<bool> _verifyAuthentication() => verifyAuthentication();
  Future<bool> _refreshAuthToken() => refreshAuthToken();
  Future<void> _ensureStorageAuthReady() => ensureStorageAuthReady();
  bool _isCurrentStageValid() => isCurrentStageValid();

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
    thumbnailModerationSubscription?.cancel();
    communityImageModerationSubscription?.cancel();
    channelsSubscription?.cancel();
    statusListener?.cancel();
    super.onClose();
  }
}

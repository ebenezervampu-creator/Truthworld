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
  UploadController({
    VideoUploadRepository? uploadRepository,
    FirebaseFirestore? firestore,
    FirebaseStorage? firebaseStorage,
  })  : _uploadRepository = uploadRepository ?? StorageVideoUploadRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance {
    _bindLegacyPrimitiveSync();
  }

  // Core Services
  final VideoUploadRepository _uploadRepository;
  @override
  VideoUploadRepository get uploadRepository => _uploadRepository;

  final FirebaseFirestore _firestore;
  @override
  FirebaseFirestore get firestore => _firestore;

  final FirebaseStorage _firebaseStorage;
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

  // ── Immutable State Snapshot (Single Source of Truth) ─────────────────────
  final Rx<UploadState> _uploadState = const UploadState().obs;
  @override
  Rx<UploadState> get uploadState => _uploadState;

  bool _isSyncingFromState = false;
  bool _isSyncingToState = false;

  @override
  void emit(UploadState newState) {
    if (_uploadState.value == newState) return;
    _uploadState.value = newState;
    _syncStateToPrimitives(newState);
  }

  @override
  void updateState(UploadState Function(UploadState current) updater) {
    emit(updater(_uploadState.value));
  }

  void _syncStateToPrimitives(UploadState s) {
    if (_isSyncingToState) return;
    _isSyncingFromState = true;
    try {
      if (selectedChannel.value != s.selectedChannel) {
        selectedChannel.value = s.selectedChannel;
      }
      if (isChannelsLoading.value != s.isChannelsLoading) {
        isChannelsLoading.value = s.isChannelsLoading;
      }
      if (channelsError.value != s.channelsError) {
        channelsError.value = s.channelsError;
      }
      if (todayUploadedDurationSeconds.value != s.todayUploadedDurationSeconds) {
        todayUploadedDurationSeconds.value = s.todayUploadedDurationSeconds;
      }
      if (remainingDailyDurationSeconds.value != s.remainingDailyDurationSeconds) {
        remainingDailyDurationSeconds.value = s.remainingDailyDurationSeconds;
      }
      if (isDailyLimitReached.value != s.isDailyLimitReached) {
        isDailyLimitReached.value = s.isDailyLimitReached;
      }
      if (isQuotaLoading.value != s.isQuotaLoading) {
        isQuotaLoading.value = s.isQuotaLoading;
      }
      if (pickedVideo.value != s.pickedVideo) {
        pickedVideo.value = s.pickedVideo;
      }
      if (pickedImage.value != s.pickedImage) {
        pickedImage.value = s.pickedImage;
      }
      if (pickedCommunityImage.value != s.pickedCommunityImage) {
        pickedCommunityImage.value = s.pickedCommunityImage;
      }
      if (isVideoPlayerInitialized.value != s.isVideoPlayerInitialized) {
        isVideoPlayerInitialized.value = s.isVideoPlayerInitialized;
      }
      if (isVideoPlaying.value != s.isVideoPlaying) {
        isVideoPlaying.value = s.isVideoPlaying;
      }
      if (currentVideoPosition.value != s.currentVideoPosition) {
        currentVideoPosition.value = s.currentVideoPosition;
      }
      if (videoDuration.value != s.videoDuration) {
        videoDuration.value = s.videoDuration;
      }
      if (videoDurationSeconds.value != s.videoDurationSeconds) {
        videoDurationSeconds.value = s.videoDurationSeconds;
      }
      if (videoUrl.value != s.videoUrl) {
        videoUrl.value = s.videoUrl;
      }
      if (thumbnailUrl.value != s.thumbnailUrl) {
        thumbnailUrl.value = s.thumbnailUrl;
      }
      if (communityImageUrl.value != s.communityImageUrl) {
        communityImageUrl.value = s.communityImageUrl;
      }
      if (communityImageStatus.value != s.communityImageStatus) {
        communityImageStatus.value = s.communityImageStatus;
      }
      if (communityImageStatusReason.value != s.communityImageStatusReason) {
        communityImageStatusReason.value = s.communityImageStatusReason;
      }
      if (videoUploadProgress.value != s.videoUploadProgress) {
        videoUploadProgress.value = s.videoUploadProgress;
      }
      if (imageUploadProgress.value != s.imageUploadProgress) {
        imageUploadProgress.value = s.imageUploadProgress;
      }
      if (uploadProgress.value != s.uploadProgress) {
        uploadProgress.value = s.uploadProgress;
      }
      if (isUploading.value != s.isUploading) {
        isUploading.value = s.isUploading;
      }
      if (isCommunityPostUploading.value != s.isCommunityPostUploading) {
        isCommunityPostUploading.value = s.isCommunityPostUploading;
      }
      if (currentVideoId != s.currentVideoId) {
        currentVideoId = s.currentVideoId;
      }
      if (selectedCategory.value != s.selectedCategory) {
        selectedCategory.value = s.selectedCategory;
      }
      if (selectedVisibility.value != s.selectedVisibility) {
        selectedVisibility.value = s.selectedVisibility;
      }
      if (isKidFriendly.value != s.isKidFriendly) {
        isKidFriendly.value = s.isKidFriendly;
      }
      if (isShort.value != s.isShort) {
        isShort.value = s.isShort;
      }
      if (uploadQuality.value != s.uploadQuality) {
        uploadQuality.value = s.uploadQuality;
      }
      if (enableComments.value != s.enableComments) {
        enableComments.value = s.enableComments;
      }
      if (allowRatings.value != s.allowRatings) {
        allowRatings.value = s.allowRatings;
      }
      if (selectedPlaylist.value != s.selectedPlaylist) {
        selectedPlaylist.value = s.selectedPlaylist;
      }
      if (isScheduled.value != s.isScheduled) {
        isScheduled.value = s.isScheduled;
      }
      if (s.scheduledDate != null && scheduledDate.value != s.scheduledDate) {
        scheduledDate.value = s.scheduledDate!;
      }
      if (finalstatus.value != s.finalstatus) {
        finalstatus.value = s.finalstatus;
      }
      if (finalstatusReason.value != s.finalstatusReason) {
        finalstatusReason.value = s.finalstatusReason;
      }
      if (titleValidationStatus.value != s.titleValidationStatus) {
        titleValidationStatus.value = s.titleValidationStatus;
      }
      if (titleValidationReason.value != s.titleValidationReason) {
        titleValidationReason.value = s.titleValidationReason;
      }
      if (descriptionValidationStatus.value != s.descriptionValidationStatus) {
        descriptionValidationStatus.value = s.descriptionValidationStatus;
      }
      if (descriptionValidationReason.value != s.descriptionValidationReason) {
        descriptionValidationReason.value = s.descriptionValidationReason;
      }
      if (hasConfirmedCopyrightDeclaration.value !=
          s.hasConfirmedCopyrightDeclaration) {
        hasConfirmedCopyrightDeclaration.value =
            s.hasConfirmedCopyrightDeclaration;
      }
      if (videoModerationStatus.value != s.videoModerationStatus) {
        videoModerationStatus.value = s.videoModerationStatus;
      }
      if (videoModerationReason.value != s.videoModerationReason) {
        videoModerationReason.value = s.videoModerationReason;
      }
      if (videoModerationSummary.value != s.videoModerationSummary) {
        videoModerationSummary.value = s.videoModerationSummary;
      }
      if (uploadStage.value != s.uploadStage) {
        uploadStage.value = s.uploadStage;
      }
      if (uploadStageLabel.value != s.uploadStageLabel) {
        uploadStageLabel.value = s.uploadStageLabel;
      }
      if (canAdvanceStage.value != s.canAdvanceStage) {
        canAdvanceStage.value = s.canAdvanceStage;
      }
      if (isProcessing.value != s.isProcessing) {
        isProcessing.value = s.isProcessing;
      }
      if (processingMessage.value != s.processingMessage) {
        processingMessage.value = s.processingMessage;
      }
      if (isFormValid.value != s.isFormValid) {
        isFormValid.value = s.isFormValid;
      }
      if (resumedVideoDraft.value != s.resumedVideoDraft) {
        resumedVideoDraft.value = s.resumedVideoDraft;
      }
      if (videoMetadata != s.videoMetadata) {
        videoMetadata = s.videoMetadata;
      }
      if (selectedTopicId.value != s.selectedTopicId) {
        selectedTopicId.value = s.selectedTopicId;
      }
      if (isTopicsLoading.value != s.isTopicsLoading) {
        isTopicsLoading.value = s.isTopicsLoading;
      }
      if (topicsError.value != s.topicsError) {
        topicsError.value = s.topicsError;
      }
      if (topicSearchQuery.value != s.topicSearchQuery) {
        topicSearchQuery.value = s.topicSearchQuery;
      }
    } finally {
      _isSyncingFromState = false;
    }
  }

  void _syncPrimitiveToState(UploadState Function(UploadState current) updater) {
    if (_isSyncingFromState) return;
    _isSyncingToState = true;
    try {
      _uploadState.value = updater(_uploadState.value);
    } finally {
      _isSyncingToState = false;
    }
  }

  void _bindLegacyPrimitiveSync() {
    addWorker(ever(selectedChannel, (c) => _syncPrimitiveToState((s) => s.copyWith(selectedChannel: c))));
    addWorker(ever(todayUploadedDurationSeconds, (v) => _syncPrimitiveToState((s) => s.copyWith(todayUploadedDurationSeconds: v))));
    addWorker(ever(remainingDailyDurationSeconds, (v) => _syncPrimitiveToState((s) => s.copyWith(remainingDailyDurationSeconds: v))));
    addWorker(ever(isDailyLimitReached, (v) => _syncPrimitiveToState((s) => s.copyWith(isDailyLimitReached: v))));
    addWorker(ever(isQuotaLoading, (v) => _syncPrimitiveToState((s) => s.copyWith(isQuotaLoading: v))));
    addWorker(ever(isUploading, (v) => _syncPrimitiveToState((s) => s.copyWith(isUploading: v))));
    addWorker(ever(uploadProgress, (v) => _syncPrimitiveToState((s) => s.copyWith(uploadProgress: v))));
    addWorker(ever(videoUploadProgress, (v) => _syncPrimitiveToState((s) => s.copyWith(videoUploadProgress: v))));
    addWorker(ever(imageUploadProgress, (v) => _syncPrimitiveToState((s) => s.copyWith(imageUploadProgress: v))));
    addWorker(ever(pickedVideo, (v) => _syncPrimitiveToState((s) => s.copyWith(pickedVideo: v))));
    addWorker(ever(pickedImage, (v) => _syncPrimitiveToState((s) => s.copyWith(pickedImage: v))));
    addWorker(ever(pickedCommunityImage, (v) => _syncPrimitiveToState((s) => s.copyWith(pickedCommunityImage: v))));
    addWorker(ever(uploadStage, (v) => _syncPrimitiveToState((s) => s.copyWith(uploadStage: v))));
    addWorker(ever(uploadStageLabel, (v) => _syncPrimitiveToState((s) => s.copyWith(uploadStageLabel: v))));
    addWorker(ever(canAdvanceStage, (v) => _syncPrimitiveToState((s) => s.copyWith(canAdvanceStage: v))));
    addWorker(ever(isProcessing, (v) => _syncPrimitiveToState((s) => s.copyWith(isProcessing: v))));
    addWorker(ever(processingMessage, (v) => _syncPrimitiveToState((s) => s.copyWith(processingMessage: v))));
    addWorker(ever(isFormValid, (v) => _syncPrimitiveToState((s) => s.copyWith(isFormValid: v))));
    addWorker(ever(videoModerationStatus, (v) => _syncPrimitiveToState((s) => s.copyWith(videoModerationStatus: v))));
    addWorker(ever(videoModerationReason, (v) => _syncPrimitiveToState((s) => s.copyWith(videoModerationReason: v))));
    addWorker(ever(hasConfirmedCopyrightDeclaration, (v) => _syncPrimitiveToState((s) => s.copyWith(hasConfirmedCopyrightDeclaration: v))));
  }

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

  // Daily Upload Quota (Standard Channel 10 min/day limit)
  @override
  final RxInt todayUploadedDurationSeconds = 0.obs;
  @override
  final RxInt remainingDailyDurationSeconds = 600.obs;
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
  final RxBool aiSummaryEnabled = true.obs;
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
  final RxString aiFactCheckTier = 'full_ground'.obs;
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

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    fetchChannelsWithRetry();
    fetchAvailableTopics();

    // Every video doesn't have video rating only when user enabled Factchecking
    addWorker(
      ever(aiFactCheckEnabled, (enabled) {
        allowRatings.value = enabled;
      }),
    );
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

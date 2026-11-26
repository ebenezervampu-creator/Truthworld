import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:video_player/video_player.dart';

/// Manages reactive state storage, atomic snapshots, and two-way primitive synchronization
/// for UploadController, shielding business logic from boilerplate.
mixin UploadReactiveStorageMixin on UploadControllerBase {
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
    syncStateToPrimitives(newState);
  }

  @override
  void updateState(UploadState Function(UploadState current) updater) {
    emit(updater(_uploadState.value));
  }

  void syncStateToPrimitives(UploadState s) {
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
      if (aiTranscriptEnabled.value != s.aiTranscriptEnabled) {
        aiTranscriptEnabled.value = s.aiTranscriptEnabled;
      }
      if (aiChaptersEnabled.value != s.aiChaptersEnabled) {
        aiChaptersEnabled.value = s.aiChaptersEnabled;
      }
      if (aiGenerateSubtitles.value != s.aiGenerateSubtitles) {
        aiGenerateSubtitles.value = s.aiGenerateSubtitles;
      }
      if (aiGenerateDubbing.value != s.aiGenerateDubbing) {
        aiGenerateDubbing.value = s.aiGenerateDubbing;
      }
      if (aiDiarizationEnabled.value != s.aiDiarizationEnabled) {
        aiDiarizationEnabled.value = s.aiDiarizationEnabled;
      }
      if (aiSummaryEnabled.value != s.aiSummaryEnabled) {
        aiSummaryEnabled.value = s.aiSummaryEnabled;
      }
      if (aiFactCheckEnabled.value != s.aiFactCheckEnabled) {
        aiFactCheckEnabled.value = s.aiFactCheckEnabled;
      }
      if (aiFactCheckTier.value != s.aiFactCheckTier) {
        aiFactCheckTier.value = s.aiFactCheckTier;
      }
      if (aiFactCheckReviewMode.value != s.aiFactCheckReviewMode) {
        aiFactCheckReviewMode.value = s.aiFactCheckReviewMode;
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

  void syncPrimitiveToState(UploadState Function(UploadState current) updater) {
    if (_isSyncingFromState) return;
    _isSyncingToState = true;
    try {
      _uploadState.value = updater(_uploadState.value);
    } finally {
      _isSyncingToState = false;
    }
  }

  void bindLegacyPrimitiveSync() {
    addWorker(ever(selectedChannel, (c) {
      syncPrimitiveToState((s) => s.copyWith(selectedChannel: c));
      if (resumedVideoDraft.value == null && c != null) {
        final cat = resolveChannelFirstCategory(c);
        if (cat.isNotEmpty && (selectedCategory.value.isEmpty || selectedCategory.value == 'Other')) {
          selectedCategory.value = cat;
        }
      }
    }));
    addWorker(ever(selectedCategory, (v) => syncPrimitiveToState((s) => s.copyWith(selectedCategory: v))));
    addWorker(ever(todayUploadedDurationSeconds, (v) => syncPrimitiveToState((s) => s.copyWith(todayUploadedDurationSeconds: v))));
    addWorker(ever(remainingDailyDurationSeconds, (v) => syncPrimitiveToState((s) => s.copyWith(remainingDailyDurationSeconds: v))));
    addWorker(ever(isDailyLimitReached, (v) => syncPrimitiveToState((s) => s.copyWith(isDailyLimitReached: v))));
    addWorker(ever(isQuotaLoading, (v) => syncPrimitiveToState((s) => s.copyWith(isQuotaLoading: v))));
    addWorker(ever(isUploading, (v) => syncPrimitiveToState((s) => s.copyWith(isUploading: v))));
    addWorker(ever(uploadProgress, (v) => syncPrimitiveToState((s) => s.copyWith(uploadProgress: v))));
    addWorker(ever(videoUploadProgress, (v) => syncPrimitiveToState((s) => s.copyWith(videoUploadProgress: v))));
    addWorker(ever(imageUploadProgress, (v) => syncPrimitiveToState((s) => s.copyWith(imageUploadProgress: v))));
    addWorker(ever(pickedVideo, (v) => syncPrimitiveToState((s) => s.copyWith(pickedVideo: v))));
    addWorker(ever(pickedImage, (v) => syncPrimitiveToState((s) => s.copyWith(pickedImage: v))));
    addWorker(ever(pickedCommunityImage, (v) => syncPrimitiveToState((s) => s.copyWith(pickedCommunityImage: v))));
    addWorker(ever(uploadStage, (v) => syncPrimitiveToState((s) => s.copyWith(uploadStage: v))));
    addWorker(ever(uploadStageLabel, (v) => syncPrimitiveToState((s) => s.copyWith(uploadStageLabel: v))));
    addWorker(ever(canAdvanceStage, (v) => syncPrimitiveToState((s) => s.copyWith(canAdvanceStage: v))));
    addWorker(ever(isProcessing, (v) => syncPrimitiveToState((s) => s.copyWith(isProcessing: v))));
    addWorker(ever(processingMessage, (v) => syncPrimitiveToState((s) => s.copyWith(processingMessage: v))));
    addWorker(ever(isFormValid, (v) => syncPrimitiveToState((s) => s.copyWith(isFormValid: v))));
    addWorker(ever(videoModerationStatus, (v) => syncPrimitiveToState((s) => s.copyWith(videoModerationStatus: v))));
    addWorker(ever(videoModerationReason, (v) => syncPrimitiveToState((s) => s.copyWith(videoModerationReason: v))));
    addWorker(ever(hasConfirmedCopyrightDeclaration, (v) => syncPrimitiveToState((s) => s.copyWith(hasConfirmedCopyrightDeclaration: v))));
    addWorker(ever(aiTranscriptEnabled, (v) => syncPrimitiveToState((s) => s.copyWith(aiTranscriptEnabled: v))));
    addWorker(ever(aiChaptersEnabled, (v) => syncPrimitiveToState((s) => s.copyWith(aiChaptersEnabled: v))));
    addWorker(ever(aiGenerateSubtitles, (v) => syncPrimitiveToState((s) => s.copyWith(aiGenerateSubtitles: v))));
    addWorker(ever(aiGenerateDubbing, (v) => syncPrimitiveToState((s) => s.copyWith(aiGenerateDubbing: v))));
    addWorker(ever(aiDiarizationEnabled, (v) => syncPrimitiveToState((s) => s.copyWith(aiDiarizationEnabled: v))));
    addWorker(ever(aiSummaryEnabled, (v) => syncPrimitiveToState((s) => s.copyWith(aiSummaryEnabled: v))));
    addWorker(ever(aiFactCheckEnabled, (v) => syncPrimitiveToState((s) => s.copyWith(aiFactCheckEnabled: v))));
    addWorker(ever(aiFactCheckTier, (v) => syncPrimitiveToState((s) => s.copyWith(aiFactCheckTier: v))));
    addWorker(ever(aiFactCheckReviewMode, (v) => syncPrimitiveToState((s) => s.copyWith(aiFactCheckReviewMode: v))));
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
  // ignore: cancel_subscriptions
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
  // ignore: cancel_subscriptions
  StreamSubscription? communityImageModerationSubscription;
  @override
  // ignore: cancel_subscriptions
  StreamSubscription? thumbnailModerationSubscription;
  @override
  // ignore: cancel_subscriptions
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? statusListener;

  /// Resolves the primary category from the channel selection.
  /// Falls back to the first available category if no channel category is found, avoiding 'Other'.
  @override
  String resolveChannelFirstCategory([Channel? channel]) {
    final ch = channel ??
        selectedChannel.value ??
        (Get.isRegistered<AuthService>() ? AuthService.to.userChannel : null);
    if (ch != null) {
      var candidate = '';
      if (ch.categories.isNotEmpty) {
        candidate = ch.categories.first.trim();
      } else if (ch.category.trim().isNotEmpty) {
        candidate = ch.category.split(',').first.trim();
      }
      if (candidate.isNotEmpty) {
        final match = videoCategories.firstWhereOrNull(
          (c) => c.toLowerCase() == candidate.toLowerCase(),
        );
        if (match != null) return match;
        return candidate;
      }
    }
    return videoCategories.isNotEmpty ? videoCategories.first : '';
  }

  // Category & Metadata
  @override
  late final RxString selectedCategory = resolveChannelFirstCategory().obs;
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
  final Rx<DateTime> scheduledDate = DateTime.now().obs;

  // Validation & Moderation Statuses
  @override
  final RxString finalstatus = 'PENDING'.obs;
  @override
  final RxString finalstatusReason = ''.obs;
  @override
  final RxString titleValidationStatus = 'PENDING'.obs;
  @override
  final RxString titleValidationReason = ''.obs;
  @override
  final RxString descriptionValidationStatus = 'PENDING'.obs;
  @override
  final RxString descriptionValidationReason = ''.obs;
  @override
  final RxBool hasConfirmedCopyrightDeclaration = true.obs;
  @override
  final RxString videoModerationStatus = 'PENDING'.obs;
  @override
  final RxString videoModerationReason = ''.obs;
  @override
  final RxString videoModerationSummary = ''.obs;

  // AI Features
  @override
  final RxBool isAiFeaturesExpanded = false.obs;

  @override
  final RxBool aiTranscriptEnabled = true.obs;
  @override
  final RxBool aiChaptersEnabled = false.obs;
  @override
  final RxBool aiGenerateSubtitles = true.obs;
  @override
  final RxBool aiGenerateDubbing = false.obs;
  @override
  final RxBool aiDiarizationEnabled = false.obs;
  @override
  final RxBool aiSummaryEnabled = true.obs;
  // Spoken Language Configuration ("From")
  @override
  final RxString primarySpokenLanguage = 'auto'.obs;
  @override
  final RxList<String> spokenLanguages = <String>[].obs;
  @override
  final RxBool isMultilingualSpoken = false.obs;

  @override
  final RxList<String> aiTranslationLanguages = <String>[].obs;
  @override
  final RxList<String> aiDubbingLanguages = <String>[].obs;
  @override
  final RxMap<String, PlatformFile> attachedSubtitleFiles =
      <String, PlatformFile>{}.obs;
  @override
  final RxMap<String, PlatformFile> attachedAudioFiles =
      <String, PlatformFile>{}.obs;
  @override
  final RxMap<String, String> attachedAudioRoles = <String, String>{}.obs;
  @override
  final RxString activePreviewLanguage = ''.obs;
  @override
  final RxString aiDubbingTier = 'audio_track'.obs;
  @override
  final RxBool aiCinemaGradeEnabled = false.obs;
  @override
  final RxBool aiStemIsolationEnabled = false.obs;
  @override
  final RxBool aiTTSEnabled = false.obs;
  @override
  final RxString aiTTSVoiceType = 'default'.obs;
  @override
  final RxBool aiFactCheckEnabled = false.obs;
  @override
  final RxString aiFactCheckTier = 'full_ground'.obs;
  @override
  final RxString aiFactCheckReviewMode = 'open_to_users'.obs;
  @override
  final Rx<PlatformFile?> voiceSampleFile = Rx<PlatformFile?>(null);
  @override
  final RxList<String> providedSources = <String>[].obs;

  // Topics
  @override
  final RxString selectedTopicId = ''.obs;
  @override
  final RxList<String> selectedTopicIds = <String>[].obs;
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
  final List<String> videoCategories = AppCategories.allCategories;

  // Helper getters & aliases
  String get uploadProgressPercent => '%';

  bool get isVideoContentApproved => videoModerationStatus.value == 'APPROVED';
  bool get isVideoContentRejected => videoModerationStatus.value == 'REJECTED';

  void selectPlaylist(String id) {
    selectedPlaylist.value = id;
  }
}

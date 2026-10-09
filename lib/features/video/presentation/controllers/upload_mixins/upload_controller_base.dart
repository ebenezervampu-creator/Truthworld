import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/verification_cache_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_state.dart';
import 'package:video_player/video_player.dart';

export 'package:truthworld/features/video/presentation/controllers/upload_state.dart';

abstract class UploadControllerBase extends BaseController
    with ContentValidationMixin {
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxTags = 5;

  // Immutable State Snapshot (Single Source of Truth)
  Rx<UploadState> get uploadState;

  /// Updates the immutable upload state atomically via [updater].
  void updateState(UploadState Function(UploadState current) updater);

  /// Directly emits a new immutable upload state snapshot.
  void emit(UploadState newState);

  // Shared Firestore & Storage
  FirebaseFirestore get firestore;
  FirebaseStorage get firebaseStorage;
  VideoUploadRepository get uploadRepository;
  ImageVerificationService get imageVerificationService;
  VerificationCacheService get cacheService;
  UserNotificationService get userNotificationService;

  // Selected Channel & Channels list
  Rx<Channel?> get selectedChannel;
  RxList<Channel> get channels;
  RxBool get isChannelsLoading;
  RxString get channelsError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      get channelsSubscription;
  set channelsSubscription(
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub,
  );

  /// Canonical ISO code of the channel's designated language (e.g. 'en', 'te', 'hi').
  String get channelLanguageCode {
    final lang = selectedChannel.value?.language.trim().toLowerCase();
    return (lang != null && lang.isNotEmpty) ? lang : 'en';
  }

  /// User-facing display name of the channel's designated language (e.g. 'English', 'Telugu (తెలుగు)').
  String get channelLanguageDisplayName {
    final code = channelLanguageCode;
    final match = supportedLanguages.firstWhereOrNull(
      (l) => l.code.toLowerCase() == code || l.name.toLowerCase() == code,
    );
    if (match != null) {
      return match.nativeName.isNotEmpty && match.nativeName != match.name
          ? '${match.name} (${match.nativeName})'
          : match.name;
    }
    return code.toUpperCase();
  }

  // Quota
  RxInt get todayUploadedDurationSeconds;
  RxInt get remainingDailyDurationSeconds;
  RxBool get isDailyLimitReached;
  RxBool get isQuotaLoading;

  // Media
  Rx<PlatformFile?> get pickedVideo;
  Rx<PlatformFile?> get pickedImage;
  Rx<PlatformFile?> get pickedCommunityImage;
  VideoPlayerController? get videoPlayerController;
  set videoPlayerController(VideoPlayerController? value);
  RxBool get isVideoPlayerInitialized;
  RxBool get isVideoPlaying;
  Rx<Duration> get currentVideoPosition;
  Rx<Duration> get videoDuration;
  RxInt get videoDurationSeconds;

  // URLs & Progress
  RxString get videoUrl;
  RxString get thumbnailUrl;
  RxString get communityImageUrl;
  RxString get communityImageStatus;
  RxString get communityImageStatusReason;
  RxDouble get videoUploadProgress;
  RxDouble get imageUploadProgress;
  RxDouble get uploadProgress;
  RxBool get isUploading;
  RxBool get isCommunityPostUploading;
  String? get currentVideoId;
  set currentVideoId(String? id);

  // Tasks & Subscriptions
  UploadTask? get videoUploadTask;
  set videoUploadTask(UploadTask? task);
  UploadTask? get currentUploadTaskVideo;
  set currentUploadTaskVideo(UploadTask? task);
  UploadTask? get currentUploadTaskCommunity;
  set currentUploadTaskCommunity(UploadTask? task);
  StreamSubscription? get communityImageModerationSubscription;
  set communityImageModerationSubscription(StreamSubscription? sub);
  StreamSubscription? get thumbnailModerationSubscription;
  set thumbnailModerationSubscription(StreamSubscription? sub);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      get statusListener;
  set statusListener(
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub,
  );

  // Category & Metadata
  RxString get selectedCategory;
  RxString get selectedVisibility;
  RxBool get isKidFriendly;
  RxBool get isShort;
  RxString get uploadQuality;
  RxBool get enableComments;
  RxBool get allowRatings;
  RxString get selectedPlaylist;
  RxBool get isScheduled;
  Rx<DateTime> get scheduledDate;

  // Validation
  RxString get finalstatus;
  RxString get finalstatusReason;
  RxString get titleValidationStatus;
  RxString get titleValidationReason;
  RxString get descriptionValidationStatus;
  RxString get descriptionValidationReason;
  RxBool get hasConfirmedCopyrightDeclaration;
  RxString get videoModerationStatus;
  RxString get videoModerationReason;
  RxString get videoModerationSummary;

  // AI features
  RxBool get aiTranscriptEnabled;
  RxBool get aiChaptersEnabled;
  RxBool get aiGenerateSubtitles;
  RxBool get aiGenerateDubbing;
  RxBool get aiDiarizationEnabled;
  RxBool get aiSummaryEnabled;
  RxList<String> get aiTranslationLanguages;
  RxList<String> get aiDubbingLanguages;
  RxBool get aiTTSEnabled;
  RxString get aiTTSVoiceType;
  RxBool get aiFactCheckEnabled;
  RxString get aiFactCheckTier;
  RxString get aiFactCheckReviewMode;
  Rx<PlatformFile?> get voiceSampleFile;
  RxList<String> get providedSources;

  // Topics
  RxString get selectedTopicId;
  RxList<Topic> get availableTopics;
  RxBool get isTopicsLoading;
  RxString get topicsError;
  RxString get topicSearchQuery;
  RxMap<String, Map<String, String>> get channelMetadataCache;
  RxMap<String, dynamic> get newTopicData;

  // Wizard Stage
  RxInt get uploadStage;
  RxString get uploadStageLabel;
  RxBool get canAdvanceStage;
  RxBool get isProcessing;
  RxString get processingMessage;
  RxBool get isFormValid;
  Rx<Video?> get resumedVideoDraft;
  Map<String, dynamic> get videoMetadata;
  set videoMetadata(Map<String, dynamic> data);

  // Text Controllers
  TextEditingController get titleController;
  TextEditingController get descriptionController;
  TextEditingController get tagController;

  // Methods
  Future<int> getTodayUploadedDurationSeconds(String channelId);
  Future<void> refreshDailyUploadQuota();
  Future<void> initializeVideoPlayer();
  Future<void> startVideoUpload(PlatformFile videoFile);
  Future<void> startImageUpload(
    PlatformFile file, {
    required bool forCommunity,
  });
  Map<String, dynamic> buildFeaturesMap({String? pipelineStage});
  Future<bool> verifyAuthentication();
  Future<bool> refreshAuthToken();
  Future<void> ensureStorageAuthReady();
  void resetUploads();
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

const Object _sentinel = Object();

/// An immutable snapshot representing the complete reactive state of the
/// video and content upload workflow.
///
/// Ensures single-tick atomic state transitions via [copyWith] and [resetUploads],
/// eliminating intermediate inconsistent UI states during multi-property updates.
@immutable
class UploadState {
  const UploadState({
    // Channel Selection & Management
    this.selectedChannel,
    this.channels = const [],
    this.isChannelsLoading = true,
    this.channelsError = '',

    // Daily Upload Quota
    this.todayUploadedDurationSeconds = 0,
    this.remainingDailyDurationSeconds = 600,
    this.isDailyLimitReached = false,
    this.isQuotaLoading = false,

    // Media & Video Player
    this.pickedVideo,
    this.pickedImage,
    this.pickedCommunityImage,
    this.isVideoPlayerInitialized = false,
    this.isVideoPlaying = false,
    this.currentVideoPosition = Duration.zero,
    this.videoDuration = Duration.zero,
    this.videoDurationSeconds = 0,

    // Upload Progress & Remote URLs
    this.videoUrl = '',
    this.thumbnailUrl = '',
    this.communityImageUrl = '',
    this.communityImageStatus = '',
    this.communityImageStatusReason = '',
    this.videoUploadProgress = 0.0,
    this.imageUploadProgress = 0.0,
    this.uploadProgress = 0.0,
    this.isUploading = false,
    this.isCommunityPostUploading = false,
    this.currentVideoId,

    // Metadata & Form Configuration
    this.selectedCategory = '',
    this.selectedVisibility = 'Public',
    this.selectedLanguage = '',
    this.isKidFriendly = false,
    this.isShort = false,
    this.uploadQuality = 'Auto',
    this.enableComments = true,
    this.allowRatings = false,
    this.selectedPlaylist = '',
    this.isScheduled = false,
    this.scheduledDate,

    // Content Validation & Moderation
    this.finalstatus = '',
    this.finalstatusReason = '',
    this.titleValidationStatus = 'UNKNOWN',
    this.titleValidationReason = '',
    this.descriptionValidationStatus = 'UNKNOWN',
    this.descriptionValidationReason = '',
    this.hasConfirmedCopyrightDeclaration = true,
    this.videoModerationStatus = 'PENDING',
    this.videoModerationReason = '',
    this.videoModerationSummary = '',

    // AI Features
    this.aiTranscriptEnabled = true,
    this.aiChaptersEnabled = false,
    this.aiGenerateSubtitles = false,
    this.aiGenerateDubbing = false,
    this.aiDiarizationEnabled = false,
    this.aiSummaryEnabled = true,
    this.aiTranslationLanguages = const [],
    this.aiDubbingLanguages = const [],
    this.aiTTSEnabled = false,
    this.aiTTSVoiceType = 'default',
    this.aiFactCheckEnabled = false,
    this.aiFactCheckTier = 'full_ground',
    this.aiFactCheckReviewMode = 'open_to_users',
    this.voiceSampleFile,
    this.providedSources = const [],

    // Topics
    this.selectedTopicId = '',
    this.availableTopics = const [],
    this.isTopicsLoading = false,
    this.topicsError = '',
    this.topicSearchQuery = '',
    this.channelMetadataCache = const {},
    this.newTopicData = const {},

    // Wizard Stage & Workflow
    this.uploadStage = 0,
    this.uploadStageLabel = 'Upload Media',
    this.canAdvanceStage = false,
    this.isProcessing = false,
    this.processingMessage = '',
    this.isFormValid = false,
    this.resumedVideoDraft,
    this.videoMetadata = const {},
  });

  // Channel Selection & Management
  final Channel? selectedChannel;
  final List<Channel> channels;
  final bool isChannelsLoading;
  final String channelsError;

  // Daily Upload Quota
  final int todayUploadedDurationSeconds;
  final int remainingDailyDurationSeconds;
  final bool isDailyLimitReached;
  final bool isQuotaLoading;

  // Media & Video Player
  final PlatformFile? pickedVideo;
  final PlatformFile? pickedImage;
  final PlatformFile? pickedCommunityImage;
  final bool isVideoPlayerInitialized;
  final bool isVideoPlaying;
  final Duration currentVideoPosition;
  final Duration videoDuration;
  final int videoDurationSeconds;

  // Upload Progress & Remote URLs
  final String videoUrl;
  final String thumbnailUrl;
  final String communityImageUrl;
  final String communityImageStatus;
  final String communityImageStatusReason;
  final double videoUploadProgress;
  final double imageUploadProgress;
  final double uploadProgress;
  final bool isUploading;
  final bool isCommunityPostUploading;
  final String? currentVideoId;

  // Metadata & Form Configuration
  final String selectedCategory;
  final String selectedVisibility;
  final String selectedLanguage;
  final bool isKidFriendly;
  final bool isShort;
  final String uploadQuality;
  final bool enableComments;
  final bool allowRatings;
  final String selectedPlaylist;
  final bool isScheduled;
  final DateTime? scheduledDate;

  // Content Validation & Moderation
  final String finalstatus;
  final String finalstatusReason;
  final String titleValidationStatus;
  final String titleValidationReason;
  final String descriptionValidationStatus;
  final String descriptionValidationReason;
  final bool hasConfirmedCopyrightDeclaration;
  final String videoModerationStatus;
  final String videoModerationReason;
  final String videoModerationSummary;

  // AI Features
  final bool aiTranscriptEnabled;
  final bool aiChaptersEnabled;
  final bool aiGenerateSubtitles;
  final bool aiGenerateDubbing;
  final bool aiDiarizationEnabled;
  final bool aiSummaryEnabled;
  final List<String> aiTranslationLanguages;
  final List<String> aiDubbingLanguages;
  final bool aiTTSEnabled;
  final String aiTTSVoiceType;
  final bool aiFactCheckEnabled;
  final String aiFactCheckTier;
  final String aiFactCheckReviewMode;
  final PlatformFile? voiceSampleFile;
  final List<String> providedSources;

  // Topics
  final String selectedTopicId;
  final List<Topic> availableTopics;
  final bool isTopicsLoading;
  final String topicsError;
  final String topicSearchQuery;
  final Map<String, Map<String, String>> channelMetadataCache;
  final Map<String, dynamic> newTopicData;

  // Wizard Stage & Workflow
  final int uploadStage;
  final String uploadStageLabel;
  final bool canAdvanceStage;
  final bool isProcessing;
  final String processingMessage;
  final bool isFormValid;
  final Video? resumedVideoDraft;
  final Map<String, dynamic> videoMetadata;

  // Derived Convenience Getters
  String get todayUploadedDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        todayUploadedDurationSeconds,
      );

  String get remainingDailyDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        remainingDailyDurationSeconds,
      );

  double get dailyQuotaUsedRatio {
    final limit =
        selectedChannel?.maxDailyVideoDurationSeconds.toDouble() ?? 600.0;
    return (todayUploadedDurationSeconds / limit).clamp(0.0, 1.0);
  }

  String get uploadProgressPercent => '${(uploadProgress * 100).toInt()}%';

  bool get isVideoContentApproved => videoModerationStatus == 'APPROVED';
  bool get isVideoContentRejected => videoModerationStatus == 'REJECTED';
  bool get hasPickedVideo => pickedVideo != null;
  bool get hasSelectedChannel => selectedChannel != null;

  /// Returns a clean reset [UploadState] keeping channels/topics intact while
  /// clearing upload media, progress, and draft IDs in a single atomic tick.
  UploadState resetUploads() {
    return copyWith(
      videoUrl: '',
      thumbnailUrl: '',
      finalstatus: '',
      finalstatusReason: '',
      videoModerationStatus: 'PENDING',
      videoModerationReason: '',
      videoModerationSummary: '',
      communityImageUrl: '',
      communityImageStatus: '',
      communityImageStatusReason: '',
      videoUploadProgress: 0.0,
      imageUploadProgress: 0.0,
      uploadProgress: 0.0,
      isUploading: false,
      isCommunityPostUploading: false,
      isShort: false,
      pickedVideo: null,
      pickedImage: null,
      pickedCommunityImage: null,
      isVideoPlayerInitialized: false,
      isVideoPlaying: false,
      currentVideoPosition: Duration.zero,
      videoDuration: Duration.zero,
      videoDurationSeconds: 0,
      selectedPlaylist: '',
      selectedTopicId: '',
      selectedLanguage: '',
      newTopicData: const {},
      isScheduled: false,
      currentVideoId: null,
      resumedVideoDraft: null,
      uploadStage: 0,
      uploadStageLabel: 'Upload Media',
      canAdvanceStage: false,
      isProcessing: false,
      processingMessage: '',
      isFormValid: false,
      hasConfirmedCopyrightDeclaration: true,
      videoMetadata: const {},
    );
  }

  /// Creates a copy of this state with the given fields replaced.
  /// Supports clearing nullable fields by explicitly passing `null`.
  UploadState copyWith({
    Object? selectedChannel = _sentinel,
    List<Channel>? channels,
    bool? isChannelsLoading,
    String? channelsError,
    int? todayUploadedDurationSeconds,
    int? remainingDailyDurationSeconds,
    bool? isDailyLimitReached,
    bool? isQuotaLoading,
    Object? pickedVideo = _sentinel,
    Object? pickedImage = _sentinel,
    Object? pickedCommunityImage = _sentinel,
    bool? isVideoPlayerInitialized,
    bool? isVideoPlaying,
    Duration? currentVideoPosition,
    Duration? videoDuration,
    int? videoDurationSeconds,
    String? videoUrl,
    String? thumbnailUrl,
    String? communityImageUrl,
    String? communityImageStatus,
    String? communityImageStatusReason,
    double? videoUploadProgress,
    double? imageUploadProgress,
    double? uploadProgress,
    bool? isUploading,
    bool? isCommunityPostUploading,
    Object? currentVideoId = _sentinel,
    String? selectedCategory,
    String? selectedVisibility,
    String? selectedLanguage,
    bool? isKidFriendly,
    bool? isShort,
    String? uploadQuality,
    bool? enableComments,
    bool? allowRatings,
    String? selectedPlaylist,
    bool? isScheduled,
    Object? scheduledDate = _sentinel,
    String? finalstatus,
    String? finalstatusReason,
    String? titleValidationStatus,
    String? titleValidationReason,
    String? descriptionValidationStatus,
    String? descriptionValidationReason,
    bool? hasConfirmedCopyrightDeclaration,
    String? videoModerationStatus,
    String? videoModerationReason,
    String? videoModerationSummary,
    bool? aiTranscriptEnabled,
    bool? aiChaptersEnabled,
    bool? aiGenerateSubtitles,
    bool? aiGenerateDubbing,
    bool? aiDiarizationEnabled,
    bool? aiSummaryEnabled,
    List<String>? aiTranslationLanguages,
    List<String>? aiDubbingLanguages,
    bool? aiTTSEnabled,
    String? aiTTSVoiceType,
    bool? aiFactCheckEnabled,
    String? aiFactCheckTier,
    String? aiFactCheckReviewMode,
    Object? voiceSampleFile = _sentinel,
    List<String>? providedSources,
    String? selectedTopicId,
    List<Topic>? availableTopics,
    bool? isTopicsLoading,
    String? topicsError,
    String? topicSearchQuery,
    Map<String, Map<String, String>>? channelMetadataCache,
    Map<String, dynamic>? newTopicData,
    int? uploadStage,
    String? uploadStageLabel,
    bool? canAdvanceStage,
    bool? isProcessing,
    String? processingMessage,
    bool? isFormValid,
    Object? resumedVideoDraft = _sentinel,
    Map<String, dynamic>? videoMetadata,
  }) {
    return UploadState(
      selectedChannel: identical(selectedChannel, _sentinel)
          ? this.selectedChannel
          : selectedChannel as Channel?,
      channels: channels ?? this.channels,
      isChannelsLoading: isChannelsLoading ?? this.isChannelsLoading,
      channelsError: channelsError ?? this.channelsError,
      todayUploadedDurationSeconds:
          todayUploadedDurationSeconds ?? this.todayUploadedDurationSeconds,
      remainingDailyDurationSeconds:
          remainingDailyDurationSeconds ?? this.remainingDailyDurationSeconds,
      isDailyLimitReached: isDailyLimitReached ?? this.isDailyLimitReached,
      isQuotaLoading: isQuotaLoading ?? this.isQuotaLoading,
      pickedVideo: identical(pickedVideo, _sentinel)
          ? this.pickedVideo
          : pickedVideo as PlatformFile?,
      pickedImage: identical(pickedImage, _sentinel)
          ? this.pickedImage
          : pickedImage as PlatformFile?,
      pickedCommunityImage: identical(pickedCommunityImage, _sentinel)
          ? this.pickedCommunityImage
          : pickedCommunityImage as PlatformFile?,
      isVideoPlayerInitialized:
          isVideoPlayerInitialized ?? this.isVideoPlayerInitialized,
      isVideoPlaying: isVideoPlaying ?? this.isVideoPlaying,
      currentVideoPosition: currentVideoPosition ?? this.currentVideoPosition,
      videoDuration: videoDuration ?? this.videoDuration,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      communityImageUrl: communityImageUrl ?? this.communityImageUrl,
      communityImageStatus: communityImageStatus ?? this.communityImageStatus,
      communityImageStatusReason:
          communityImageStatusReason ?? this.communityImageStatusReason,
      videoUploadProgress: videoUploadProgress ?? this.videoUploadProgress,
      imageUploadProgress: imageUploadProgress ?? this.imageUploadProgress,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploading: isUploading ?? this.isUploading,
      isCommunityPostUploading:
          isCommunityPostUploading ?? this.isCommunityPostUploading,
      currentVideoId: identical(currentVideoId, _sentinel)
          ? this.currentVideoId
          : currentVideoId as String?,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedVisibility: selectedVisibility ?? this.selectedVisibility,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      isShort: isShort ?? this.isShort,
      uploadQuality: uploadQuality ?? this.uploadQuality,
      enableComments: enableComments ?? this.enableComments,
      allowRatings: allowRatings ?? this.allowRatings,
      selectedPlaylist: selectedPlaylist ?? this.selectedPlaylist,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledDate: identical(scheduledDate, _sentinel)
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      finalstatus: finalstatus ?? this.finalstatus,
      finalstatusReason: finalstatusReason ?? this.finalstatusReason,
      titleValidationStatus:
          titleValidationStatus ?? this.titleValidationStatus,
      titleValidationReason:
          titleValidationReason ?? this.titleValidationReason,
      descriptionValidationStatus:
          descriptionValidationStatus ?? this.descriptionValidationStatus,
      descriptionValidationReason:
          descriptionValidationReason ?? this.descriptionValidationReason,
      hasConfirmedCopyrightDeclaration:
          hasConfirmedCopyrightDeclaration ??
              this.hasConfirmedCopyrightDeclaration,
      videoModerationStatus:
          videoModerationStatus ?? this.videoModerationStatus,
      videoModerationReason:
          videoModerationReason ?? this.videoModerationReason,
      videoModerationSummary:
          videoModerationSummary ?? this.videoModerationSummary,
      aiTranscriptEnabled: aiTranscriptEnabled ?? this.aiTranscriptEnabled,
      aiChaptersEnabled: aiChaptersEnabled ?? this.aiChaptersEnabled,
      aiGenerateSubtitles: aiGenerateSubtitles ?? this.aiGenerateSubtitles,
      aiGenerateDubbing: aiGenerateDubbing ?? this.aiGenerateDubbing,
      aiDiarizationEnabled: aiDiarizationEnabled ?? this.aiDiarizationEnabled,
      aiSummaryEnabled: aiSummaryEnabled ?? this.aiSummaryEnabled,
      aiTranslationLanguages:
          aiTranslationLanguages ?? this.aiTranslationLanguages,
      aiDubbingLanguages: aiDubbingLanguages ?? this.aiDubbingLanguages,
      aiTTSEnabled: aiTTSEnabled ?? this.aiTTSEnabled,
      aiTTSVoiceType: aiTTSVoiceType ?? this.aiTTSVoiceType,
      aiFactCheckEnabled: aiFactCheckEnabled ?? this.aiFactCheckEnabled,
      aiFactCheckTier: aiFactCheckTier ?? this.aiFactCheckTier,
      aiFactCheckReviewMode:
          aiFactCheckReviewMode ?? this.aiFactCheckReviewMode,
      voiceSampleFile: identical(voiceSampleFile, _sentinel)
          ? this.voiceSampleFile
          : voiceSampleFile as PlatformFile?,
      providedSources: providedSources ?? this.providedSources,
      selectedTopicId: selectedTopicId ?? this.selectedTopicId,
      availableTopics: availableTopics ?? this.availableTopics,
      isTopicsLoading: isTopicsLoading ?? this.isTopicsLoading,
      topicsError: topicsError ?? this.topicsError,
      topicSearchQuery: topicSearchQuery ?? this.topicSearchQuery,
      channelMetadataCache: channelMetadataCache ?? this.channelMetadataCache,
      newTopicData: newTopicData ?? this.newTopicData,
      uploadStage: uploadStage ?? this.uploadStage,
      uploadStageLabel: uploadStageLabel ?? this.uploadStageLabel,
      canAdvanceStage: canAdvanceStage ?? this.canAdvanceStage,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage ?? this.processingMessage,
      isFormValid: isFormValid ?? this.isFormValid,
      resumedVideoDraft: identical(resumedVideoDraft, _sentinel)
          ? this.resumedVideoDraft
          : resumedVideoDraft as Video?,
      videoMetadata: videoMetadata ?? this.videoMetadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadState &&
        other.selectedChannel == selectedChannel &&
        listEquals(other.channels, channels) &&
        other.isChannelsLoading == isChannelsLoading &&
        other.channelsError == channelsError &&
        other.todayUploadedDurationSeconds == todayUploadedDurationSeconds &&
        other.remainingDailyDurationSeconds == remainingDailyDurationSeconds &&
        other.isDailyLimitReached == isDailyLimitReached &&
        other.isQuotaLoading == isQuotaLoading &&
        other.pickedVideo == pickedVideo &&
        other.pickedImage == pickedImage &&
        other.pickedCommunityImage == pickedCommunityImage &&
        other.isVideoPlayerInitialized == isVideoPlayerInitialized &&
        other.isVideoPlaying == isVideoPlaying &&
        other.currentVideoPosition == currentVideoPosition &&
        other.videoDuration == videoDuration &&
        other.videoDurationSeconds == videoDurationSeconds &&
        other.videoUrl == videoUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.communityImageUrl == communityImageUrl &&
        other.communityImageStatus == communityImageStatus &&
        other.communityImageStatusReason == communityImageStatusReason &&
        other.videoUploadProgress == videoUploadProgress &&
        other.imageUploadProgress == imageUploadProgress &&
        other.uploadProgress == uploadProgress &&
        other.isUploading == isUploading &&
        other.isCommunityPostUploading == isCommunityPostUploading &&
        other.currentVideoId == currentVideoId &&
        other.selectedCategory == selectedCategory &&
        other.selectedVisibility == selectedVisibility &&
        other.isKidFriendly == isKidFriendly &&
        other.isShort == isShort &&
        other.uploadQuality == uploadQuality &&
        other.enableComments == enableComments &&
        other.allowRatings == allowRatings &&
        other.selectedPlaylist == selectedPlaylist &&
        other.isScheduled == isScheduled &&
        other.scheduledDate == scheduledDate &&
        other.finalstatus == finalstatus &&
        other.finalstatusReason == finalstatusReason &&
        other.titleValidationStatus == titleValidationStatus &&
        other.titleValidationReason == titleValidationReason &&
        other.descriptionValidationStatus == descriptionValidationStatus &&
        other.descriptionValidationReason == descriptionValidationReason &&
        other.hasConfirmedCopyrightDeclaration ==
            hasConfirmedCopyrightDeclaration &&
        other.videoModerationStatus == videoModerationStatus &&
        other.videoModerationReason == videoModerationReason &&
        other.videoModerationSummary == videoModerationSummary &&
        other.aiTranscriptEnabled == aiTranscriptEnabled &&
        other.aiChaptersEnabled == aiChaptersEnabled &&
        other.aiGenerateSubtitles == aiGenerateSubtitles &&
        other.aiGenerateDubbing == aiGenerateDubbing &&
        other.aiDiarizationEnabled == aiDiarizationEnabled &&
        other.aiSummaryEnabled == aiSummaryEnabled &&
        listEquals(other.aiTranslationLanguages, aiTranslationLanguages) &&
        listEquals(other.aiDubbingLanguages, aiDubbingLanguages) &&
        other.aiTTSEnabled == aiTTSEnabled &&
        other.aiTTSVoiceType == aiTTSVoiceType &&
        other.aiFactCheckEnabled == aiFactCheckEnabled &&
        other.aiFactCheckTier == aiFactCheckTier &&
        other.aiFactCheckReviewMode == aiFactCheckReviewMode &&
        other.voiceSampleFile == voiceSampleFile &&
        listEquals(other.providedSources, providedSources) &&
        other.selectedTopicId == selectedTopicId &&
        listEquals(other.availableTopics, availableTopics) &&
        other.isTopicsLoading == isTopicsLoading &&
        other.topicsError == topicsError &&
        other.topicSearchQuery == topicSearchQuery &&
        mapEquals(other.channelMetadataCache, channelMetadataCache) &&
        mapEquals(other.newTopicData, newTopicData) &&
        other.uploadStage == uploadStage &&
        other.uploadStageLabel == uploadStageLabel &&
        other.canAdvanceStage == canAdvanceStage &&
        other.isProcessing == isProcessing &&
        other.processingMessage == processingMessage &&
        other.isFormValid == isFormValid &&
        other.resumedVideoDraft == resumedVideoDraft &&
        mapEquals(other.videoMetadata, videoMetadata);
  }

  @override
  int get hashCode => Object.hashAll([
        selectedChannel,
        isChannelsLoading,
        channelsError,
        todayUploadedDurationSeconds,
        remainingDailyDurationSeconds,
        isDailyLimitReached,
        isQuotaLoading,
        pickedVideo,
        pickedImage,
        pickedCommunityImage,
        isVideoPlayerInitialized,
        isVideoPlaying,
        currentVideoPosition,
        videoDuration,
        videoDurationSeconds,
        videoUrl,
        thumbnailUrl,
        communityImageUrl,
        communityImageStatus,
        uploadProgress,
        aiFactCheckTier,
      ]);

  @override
  String toString() {
    return 'UploadState(isUploading: $isUploading, progress: $uploadProgressPercent, stage: $uploadStageLabel, channel: ${selectedChannel?.channelName ?? "none"})';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video/video_barrel.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

export 'package:truthworld/features/video/data/models/video/video_barrel.dart';

/// Core domain model representing a Video in TruthWorld.
class Video {
  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.ownerId,
    required this.channelId,
    required this.channelName,
    required this.category,
    required this.tags,
    String? vTitleLowercase,
    String? originalUrl,
    String? videoUrl,
    this.hlsUrl = '',
    this.dashUrl = '',
    this.storyboardUrl = '',
    this.storyboardVariants = const [],
    this.adaptiveResolutions = const [],
    this.thumbnailVariants = const [],
    this.animatedPreviewUrl = '',
    String? channelAvatarUrl,
    String? channelImage,
    int? viewCount,
    dynamic views,
    int? likeCount,
    dynamic likes,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    dynamic duration,
    Duration? vDurationValue,
    dynamic createdAt,
    dynamic uploadedAt,
    dynamic updatedAt,
    dynamic status,
    dynamic visibility,
    this.topics = const [],
    this.language = 'en',
    this.languages = const [],
    this.isShort = false,
    this.isKidFriendly = false,
    bool? allowComments,
    bool enableComments = true,
    this.allowClipping = true,
    this.isMonetized = false,
    this.allowRatings = false,
    this.showLikeCount = true,
    this.showDislikeCount = true,
    this.autoChaptersEnabled = true,
    this.sourceLinks = const [],
    this.isFactChecked = false,
    this.factCheckTier = 'standard',
    this.factCheckReviewMode = 'open_to_users',
    this.isFactCheckApproved = true,
    this.isVerified = false,
    List<String>? likedBy,
    Map<String, String>? mediaSubtitles,
    Map<String, String>? dubbedVideos,
    Map<String, String>? audioTracks,
    List<VideoChapter>? chapters,
    String? factCheckUrl,
    String? transcriptionUrl,
    ScoringFactors? scoringFactors,
    List<TrustDeduction>? deductions,
    List<ContextualFlag>? contextualFlags,
    HonestyBreakdown? honestyBreakdown,
    bool? harmCapApplied,
    String? harmCapReason,
    Map<String, double>? categoryWeightProfile,
    List<String>? confidenceNotes,
    List<String>? diagnostics,
    FactCheckStats? factCheckStats,
    String? videoCategory,
    HardeningMetadata? hardeningMetadata,
    double? intentToMisleadScore,
    UIReport? uiReport,
    this.isSeen = false,
    this.totalWatchTimeSeconds = 0,
    this.trustLabel,
    this.channelStatus,
    this.scheduledPublishAt,
    this.coinBattlePairVideoId,
    this.coinBattleStance,
    this.geminiApproved,
    this.isApproved,
    this.moderationSummary = '',
    this.embedding,
    this.jobId,
    this.resubmitCount = 0,
    this.isChannelTrusted = false,
    this.isProvisional = false,
    this.provisionalScore,
    this.provisionalLabel,
    this.provisionalViewerNote,
    this.provisionalClaims = const [],
    this.credibilityStatus,
  })  : titleLowercase = (vTitleLowercase == null || vTitleLowercase.isEmpty)
            ? title.toLowerCase()
            : vTitleLowercase,
        originalUrl = (originalUrl == null || originalUrl.isEmpty)
            ? (videoUrl ?? '')
            : originalUrl,
        channelAvatarUrl = (channelAvatarUrl != null && channelAvatarUrl.isNotEmpty)
            ? channelAvatarUrl
            : (channelImage != null && channelImage.isNotEmpty)
                ? channelImage
                : '',
        _rawViewCount = viewCount ??
            (views is int
                ? views
                : (int.tryParse(views?.toString() ?? '0') ?? 0)),
        likeCount = likeCount ??
            (likes is int
                ? likes
                : (int.tryParse(likes?.toString() ?? '0') ?? 0)),
        durationValue =
            (vDurationValue != null && vDurationValue != Duration.zero)
                ? vDurationValue
                : parseDuration(duration),
        createdAt = TimestampUtils.parse(createdAt ?? uploadedAt),
        updatedAt = TimestampUtils.parse(updatedAt ?? createdAt ?? uploadedAt),
        status = status is VideoStatus
            ? status
            : (status?.toString().toLowerCase() == 'published' ||
                    status?.toString().toLowerCase() == 'ready'
                ? VideoStatus.ready
                : VideoStatus.processing),
        visibility = visibility?.toString() ?? 'public',
        enableComments = allowComments ?? enableComments,
        likedBy = likedBy ?? [],
        _directFactCheckUrl = factCheckUrl ?? '',
        _directTranscriptionUrl = transcriptionUrl ?? '',
        _directMediaSubtitles = mediaSubtitles ?? const {},
        _directDubbedVideos = dubbedVideos ?? const {},
        _directAudioTracks = audioTracks ?? const {} {
    // Populate the VideoMediaService static caches for instant synchronous retrieval
    VideoMediaCacheManager.populateCaches(
      id: id,
      originalUrl: this.originalUrl,
      hlsUrl: hlsUrl,
      dashUrl: dashUrl,
      adaptiveResolutions: adaptiveResolutions,
      thumbnailVariants: thumbnailVariants,
      animatedPreviewUrl: animatedPreviewUrl,
      trustLabel: trustLabel,
      mediaSubtitles: mediaSubtitles,
      dubbedVideos: dubbedVideos,
      audioTracks: audioTracks,
      chapters: chapters,
      factCheckUrl: factCheckUrl,
      transcriptionUrl: transcriptionUrl,
      scoringFactors: scoringFactors,
      deductions: deductions,
      contextualFlags: contextualFlags,
      honestyBreakdown: honestyBreakdown,
      harmCapApplied: harmCapApplied,
      harmCapReason: harmCapReason,
      categoryWeightProfile: categoryWeightProfile,
      confidenceNotes: confidenceNotes,
      diagnostics: diagnostics,
      factCheckStats: factCheckStats,
      videoCategory: videoCategory,
      hardeningMetadata: hardeningMetadata,
      intentToMisleadScore: intentToMisleadScore,
      uiReport: uiReport,
    );
  }

  factory Video.fromMap(Map<String, dynamic> data, [String? docId]) =>
      VideoMapParser.parse(data, docId);

  factory Video.fromDocumentSnapshot(DocumentSnapshot doc) {
    return Video.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
  }

  factory Video.fromOffline(OfflineVideo offline) {
    return Video(
      id: offline.id,
      title: offline.title,
      description: 'Saved Video',
      thumbnailUrl: offline.thumbnailUrl,
      ownerId: '',
      channelId: '',
      channelName: offline.channelName,
      channelAvatarUrl: offline.channelImage,
      category: 'Downloads',
      tags: [],
      viewCount: int.tryParse(offline.views) ?? 0,
      videoUrl: offline.videoUrl,
      hlsUrl: offline.videoUrl?.contains('.m3u8') == true ? offline.videoUrl! : '',
    );
  }

  factory Video.empty() {
    return Video(
      id: '',
      title: '',
      description: '',
      thumbnailUrl: '',
      ownerId: '',
      channelId: '',
      channelName: '',
      category: '',
      tags: [],
    );
  }

  final String id;
  final String title;
  final String titleLowercase;
  final String description;

  // Storage & Streaming
  final String originalUrl;
  final String hlsUrl;
  final String dashUrl;
  final List<VideoResolutionV2> adaptiveResolutions;

  // Thumbnails & Previews
  final String thumbnailUrl;
  final List<String> thumbnailVariants;
  final String storyboardUrl;
  final List<String> storyboardVariants;
  final String animatedPreviewUrl;

  // Ownership & Context
  final String ownerId;
  String get userId => ownerId;
  final String channelId;
  final String channelName;
  final String channelAvatarUrl;

  // Engagement Counters
  final int _rawViewCount;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final int shareCount;
  final int totalWatchTimeSeconds;

  // Metadata
  final Duration durationValue;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final VideoStatus status;
  final String visibility;
  final List<String> likedBy;

  // Content Info
  final String category;
  final List<String> tags;
  final List<String> topics;
  final String language;
  final List<String> languages;
  final bool isShort;
  final bool isKidFriendly;

  // Flags
  final bool enableComments;
  bool get allowComments => enableComments;
  final bool allowClipping;
  final bool isMonetized;
  final bool allowRatings;
  final bool showLikeCount;
  final bool showDislikeCount;
  final bool autoChaptersEnabled;
  final List<String>? sourceLinks;
  final bool isFactChecked;
  final String factCheckTier; // "short" | "standard" | "full_ground"
  final String factCheckReviewMode; // "open_to_users" | "first_to_creator"
  final bool isFactCheckApproved;
  final bool isVerified;
  final bool isChannelTrusted;
  /// Blue Checkmark badges are completely discontinued platform-wide for channels.
  bool get showVerifiedBadge => false;
  bool isSeen = false;
  final String? channelStatus;
  final DateTime? scheduledPublishAt;
  final String? coinBattlePairVideoId;
  final String? coinBattleStance;
  final bool? geminiApproved;
  final bool? isApproved;
  final String moderationSummary;
  final List<double>? embedding;
  final int resubmitCount;

  bool get canResubmit => isRejected && resubmitCount < 2;
  int get remainingResubmissions => (2 - resubmitCount).clamp(0, 2);
  bool get hasReachedMaxResubmissions => isRejected && resubmitCount >= 2;

  // v8.0 Credibility Fields (lightweight)
  final String? trustLabel;
  final String? jobId;
  final bool isProvisional;
  final double? provisionalScore;
  final String? provisionalLabel;
  final String? provisionalViewerNote;
  final List<Map<String, dynamic>> provisionalClaims;
  final String? credibilityStatus;

  // Direct fields (immediate availability without cache delay)
  final String _directFactCheckUrl;
  final String _directTranscriptionUrl;
  final Map<String, String> _directMediaSubtitles;
  final Map<String, String> _directDubbedVideos;
  final Map<String, String> _directAudioTracks;

  // Summary getter with priority: moderation.summary -> credibility.summary -> description
  String get summary {
    if (UserFeedbackSanitizer.isValidVideoSummary(moderationSummary)) {
      return moderationSummary;
    }
    final credSummary = VideoMediaService.credibilityCache[id]?.summary;
    if (UserFeedbackSanitizer.isValidVideoSummary(credSummary)) {
      return credSummary!;
    }
    return description;
  }

  // Getters lookup direct first, then VideoMediaService static caches
  Map<String, String> get mediaSubtitles {
    final direct = _directMediaSubtitles;
    final cached = VideoMediaService.localizationCache[id]?.subtitles ?? const {};
    final merged = Map<String, String>.from(cached)..addAll(direct);
    if (transcriptionUrl.isNotEmpty) {
      final origLang = language.isNotEmpty ? language : 'en';
      final normOrig = normalizeLanguageCode(origLang);
      final hasOrig = merged.keys.any((k) => normalizeLanguageCode(k) == normOrig);
      if (!hasOrig) {
        merged[origLang] = transcriptionUrl;
      }
    }
    return merged;
  }
  Map<String, String> get dubbedVideos => _directDubbedVideos.isNotEmpty
      ? _directDubbedVideos
      : (VideoMediaService.localizationCache[id]?.dubbedVideos ?? const {});
  Map<String, String> get audioTracks => _directAudioTracks.isNotEmpty
      ? _directAudioTracks
      : (VideoMediaService.localizationCache[id]?.audioTracks ?? const {});
  List<VideoChapter> get chapters =>
      VideoMediaService.streamingCache[id]?.chapters ?? const [];

  ScoringFactors? get scoringFactors =>
      VideoMediaService.credibilityCache[id]?.scoringFactors;
  List<TrustDeduction> get deductions =>
      VideoMediaService.credibilityCache[id]?.deductions ?? const [];
  List<ContextualFlag> get contextualFlags =>
      VideoMediaService.credibilityCache[id]?.contextualFlags ?? const [];
  HonestyBreakdown? get honestyBreakdown =>
      VideoMediaService.credibilityCache[id]?.honestyBreakdown;
  bool get harmCapApplied =>
      VideoMediaService.credibilityCache[id]?.harmCapApplied ?? false;
  String? get harmCapReason =>
      VideoMediaService.credibilityCache[id]?.harmCapReason;
  Map<String, double>? get categoryWeightProfile =>
      VideoMediaService.credibilityCache[id]?.categoryWeightProfile;
  List<String> get confidenceNotes =>
      VideoMediaService.credibilityCache[id]?.confidenceNotes ?? const [];
  List<String> get diagnostics =>
      VideoMediaService.credibilityCache[id]?.diagnostics ?? const [];
  FactCheckStats? get factCheckStats =>
      VideoMediaService.credibilityCache[id]?.factCheckStats;
  String? get videoCategory =>
      VideoMediaService.credibilityCache[id]?.videoCategory;

  HardeningMetadata? get hardeningMetadata =>
      VideoMediaService.credibilityCache[id]?.hardeningMetadata;
  double? get intentToMisleadScore =>
      VideoMediaService.credibilityCache[id]?.intentToMisleadScore;
  String? get effectiveCategory =>
      VideoMediaService.credibilityCache[id]?.effectiveCategory;
  UIReport? get uiReport => VideoMediaService.credibilityCache[id]?.uiReport;
  String get factCheckUrl {
    if (_directFactCheckUrl.isNotEmpty) return _directFactCheckUrl;
    final cached = VideoMediaService.credibilityCache[id]?.factCheckUrl ?? '';
    if (cached.isNotEmpty) return cached;
    return '';
  }

  String get transcriptionUrl {
    if (_directTranscriptionUrl.isNotEmpty) return _directTranscriptionUrl;
    final cached =
        VideoMediaService.credibilityCache[id]?.transcriptionUrl ?? '';
    if (cached.isNotEmpty) return cached;
    return '';
  }

  // Compatibility & Reactive Getters
  int get likes => likeCount;

  int get viewCount {
    if (Get.isRegistered<MainController>()) {
      final live = MainController.to.videoViews[id];
      if (live != null && live > _rawViewCount) {
        return live;
      }
    }
    return _rawViewCount;
  }

  int get views => viewCount;
  Timestamp get uploadedAt => createdAt;

  Set<String>? _categoryTokens;

  /// Non-factual or creative categories where AI credibility / fact-checking is not applicable.
  static const Set<String> nonCredibilityCategories =
      AppCategories.nonCredibilityTokens;

  /// Returns true if the video is non-factual/creative content where AI credibility is not applicable.
  bool get isNonCredibilityCategory {
    final cat = (videoCategory ?? effectiveCategory ?? category).trim().toLowerCase();
    if (cat.isNotEmpty &&
        (nonCredibilityCategories.contains(cat) ||
            nonCredibilityCategories.any((token) => cat.contains(token) || token.contains(cat)))) {
      return true;
    }
    return categoryTokens.any((t) =>
        nonCredibilityCategories.contains(t) ||
        nonCredibilityCategories.any((token) => t.contains(token) || token.contains(t)));
  }

  /// Returns true if this video actually has non-empty TruthWorld Intelligence & Credibility.
  bool get hasTruthIntelligence {
    if (isNonCredibilityCategory) return false;
    if (isProvisional ||
        provisionalClaims.isNotEmpty ||
        (provisionalScore != null && provisionalScore! > 0) ||
        credibilityStatus == 'provisional_ready') {
      return true;
    }
    if (factCheckUrl.trim().isNotEmpty) return true;
    final cached = VideoMediaService.credibilityCache[id];
    if (cached != null) {
      if (cached.factCheckUrl.trim().isNotEmpty) return true;
      if (cached.claims.isNotEmpty) return true;
      if (cached.uiReport != null &&
          (cached.uiReport!.keyClaims.isNotEmpty ||
              cached.uiReport!.summary.rating != null)) {
        return true;
      }
      if (cached.factCheckStats != null &&
          cached.factCheckStats!.totalClaims > 0) {
        return true;
      }
    }
    if (uiReport != null &&
        (uiReport!.keyClaims.isNotEmpty || uiReport!.summary.rating != null)) {
      return true;
    }
    if (factCheckStats != null && factCheckStats!.totalClaims > 0) {
      return true;
    }
    // If marked isFactChecked and has an authentic verified trust score
    if (isFactChecked) return true;
    return false;
  }

  /// Returns true if this video is eligible for and actually has AI credibility / fact-checking enabled and present.
  bool get hasAiCredibility => hasTruthIntelligence;

  /// Whether the creator specified that fact-check results should be reviewed before viewers can see them
  bool get isFactCheckCreatorReviewFirst => factCheckReviewMode == 'first_to_creator';

  /// Duration of creator review grace period before automatic publication to viewers.
  /// Standard window is 48 hours; accelerated to 24 hours for high-risk / low-trust content (< 50% trust).
  Duration get factCheckGracePeriod {
    final isHighRisk = factCheckStats != null && factCheckStats!.incorrect > 0;
    return isHighRisk ? const Duration(hours: 24) : const Duration(hours: 48);
  }

  /// Whether the creator review grace period has expired, triggering public transparency.
  bool get isFactCheckGracePeriodExpired {
    final createdTime = createdAt.toDate();
    final elapsed = DateTime.now().difference(createdTime);
    return elapsed >= factCheckGracePeriod;
  }

  /// Remaining duration in the creator review grace period before automatic public transparency.
  Duration get factCheckGracePeriodRemaining {
    final createdTime = createdAt.toDate();
    final elapsed = DateTime.now().difference(createdTime);
    final diff = factCheckGracePeriod - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether fact-checking is set to private creator review first and still within the unexpired review window.
  bool get isFactCheckPendingApproval =>
      isFactCheckCreatorReviewFirst &&
      !isFactCheckApproved &&
      !isFactCheckGracePeriodExpired;

  /// Whether regular viewers (public) can see fact-checking results & verification icon
  bool get canPublicViewFactCheck => !isFactCheckPendingApproval;

  /// Public visibility check for AI credibility (must have credibility AND not be pending creator review)
  bool get hasPublicAiCredibility => hasTruthIntelligence && canPublicViewFactCheck;

  /// Lazily cached, pre-normalized tokens for O(1) category matching & search.
  Set<String> get categoryTokens {
    if (_categoryTokens != null) return _categoryTokens!;
    final set = <String>{};
    if (category.isNotEmpty) {
      set.add(category.trim().toLowerCase());
    }
    for (final tag in tags) {
      final s = tag.trim().toLowerCase();
      if (s.isNotEmpty) set.add(s);
    }
    for (final topic in topics) {
      final s = topic.trim().toLowerCase();
      if (s.isNotEmpty) set.add(s);
    }
    return _categoryTokens = set;
  }
  String get videoUrl => originalUrl;
  String get channelImage => channelAvatarUrl;
  String get duration => VideoDurationUtils.formatDuration(durationValue);
  int get durationMs => durationValue.inMilliseconds;
  int get durationSeconds => durationValue.inSeconds;
  List<ResolutionV2> get resolutions => [ResolutionV2(originalUrl)];
  bool get isScheduled => status == VideoStatus.scheduled;

  static Duration parseDuration(dynamic duration) =>
      VideoDurationUtils.parseDuration(duration);

  OfflineVideo toOffline() => VideoSerializer.toOffline(this);

  Map<String, dynamic> toMap() => VideoSerializer.toMap(this);

  Video copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? ownerId,
    String? channelId,
    String? channelName,
    String? category,
    List<String>? tags,
    String? vTitleLowercase,
    String? originalUrl,
    String? videoUrl,
    String? hlsUrl,
    String? dashUrl,
    String? storyboardUrl,
    List<String>? storyboardVariants,
    List<VideoResolutionV2>? adaptiveResolutions,
    List<String>? thumbnailVariants,
    String? animatedPreviewUrl,
    String? channelAvatarUrl,
    int? viewCount,
    int? likeCount,
    int? dislikeCount,
    int? commentCount,
    int? shareCount,
    Duration? vDurationValue,
    dynamic createdAt,
    dynamic uploadedAt,
    dynamic updatedAt,
    VideoStatus? status,
    String? visibility,
    List<String>? topics,
    String? language,
    List<String>? languages,
    bool? isShort,
    bool? isKidFriendly,
    bool? allowComments,
    bool? enableComments,
    bool? isMonetized,
    bool? allowRatings,
    bool? showLikeCount,
    bool? showDislikeCount,
    bool? autoChaptersEnabled,
    List<String>? sourceLinks,
    bool? isFactChecked,
    String? factCheckTier,
    String? factCheckReviewMode,
    bool? isFactCheckApproved,
    bool? isVerified,
    List<String>? likedBy,
    bool? isSeen,
    int? totalWatchTimeSeconds,
    String? trustLabel,
    String? channelStatus,
    String? coinBattlePairVideoId,
    String? coinBattleStance,
    String? moderationSummary,
    DateTime? scheduledPublishAt,
    List<double>? embedding,
    String? jobId,
    int? resubmitCount,
    Map<String, String>? audioTracks,
    Map<String, String>? dubbedVideos,
    Map<String, String>? mediaSubtitles,
    String? transcriptionUrl,
    String? factCheckUrl,
    bool? isChannelTrusted,
    bool? isProvisional,
    double? provisionalScore,
    String? provisionalLabel,
    String? provisionalViewerNote,
    List<Map<String, dynamic>>? provisionalClaims,
    String? credibilityStatus,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      moderationSummary: moderationSummary ?? this.moderationSummary,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      ownerId: ownerId ?? this.ownerId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      vTitleLowercase: vTitleLowercase ?? titleLowercase,
      originalUrl: originalUrl ?? this.originalUrl,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      dashUrl: dashUrl ?? this.dashUrl,
      storyboardUrl: storyboardUrl ?? this.storyboardUrl,
      storyboardVariants: storyboardVariants ?? this.storyboardVariants,
      adaptiveResolutions: adaptiveResolutions ?? this.adaptiveResolutions,
      thumbnailVariants: thumbnailVariants ?? this.thumbnailVariants,
      animatedPreviewUrl: animatedPreviewUrl ?? this.animatedPreviewUrl,
      channelAvatarUrl: channelAvatarUrl ?? this.channelAvatarUrl,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      vDurationValue: vDurationValue ?? durationValue,
      createdAt: createdAt ?? this.createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      topics: topics ?? this.topics,
      language: language ?? this.language,
      languages: languages ?? this.languages,
      isShort: isShort ?? this.isShort,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      enableComments: allowComments ?? enableComments ?? this.enableComments,
      isMonetized: isMonetized ?? this.isMonetized,
      allowRatings: allowRatings ?? this.allowRatings,
      showLikeCount: showLikeCount ?? this.showLikeCount,
      showDislikeCount: showDislikeCount ?? this.showDislikeCount,
      autoChaptersEnabled: autoChaptersEnabled ?? this.autoChaptersEnabled,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      isFactChecked: isFactChecked ?? this.isFactChecked,
      factCheckTier: factCheckTier ?? this.factCheckTier,
      factCheckReviewMode: factCheckReviewMode ?? this.factCheckReviewMode,
      isFactCheckApproved: isFactCheckApproved ?? this.isFactCheckApproved,
      isVerified: isVerified ?? this.isVerified,
      isChannelTrusted: isChannelTrusted ?? this.isChannelTrusted,
      likedBy: likedBy ?? this.likedBy,
      isSeen: isSeen ?? this.isSeen,
      totalWatchTimeSeconds:
          totalWatchTimeSeconds ?? this.totalWatchTimeSeconds,
      trustLabel: trustLabel ?? this.trustLabel,
      channelStatus: channelStatus ?? this.channelStatus,
      scheduledPublishAt: scheduledPublishAt ?? this.scheduledPublishAt,
      coinBattlePairVideoId:
          coinBattlePairVideoId ?? this.coinBattlePairVideoId,
      coinBattleStance: coinBattleStance ?? this.coinBattleStance,
      embedding: embedding ?? this.embedding,
      jobId: jobId ?? this.jobId,
      resubmitCount: resubmitCount ?? this.resubmitCount,
      audioTracks: audioTracks ?? this.audioTracks,
      dubbedVideos: dubbedVideos ?? this.dubbedVideos,
      mediaSubtitles: mediaSubtitles ?? this.mediaSubtitles,
      transcriptionUrl: transcriptionUrl ?? this.transcriptionUrl,
      factCheckUrl: factCheckUrl ?? this.factCheckUrl,
      isProvisional: isProvisional ?? this.isProvisional,
      provisionalScore: provisionalScore ?? this.provisionalScore,
      provisionalLabel: provisionalLabel ?? this.provisionalLabel,
      provisionalViewerNote: provisionalViewerNote ?? this.provisionalViewerNote,
      provisionalClaims: provisionalClaims ?? this.provisionalClaims,
      credibilityStatus: credibilityStatus ?? this.credibilityStatus,
    );
  }

  /// Converts this data model to a pure domain [VideoEntity].
  VideoEntity toEntity() {
    return VideoEntity(
      id: id,
      title: title,
      ownerId: ownerId,
      channelId: channelId,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
      description: description,
      channelName: channelName,
      channelAvatarUrl: channelAvatarUrl,
      thumbnailUrl: thumbnailUrl,
      originalUrl: originalUrl,
      hlsUrl: hlsUrl,
      dashUrl: dashUrl,
      storyboardUrl: storyboardUrl,
      storyboardVariants: storyboardVariants,
      viewCount: viewCount,
      likeCount: likeCount,
      dislikeCount: dislikeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      duration: durationValue,
      status: status.name,
      visibility: visibility,
      category: category,
      tags: tags,
      topics: topics,
      language: language,
      isShort: isShort,
      isKidFriendly: isKidFriendly,
      enableComments: enableComments,
      isMonetized: isMonetized,
      resubmitCount: resubmitCount,
    );
  }

  /// Creates a [Video] data model from a pure domain [VideoEntity].
  static Video fromEntity(VideoEntity entity) {
    return Video(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      thumbnailUrl: entity.thumbnailUrl,
      ownerId: entity.ownerId,
      channelId: entity.channelId,
      channelName: entity.channelName,
      channelAvatarUrl: entity.channelAvatarUrl,
      category: entity.category,
      tags: entity.tags,
      resubmitCount: entity.resubmitCount,
      originalUrl: entity.originalUrl,
      hlsUrl: entity.hlsUrl,
      dashUrl: entity.dashUrl,
      storyboardUrl: entity.storyboardUrl,
      storyboardVariants: entity.storyboardVariants,
      viewCount: entity.viewCount,
      likeCount: entity.likeCount,
      dislikeCount: entity.dislikeCount,
      commentCount: entity.commentCount,
      shareCount: entity.shareCount,
      vDurationValue: entity.duration,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      status: entity.status,
      visibility: entity.visibility,
      topics: entity.topics,
      language: entity.language,
      isShort: entity.isShort,
      isKidFriendly: entity.isKidFriendly,
      enableComments: entity.enableComments,
      isMonetized: entity.isMonetized,
    );
  }
}

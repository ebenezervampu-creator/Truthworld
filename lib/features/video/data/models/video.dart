import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
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
    this.enableComments = true,
    this.allowClipping = true,
    this.isMonetized = false,
    this.allowRatings = false,
    this.showLikeCount = true,
    this.showDislikeCount = true,
    this.autoChaptersEnabled = true,
    this.trustScore = 0.0,
    this.sourceLinks = const [],
    this.isFactChecked = false,
    this.factCheckTier = 'standard',
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
        viewCount = viewCount ??
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
      trustScore: trustScore,
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
      description: 'Offline Video',
      thumbnailUrl: offline.thumbnailUrl,
      ownerId: '',
      channelId: '',
      channelName: offline.channelName,
      channelAvatarUrl: offline.channelImage,
      category: 'Downloads',
      tags: [],
      viewCount: int.tryParse(offline.views) ?? 0,
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
  final String channelId;
  final String channelName;
  final String channelAvatarUrl;

  // Engagement Counters
  final int viewCount;
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
  final bool allowClipping;
  final bool isMonetized;
  final bool allowRatings;
  final bool showLikeCount;
  final bool showDislikeCount;
  final bool autoChaptersEnabled;
  final double trustScore;
  final List<String>? sourceLinks;
  final bool isFactChecked;
  final String factCheckTier; // "short" | "standard" | "full_ground"
  final bool isVerified;
  bool isSeen = false;
  final String? channelStatus;
  final DateTime? scheduledPublishAt;
  final String? coinBattlePairVideoId;
  final String? coinBattleStance;
  final bool? geminiApproved;
  final bool? isApproved;
  final String moderationSummary;
  final List<double>? embedding;

  // v8.0 Credibility Fields (lightweight)
  final String? trustLabel;
  final String? jobId;

  // Direct fields (immediate availability without cache delay)
  final String _directFactCheckUrl;
  final String _directTranscriptionUrl;
  final Map<String, String> _directMediaSubtitles;
  final Map<String, String> _directDubbedVideos;
  final Map<String, String> _directAudioTracks;

  // Summary getter with priority: moderation.summary -> credibility.summary -> description
  String get summary => moderationSummary.isNotEmpty
      ? moderationSummary
      : (VideoMediaService.credibilityCache[id]?.summary.isNotEmpty == true
          ? VideoMediaService.credibilityCache[id]!.summary
          : description);

  // Getters lookup direct first, then VideoMediaService static caches
  Map<String, String> get mediaSubtitles => _directMediaSubtitles.isNotEmpty
      ? _directMediaSubtitles
      : (VideoMediaService.localizationCache[id]?.subtitles ?? const {});
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

  // Compatibility Getters
  int get likes => likeCount;
  int get views => viewCount;
  double get truthScore => trustScore;
  double get trustIndex => trustScore;
  Timestamp get uploadedAt => createdAt;

  Set<String>? _categoryTokens;

  /// Non-factual or creative categories where AI credibility / fact-checking is not applicable.
  static const Set<String> nonCredibilityCategories =
      AppCategories.nonCredibilityTokens;

  /// Returns true if the video is non-factual/creative content where AI credibility is not applicable.
  bool get isNonCredibilityCategory {
    final cat = (videoCategory ?? category).trim().toLowerCase();
    if (cat.isNotEmpty &&
        (nonCredibilityCategories.contains(cat) ||
            nonCredibilityCategories.any(cat.contains))) {
      return true;
    }
    return categoryTokens.any(nonCredibilityCategories.contains);
  }

  /// Returns true if this video is eligible for and actually has AI credibility / fact-checking enabled and present.
  bool get hasAiCredibility {
    if (isNonCredibilityCategory) return false;
    return isFactChecked ||
        factCheckUrl.isNotEmpty ||
        (uiReport != null &&
            (uiReport?.keyClaims.isNotEmpty == true ||
                uiReport?.summary.rating != null));
  }

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
    bool? enableComments,
    bool? isMonetized,
    bool? allowRatings,
    bool? showLikeCount,
    bool? showDislikeCount,
    bool? autoChaptersEnabled,
    double? trustScore,
    List<String>? sourceLinks,
    bool? isFactChecked,
    String? factCheckTier,
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
    Map<String, String>? audioTracks,
    Map<String, String>? dubbedVideos,
    Map<String, String>? mediaSubtitles,
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
      enableComments: enableComments ?? this.enableComments,
      isMonetized: isMonetized ?? this.isMonetized,
      allowRatings: allowRatings ?? this.allowRatings,
      showLikeCount: showLikeCount ?? this.showLikeCount,
      showDislikeCount: showDislikeCount ?? this.showDislikeCount,
      autoChaptersEnabled: autoChaptersEnabled ?? this.autoChaptersEnabled,
      trustScore: trustScore ?? this.trustScore,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      isFactChecked: isFactChecked ?? this.isFactChecked,
      factCheckTier: factCheckTier ?? this.factCheckTier,
      isVerified: isVerified ?? this.isVerified,
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
      audioTracks: audioTracks ?? this.audioTracks,
      dubbedVideos: dubbedVideos ?? this.dubbedVideos,
      mediaSubtitles: mediaSubtitles ?? this.mediaSubtitles,
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
      trustScore: trustScore,
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
      trustScore: entity.trustScore,
    );
  }
}

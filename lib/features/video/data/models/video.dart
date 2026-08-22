import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

enum VideoStatus {
  uploading,
  processing, // Transcoding to HLS/Dash
  ready, // Published
  flagged, // Under review
  deleted,
  private,
  scheduled,
  rejected, // Failed moderation — content violates guidelines
  pending_review, // Awaiting manual admin review (ambiguous moderation)
  draft, // Draft video
}

class VideoResolutionV2 {
  VideoResolutionV2({
    required this.label,
    required this.url,
    required this.width,
    required this.height,
    required this.bitrate,
  });

  factory VideoResolutionV2.fromMap(Map<String, dynamic> map) =>
      VideoResolutionV2(
        label: map['label'] ?? '',
        url: map['url'] ?? '',
        width: map['width'] ?? 0,
        height: map['height'] ?? 0,
        bitrate: map['bitrate'] ?? 0,
      );
  final String label; // e.g., "1080p", "720p"
  final String url;
  final int width;
  final int height;
  final int bitrate;

  Map<String, dynamic> toMap() => {
    'label': label,
    'url': url,
    'width': width,
    'height': height,
    'bitrate': bitrate,
  };
}

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
    this.isMonetized = false,
    this.allowRatings = false,
    this.showLikeCount = true,
    this.showDislikeCount = true,
    this.trustScore = 0.0,
    this.sourceLinks = const [],
    this.isFactChecked = false,
    this.isVerified = false,
    List<String>? likedBy,
    // Ignored/deprecated heavy fields for backward compatibility
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
  }) : titleLowercase = (vTitleLowercase == null || vTitleLowercase.isEmpty)
           ? title.toLowerCase()
           : vTitleLowercase,
       originalUrl = (originalUrl == null || originalUrl.isEmpty)
           ? (videoUrl ?? '')
           : originalUrl,
       channelAvatarUrl = channelAvatarUrl ?? channelImage ?? '',
       viewCount =
           viewCount ??
           (views is int
               ? views
               : (int.tryParse(views?.toString() ?? '0') ?? 0)),
       likeCount =
           likeCount ??
           (likes is int
               ? likes
               : (int.tryParse(likes?.toString() ?? '0') ?? 0)),
       durationValue =
           (vDurationValue != null && vDurationValue != Duration.zero)
           ? vDurationValue
           : parseDuration(duration),
       createdAt = TimestampUtils.parse(createdAt ?? uploadedAt),
       updatedAt = TimestampUtils.parse(updatedAt ?? createdAt ?? uploadedAt),
       status = status is VideoStatus ? status : VideoStatus.processing,
       visibility = visibility?.toString() ?? 'public',
       likedBy = likedBy ?? [],
       _directFactCheckUrl = factCheckUrl ?? '',
       _directTranscriptionUrl = transcriptionUrl ?? '',
       _directMediaSubtitles = mediaSubtitles ?? const {} {
    // Populate the VideoMediaService static caches for instant synchronous retrieval
    if ((mediaSubtitles != null && mediaSubtitles.isNotEmpty) ||
        (dubbedVideos != null && dubbedVideos.isNotEmpty) ||
        (audioTracks != null && audioTracks.isNotEmpty)) {
      VideoMediaService.localizationCache[id] = VideoMediaLocalization(
        subtitles: mediaSubtitles ?? const {},
        dubbedVideos: dubbedVideos ?? const {},
        audioTracks: audioTracks ?? const {},
      );
    }
    if (scoringFactors != null ||
        deductions != null ||
        contextualFlags != null ||
        honestyBreakdown != null ||
        (factCheckUrl != null && factCheckUrl.isNotEmpty) ||
        (transcriptionUrl != null && transcriptionUrl.isNotEmpty)) {
      VideoMediaService.credibilityCache[id] = VideoMediaCredibility(
        trustScore: trustScore,
        trustLabel: trustLabel,
        scoringFactors: scoringFactors,
        deductions: deductions ?? const [],
        contextualFlags: contextualFlags ?? const [],
        honestyBreakdown: honestyBreakdown,
        harmCapApplied: harmCapApplied ?? false,
        harmCapReason: harmCapReason,
        categoryWeightProfile: categoryWeightProfile,
        confidenceNotes: confidenceNotes ?? const [],
        diagnostics: diagnostics ?? const [],
        factCheckStats: factCheckStats,
        videoCategory: videoCategory,
        hardeningMetadata: hardeningMetadata,
        intentToMisleadScore: intentToMisleadScore,
        uiReport: uiReport,
        factCheckUrl: factCheckUrl ?? '',
        transcriptionUrl: transcriptionUrl ?? '',
      );
    }
    if (chapters != null) {
      VideoMediaService.streamingCache[id] = VideoMediaStreaming(
        originalUrl: originalUrl ?? '',
        hlsUrl: hlsUrl,
        dashUrl: dashUrl,
        adaptiveResolutions: adaptiveResolutions,
        thumbnailVariants: thumbnailVariants,
        animatedPreviewUrl: animatedPreviewUrl,
        chapters: chapters,
      );
    }
  }

  factory Video.fromMap(Map<String, dynamic> data, [String? docId]) {
    final finalId = docId ?? data['id'] ?? data['videoId'] ?? '';
    final rawVideoUrl = (data['videoUrl'] as String?) ?? (data['originalUrl'] as String?) ?? '';
    
    // 1. Resolve adaptive resolutions with fallback
    var resolutionsList = (data['adaptiveResolutions'] as List? ?? [])
        .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    if (resolutionsList.isEmpty && rawVideoUrl.isNotEmpty) {
      resolutionsList = [
        VideoResolutionV2(label: '1080p', url: rawVideoUrl, width: 1920, height: 1080, bitrate: 4500000),
        VideoResolutionV2(label: '720p', url: rawVideoUrl, width: 1280, height: 720, bitrate: 2500000),
        VideoResolutionV2(label: '480p', url: rawVideoUrl, width: 854, height: 480, bitrate: 1200000),
        VideoResolutionV2(label: '360p', url: rawVideoUrl, width: 640, height: 360, bitrate: 800000),
        VideoResolutionV2(label: '240p', url: rawVideoUrl, width: 426, height: 240, bitrate: 400000),
        VideoResolutionV2(label: '144p', url: rawVideoUrl, width: 256, height: 144, bitrate: 200000),
      ];
    }

    // 2. Infer clean title if missing or untitled
    var parsedTitle = (data['title'] as String?) ?? '';
    if (parsedTitle.trim().isEmpty || parsedTitle.toLowerCase().startsWith('untitled')) {
      // autoChapters can be a bool (aiFeatures flag) or a List (AI-generated chapters)
      final rawAutoChapters = data['autoChapters'];
      final chapters = rawAutoChapters is List ? rawAutoChapters : null;
      final summary = data['summary'] as String?;
      if (chapters != null && chapters.isNotEmpty && chapters[0] is Map && chapters[0]['title'] != null) {
        parsedTitle = chapters[0]['title'].toString();
      } else if (summary != null && summary.trim().length > 5) {
        parsedTitle = summary.length > 60 ? '${summary.substring(0, 57)}...' : summary;
      } else {
        parsedTitle = 'Truthworld Insight Video';
      }
    }

    // 3. Fallback FactCheck & Transcription URLs
    final parsedFactCheckUrl = (data['media'] != null && data['media']['factCheckUrl'] != null && (data['media']['factCheckUrl'] as String).isNotEmpty)
        ? (data['media']['factCheckUrl'] as String)
        : ((data['factCheckUrl'] as String?)?.isNotEmpty == true
            ? (data['factCheckUrl'] as String)
            : '');

    final parsedTranscriptUrl = (data['media'] != null && data['media']['transcriptionUrl'] != null && (data['media']['transcriptionUrl'] as String).isNotEmpty)
        ? (data['media']['transcriptionUrl'] as String)
        : ((data['transcriptionUrl'] as String?)?.isNotEmpty == true
            ? (data['transcriptionUrl'] as String)
            : '');

    final parsedThumbnailUrl = (data['thumbnailUrl'] as String?)?.trim() ?? '';
    final thumbnailVariantsList = List<String>.from(data['thumbnailVariants'] ?? []);
    final animPreviewUrl = (data['animatedPreviewUrl'] as String?)?.trim() ?? '';
    var resolvedThumbnailUrl = parsedThumbnailUrl;
    if (resolvedThumbnailUrl.isEmpty && thumbnailVariantsList.isNotEmpty) {
      resolvedThumbnailUrl = thumbnailVariantsList.first;
    }
    if (resolvedThumbnailUrl.isEmpty && animPreviewUrl.isNotEmpty) {
      resolvedThumbnailUrl = animPreviewUrl;
    }

    final parsedGeminiApproved = data['geminiApproved'] as bool? ??
        (data['moderation'] is Map
            ? data['moderation']['geminiApproved'] as bool?
            : null);
    final parsedIsApproved = data['isApproved'] as bool? ??
        (data['moderation'] is Map
            ? data['moderation']['isApproved'] as bool?
            : null);

    final parsedModerationSummary = (data['moderation'] is Map &&
            data['moderation']['summary'] != null &&
            (data['moderation']['summary'] as String).isNotEmpty)
        ? (data['moderation']['summary'] as String)
        : ((data['summary'] as String?)?.isNotEmpty == true
            ? (data['summary'] as String)
            : ((data['moderation'] is Map &&
                    data['moderation']['explanation'] != null &&
                    (data['moderation']['explanation'] as String).isNotEmpty)
                ? (data['moderation']['explanation'] as String)
                : ''));

    return Video(
      id: finalId,
      title: parsedTitle,
      vTitleLowercase: data['titleLowercase'] ?? parsedTitle.toLowerCase(),
      description: data['description'] ?? '',
      moderationSummary: parsedModerationSummary,
      originalUrl: data['originalUrl'] ?? rawVideoUrl,
      videoUrl: data['videoUrl'] ?? rawVideoUrl,
      hlsUrl: data['hlsUrl'] ?? rawVideoUrl,
      dashUrl: data['dashUrl'] ?? rawVideoUrl,
      adaptiveResolutions: resolutionsList,
      thumbnailUrl: resolvedThumbnailUrl,
      thumbnailVariants: thumbnailVariantsList,
      animatedPreviewUrl: animPreviewUrl,
      geminiApproved: parsedGeminiApproved,
      isApproved: parsedIsApproved,
      ownerId: data['ownerId'] ?? '',
      channelId: data['channelId'] ?? '',
      channelName: data['channelName'] ?? '',
      channelAvatarUrl: data['channelAvatarUrl'] ?? '',
      viewCount:
          (data['viewCount'] as num?)?.toInt() ??
          (data['views'] as num?)?.toInt() ??
          (data['stats'] is Map
              ? (data['stats']['views'] as num?)?.toInt()
              : null) ??
          0,
      likeCount: data['likeCount'] ?? 0,
      dislikeCount: data['dislikeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      vDurationValue: Duration(milliseconds: data['durationMs'] ?? 0),
      createdAt: data['createdAt'],
      uploadedAt: data['uploadedAt'] ?? data['publishedAt'],
      updatedAt: data['updatedAt'],
      status: () {
        final rawStatus = (data['status'] as String?)?.toLowerCase() ?? '';
        final pipelineStage = ((data['aiFeatures'] is Map
                    ? data['aiFeatures']['pipelineStage']
                    : null) ??
                data['pipelineStage'])
            ?.toString()
            .toLowerCase();
        if (rawStatus == 'draft' || pipelineStage == 'draft') {
          return VideoStatus.draft;
        }
        if (rawStatus == 'uploaded' || rawStatus == 'uploading') {
          return VideoStatus.uploading;
        }
        return VideoStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => (rawStatus == 'uploaded' ||
                  rawStatus == 'uploading' ||
                  rawStatus == 'processing')
              ? VideoStatus.draft
              : VideoStatus.ready,
        );
      }(),
      visibility: data['visibility'] ?? 'public',
      category: data['category'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      topics: List<String>.from(data['topics'] ?? []),
      language: data['language'] ?? 'en',
      // 'languages' holds full-name translation targets (e.g. ["Tamil"]) from Firestore
      languages: List<String>.from(
        data['languages'] ??
        (data['aiFeatures'] is Map
            ? (data['aiFeatures']['translationLanguages'] ?? [])
            : []) ??
        [],
      ),
      isShort: data['isShort'] ?? false,
      isKidFriendly: data['isKidFriendly'] ?? false,
      enableComments: data['enableComments'] ?? true,
      isMonetized: data['isMonetized'] ?? false,
      mediaSubtitles:
          data['media'] != null && data['media']['subtitles'] != null
          ? Map<String, String>.from(data['media']['subtitles'] as Map)
          : (data['subtitles'] != null
                ? Map<String, String>.from(data['subtitles'] as Map)
                : const {}),
      dubbedVideos:
          data['media'] != null && data['media']['dubbedVideos'] != null
          ? Map<String, String>.from(data['media']['dubbedVideos'] as Map)
          : (data['dubbedVideos'] != null
                ? Map<String, String>.from(data['dubbedVideos'] as Map)
                : const {}),
      audioTracks: data['media'] != null && data['media']['audioTracks'] != null
          ? Map<String, String>.from(data['media']['audioTracks'] as Map)
          : (data['audioTracks'] != null
                ? Map<String, String>.from(data['audioTracks'] as Map)
                : const {}),
      factCheckUrl: parsedFactCheckUrl,
      transcriptionUrl: parsedTranscriptUrl,
      allowRatings: data['allowRatings'] ?? false,
      showLikeCount:
          data['showLikeCount'] ??
          data['showLikesCount'] ??
          data['showLikes'] ??
          true,
      showDislikeCount:
          data['showDislikeCount'] ??
          data['showDislikesCount'] ??
          data['showDislikes'] ??
          true,
      trustScore: (data['trustScore'] ?? 0).toDouble(),
      sourceLinks: List<String>.from(data['sourceLinks'] ?? []),
      isFactChecked: (data['isFactChecked'] as bool?) ?? parsedFactCheckUrl.isNotEmpty,
      isVerified: data['isVerified'] ?? false,
      // Read chapters from 'chapters' field first; fall back to root 'autoChapters' array.
      // 'autoChapters' at root is a List of chapter maps (from AI pipeline).
      // Deduplicate by startMs to prevent showing the same chapter twice.
      chapters: () {
        final fromChapters = (data['chapters'] as List? ?? [])
            .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        if (fromChapters.isNotEmpty) return fromChapters;
        final rawAutoChapters = data['autoChapters'];
        if (rawAutoChapters is List && rawAutoChapters.isNotEmpty) {
          return rawAutoChapters
              .whereType<Map>()
              .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
        return <VideoChapter>[];
      }(),
      totalWatchTimeSeconds: data['totalWatchTimeSeconds'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      // v8.0
      trustLabel: data['trustLabel'],
      channelStatus: data['channelStatus'],
      scheduledPublishAt: data['scheduledPublishAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['scheduledPublishAt'])
          : null,
      scoringFactors: data['scoringFactors'] != null
          ? ScoringFactors.fromMap(
              Map<String, dynamic>.from(data['scoringFactors']),
            )
          : null,
      deductions: (data['deductions'] as List? ?? [])
          .map((e) => TrustDeduction.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      contextualFlags: (data['contextualFlags'] as List? ?? [])
          .map((e) => ContextualFlag.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      honestyBreakdown: data['honestyBreakdown'] != null
          ? HonestyBreakdown.fromMap(
              Map<String, dynamic>.from(data['honestyBreakdown']),
            )
          : null,
      harmCapApplied: data['harmCapApplied'] ?? false,
      harmCapReason: data['harmCapReason'],
      categoryWeightProfile: data['categoryWeightProfile'] != null
          ? Map<String, double>.from(
              data['categoryWeightProfile'].map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            )
          : null,
      confidenceNotes: List<String>.from(data['confidenceNotes'] ?? []),
      diagnostics: List<String>.from(data['diagnostics'] ?? []),
      factCheckStats: data['factCheckStats'] != null
          ? FactCheckStats.fromMap(
              Map<String, dynamic>.from(data['factCheckStats']),
            )
          : null,
      videoCategory: data['videoCategory'],
      hardeningMetadata: data['hardeningMetadata'] != null
          ? HardeningMetadata.fromMap(
              Map<String, dynamic>.from(data['hardeningMetadata']),
            )
          : null,
      intentToMisleadScore: (data['intentToMisleadScore'] ?? 0).toDouble(),
      uiReport: data['uiReport'] != null
          ? UIReport.fromMap(Map<String, dynamic>.from(data['uiReport']))
          : null,
      coinBattlePairVideoId: data['coinBattlePairVideoId'] as String?,
      coinBattleStance: data['coinBattleStance'] as String?,
    );
  }

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
  final String titleLowercase; // For search efficiency
  final String description;

  // Storage & Streaming
  final String originalUrl; // Raw upload for backup/download
  final String hlsUrl; // Adaptive streaming manifest
  final String dashUrl; // Alternative streaming
  final List<VideoResolutionV2> adaptiveResolutions;

  // Thumbnails & Previews
  final String thumbnailUrl;
  final List<String> thumbnailVariants; // [small, medium, large]
  final String animatedPreviewUrl; // GIF or short MP4 for hover

  // Ownership & Context
  final String ownerId;
  final String channelId;
  final String channelName;
  final String channelAvatarUrl;

  // Engagement (Atomic Counters)
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
  final String visibility; // public, private, unlisted
  final List<String> likedBy;

  // Content Info
  final String category;
  final List<String> tags;
  final List<String> topics;
  final String language;
  final List<String> languages; // Requested translation/subtitle languages (full names or codes)
  final bool isShort;
  final bool isKidFriendly;

  // Flags
  final bool enableComments;
  final bool isMonetized;
  final bool allowRatings;
  final bool showLikeCount;
  final bool showDislikeCount;
  final double trustScore;
  final List<String>? sourceLinks;
  final bool isFactChecked;
  final bool isVerified;
  bool isSeen = false;
  final String? channelStatus;
  final DateTime? scheduledPublishAt;
  final String? coinBattlePairVideoId;
  final String? coinBattleStance;
  final bool? geminiApproved;
  final bool? isApproved;
  final String moderationSummary;

  // v8.0 Credibility Fields (lightweight)
  final String? trustLabel;

  // Direct fields (immediate availability without cache delay)
  final String _directFactCheckUrl;
  final String _directTranscriptionUrl;
  final Map<String, String> _directMediaSubtitles;

  // Summary getter with priority: moderation.summary -> credibility.summary -> description
  String get summary => moderationSummary.isNotEmpty
      ? moderationSummary
      : (VideoMediaService.credibilityCache[id]?.summary.isNotEmpty == true
          ? VideoMediaService.credibilityCache[id]!.summary
          : description);

  // Getters lookup direct first, then VideoMediaService static caches
  Map<String, String> get mediaSubtitles =>
      _directMediaSubtitles.isNotEmpty
          ? _directMediaSubtitles
          : (VideoMediaService.localizationCache[id]?.subtitles ?? const {});
  Map<String, String> get dubbedVideos =>
      VideoMediaService.localizationCache[id]?.dubbedVideos ?? const {};
  Map<String, String> get audioTracks =>
      VideoMediaService.localizationCache[id]?.audioTracks ?? const {};
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
  String get videoUrl => originalUrl;
  String get channelImage => channelAvatarUrl;
  String get duration => _formatDuration(durationValue);
  int get durationMs => durationValue.inMilliseconds;
  int get durationSeconds => durationValue.inSeconds;
  List<ResolutionV2> get resolutions => [ResolutionV2(originalUrl)];
  bool get isScheduled => status == VideoStatus.scheduled;

  /// Returns true if video is approved by Gemini AI moderation or manual admin review.
  bool get isApprovedByGeminiOrManual {
    // 1. Explicit negative moderation flags
    if (geminiApproved == false || isApproved == false) return false;
    if (status == VideoStatus.rejected ||
        status == VideoStatus.flagged ||
        status == VideoStatus.pending_review ||
        status == VideoStatus.draft ||
        status == VideoStatus.uploading ||
        status == VideoStatus.processing) {
      return false;
    }
    // 2. Explicit positive approval flags
    if (geminiApproved == true || isApproved == true) return true;

    // 3. Fallback for ready status
    if (status == VideoStatus.ready) return true;

    return false;
  }

  bool get isDraft {
    if (status == VideoStatus.draft || status == VideoStatus.uploading) return true;
    final vis = visibility.trim().toLowerCase();
    if (vis == 'draft' || vis == 'private_draft') return true;
    final t = title.trim().toLowerCase();
    if (t.isEmpty ||
        t == 'uploading...' ||
        t.startsWith('uploading') ||
        t == 'untitled' ||
        t == 'untitled draft' ||
        t.startsWith('untitled')) {
      return true;
    }
    return false;
  }

  bool get isUntitled {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t == 'untitled' ||
        t == 'untitled video' ||
        t == 'untitled draft' ||
        t == 'untitled campaign' ||
        t == 'untitled playlist' ||
        t == 'untitled topic' ||
        t.startsWith('untitled') ||
        t == 'uploading...' ||
        t.startsWith('uploading')) {
      return true;
    }
    return false;
  }

  bool get isUploadingOrProcessing {
    if (isDraft) return true;
    if (status == VideoStatus.uploading ||
        status == VideoStatus.processing ||
        status == VideoStatus.draft ||
        status == VideoStatus.pending_review) {
      return true;
    }
    final statusName = status.name.toLowerCase();
    if (statusName == 'uploading' ||
        statusName == 'uploaded' ||
        statusName == 'processing' ||
        statusName == 'draft' ||
        statusName == 'pending_review' ||
        statusName == 'pending') {
      return true;
    }
    return false;
  }

  static Duration parseDuration(dynamic duration) {
    if (duration is Duration) return duration;
    if (duration == null) return Duration.zero;
    if (duration is int) {
      if (duration > 100000) {
        return Duration(milliseconds: duration);
      }
      return Duration(seconds: duration);
    }
    if (duration is double) {
      return Duration(seconds: duration.toInt());
    }
    if (duration is String) {
      final str = duration.trim();
      if (str.isEmpty) return Duration.zero;
      final parts = str.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return Duration(minutes: m, seconds: s);
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return Duration(hours: h, minutes: m, seconds: s);
      } else {
        final val = int.tryParse(str);
        if (val != null) {
          if (val > 100000) return Duration(milliseconds: val);
          return Duration(seconds: val);
        }
      }
    }
    return Duration.zero;
  }

  static String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return '${twoDigits(d.inHours)}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  OfflineVideo toOffline() {
    return OfflineVideo(
      id: id,
      title: title,
      channelName: channelName,
      channelImage: channelAvatarUrl,
      views: views.toString(),
      thumbnailUrl: thumbnailUrl,
      downloadedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'titleLowercase': titleLowercase,
      'description': description,
      'originalUrl': originalUrl,
      'hlsUrl': hlsUrl,
      'dashUrl': dashUrl,
      'adaptiveResolutions': adaptiveResolutions.map((e) => e.toMap()).toList(),
      'thumbnailUrl': thumbnailUrl,
      'thumbnailVariants': thumbnailVariants,
      'animatedPreviewUrl': animatedPreviewUrl,
      'ownerId': ownerId,
      'channelId': channelId,
      'channelName': channelName,
      'channelAvatarUrl': channelAvatarUrl,
      'viewCount': viewCount,
      'views': viewCount,
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'durationMs': durationValue.inMilliseconds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'uploadedAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status.name,
      'visibility': visibility,
      'category': category,
      'tags': tags,
      'topics': topics,
      'language': language,
      'languages': languages,
      'isShort': isShort,
      'isKidFriendly': isKidFriendly,
      'enableComments': enableComments,
      'isMonetized': isMonetized,
      'allowRatings': allowRatings,
      'showLikeCount': showLikeCount,
      'showDislikeCount': showDislikeCount,
      'trustScore': trustScore,
      'sourceLinks': sourceLinks,
      'isFactChecked': isFactChecked,
      'isVerified': isVerified,
      'qualifiedViewCount': viewCount,
      'totalWatchTimeSeconds': totalWatchTimeSeconds,
      'likedBy': likedBy,
      'trustLabel': trustLabel,
      'channelStatus': channelStatus,
      'scheduledPublishAt': scheduledPublishAt?.millisecondsSinceEpoch,
      'coinBattlePairVideoId': coinBattlePairVideoId,
      'coinBattleStance': coinBattleStance,
      'moderationSummary': moderationSummary,
    };
  }

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
    double? trustScore,
    List<String>? sourceLinks,
    bool? isFactChecked,
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
      trustScore: trustScore ?? this.trustScore,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      isFactChecked: isFactChecked ?? this.isFactChecked,
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
    );
  }
}

class ResolutionV2 {
  ResolutionV2(this.path);
  final String path;
}

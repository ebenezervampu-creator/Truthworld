import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';

enum VideoStatus {
  uploading,
  processing, // Transcoding to HLS/Dash
  ready, // Published
  flagged, // Under review
  deleted,
  private,
  scheduled,
}

class VideoResolutionV2 {
  final String label; // e.g., "1080p", "720p"
  final String url;
  final int width;
  final int height;
  final int bitrate;

  VideoResolutionV2({
    required this.label,
    required this.url,
    required this.width,
    required this.height,
    required this.bitrate,
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'url': url,
    'width': width,
    'height': height,
    'bitrate': bitrate,
  };

  factory VideoResolutionV2.fromMap(Map<String, dynamic> map) =>
      VideoResolutionV2(
        label: map['label'] ?? '',
        url: map['url'] ?? '',
        width: map['width'] ?? 0,
        height: map['height'] ?? 0,
        bitrate: map['bitrate'] ?? 0,
      );
}

class Video {
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
  final String language;
  final bool isShort;
  final bool isKidFriendly;

  // Flags
  final bool enableComments;
  final bool isMonetized;
  final bool allowRatings;
  final double trustScore;
  final double videoRating;
  bool isSeen = false;

  // v8.0 Credibility Fields (lightweight)
  final String? trustLabel;

  // Getters lookup from VideoMediaService static caches
  Map<String, String> get mediaSubtitles =>
      VideoMediaService.localizationCache[id]?.subtitles ?? const {};
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
  String get factCheckUrl =>
      VideoMediaService.credibilityCache[id]?.factCheckUrl ?? '';
  String get transcriptionUrl =>
      VideoMediaService.credibilityCache[id]?.transcriptionUrl ?? '';

  // Compatibility Getters
  int get likes => likeCount;
  int get views => viewCount;
  double get trustIndex => trustScore;
  Timestamp get uploadedAt => createdAt;
  String get videoUrl => originalUrl;
  String get channelImage => channelAvatarUrl;
  String get duration => _formatDuration(durationValue);
  List<ResolutionV2> get resolutions => [ResolutionV2(originalUrl)];
  bool get isScheduled => status == VideoStatus.scheduled;

  static String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${twoDigits(d.inHours)}:$minutes:$seconds";
    return "$minutes:$seconds";
  }

  Video({
    required this.id,
    required this.title,
    String? vTitleLowercase,
    required this.description,
    String? originalUrl,
    String? videoUrl,
    this.hlsUrl = '',
    this.dashUrl = '',
    this.adaptiveResolutions = const [],
    required this.thumbnailUrl,
    this.thumbnailVariants = const [],
    this.animatedPreviewUrl = '',
    required this.ownerId,
    required this.channelId,
    required this.channelName,
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
    required this.category,
    required this.tags,
    this.language = 'en',
    this.isShort = false,
    this.isKidFriendly = false,
    this.enableComments = true,
    this.isMonetized = false,
    this.allowRatings = false,
    this.trustScore = 0.0,
    this.videoRating = 0.0,
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
    String? effectiveCategory,
    UIReport? uiReport,
    // Ignored legacy fields
    dynamic shares,
    dynamic downloads,
    dynamic reportCount,
    dynamic reports,
    dynamic isBlocked,
    dynamic fileName,
    this.isSeen = false,
    this.totalWatchTimeSeconds = 0,
    this.trustLabel,
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
           vDurationValue ?? (duration is Duration ? duration : Duration.zero),
       createdAt = TimestampUtils.parse(createdAt ?? uploadedAt),
       updatedAt = TimestampUtils.parse(updatedAt ?? createdAt ?? uploadedAt),
       status = status is VideoStatus ? status : VideoStatus.processing,
       visibility = visibility?.toString() ?? 'public',
       likedBy = likedBy ?? [] {
    // Populate the VideoMediaService static caches for instant synchronous retrieval
    if (mediaSubtitles != null || dubbedVideos != null || audioTracks != null) {
      VideoMediaService.localizationCache[id] = VideoMediaLocalization(
        subtitles: mediaSubtitles ?? const {},
        dubbedVideos: dubbedVideos ?? const {},
        audioTracks: audioTracks ?? const {},
      );
    }
    if (scoringFactors != null ||
        deductions != null ||
        contextualFlags != null ||
        honestyBreakdown != null) {
      VideoMediaService.credibilityCache[id] = VideoMediaCredibility(
        trustScore: trustScore,
        videoRating: videoRating,
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
      'language': language,
      'isShort': isShort,
      'isKidFriendly': isKidFriendly,
      'enableComments': enableComments,
      'isMonetized': isMonetized,
      'allowRatings': allowRatings,
      'trustScore': trustScore,
      'videoRating': videoRating,
      'qualifiedViewCount': viewCount,
      'totalWatchTimeSeconds': totalWatchTimeSeconds,
      'likedBy': likedBy,
      'trustLabel': trustLabel,
    };
  }

  factory Video.fromMap(Map<String, dynamic> data, [String? docId]) {
    String finalId = docId ?? data['id'] ?? data['videoId'] ?? '';
    return Video(
      id: finalId,
      title: data['title'] ?? '',
      vTitleLowercase: data['titleLowercase'] ?? '',
      description: data['description'] ?? '',
      originalUrl: data['originalUrl'],
      videoUrl: data['videoUrl'],
      hlsUrl: data['hlsUrl'] ?? '',
      dashUrl: data['dashUrl'] ?? '',
      adaptiveResolutions: (data['adaptiveResolutions'] as List? ?? [])
          .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      thumbnailVariants: List<String>.from(data['thumbnailVariants'] ?? []),
      animatedPreviewUrl: data['animatedPreviewUrl'] ?? '',
      ownerId: data['ownerId'] ?? '',
      channelId: data['channelId'] ?? '',
      channelName: data['channelName'] ?? '',
      channelAvatarUrl: data['channelAvatarUrl'] ?? '',
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      dislikeCount: data['dislikeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      vDurationValue: Duration(milliseconds: data['durationMs'] ?? 0),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      status: VideoStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => VideoStatus.processing,
      ),
      visibility: data['visibility'] ?? 'public',
      category: data['category'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      language: data['language'] ?? 'en',
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
      factCheckUrl:
          data['media'] != null && data['media']['factCheckUrl'] != null
          ? (data['media']['factCheckUrl'] as String? ?? '')
          : (data['factCheckUrl'] as String? ?? ''),
      transcriptionUrl:
          data['media'] != null && data['media']['transcriptionUrl'] != null
          ? (data['media']['transcriptionUrl'] as String? ?? '')
          : (data['transcriptionUrl'] as String? ?? ''),
      allowRatings: data['allowRatings'] ?? false,
      trustScore: (data['trustScore'] ?? 0).toDouble(),
      videoRating: (data['videoRating'] ?? 0).toDouble(),
      chapters: (data['chapters'] as List? ?? [])
          .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totalWatchTimeSeconds: data['totalWatchTimeSeconds'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      // v8.0
      trustLabel: data['trustLabel'],
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
      effectiveCategory: data['effectiveCategory'],
      uiReport: data['uiReport'] != null
          ? UIReport.fromMap(Map<String, dynamic>.from(data['uiReport']))
          : null,
    );
  }

  factory Video.fromDocumentSnapshot(DocumentSnapshot doc) {
    return Video.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
}

class ResolutionV2 {
  final String path;
  ResolutionV2(this.path);
}

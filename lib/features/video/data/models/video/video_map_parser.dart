import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Pure parser converting raw Firestore/JSON maps into strongly-typed [Video] model instances.
class VideoMapParser {
  const VideoMapParser._();

  /// Parses a map of video attributes into a [Video] instance.
  static Video parse(Map<String, dynamic> data, [String? docId]) {
    final finalId = docId ?? data['id'] ?? data['videoId'] ?? '';

    String firstNonEmpty(List<dynamic> items) {
      for (final item in items) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return '';
    }

    final mediaMap = data['media'] is Map ? data['media'] as Map : null;
    final rawVideoUrl = firstNonEmpty([
      data['videoUrl'],
      data['originalUrl'],
      data['hlsUrl'],
      data['dashUrl'],
      data['url'],
      data['downloadUrl'],
      mediaMap?['videoUrl'],
      mediaMap?['originalUrl'],
      mediaMap?['hlsUrl'],
      mediaMap?['dashUrl'],
      mediaMap?['url'],
      mediaMap?['downloadUrl'],
    ]);

    // 1. Resolve adaptive resolutions with fallback
    var resolutionsList = (data['adaptiveResolutions'] as List? ?? [])
        .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    if (resolutionsList.isEmpty && rawVideoUrl.isNotEmpty) {
      resolutionsList = [
        VideoResolutionV2(
          label: '1080p',
          url: rawVideoUrl,
          width: 1920,
          height: 1080,
          bitrate: 4500000,
        ),
        VideoResolutionV2(
          label: '720p',
          url: rawVideoUrl,
          width: 1280,
          height: 720,
          bitrate: 2500000,
        ),
        VideoResolutionV2(
          label: '480p',
          url: rawVideoUrl,
          width: 854,
          height: 480,
          bitrate: 1200000,
        ),
        VideoResolutionV2(
          label: '360p',
          url: rawVideoUrl,
          width: 640,
          height: 360,
          bitrate: 800000,
        ),
        VideoResolutionV2(
          label: '240p',
          url: rawVideoUrl,
          width: 426,
          height: 240,
          bitrate: 400000,
        ),
        VideoResolutionV2(
          label: '144p',
          url: rawVideoUrl,
          width: 256,
          height: 144,
          bitrate: 200000,
        ),
      ];
    }

    // 2. Infer clean title if missing or untitled
    var parsedTitle = (data['title'] as String?) ?? '';
    if (parsedTitle.trim().isEmpty ||
        parsedTitle.toLowerCase().startsWith('untitled')) {
      final rawAutoChapters = data['autoChapters'];
      final chapters = rawAutoChapters is List ? rawAutoChapters : null;
      final summary = data['summary'] as String?;
      if (chapters != null &&
          chapters.isNotEmpty &&
          chapters[0] is Map &&
          chapters[0]['title'] != null) {
        parsedTitle = chapters[0]['title'].toString();
      } else if (summary != null && summary.trim().length > 5) {
        parsedTitle = summary.length > 60
            ? '${summary.substring(0, 57)}...'
            : summary;
      } else {
        parsedTitle = 'Truthworld Insight Video';
      }
    }

    // 3. Fallback FactCheck & Transcription URLs
    final parsedFactCheckUrl = (data['media'] != null &&
            data['media']['factCheckUrl'] != null &&
            (data['media']['factCheckUrl'] as String).isNotEmpty)
        ? (data['media']['factCheckUrl'] as String)
        : ((data['factCheckUrl'] as String?)?.isNotEmpty == true
            ? (data['factCheckUrl'] as String)
            : '');

    final parsedTranscriptUrl = (data['media'] != null &&
            data['media']['transcriptionUrl'] != null &&
            (data['media']['transcriptionUrl'] as String).isNotEmpty)
        ? (data['media']['transcriptionUrl'] as String)
        : ((data['transcriptionUrl'] as String?)?.isNotEmpty == true
            ? (data['transcriptionUrl'] as String)
            : '');

    final parsedThumbnailUrl = firstNonEmpty([
      data['thumbnailUrl'],
      data['thumbnail'],
      mediaMap?['thumbnailUrl'],
      mediaMap?['thumbnail'],
    ]);
    final thumbnailVariantsList =
        List<String>.from(data['thumbnailVariants'] ?? []);
    final animPreviewUrl =
        (data['animatedPreviewUrl'] as String?)?.trim() ?? '';
    var resolvedThumbnailUrl = parsedThumbnailUrl;
    if (resolvedThumbnailUrl.isEmpty && thumbnailVariantsList.isNotEmpty) {
      resolvedThumbnailUrl = thumbnailVariantsList.first;
    }
    if (resolvedThumbnailUrl.isEmpty && animPreviewUrl.isNotEmpty) {
      resolvedThumbnailUrl = animPreviewUrl;
    }

    final moderationMap =
        data['moderation'] is Map ? data['moderation'] as Map : null;
    final moderationStatus =
        moderationMap?['status']?.toString().toLowerCase();
    final policyAction =
        moderationMap?['policyAction']?.toString().toLowerCase();
    final isModApproved =
        moderationStatus == 'approved' || policyAction == 'allow';

    final parsedGeminiApproved = data['geminiApproved'] as bool? ??
        (moderationMap?['geminiApproved'] as bool?) ??
        (isModApproved ? true : null);
    final parsedIsApproved = data['isApproved'] as bool? ??
        (moderationMap?['isApproved'] as bool?) ??
        (isModApproved ? true : null) ??
        (data['gatewayStatus'] == 'APPROVED' ? true : null) ??
        (data['isVerified'] == true ? true : null) ??
        (data['credibilityVerified'] == true ? true : null);

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

    final aiFeatures =
        data['aiFeatures'] is Map ? data['aiFeatures'] as Map : null;
    final parsedAutoChaptersEnabled = (data['autoChaptersEnabled'] as bool?) ??
        (data['allowAutoChapters'] as bool?) ??
        (data['autoChapters'] is bool ? data['autoChapters'] as bool : null) ??
        (aiFeatures != null && aiFeatures['autoChapters'] is bool
            ? aiFeatures['autoChapters'] as bool
            : null) ??
        true;

    final resolvedChapters = VideoChapterParser.resolveChapters(
      explicitChapters: data['chapters'] as List?,
      description: (data['description'] as String?) ?? '',
      rawAutoChapters: data['autoChapters'],
      autoChaptersEnabled: parsedAutoChaptersEnabled,
    );

    final parsedHlsUrl = _cleanHlsUrl(
      data['hlsUrl'] ?? (data['media'] is Map ? data['media']['hlsUrl'] : null),
    );
    final parsedDashUrl = _cleanDashUrl(
      data['dashUrl'] ?? (data['media'] is Map ? data['media']['dashUrl'] : null),
    );

    final parsedStoryboardUrl = (data['storyboardUrl'] as String?)?.trim() ??
        (data['spriteUrl'] as String?)?.trim() ??
        (data['media'] is Map
            ? ((data['media']['storyboardUrl'] ?? data['media']['spriteUrl']) as String?)?.trim()
            : null) ??
        '';

    final parsedStoryboardVariants = data['storyboardVariants'] is List
        ? (data['storyboardVariants'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : (data['spriteVariants'] is List
            ? (data['spriteVariants'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
            : (data['media'] is Map && data['media']['storyboardVariants'] is List
                ? (data['media']['storyboardVariants'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
                : const <String>[]));

    return Video(
      id: finalId,
      title: parsedTitle,
      vTitleLowercase: data['titleLowercase'] ?? parsedTitle.toLowerCase(),
      description: data['description'] ?? '',
      moderationSummary: parsedModerationSummary,
      originalUrl: firstNonEmpty([data['originalUrl'], rawVideoUrl]),
      videoUrl: firstNonEmpty([data['videoUrl'], rawVideoUrl]),
      hlsUrl: parsedHlsUrl,
      dashUrl: parsedDashUrl,
      storyboardUrl: parsedStoryboardUrl,
      storyboardVariants: parsedStoryboardVariants,
      adaptiveResolutions: resolutionsList,
      thumbnailUrl: resolvedThumbnailUrl,
      thumbnailVariants: thumbnailVariantsList,
      animatedPreviewUrl: animPreviewUrl,
      geminiApproved: parsedGeminiApproved,
      isApproved: parsedIsApproved,
      ownerId: data['ownerId'] ?? '',
      channelId: (data['channelId'] as String?)?.trim().isNotEmpty == true
          ? data['channelId']
          : ((data['ownerId'] as String?)?.trim().isNotEmpty == true
              ? data['ownerId']
              : (data['userId'] ?? '')),
      channelName: data['channelName'] ??
          data['ownerName'] ??
          data['creatorName'] ??
          '',
      channelAvatarUrl: (data['channelImage'] as String?)?.trim().isNotEmpty == true
          ? (data['channelImage'] as String).trim()
          : (data['channelAvatarUrl'] as String?)?.trim().isNotEmpty == true
              ? (data['channelAvatarUrl'] as String).trim()
              : (data['avatarUrl'] as String?)?.trim().isNotEmpty == true
                  ? (data['avatarUrl'] as String).trim()
                  : (data['ownerAvatarUrl'] as String?)?.trim().isNotEmpty == true
                      ? (data['ownerAvatarUrl'] as String).trim()
                      : (data['creatorAvatarUrl'] as String?)?.trim().isNotEmpty == true
                          ? (data['creatorAvatarUrl'] as String).trim()
                          : (data['channelImageUrl'] as String?)?.trim().isNotEmpty == true
                              ? (data['channelImageUrl'] as String).trim()
                              : '',
      viewCount: (data['viewCount'] as num?)?.toInt() ??
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
        final targetStatus = (data['targetStatus'] as String?)?.toLowerCase();
        final pipelineStage = ((data['aiFeatures'] is Map
                    ? data['aiFeatures']['pipelineStage']
                    : null) ??
                data['pipelineStage'])
            ?.toString()
            .toLowerCase();
        final isAlreadyPublished = rawStatus == 'published' ||
            rawStatus == 'ready' ||
            rawStatus == 'active' ||
            targetStatus == 'published' ||
            targetStatus == 'ready' ||
            pipelineStage == 'published' ||
            data['isPublished'] == true ||
            (data['publishedAt'] != null && data['publishedAt'] != 0);

        if (rawStatus == 'deleted') return VideoStatus.deleted;
        if (rawStatus == 'rejected') return VideoStatus.rejected;
        if (rawStatus == 'private') return VideoStatus.private;
        if (rawStatus == 'scheduled') return VideoStatus.scheduled;
        if (rawStatus == 'flagged') return VideoStatus.flagged;

        if (isAlreadyPublished) {
          return VideoStatus.ready;
        }

        if (rawStatus == 'draft' || pipelineStage == 'draft') {
          return VideoStatus.draft;
        }
        if (rawStatus == 'uploaded' || rawStatus == 'uploading') {
          if (rawVideoUrl.isNotEmpty &&
              (targetStatus == 'published' ||
                  data['visibility']?.toString().toLowerCase() == 'public')) {
            return VideoStatus.ready;
          }
          return VideoStatus.uploading;
        }
        if (rawStatus == 'processing') {
          if (rawVideoUrl.isNotEmpty || resolutionsList.isNotEmpty) {
            return VideoStatus.ready;
          }
          return VideoStatus.processing;
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
      allowClipping: data['allowClipping'] as bool? ??
          data['allowClips'] as bool? ??
          true,
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
                  : (data['media'] != null && data['media']['dubbed'] != null
                      ? Map<String, String>.from(data['media']['dubbed'] as Map)
                      : (data['dubbed'] != null
                          ? Map<String, String>.from(data['dubbed'] as Map)
                          : const {}))),
      audioTracks:
          data['media'] != null && data['media']['audioTracks'] != null
              ? Map<String, String>.from(data['media']['audioTracks'] as Map)
              : (data['audioTracks'] != null
                  ? Map<String, String>.from(data['audioTracks'] as Map)
                  : (data['media'] != null && data['media']['audio'] != null
                      ? Map<String, String>.from(data['media']['audio'] as Map)
                      : (data['audio'] != null
                          ? Map<String, String>.from(data['audio'] as Map)
                          : const {}))),
      jobId: ((data['jobId'] ?? data['pipelineJobId']) ??
              (data['media'] is Map
                  ? (data['media']['jobId'] ?? data['media']['pipelineJobId'])
                  : null)) as String?,
      factCheckUrl: parsedFactCheckUrl,
      transcriptionUrl: parsedTranscriptUrl,
      allowRatings: data['allowRatings'] ?? false,
      showLikeCount: data['showLikeCount'] ??
          data['showLikesCount'] ??
          data['showLikes'] ??
          true,
      showDislikeCount: data['showDislikeCount'] ??
          data['showDislikesCount'] ??
          data['showDislikes'] ??
          true,
      autoChaptersEnabled: parsedAutoChaptersEnabled,
      trustScore: (data['trustScore'] ?? 0).toDouble(),
      sourceLinks: List<String>.from(data['sourceLinks'] ?? []),
      isFactChecked:
          (data['isFactChecked'] as bool?) ?? parsedFactCheckUrl.isNotEmpty,
      factCheckTier: (data['factCheckTier'] ??
              (data['aiFeatures'] is Map
                  ? data['aiFeatures']['factCheckTier']
                  : null) ??
              (data['media'] is Map ? data['media']['factCheckTier'] : null) ??
              'standard')
          .toString(),
      isVerified: data['isVerified'] ?? false,
      chapters: resolvedChapters,
      totalWatchTimeSeconds: (data['totalWatchTimeSeconds'] as num?)?.toInt() ??
          (data['metrics'] is Map
              ? (data['metrics']['totalWatchTimeSeconds'] as num?)?.toInt()
              : null) ??
          (data['stats'] is Map
              ? (data['stats']['totalWatchTimeSeconds'] as num?)?.toInt()
              : null) ??
          0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
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
      embedding: () {
        final raw = data['embedding'];
        if (raw == null) return null;
        if (raw is List) {
          return raw.map((e) => (e as num).toDouble()).toList();
        }
        if (raw is Map && raw['values'] is List) {
          return (raw['values'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
        }
        return null;
      }(),
    );
  }

  static String _cleanHlsUrl(dynamic raw) {
    if (raw is! String) return '';
    final url = raw.trim();
    if (url.isEmpty) return '';
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('/hls/') || lower.contains('/cmaf/')) {
      return url;
    }
    return '';
  }

  static String _cleanDashUrl(dynamic raw) {
    if (raw is! String) return '';
    final url = raw.trim();
    if (url.isEmpty) return '';
    final lower = url.toLowerCase();
    if (lower.contains('.mpd') || lower.contains('/dash/')) {
      return url;
    }
    return '';
  }
}

import 'dart:math' as math;

import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
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
      data['hlsMasterUrl'],
      data['hlsUrl'],
      data['dashUrl'],
      data['url'],
      data['downloadUrl'],
      mediaMap?['videoUrl'],
      mediaMap?['originalUrl'],
      mediaMap?['hlsMasterUrl'],
      mediaMap?['hlsUrl'],
      mediaMap?['dashUrl'],
      mediaMap?['url'],
      mediaMap?['downloadUrl'],
    ]);

    // 1. Resolve adaptive resolutions with fallback (guarantee complete ladder down to 144p)
    final rawResolutions = (data['adaptiveResolutions'] as List? ??
            (data['media'] is Map ? data['media']['adaptiveResolutions'] as List? : null) ??
            [])
        .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // Support legacy and direct resolutions map/list formats
    if (rawResolutions.isEmpty) {
      final legacyResolutions = data['resolutions'] ??
          (data['media'] is Map ? data['media']['resolutions'] : null);
      if (legacyResolutions is Map) {
        legacyResolutions.forEach((k, v) {
          if (k != null && v != null) {
            final label = k.toString();
            final url = v is Map ? (v['url']?.toString() ?? '') : v.toString();
            if (url.isNotEmpty) {
              final height = VideoResolutionV2.inferHeightFromLabel(label);
              rawResolutions.add(
                VideoResolutionV2(
                  label: label,
                  url: url,
                  width: (height * 16 / 9).round(),
                  height: height > 0 ? height : 1080,
                  bitrate: 0,
                  fps: VideoResolutionV2.inferFpsFromLabel(label),
                ),
              );
            }
          }
        });
      } else if (legacyResolutions is List) {
        for (final item in legacyResolutions) {
          if (item is Map) {
            rawResolutions.add(VideoResolutionV2.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    final resolutionsList = rawResolutions.isNotEmpty
        ? VideoResolutionV2.ensureCompleteLadder(
            rawResolutions,
            fallbackUrl: rawVideoUrl,
          )
        : const <VideoResolutionV2>[];

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
    final parsedFactCheckUrl =
        (data['media'] != null &&
            data['media']['factCheckUrl'] != null &&
            (data['media']['factCheckUrl'] as String).isNotEmpty)
        ? (data['media']['factCheckUrl'] as String)
        : ((data['factCheckUrl'] as String?)?.isNotEmpty == true
              ? (data['factCheckUrl'] as String)
              : '');

    final parsedTranscriptUrl =
        (data['media'] != null &&
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
    final thumbnailVariantsList = List<String>.from(
      data['thumbnailVariants'] ?? [],
    );
    final animPreviewUrl =
        (data['animatedPreviewUrl'] as String?)?.trim() ?? '';
    var resolvedThumbnailUrl = parsedThumbnailUrl;
    if (resolvedThumbnailUrl.isEmpty && thumbnailVariantsList.isNotEmpty) {
      resolvedThumbnailUrl = thumbnailVariantsList.first;
    }
    if (resolvedThumbnailUrl.isEmpty && animPreviewUrl.isNotEmpty) {
      resolvedThumbnailUrl = animPreviewUrl;
    }
    if (resolvedThumbnailUrl.isNotEmpty) {
      // Retain original authentic URL in thumbnailVariants as a resilient fallback
      if (!thumbnailVariantsList.contains(resolvedThumbnailUrl)) {
        thumbnailVariantsList.insert(0, resolvedThumbnailUrl);
      }
      resolvedThumbnailUrl = StorageUtils.getFastDownloadUrl(resolvedThumbnailUrl);
    }

    final moderationMap = data['moderation'] is Map
        ? data['moderation'] as Map
        : null;
    final moderationStatus = moderationMap?['status']?.toString().toLowerCase();
    final policyAction = moderationMap?['policyAction']
        ?.toString()
        .toLowerCase();
    final directModStatus = data['moderationStatus']?.toString().toLowerCase();
    final stagesMap = data['stages'] is Map ? data['stages'] as Map : null;
    final stageModStatus = (stagesMap?['moderation'] is Map
            ? stagesMap!['moderation']['status']
            : null)
        ?.toString()
        .toLowerCase();
    final rawStatusLower = (data['status'] as String?)?.toLowerCase() ?? '';
    final rawVisibilityLower = (data['visibility'] as String?)?.toLowerCase() ?? '';

    final isModRejected = moderationStatus == 'rejected' ||
        moderationStatus == 'failed' ||
        moderationStatus == 'blocked' ||
        policyAction == 'reject' ||
        policyAction == 'block' ||
        directModStatus == 'rejected' ||
        stageModStatus == 'failed' ||
        (data['rejectionReason'] != null &&
            data['rejectionReason'].toString().trim().isNotEmpty) ||
        data['rejected'] == true ||
        rawStatusLower == 'rejected' ||
        rawVisibilityLower == 'rejected';

    final isModApproved = !isModRejected &&
        (moderationStatus == 'approved' || policyAction == 'allow');

    final parsedGeminiApproved = isModRejected
        ? false
        : (data['geminiApproved'] as bool? ??
            (moderationMap?['geminiApproved'] as bool?) ??
            (isModApproved ? true : null));
    final parsedIsApproved = isModRejected
        ? false
        : (data['isApproved'] as bool? ??
            (moderationMap?['isApproved'] as bool?) ??
            (isModApproved ? true : null) ??
            (data['gatewayStatus'] == 'APPROVED' ? true : null) ??
            (data['isVerified'] == true ? true : null) ??
            (data['credibilityVerified'] == true ? true : null));

    final modMap = data['moderation'] is Map ? data['moderation'] as Map : null;
    final modSummary = (modMap?['summary'] as String?)?.trim() ?? '';
    final directModSummary = (data['moderationSummary'] as String?)?.trim() ?? '';
    final topLevelSummary = (data['summary'] as String?)?.trim() ?? '';

    final videoLang = (data['language'] as String?)?.trim() ??
        (modMap?['detectedLanguage'] as String?)?.trim();

    var parsedModerationSummary = '';
    if (UserFeedbackSanitizer.isValidVideoSummary(modSummary, targetLanguage: videoLang)) {
      parsedModerationSummary = modSummary;
    } else if (UserFeedbackSanitizer.isValidVideoSummary(directModSummary, targetLanguage: videoLang)) {
      parsedModerationSummary = directModSummary;
    } else if (UserFeedbackSanitizer.isValidVideoSummary(topLevelSummary, targetLanguage: videoLang)) {
      parsedModerationSummary = topLevelSummary;
    }

    final aiFeatures = data['aiFeatures'] is Map
        ? data['aiFeatures'] as Map
        : null;
    final parsedAutoChaptersEnabled =
        (data['autoChaptersEnabled'] as bool?) ??
        (data['allowAutoChapters'] as bool?) ??
        (data['autoChapters'] is bool ? data['autoChapters'] as bool : null) ??
        (aiFeatures != null && aiFeatures['autoChapters'] is bool
            ? aiFeatures['autoChapters'] as bool
            : null) ??
        true;

    final parsedDuration = () {
      if (data['durationMs'] is num && (data['durationMs'] as num) > 0) {
        return Duration(milliseconds: (data['durationMs'] as num).toInt());
      }
      if (data['durationSeconds'] is num &&
          (data['durationSeconds'] as num) > 0) {
        return Duration(seconds: (data['durationSeconds'] as num).toInt());
      }
      if (data['duration'] != null) {
        final parsed = VideoDurationUtils.parseDuration(data['duration']);
        if (parsed != Duration.zero) return parsed;
      }
      return Duration.zero;
    }();

    final resolvedChapters = VideoChapterParser.resolveChapters(
      explicitChapters: data['chapters'] as List?,
      description: (data['description'] as String?) ?? '',
      rawAutoChapters: data['autoChapters'],
      autoChaptersEnabled: parsedAutoChaptersEnabled,
      maxDuration: parsedDuration,
    );

    final parsedHlsUrl = _cleanHlsUrl(
      data['hlsMasterUrl'] ??
          data['hlsUrl'] ??
          (data['media'] is Map ? (data['media']['hlsMasterUrl'] ?? data['media']['hlsUrl']) : null),
    );
    final parsedDashUrl = _cleanDashUrl(
      data['dashUrl'] ??
          (data['media'] is Map ? data['media']['dashUrl'] : null),
    );

    final parsedStoryboardUrl =
        (data['storyboardUrl'] as String?)?.trim() ??
        (data['spriteUrl'] as String?)?.trim() ??
        (data['media'] is Map
            ? ((data['media']['storyboardUrl'] ?? data['media']['spriteUrl'])
                      as String?)
                  ?.trim()
            : null) ??
        '';

    final parsedStoryboardVariants = data['storyboardVariants'] is List
        ? (data['storyboardVariants'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : (data['spriteVariants'] is List
              ? (data['spriteVariants'] as List)
                    .map((e) => e.toString())
                    .where((e) => e.trim().isNotEmpty)
                    .toList()
              : (data['media'] is Map &&
                        data['media']['storyboardVariants'] is List
                    ? (data['media']['storyboardVariants'] as List)
                          .map((e) => e.toString())
                          .where((e) => e.trim().isNotEmpty)
                          .toList()
                    : const <String>[]));

    final rawViewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
    final rawViews = (data['views'] as num?)?.toInt() ?? 0;
    final rawStatsViews = (data['stats'] is Map
            ? (data['stats']['views'] as num?)?.toInt()
            : null) ??
        0;
    final resolvedViewCount =
        math.max(rawViewCount, math.max(rawViews, rawStatsViews));

    final rawWatchTime =
        (data['totalWatchTimeSeconds'] as num?)?.toInt() ??
        (data['metrics'] is Map
            ? (data['metrics']['totalWatchTimeSeconds'] as num?)?.toInt()
            : null) ??
        (data['stats'] is Map
            ? (data['stats']['totalWatchTimeSeconds'] as num?)?.toInt()
            : null) ??
        0;

    final resolvedWatchTime = () {
      final durSec = parsedDuration.inSeconds;
      if (durSec > 0 && rawWatchTime > 0) {
        // Epistemic ceiling: Total watch time can NEVER mathematically exceed Math.max(1, views) * durationSeconds
        final maxAllowed = math.max(1, resolvedViewCount) * durSec;
        return math.min(rawWatchTime, maxAllowed);
      }
      return rawWatchTime;
    }();

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
      channelName:
          data['channelName'] ?? data['ownerName'] ?? data['creatorName'] ?? '',
      channelAvatarUrl:
          (data['channelImage'] as String?)?.trim().isNotEmpty == true
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
      isChannelTrusted: (data['channelTrustedModerationBypass'] as bool?) ??
          (data['isChannelTrusted'] as bool?) ??
          (data['trustedModerationBypass'] as bool?) ??
          (data['bypassModeration'] as bool?) ??
          (data['trustedChannel'] as bool?) ??
          false,
      viewCount: resolvedViewCount,
      likeCount: data['likeCount'] ?? 0,
      dislikeCount: data['dislikeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      vDurationValue: parsedDuration,
      duration: VideoDurationUtils.formatDuration(parsedDuration),
      createdAt: data['createdAt'],
      uploadedAt: data['uploadedAt'] ?? data['publishedAt'],
      updatedAt: data['updatedAt'],
      status: () {
        final rawStatus = (data['status'] as String?)?.toLowerCase() ?? '';
        final targetStatus = (data['targetStatus'] as String?)?.toLowerCase();
        final pipelineStage =
            ((data['aiFeatures'] is Map
                        ? data['aiFeatures']['pipelineStage']
                        : null) ??
                    data['pipelineStage'])
                ?.toString()
                .toLowerCase();
        final isAlreadyPublished =
            rawStatus == 'published' ||
            rawStatus == 'ready' ||
            rawStatus == 'active' ||
            targetStatus == 'published' ||
            targetStatus == 'ready' ||
            pipelineStage == 'published' ||
            data['isPublished'] == true ||
            (data['publishedAt'] != null && data['publishedAt'] != 0);

        if (rawStatus == 'deleted' ||
            rawStatus == 'deletion_pending' ||
            rawStatus == 'trashed') {
          return VideoStatus.deleted;
        }
        if (isModRejected || rawStatus == 'rejected') return VideoStatus.rejected;
        if (moderationStatus == 'manual_review' ||
            moderationStatus == 'pending_review' ||
            rawStatus == 'pending_review' ||
            targetStatus == 'pending_review') {
          return VideoStatus.pending_review;
        }
        if (rawStatus == 'private') return VideoStatus.private;
        if (rawStatus == 'scheduled' || targetStatus == 'scheduled' || data['visibility']?.toString().toLowerCase() == 'scheduled') return VideoStatus.scheduled;
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
          orElse: () =>
              (rawStatus == 'uploaded' ||
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
      dubbingLanguages: List<String>.from(
        data['dubbingLanguages'] ??
            (data['aiFeatures'] is Map
                ? (data['aiFeatures']['dubbingLanguages'] ?? [])
                : []) ??
            [],
      ),
      isShort: data['isShort'] ?? false,
      isKidFriendly: data['isKidFriendly'] ?? false,
      enableComments: data['enableComments'] ?? true,
      allowClipping:
          data['allowClipping'] as bool? ?? data['allowClips'] as bool? ?? true,
      isMonetized: data['isMonetized'] ?? false,
      mediaSubtitles: () {
        final raw = data['media'] != null && data['media']['subtitles'] != null
            ? data['media']['subtitles']
            : (data['mediaSubtitles'] ?? data['subtitles']);
        final res = <String, String>{};
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k != null) {
              if (v is String && v.isNotEmpty) {
                res[k.toString()] = v;
              } else if (v is Map) {
                final url = v['url'] ?? v['srtPath'] ?? v['vttPath'] ?? v['subtitleUrl'];
                if (url != null && url.toString().isNotEmpty) {
                  res[k.toString()] = url.toString();
                }
              }
            }
          });
        }
        // Auto-inject original language subtitle if transcriptionUrl or artifacts exist
        final origLang = (data['language'] as String?)?.trim().isNotEmpty == true
            ? (data['language'] as String).trim()
            : 'en';
        final normOrig = normalizeLanguageCode(origLang);
        final hasOrig = res.keys.any((k) => normalizeLanguageCode(k) == normOrig);
        if (!hasOrig) {
          final candidateUrl = parsedTranscriptUrl.isNotEmpty
              ? parsedTranscriptUrl
              : (data['artifacts'] is Map && data['artifacts']['transcription'] is Map
                  ? ((data['artifacts']['transcription']['srtUrl'] ??
                      data['artifacts']['transcription']['vttUrl'] ??
                      data['artifacts']['transcription']['jsonUrl']) as String?) ?? ''
                  : '');
          if (candidateUrl.isNotEmpty) {
            res[origLang] = candidateUrl;
          }
        }
        return res;
      }(),
      dubbedVideos: () {
        final raw = data['media'] != null && data['media']['dubbedVideos'] != null
            ? data['media']['dubbedVideos']
            : (data['dubbedVideos'] ?? (data['media'] != null ? data['media']['dubbed'] : null) ?? data['dubbed']);
        if (raw is Map) {
          final res = <String, String>{};
          raw.forEach((k, v) {
            if (k != null) {
              if (v is String && v.isNotEmpty) {
                res[k.toString()] = v;
              } else if (v is Map) {
                final url = v['url'] ?? v['videoUrl'] ?? v['dubbedUrl'];
                if (url != null && url.toString().isNotEmpty) {
                  res[k.toString()] = url.toString();
                }
              }
            }
          });
          return res;
        }
        return const <String, String>{};
      }(),
      audioTracks: () {
        final res = <String, String>{};
        void extractFrom(dynamic raw) {
          if (raw is Map) {
            raw.forEach((k, v) {
              if (k != null) {
                if (v is String && v.isNotEmpty) {
                  res[k.toString()] = v;
                } else if (v is Map) {
                  final url = v['audioUrl'] ?? v['playlistUrl'] ?? v['url'];
                  if (url != null && url.toString().isNotEmpty) {
                    res[k.toString()] = url.toString();
                  }
                }
              }
            });
          }
        }

        extractFrom(data['media'] is Map ? data['media']['audioTracks'] : null);
        extractFrom(data['audioTracks']);
        extractFrom(data['media'] is Map ? data['media']['audio'] : null);
        extractFrom(data['audio']);

        data.forEach((key, val) {
          if (val is String && val.isNotEmpty) {
            if (key.startsWith('audioTracks.')) {
              final code = key.substring('audioTracks.'.length);
              if (code.isNotEmpty) res[code] = val;
            } else if (key.startsWith('media.audioTracks.')) {
              final code = key.substring('media.audioTracks.'.length);
              if (code.isNotEmpty) res[code] = val;
            }
          }
        });
        return res;
      }(),
      audioTrackSources: () {
        final res = <String, String>{};
        void extractFrom(dynamic raw) {
          if (raw is Map) {
            raw.forEach((k, v) {
              if (k != null && v is String && v.isNotEmpty) {
                res[k.toString()] = v;
              }
            });
          }
        }

        extractFrom(data['media'] is Map ? data['media']['audioTrackSources'] : null);
        extractFrom(data['audioTrackSources']);

        data.forEach((key, val) {
          if (val is String && val.isNotEmpty) {
            if (key.startsWith('audioTrackSources.')) {
              final code = key.substring('audioTrackSources.'.length);
              if (code.isNotEmpty) res[code] = val;
            } else if (key.startsWith('media.audioTrackSources.')) {
              final code = key.substring('media.audioTrackSources.'.length);
              if (code.isNotEmpty) res[code] = val;
            }
          }
        });
        return res;
      }(),
      aiDubbedAudio: () {
        final res = <String, String>{};
        final raw = data['aiDubbedAudio'];
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k != null && v is String && v.isNotEmpty) {
              res[k.toString()] = v;
            }
          });
        }
        return res;
      }(),
      jobId:
          ((data['jobId'] ?? data['pipelineJobId']) ??
                  (data['media'] is Map
                      ? (data['media']['jobId'] ??
                            data['media']['pipelineJobId'])
                      : null))
              as String?,
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
      autoChaptersEnabled: parsedAutoChaptersEnabled,
      sourceLinks: List<String>.from(data['sourceLinks'] ?? []),
      isFactChecked: (data['isFactChecked'] == true) ||
          (data['credibilityVerified'] == true) ||
          (data['hasFactChecking'] == true) ||
          (data['factChecking'] == true) ||
          (data['isFactChecking'] == true) ||
          (data['aiFeatures'] is Map &&
              (data['aiFeatures']['isFactChecked'] == true ||
                  data['aiFeatures']['factChecking'] == true ||
                  data['aiFeatures']['factCheck'] == true)) ||
          (data['factCheckStats'] is Map) ||
          (data['uiReport'] is Map) ||
          parsedFactCheckUrl.isNotEmpty,
      factCheckTier:
          (data['factCheckTier'] ??
                  (data['aiFeatures'] is Map
                      ? data['aiFeatures']['factCheckTier']
                      : null) ??
                  (data['media'] is Map
                      ? data['media']['factCheckTier']
                      : null) ??
                  'standard')
              .toString(),
      factCheckReviewMode: (data['factCheckReviewMode'] ??
              (data['aiFeatures'] is Map
                  ? data['aiFeatures']['factCheckReviewMode']
                  : null) ??
              (data['factCheckReviewFirst'] == true ? 'first_to_creator' : null) ??
              'open_to_users')
          .toString(),
      isFactCheckApproved: (data['isFactCheckApproved'] as bool?) ??
          (data['factCheckApproved'] as bool?) ??
          ((data['factCheckReviewMode'] ??
                  (data['aiFeatures'] is Map
                      ? data['aiFeatures']['factCheckReviewMode']
                      : null)) != 'first_to_creator'),
      factCheckCompletedAt: data['factCheckCompletedAt'],
      isVerified: data['isVerified'] ?? false,
      chapters: resolvedChapters,
      totalWatchTimeSeconds: resolvedWatchTime,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      trustLabel: data['trustLabel'],
      channelStatus: data['channelStatus'],
      scheduledPublishAt: TimestampUtils.parseToDateTime(
        data['scheduledPublishAt'] ?? data['scheduledTime'],
      ),
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
          : (data['claimLedgerSummary'] != null || data['claimLedger'] != null)
              ? UIReport.fromMap(Map<String, dynamic>.from(data))
              : null,
      coinBattlePairVideoId: data['coinBattlePairVideoId'] as String?,
      coinBattleStance: data['coinBattleStance'] as String?,
      resubmitCount: (data['resubmitCount'] as num?)?.toInt() ??
          (moderationMap?['resubmitCount'] as num?)?.toInt() ??
          0,
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
      isProvisional: data['isProvisional'] == true ||
          data['credibilityStatus'] == 'provisional_ready',
      provisionalScore: (data['provisionalScore'] is num)
          ? (data['provisionalScore'] as num).toDouble()
          : null,
      provisionalLabel: data['provisionalLabel']?.toString(),
      provisionalViewerNote: data['provisionalViewerNote']?.toString(),
      provisionalClaims: (data['provisionalClaims'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['provisionalClaims'] as List)
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from),
            )
          : const [],
      credibilityStatus: data['credibilityStatus']?.toString(),
      playbackReady: (data['media'] is Map && data['media']['playbackReady'] == true) ||
          data['playbackReady'] == true,
      transcodeFailed: (data['media'] is Map && data['media']['transcodeFailed'] == true) ||
          data['transcodeFailed'] == true,
      transcodeError: (data['media'] is Map ? data['media']['transcodeError'] as String? : null) ??
          data['transcodeError'] as String?,
      abrHlsUrl: (data['media'] is Map ? data['media']['abrHlsUrl'] as String? : null) ?? '',
      abrHlsHdUrl: (data['media'] is Map ? data['media']['abrHlsHdUrl'] as String? : null) ?? '',
    );
  }

  static String _cleanHlsUrl(dynamic raw) {
    if (raw is! String) return '';
    final url = raw.trim();
    if (url.isEmpty) return '';
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') ||
        lower.contains('/hls/') ||
        lower.contains('/cmaf/')) {
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

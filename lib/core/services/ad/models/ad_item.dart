import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdItem {
  const AdItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.advertiser,
    required this.imageUrl,
    required this.ctaText,
    required this.ctaTarget,
    required this.gradientColors,
    this.fallbackIcon,
    this.videoUrl,
    this.isSkippableAd = false,
    this.budgetTier,
    this.budgetAmount,
    this.spentAmount,
    this.adType = 'homepage',
    this.status = 'active',
    this.impressions = 0,
    this.clicks = 0,
    this.videoId,
    this.resolutions,
    this.subtitles,
    this.audioTracks,
    this.geminiApproved,
    this.moderationReason,
    this.midrollVideoUrl,
    this.pinnedCommentText,
    this.targetAgeGroups,
    this.targetGenders,
    this.targetLocations,
    this.targetLanguages,
    this.targetTopics,
  });

  factory AdItem.fromMap(Map<String, dynamic> map) {
    final colors = map['gradientColors'] as List<dynamic>?;
    final parsedColors = colors != null
        ? colors.map((val) => Color(val as int)).toList()
        : [AppColors.brand, AppColors.brandVariant];

    final isSkippable = map['isSkippableAd'] ?? false;
    final fallbackType = isSkippable ? 'skippable' : 'homepage';

    return AdItem(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      advertiser: map['advertiser'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      ctaText: map['ctaText'] ?? 'Learn More',
      ctaTarget: map['ctaTarget'] ?? '',
      gradientColors: parsedColors,
      videoUrl: map['videoUrl'] as String?,
      isSkippableAd: isSkippable,
      budgetTier: map['budgetTier'] as String?,
      budgetAmount: (map['budgetAmount'] as num?)?.toDouble(),
      spentAmount: (map['spentAmount'] as num?)?.toDouble(),
      adType: map['adType'] ?? fallbackType,
      status: map['status'] ?? 'active',
      impressions: (map['impressions'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
      videoId: map['videoId'] as String?,
      resolutions: (map['resolutions'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      subtitles: map['subtitles'] != null
          ? Map<String, String>.from(map['subtitles'] as Map)
          : null,
      audioTracks: map['audioTracks'] != null
          ? Map<String, String>.from(map['audioTracks'] as Map)
          : null,
      geminiApproved: map['geminiApproved'] as bool?,
      moderationReason: map['moderationReason'] as String?,
      midrollVideoUrl: map['midrollVideoUrl'] as String?,
      pinnedCommentText: map['pinnedCommentText'] as String?,
      targetAgeGroups: (map['targetAgeGroups'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      targetGenders: (map['targetGenders'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      targetLocations: (map['targetLocations'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      targetLanguages: (map['targetLanguages'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      targetTopics: (map['targetTopics'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
  final String id;
  final String userId;
  final String title;
  final String description;
  final String advertiser;
  final String imageUrl;
  final String ctaText;
  final String ctaTarget;
  final List<Color> gradientColors;
  final IconData? fallbackIcon;
  final String? videoUrl;
  final bool isSkippableAd;
  final String? budgetTier;
  final double? budgetAmount;
  final double? spentAmount;
  final String
  adType; // 'skippable', 'homepage', 'scroll', 'comment', 'video_sponsor'
  final String status; // 'active', 'paused'
  final int impressions;
  final int clicks;
  final String? videoId;
  final List<Map<String, dynamic>>? resolutions;
  final Map<String, String>? subtitles;
  final Map<String, String>? audioTracks;
  final bool? geminiApproved;
  final String? moderationReason;
  final String? midrollVideoUrl;
  final String? pinnedCommentText;
  final List<String>? targetAgeGroups;
  final List<String>? targetGenders;
  final List<String>? targetLocations;
  final List<String>? targetLanguages;
  final List<String>? targetTopics;

  String get sponsorBumperText =>
      'This video is brought to you by ${advertiser.isNotEmpty ? advertiser : "our sponsor"}';

  double get totalBudget => budgetAmount ?? 2000.0;

  double get spent {
    if (spentAmount != null) return spentAmount!;
    final calculated = (impressions * 0.15) + (clicks * 2.0);
    return calculated > totalBudget ? totalBudget : calculated;
  }

  double get remaining {
    final rem = totalBudget - spent;
    return rem > 0 ? rem : 0.0;
  }

  double get budgetProgress {
    if (totalBudget <= 0) return 0.0;
    return (spent / totalBudget).clamp(0.0, 1.0);
  }

  /// Whether this ad contains a video source
  bool get hasVideo {
    final v = videoUrl;
    if (v != null && v.trim().isNotEmpty && !v.trim().startsWith('blob:')) {
      return true;
    }
    final mid = midrollVideoUrl;
    if (mid != null && mid.trim().isNotEmpty && !mid.trim().startsWith('blob:')) {
      return true;
    }
    if (resolutions != null && resolutions!.isNotEmpty) {
      for (final res in resolutions!) {
        final u = res['url'] as String?;
        if (u != null && u.trim().isNotEmpty && !u.trim().startsWith('blob:')) {
          return true;
        }
      }
    }
    if (videoId != null && videoId!.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Returns the effective video stream URL from direct videoUrl, midrollVideoUrl,
  /// adaptive resolutions, or cached video data.
  String? get effectiveVideoUrl {
    final v = videoUrl;
    if (v != null && v.trim().isNotEmpty && !v.trim().startsWith('blob:')) {
      return v.trim();
    }
    final mid = midrollVideoUrl;
    if (mid != null && mid.trim().isNotEmpty && !mid.trim().startsWith('blob:')) {
      return mid.trim();
    }
    if (resolutions != null && resolutions!.isNotEmpty) {
      for (final res in resolutions!) {
        final u = res['url'] as String?;
        if (u != null && u.trim().isNotEmpty && !u.trim().startsWith('blob:')) {
          return u.trim();
        }
      }
    }
    if (videoId != null && videoId!.trim().isNotEmpty) {
      final cached = DeepLinkService.instance.getVideoFromCache(videoId!.trim());
      if (cached != null && cached.videoUrl.isNotEmpty) {
        return cached.videoUrl;
      }
    }
    return null;
  }

  /// Converts this AdItem into a playable Video model for VideoScreen playback
  Video toVideo() {
    final effectiveUrl = effectiveVideoUrl ?? '';
    final vidId = (videoId != null && videoId!.trim().isNotEmpty)
        ? videoId!.trim()
        : (id.trim().isNotEmpty ? id.trim() : 'ad_${DateTime.now().millisecondsSinceEpoch}');
    final targetTitle = title.trim().isNotEmpty ? title.trim() : 'Sponsored Video';
    final targetAdvertiser = advertiser.trim().isNotEmpty ? advertiser.trim() : 'Sponsored';
    final targetDescription = description.trim().isNotEmpty ? description.trim() : '';
    final targetThumbnail = imageUrl.trim().isNotEmpty ? imageUrl.trim() : '';

    final adaptiveRes = (resolutions != null && resolutions!.isNotEmpty)
        ? resolutions!
            .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : (effectiveUrl.isNotEmpty
            ? [
                VideoResolutionV2(
                  label: '1080p',
                  url: effectiveUrl,
                  width: 1920,
                  height: 1080,
                  bitrate: 4500000,
                ),
                VideoResolutionV2(
                  label: '720p',
                  url: effectiveUrl,
                  width: 1280,
                  height: 720,
                  bitrate: 2500000,
                ),
                VideoResolutionV2(
                  label: '480p',
                  url: effectiveUrl,
                  width: 854,
                  height: 480,
                  bitrate: 1200000,
                ),
              ]
            : <VideoResolutionV2>[]);

    final isImgValidUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return Video(
      id: vidId,
      title: targetTitle,
      description: targetDescription,
      thumbnailUrl: targetThumbnail,
      ownerId: userId.trim().isNotEmpty ? userId.trim() : 'advertiser',
      channelId: userId.trim().isNotEmpty ? userId.trim() : 'advertiser',
      channelName: targetAdvertiser,
      channelAvatarUrl: isImgValidUrl ? imageUrl : '',
      channelImage: isImgValidUrl ? imageUrl : '',
      category: 'Sponsored',
      tags: const ['ad', 'sponsored'],
      videoUrl: effectiveUrl,
      originalUrl: effectiveUrl,
      adaptiveResolutions: adaptiveRes,
      createdAt: Timestamp.now(),
      status: VideoStatus.ready,
      visibility: 'public',
      geminiApproved: true,
      isApproved: true,
    );
  }

  AdItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? advertiser,
    String? imageUrl,
    String? ctaText,
    String? ctaTarget,
    List<Color>? gradientColors,
    IconData? fallbackIcon,
    String? videoUrl,
    bool? isSkippableAd,
    String? budgetTier,
    double? budgetAmount,
    double? spentAmount,
    String? adType,
    String? status,
    int? impressions,
    int? clicks,
    String? videoId,
    List<Map<String, dynamic>>? resolutions,
    Map<String, String>? subtitles,
    Map<String, String>? audioTracks,
    bool? geminiApproved,
    String? moderationReason,
    String? midrollVideoUrl,
    String? pinnedCommentText,
    List<String>? targetAgeGroups,
    List<String>? targetGenders,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    List<String>? targetTopics,
  }) {
    return AdItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      advertiser: advertiser ?? this.advertiser,
      imageUrl: imageUrl ?? this.imageUrl,
      ctaText: ctaText ?? this.ctaText,
      ctaTarget: ctaTarget ?? this.ctaTarget,
      gradientColors: gradientColors ?? this.gradientColors,
      fallbackIcon: fallbackIcon ?? this.fallbackIcon,
      videoUrl: videoUrl ?? this.videoUrl,
      isSkippableAd: isSkippableAd ?? this.isSkippableAd,
      budgetTier: budgetTier ?? this.budgetTier,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      adType: adType ?? this.adType,
      status: status ?? this.status,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      videoId: videoId ?? this.videoId,
      resolutions: resolutions ?? this.resolutions,
      subtitles: subtitles ?? this.subtitles,
      audioTracks: audioTracks ?? this.audioTracks,
      geminiApproved: geminiApproved ?? this.geminiApproved,
      moderationReason: moderationReason ?? this.moderationReason,
      midrollVideoUrl: midrollVideoUrl ?? this.midrollVideoUrl,
      pinnedCommentText: pinnedCommentText ?? this.pinnedCommentText,
      targetAgeGroups: targetAgeGroups ?? this.targetAgeGroups,
      targetGenders: targetGenders ?? this.targetGenders,
      targetLocations: targetLocations ?? this.targetLocations,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      targetTopics: targetTopics ?? this.targetTopics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'advertiser': advertiser,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'ctaTarget': ctaTarget,
      'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
      'videoUrl': videoUrl,
      'isSkippableAd': isSkippableAd,
      'budgetTier': budgetTier,
      'budgetAmount': budgetAmount,
      'spentAmount': spentAmount,
      'adType': adType,
      'status': status,
      'impressions': impressions,
      'clicks': clicks,
      'videoId': videoId,
      'resolutions': resolutions,
      'subtitles': subtitles,
      'audioTracks': audioTracks,
      'geminiApproved': geminiApproved,
      'moderationReason': moderationReason,
      'midrollVideoUrl': midrollVideoUrl,
      'pinnedCommentText': pinnedCommentText,
      'targetAgeGroups': targetAgeGroups,
      'targetGenders': targetGenders,
      'targetLocations': targetLocations,
      'targetLanguages': targetLanguages,
      'targetTopics': targetTopics,
    };
  }
}

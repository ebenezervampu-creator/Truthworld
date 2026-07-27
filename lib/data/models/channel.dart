import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

enum ChannelStatus { active, suspended, underReview, deleted, verificationPending, verificationRejected }

enum MonetizationTier { none, eligible, basic, premium, pro }

class ChannelMetricsV2 {

  ChannelMetricsV2({
    this.totalViews = 0,
    this.totalWatchTimeMinutes = 0,
    this.averageRetention = 0.0,
  });

  factory ChannelMetricsV2.fromMap(Map<String, dynamic> map) =>
      ChannelMetricsV2(
        totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
        totalWatchTimeMinutes: (map['totalWatchTimeMinutes'] as num?)?.toInt() ?? 0,
        averageRetention: (map['averageRetention'] as num?)?.toDouble() ?? 0.0,
      );
  final int totalViews;
  final int totalWatchTimeMinutes;
  final double averageRetention;

  Map<String, dynamic> toMap() => {
    'totalViews': totalViews,
    'totalWatchTimeMinutes': totalWatchTimeMinutes,
    'averageRetention': averageRetention,
  };
}

class Channel {

  Channel({
    required this.id,
    required this.name,
    required this.nameLowercase,
    required this.handle,
    required this.handleLowercase,
    required this.description,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.ownerId, required this.createdAt, required this.updatedAt, this.avatarVariants = const [],
    this.avatarFileId,
    this.bannerFileId,
    this.avatarStatus,
    this.bannerStatus,
    this.subscriberCount = 0,
    this.videoCount = 0,
    ChannelMetricsV2? metrics,
    this.status = ChannelStatus.active,
    this.isVerified = false,
    this.category = 'other',
    this.categories = const [],
    this.language = 'en',
    this.monetizationTier = MonetizationTier.none,
    this.monetizationSettings,
    this.brandingSettings,
    this.socialLinks,
    this.featuredVideoIds = const [],
    this.moderationReason = '',
  }) : metrics = metrics ?? ChannelMetricsV2();

  factory Channel.fromMap(Map<String, dynamic> data, String docId) {
    return Channel(
      id: docId,
      name: data['name'] ?? '',
      nameLowercase: data['nameLowercase'] ?? '',
      handle: data['handle'] ?? '',
      handleLowercase: data['handleLowercase'] ?? '',
      description: data['description'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      avatarVariants: List<String>.from(data['avatarVariants'] ?? []),
      avatarFileId: data['avatarFileId'] as String?,
      bannerFileId: data['bannerFileId'] as String?,
      avatarStatus: data['avatarStatus'] as String?,
      bannerStatus: data['bannerStatus'] as String?,
      ownerId: data['ownerId'] ?? '',
      createdAt: TimestampUtils.parse(data['createdAt']),
      updatedAt: TimestampUtils.parse(data['updatedAt']),
      subscriberCount: (data['subscriberCount'] as num?)?.toInt() ?? 0,
      videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
      metrics: data['metrics'] != null
          ? ChannelMetricsV2.fromMap(Map<String, dynamic>.from(data['metrics']))
          : ChannelMetricsV2(),
      status: ChannelStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => ChannelStatus.active,
      ),
      isVerified: data['isVerified'] ?? false,
      category: data['category'] ?? 'other',
      categories: data['categories'] != null
          ? List<String>.from(data['categories'])
          : (data['category'] != null && (data['category'] as String).isNotEmpty
              ? (data['category'] as String)
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : ['other']),
      language: data['language'] ?? 'en',
      monetizationTier: MonetizationTier.values.firstWhere(
        (e) => e.name == (data['monetizationTier'] ?? 'none'),
        orElse: () => MonetizationTier.none,
      ),
      monetizationSettings: data['monetizationSettings'],
      brandingSettings: data['brandingSettings'],
      socialLinks: data['socialLinks'],
      featuredVideoIds: List<String>.from(data['featuredVideoIds'] ?? []),
      moderationReason: data['moderationReason'] as String?,
    );
  }

  factory Channel.fromDocumentSnapshot(DocumentSnapshot doc) {
    return Channel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
  }
  final String id;
  final String name;
  final String nameLowercase; // For search/name check efficiency
  final String handle; // e.g. @tower_vsp
  final String handleLowercase;
  final String description;

  // Media Assets
  final String avatarUrl;
  final String bannerUrl;
  final List<String> avatarVariants; // Small, HighRes
  final String? avatarFileId;
  final String? bannerFileId;
  final String? avatarStatus;
  final String? bannerStatus;

  // Ownership & Context
  final String ownerId;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  // Engagement (Atomic Counters)
  final int subscriberCount;
  final int videoCount;
  final ChannelMetricsV2 metrics;

  // Status & Settings
  final ChannelStatus status;
  final bool isVerified;
  final String category;
  final List<String> categories;
  final String language;
  final String? moderationReason;

  // Monetization
  final MonetizationTier monetizationTier;
  final Map<String, dynamic>? monetizationSettings;

  // Advanced Branding
  final Map<String, dynamic>?
  brandingSettings; // Primary/Secondary colors, Custom font
  final Map<String, dynamic>?
  socialLinks; // { "twitter": "url", "insta": "url" }

  // Optimization:
  // - Banned Users & Mods moved to subcollections or separate docs for millions of users.
  // - Top Video pinned items stored as IDs.
  final List<String> featuredVideoIds;

  // Compatibility Getters
  int get viewCount => metrics.totalViews;
  String get channelId => id;
  String get channelName => name;
  String get bannerImageUrl => bannerUrl;
  bool get isArchived => status == ChannelStatus.deleted;
  String get websiteUrl => socialLinks?['website'] ?? '';
  String get channelRoute {
    if (handle.isNotEmpty) {
      return handle.startsWith('@') ? '/$handle' : '/@$handle';
    }
    return '/channel/$id';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameLowercase': nameLowercase,
      'handle': handle,
      'handleLowercase': handleLowercase,
      'description': description,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'avatarVariants': avatarVariants,
      'avatarFileId': avatarFileId,
      'bannerFileId': bannerFileId,
      'avatarStatus': avatarStatus,
      'bannerStatus': bannerStatus,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'metrics': metrics.toMap(),
      'status': status.name,
      'isVerified': isVerified,
      'category': category,
      'categories': categories,
      'language': language,
      'monetizationTier': monetizationTier.name,
      'monetizationSettings': monetizationSettings,
      'brandingSettings': brandingSettings,
      'socialLinks': socialLinks,
      'featuredVideoIds': featuredVideoIds,
      'moderationReason': moderationReason,
    };
  }
}






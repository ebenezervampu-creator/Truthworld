import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

enum ChannelStatus {
  active,
  suspended,
  underReview,
  deleted,
  verificationPending,
  verificationRejected,
}

enum MonetizationTier { none, eligible, basic, premium, pro }

enum ChannelType { standard, custom }

enum LossPreventionMode { active, warning, autoScaled, suspended }

class CustomChannelInfraConfig {
  CustomChannelInfraConfig({
    required this.stripeConnectAccountId,
    required this.subscriptionId,
    this.storageUsedBytes = 0,
    this.storageQuotaBytes = 53687091200, // 50 GB
    this.bandwidthUsedBytesThisMonth = 0,
    this.bandwidthQuotaBytesThisMonth = 214748364800, // 200 GB
    this.currentMonthInfraCost = 0.0,
    this.flatPlatformFee = 15.0,
    this.trialCreditUSD = 10.0,
    this.trialCreditRemainingUSD = 10.0,
    this.planTier = 'starter_15',
    this.lossPreventionMode = LossPreventionMode.active,
  });

  factory CustomChannelInfraConfig.fromMap(Map<String, dynamic> map) {
    return CustomChannelInfraConfig(
      stripeConnectAccountId: map['stripeConnectAccountId'] as String? ?? '',
      subscriptionId: map['subscriptionId'] as String? ?? '',
      storageUsedBytes: (map['storageUsedBytes'] as num?)?.toInt() ?? 0,
      storageQuotaBytes:
          (map['storageQuotaBytes'] as num?)?.toInt() ?? 53687091200,
      bandwidthUsedBytesThisMonth:
          (map['bandwidthUsedBytesThisMonth'] as num?)?.toInt() ?? 0,
      bandwidthQuotaBytesThisMonth:
          (map['bandwidthQuotaBytesThisMonth'] as num?)?.toInt() ??
          214748364800,
      currentMonthInfraCost:
          (map['currentMonthInfraCost'] as num?)?.toDouble() ?? 0.0,
      flatPlatformFee: (map['flatPlatformFee'] as num?)?.toDouble() ?? 15.0,
      trialCreditUSD: (map['trialCreditUSD'] as num?)?.toDouble() ?? 10.0,
      trialCreditRemainingUSD:
          (map['trialCreditRemainingUSD'] as num?)?.toDouble() ?? 10.0,
      planTier: map['planTier'] as String? ?? 'starter_15',
      lossPreventionMode: LossPreventionMode.values.firstWhere(
        (e) => e.name == (map['lossPreventionMode'] ?? 'active'),
        orElse: () => LossPreventionMode.active,
      ),
    );
  }

  final String stripeConnectAccountId;
  final String subscriptionId;
  final int storageUsedBytes;
  final int storageQuotaBytes;
  final int bandwidthUsedBytesThisMonth;
  final int bandwidthQuotaBytesThisMonth;
  final double currentMonthInfraCost;
  final double flatPlatformFee;
  final double trialCreditUSD;
  final double trialCreditRemainingUSD;
  final String planTier;
  final LossPreventionMode lossPreventionMode;

  Map<String, dynamic> toMap() => {
    'stripeConnectAccountId': stripeConnectAccountId,
    'subscriptionId': subscriptionId,
    'storageUsedBytes': storageUsedBytes,
    'storageQuotaBytes': storageQuotaBytes,
    'bandwidthUsedBytesThisMonth': bandwidthUsedBytesThisMonth,
    'bandwidthQuotaBytesThisMonth': bandwidthQuotaBytesThisMonth,
    'currentMonthInfraCost': currentMonthInfraCost,
    'flatPlatformFee': flatPlatformFee,
    'trialCreditUSD': trialCreditUSD,
    'trialCreditRemainingUSD': trialCreditRemainingUSD,
    'planTier': planTier,
    'lossPreventionMode': lossPreventionMode.name,
  };
}

class ChannelMetricsV2 {
  ChannelMetricsV2({
    this.totalViews = 0,
    this.totalWatchTimeMinutes = 0,
    this.averageRetention = 0.0,
  });

  factory ChannelMetricsV2.fromMap(
    Map<String, dynamic> map, {
    int fallbackViews = 0,
    int fallbackWatchMinutes = 0,
  }) {
    final parsedViews = (map['totalViews'] as num?)?.toInt() ??
        (map['viewCount'] as num?)?.toInt() ??
        0;
    final parsedWatchMin = (map['totalWatchTimeMinutes'] as num?)?.toInt() ??
        ((map['totalWatchTimeSeconds'] as num?) != null
            ? (((map['totalWatchTimeSeconds'] as num).toDouble()) / 60.0).round()
            : 0);

    return ChannelMetricsV2(
      totalViews: parsedViews > 0 ? parsedViews : fallbackViews,
      totalWatchTimeMinutes:
          parsedWatchMin > 0 ? parsedWatchMin : fallbackWatchMinutes,
      averageRetention: (map['averageRetention'] as num?)?.toDouble() ?? 0.0,
    );
  }
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
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.avatarVariants = const [],
    this.avatarFileId,
    this.bannerFileId,
    this.avatarStatus,
    this.bannerStatus,
    this.avatarStatusReason,
    this.bannerStatusReason,
    this.subscriberCount = 0,
    this.videoCount = 0,
    ChannelMetricsV2? metrics,
    this.brandingApprovedDismissed = false,
    this.status = ChannelStatus.active,
    this.geminiApproved,
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
    this.channelType = ChannelType.standard,
    this.infraConfig,
    this.pendingChannelType,
    this.pendingTypeEffectiveDate,
    this.nextBillingCycleDate,
  }) : metrics = metrics ?? ChannelMetricsV2();

  factory Channel.fromMap(Map<String, dynamic> data, String docId) {
    var nameVal = (data['name'] as String?)?.trim() ?? (data['channelName'] as String?)?.trim() ?? '';
    if (nameVal.isEmpty || nameVal.toLowerCase().startsWith('untitled')) {
      nameVal = 'Truthworld Channel';
    }
    var handleVal = (data['handle'] as String?)?.trim() ?? '';
    if (handleVal.isEmpty) {
      handleVal = '@${nameVal.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    }

    final parsedGeminiApproved = data['geminiApproved'] as bool?;
    var statusVal = ChannelStatus.values.firstWhere(
      (e) => e.name == (data['status'] ?? 'active'),
      orElse: () => ChannelStatus.active,
    );
    if (parsedGeminiApproved == true) {
      statusVal = ChannelStatus.active;
    } else if (parsedGeminiApproved == false && (statusVal == ChannelStatus.underReview || statusVal == ChannelStatus.active)) {
      statusVal = ChannelStatus.verificationRejected;
    }

    final rootViews = (data['viewCount'] as num?)?.toInt() ?? (data['totalViews'] as num?)?.toInt() ?? 0;
    final rootWatchMinutes = (data['totalWatchTimeMinutes'] as num?)?.toInt() ??
        ((data['totalWatchTimeSeconds'] as num?) != null
            ? (((data['totalWatchTimeSeconds'] as num).toDouble()) / 60.0).round()
            : 0);

    return Channel(
      id: docId,
      name: nameVal,
      nameLowercase: data['nameLowercase'] ?? nameVal.toLowerCase(),
      handle: handleVal,
      handleLowercase: data['handleLowercase'] ?? handleVal.toLowerCase(),
      description: data['description'] ?? '',
      avatarUrl: data['avatarUrl'] ?? data['avatarImage'] ?? data['channelAvatarUrl'] ?? '',
      bannerUrl: data['bannerUrl'] ?? data['bannerImage'] ?? '',
      avatarVariants: List<String>.from(data['avatarVariants'] ?? []),
      avatarFileId: data['avatarFileId'] as String?,
      bannerFileId: data['bannerFileId'] as String?,
      avatarStatus: data['avatarStatus'] as String?,
      bannerStatus: data['bannerStatus'] as String?,
      avatarStatusReason: data['avatarStatusReason'] as String?,
      bannerStatusReason: data['bannerStatusReason'] as String?,
      ownerId: data['ownerId'] ?? data['userId'] ?? '',
      createdAt: TimestampUtils.parse(data['createdAt']),
      updatedAt: TimestampUtils.parse(data['updatedAt']),
      subscriberCount: (data['subscriberCount'] as num?)?.toInt() ?? (data['subscribers'] as num?)?.toInt() ?? 0,
      videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
      metrics: data['metrics'] != null
          ? ChannelMetricsV2.fromMap(
              Map<String, dynamic>.from(data['metrics']),
              fallbackViews: rootViews,
              fallbackWatchMinutes: rootWatchMinutes,
            )
          : ChannelMetricsV2(
              totalViews: rootViews,
              totalWatchTimeMinutes: rootWatchMinutes,
            ),
      brandingApprovedDismissed: data['brandingApprovedDismissed'] == true ||
          data['approvalBannerDismissed'] == true,
      status: statusVal,
      geminiApproved: parsedGeminiApproved,
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
      channelType: ChannelType.values.firstWhere(
        (e) => e.name == (data['channelType'] ?? 'standard'),
        orElse: () => ChannelType.standard,
      ),
      infraConfig: data['infraConfig'] != null
          ? CustomChannelInfraConfig.fromMap(
              Map<String, dynamic>.from(data['infraConfig']),
            )
          : null,
      pendingChannelType: data['pendingChannelType'] != null
          ? ChannelType.values.firstWhere(
              (e) => e.name == data['pendingChannelType'],
              orElse: () => ChannelType.standard,
            )
          : null,
      pendingTypeEffectiveDate: data['pendingTypeEffectiveDate'] != null
          ? TimestampUtils.parse(data['pendingTypeEffectiveDate'])
          : null,
      nextBillingCycleDate: data['nextBillingCycleDate'] != null
          ? TimestampUtils.parse(data['nextBillingCycleDate'])
          : null,
    );
  }

  factory Channel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null || data is! Map) {
      return Channel.fromMap(<String, dynamic>{}, doc.id);
    }
    return Channel.fromMap(Map<String, dynamic>.from(data), doc.id);
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
  final String? avatarStatusReason;
  final String? bannerStatusReason;

  // Ownership & Context
  final String ownerId;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  // Engagement (Atomic Counters)
  final int subscriberCount;
  final int videoCount;
  final ChannelMetricsV2 metrics;

  // Status & Settings
  final bool brandingApprovedDismissed;
  final ChannelStatus status;
  final bool? geminiApproved;
  final bool isVerified;
  final String category;
  final List<String> categories;
  final String language;
  final String? moderationReason;

  // Monetization & Infrastructure
  final MonetizationTier monetizationTier;
  final Map<String, dynamic>? monetizationSettings;
  final ChannelType channelType;
  final CustomChannelInfraConfig? infraConfig;

  // Billing Cycle Lock & Scheduled Tier Switch
  final ChannelType? pendingChannelType;
  final Timestamp? pendingTypeEffectiveDate;
  final Timestamp? nextBillingCycleDate;

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

  // Standard Channel Constraints (20 min daily upload limit, up to 20 min duration per day)
  int get maxAllowedVideos => 999999;
  int get minVideoDurationSeconds => 0;
  int get maxDailyVideoDurationSeconds =>
      channelType == ChannelType.standard ? 1200 : 86400; // 20 minutes (1200s) per day
  int get maxVideoDurationSeconds =>
      channelType == ChannelType.standard ? 1200 : 86400; // 20 minutes (1200s) max per video
  int get maxTotalVideoDurationSeconds =>
      channelType == ChannelType.standard ? 1200 : 8640000; // 20 minutes daily total (1200s)

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
      'avatarStatusReason': avatarStatusReason,
      'bannerStatusReason': bannerStatusReason,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'metrics': metrics.toMap(),
      'brandingApprovedDismissed': brandingApprovedDismissed,
      'status': status.name,
      'geminiApproved': geminiApproved,
      'isVerified': isVerified,
      'category': category,
      'categories': categories,
      'language': language,
      'monetizationTier': monetizationTier.name,
      'monetizationSettings': monetizationSettings,
      'channelType': channelType.name,
      'infraConfig': infraConfig?.toMap(),
      'pendingChannelType': pendingChannelType?.name,
      'pendingTypeEffectiveDate': pendingTypeEffectiveDate,
      'nextBillingCycleDate': nextBillingCycleDate,
      'brandingSettings': brandingSettings,
      'socialLinks': socialLinks,
      'featuredVideoIds': featuredVideoIds,
      'moderationReason': moderationReason,
    };
  }
}

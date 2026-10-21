import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/features/video/data/models/video.dart';


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
    required this.subscriptionId,
    this.stripeConnectAccountId = '',
    this.storageUsedBytes = 0,
    this.storageQuotaBytes = 53687091200, // 50 GB
    this.bandwidthUsedBytesThisMonth = 0,
    this.bandwidthQuotaBytesThisMonth = 214748364800, // 200 GB
    this.currentMonthInfraCost = 0.0,
    this.flatPlatformFee = 15.0,
    this.trialCreditUSD = 0.0,
    this.trialCreditRemainingUSD = 0.0,
    this.rolloverCreditUSD = 0.0,
    this.planTier = 'starter_15',
    this.lossPreventionMode = LossPreventionMode.active,
    this.autoPay = true,
    this.isWithdrawalHeld = false,
    this.withdrawalHoldReason = '',
  });

  factory CustomChannelInfraConfig.fromMap(Map<String, dynamic> map) {
    // Promotional trial credits discontinued to prevent farming and bot abuse.
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
      rolloverCreditUSD:
          (map['rolloverCreditUSD'] as num?)?.toDouble() ?? 0.0,
      planTier: map['planTier'] as String? ?? 'starter_15',
      lossPreventionMode: LossPreventionMode.values.firstWhere(
        (e) => e.name == (map['lossPreventionMode'] ?? 'active'),
        orElse: () => LossPreventionMode.active,
      ),
      autoPay: (map['autoPay'] as bool?) ?? (map['isAutoPay'] as bool?) ?? true,
      isWithdrawalHeld: (map['isWithdrawalHeld'] as bool?) ?? false,
      withdrawalHoldReason: (map['withdrawalHoldReason'] as String?) ?? '',
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
  final double rolloverCreditUSD;
  final String planTier;
  final LossPreventionMode lossPreventionMode;
  final bool autoPay;
  final bool isWithdrawalHeld;
  final String withdrawalHoldReason;

  /// Unspent plan amount from the current cycle guaranteed never to be lost
  double get unspentCurrentMonthPlanBalance =>
      (flatPlatformFee - currentMonthInfraCost).clamp(0.0, flatPlatformFee);

  /// Total protected balance that will roll over or remain usable down to the exact cent
  double get totalProtectedBalance => rolloverCreditUSD + unspentCurrentMonthPlanBalance;

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
    'rolloverCreditUSD': rolloverCreditUSD,
    'planTier': planTier,
    'lossPreventionMode': lossPreventionMode.name,
    'autoPay': autoPay,
    'isWithdrawalHeld': isWithdrawalHeld,
    'withdrawalHoldReason': withdrawalHoldReason,
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

  ChannelMetricsV2 copyWith({
    int? totalViews,
    int? totalWatchTimeMinutes,
    double? averageRetention,
  }) {
    return ChannelMetricsV2(
      totalViews: totalViews ?? this.totalViews,
      totalWatchTimeMinutes:
          totalWatchTimeMinutes ?? this.totalWatchTimeMinutes,
      averageRetention: averageRetention ?? this.averageRetention,
    );
  }
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
    this.visibility = 'Public',
    this.showLikeCount = true,
    this.showDislikeCount = true,
    this.showSubscriberCount = true,
    this.allowComments = true,
    this.monetizationTier = MonetizationTier.none,
    this.monetizationSettings,
    this.brandingSettings,
    this.socialLinks,
    this.customLinks = const [],
    this.featuredVideoIds = const [],
    this.moderationReason = '',
    this.channelType = ChannelType.standard,
    this.infraConfig,
    this.pendingChannelType,
    this.pendingTypeEffectiveDate,
    this.nextBillingCycleDate,
    this.walletBalanceUSD = 0.0,
    this.adsRevenueTotal = 0.0,
    this.premiumSubsRevenueTotal = 0.0,
    this.membershipRevenueTotal = 0.0,
    this.superchatRevenueTotal = 0.0,
    this.withdrawnRevenueTotal = 0.0,
    this.clearedWithdrawableRevenueTotal,
    this.pendingRevenueTotal,
    this.autoPayoutEnabled = true,
    this.noAdsForMembers = false,
    this.country = 'IN',
    this.hasMemberships = false,
    this.deletionScheduledAt,
    this.deletionGracePeriodExpiresAt,
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
      (e) => e.name.toLowerCase() == (data['status']?.toString() ?? 'active').toLowerCase(),
      orElse: () => ChannelStatus.active,
    );
    if (parsedGeminiApproved == true) {
      statusVal = ChannelStatus.active;
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
      avatarUrl: () {
        final candidates = [
          data['avatarUrl'],
          data['avatarImage'],
          data['channelAvatarUrl'],
          data['channelImage'],
          data['photoUrl'],
          data['photoURL'],
          data['profileImageUrl'],
          data['avatar'],
          data['imageUrl'],
        ];
        for (final item in candidates) {
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
        }
        return '';
      }(),
      bannerUrl: () {
        final candidates = [
          data['bannerUrl'],
          data['bannerImageUrl'],
          data['bannerImage'],
          data['banner'],
          data['bannerPicUrl'],
          data['coverUrl'],
          data['headerUrl'],
        ];
        for (final item in candidates) {
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
        }
        return '';
      }(),
      avatarVariants: data['avatarVariants'] is Iterable
          ? List<String>.from(data['avatarVariants'] as Iterable)
          : const [],
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
      metrics: data['metrics'] is Map
          ? ChannelMetricsV2.fromMap(
              Map<String, dynamic>.from(data['metrics'] as Map),
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
      visibility: data['visibility'] as String? ??
          (data['isPublic'] == false ? 'Private' : 'Public'),
      showLikeCount: (data['showLikeCount'] as bool?) ?? true,
      showDislikeCount: (data['showDislikeCount'] as bool?) ?? true,
      showSubscriberCount: (data['showSubscriberCount'] as bool?) ?? true,
      allowComments: (data['allowComments'] as bool?) ?? true,
      monetizationTier: MonetizationTier.values.firstWhere(
        (e) => e.name == (data['monetizationTier'] ?? 'none'),
        orElse: () => MonetizationTier.none,
      ),
      monetizationSettings: data['monetizationSettings'] is Map
          ? Map<String, dynamic>.from(data['monetizationSettings'] as Map)
          : null,
      brandingSettings: data['brandingSettings'] is Map
          ? Map<String, dynamic>.from(data['brandingSettings'] as Map)
          : null,
      socialLinks: data['socialLinks'] is Map
          ? Map<String, dynamic>.from(data['socialLinks'] as Map)
          : null,
      customLinks: data['customLinks'] is Iterable
          ? (data['customLinks'] as Iterable)
              .whereType<Map>()
              .map((m) => {
                    'title': (m['title'] ?? '').toString(),
                    'url': (m['url'] ?? '').toString(),
                  })
              .where((e) => (e['url'] ?? '').trim().isNotEmpty)
              .toList()
          : (data['socialLinks'] is Map && data['socialLinks']['customLinks'] is Iterable
              ? (data['socialLinks']['customLinks'] as Iterable)
                  .whereType<Map>()
                  .map((m) => {
                        'title': (m['title'] ?? '').toString(),
                        'url': (m['url'] ?? '').toString(),
                      })
                  .where((e) => (e['url'] ?? '').trim().isNotEmpty)
                  .toList()
              : const []),
      featuredVideoIds: data['featuredVideoIds'] is Iterable
          ? List<String>.from(data['featuredVideoIds'] as Iterable)
          : const [],
      moderationReason: data['moderationReason'] as String?,
      channelType: ChannelType.values.firstWhere(
        (e) => e.name == (data['channelType'] ?? 'standard'),
        orElse: () => ChannelType.standard,
      ),
      infraConfig: data['infraConfig'] is Map
          ? CustomChannelInfraConfig.fromMap(
              Map<String, dynamic>.from(data['infraConfig'] as Map),
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
      walletBalanceUSD: (data['walletBalanceUSD'] as num?)?.toDouble() ??
          (data['walletBalance'] as num?)?.toDouble() ??
          0.0,
      adsRevenueTotal: (data['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0,
      premiumSubsRevenueTotal:
          (data['premiumSubsRevenueTotal'] as num?)?.toDouble() ?? 0.0,
      membershipRevenueTotal: ((data['membershipRevenueTotal'] ??
              data['membershipsRevenueTotal']) as num?)
          ?.toDouble() ??
          0.0,
      superchatRevenueTotal:
          (data['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0,
      withdrawnRevenueTotal:
          (data['withdrawnRevenueTotal'] as num?)?.toDouble() ?? 0.0,
      clearedWithdrawableRevenueTotal:
          (data['clearedWithdrawableRevenueTotal'] as num?)?.toDouble(),
      pendingRevenueTotal: (data['pendingRevenueTotal'] as num?)?.toDouble(),
      autoPayoutEnabled: (data['autoPayoutEnabled'] as bool?) ?? true,
      noAdsForMembers: (data['noAdsForMembers'] as bool?) ??
          (data['monetizationSettings'] is Map
              ? ((data['monetizationSettings']['noAdsForMembers'] as bool?) ??
                  (data['monetizationSettings']['memberAdFreeEnabled'] as bool?))
              : null) ??
          false,
      country: (data['country'] as String?)?.trim().isNotEmpty == true
          ? (data['country'] as String).trim()
          : 'IN',
      hasMemberships: (data['hasMemberships'] as bool?) ?? false,
      deletionScheduledAt: data['deletionScheduledAt'] != null
          ? TimestampUtils.parse(data['deletionScheduledAt'])
          : null,
      deletionGracePeriodExpiresAt: data['deletionGracePeriodExpiresAt'] != null
          ? TimestampUtils.parse(data['deletionGracePeriodExpiresAt'])
          : null,
    );
  }

  factory Channel.fromDocumentSnapshot(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null || data is! Map) {
        return Channel.fromMap(<String, dynamic>{}, doc.id);
      }
      return Channel.fromMap(Map<String, dynamic>.from(data), doc.id);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'Channel.fromDocumentSnapshot',
      );
      return Channel.fromMap(<String, dynamic>{}, doc.id);
    }
  }

  /// Optimistically constructs a channel from an already-hydrated [Video] entity for 0ms low-latency rendering.
  factory Channel.fromVideo(Video video) {
    final effectiveId = video.channelId.trim().isNotEmpty
        ? video.channelId.trim()
        : (video.ownerId.trim().isNotEmpty ? video.ownerId.trim() : 'channel_pending');
    final nameVal = video.channelName.trim().isNotEmpty
        ? video.channelName.trim()
        : 'Truthworld Channel';
    final handleVal = '@${nameVal.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    final avatar = video.channelAvatarUrl.trim().isNotEmpty
        ? video.channelAvatarUrl.trim()
        : (video.channelImage.trim().isNotEmpty ? video.channelImage.trim() : '');
    return Channel(
      id: effectiveId,
      name: nameVal,
      nameLowercase: nameVal.toLowerCase(),
      handle: handleVal,
      handleLowercase: handleVal.toLowerCase(),
      description: '',
      avatarUrl: avatar,
      bannerUrl: '',
      ownerId: video.ownerId,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isVerified: video.isVerified,
    );
  }

  Channel copyWith({
    String? id,
    String? name,
    String? nameLowercase,
    String? handle,
    String? handleLowercase,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    List<String>? avatarVariants,
    String? avatarFileId,
    String? bannerFileId,
    String? avatarStatus,
    String? bannerStatus,
    String? avatarStatusReason,
    String? bannerStatusReason,
    int? subscriberCount,
    int? videoCount,
    ChannelMetricsV2? metrics,
    bool? brandingApprovedDismissed,
    ChannelStatus? status,
    bool? geminiApproved,
    bool? isVerified,
    String? category,
    List<String>? categories,
    String? language,
    String? visibility,
    bool? showLikeCount,
    bool? showDislikeCount,
    bool? showSubscriberCount,
    bool? allowComments,
    MonetizationTier? monetizationTier,
    dynamic monetizationSettings,
    dynamic brandingSettings,
    Map<String, dynamic>? socialLinks,
    List<Map<String, String>>? customLinks,
    List<String>? featuredVideoIds,
    String? moderationReason,
    ChannelType? channelType,
    CustomChannelInfraConfig? infraConfig,
    ChannelType? pendingChannelType,
    Timestamp? pendingTypeEffectiveDate,
    Timestamp? nextBillingCycleDate,
    double? walletBalanceUSD,
    double? adsRevenueTotal,
    double? premiumSubsRevenueTotal,
    double? membershipRevenueTotal,
    double? superchatRevenueTotal,
    double? withdrawnRevenueTotal,
    double? clearedWithdrawableRevenueTotal,
    double? pendingRevenueTotal,
    bool? autoPayoutEnabled,
    bool? noAdsForMembers,
    String? ownerId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? country,
    bool? hasMemberships,
    Timestamp? deletionScheduledAt,
    Timestamp? deletionGracePeriodExpiresAt,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLowercase: nameLowercase ?? (name != null ? name.toLowerCase() : this.nameLowercase),
      handle: handle ?? this.handle,
      handleLowercase: handleLowercase ?? (handle != null ? handle.toLowerCase() : this.handleLowercase),
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      avatarVariants: avatarVariants ?? this.avatarVariants,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      bannerFileId: bannerFileId ?? this.bannerFileId,
      avatarStatus: avatarStatus ?? this.avatarStatus,
      bannerStatus: bannerStatus ?? this.bannerStatus,
      avatarStatusReason: avatarStatusReason ?? this.avatarStatusReason,
      bannerStatusReason: bannerStatusReason ?? this.bannerStatusReason,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      videoCount: videoCount ?? this.videoCount,
      metrics: metrics ?? this.metrics,
      brandingApprovedDismissed: brandingApprovedDismissed ?? this.brandingApprovedDismissed,
      status: status ?? this.status,
      geminiApproved: geminiApproved ?? this.geminiApproved,
      isVerified: isVerified ?? this.isVerified,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      language: language ?? this.language,
      visibility: visibility ?? this.visibility,
      showLikeCount: showLikeCount ?? this.showLikeCount,
      showDislikeCount: showDislikeCount ?? this.showDislikeCount,
      showSubscriberCount: showSubscriberCount ?? this.showSubscriberCount,
      allowComments: allowComments ?? this.allowComments,
      monetizationTier: monetizationTier ?? this.monetizationTier,
      monetizationSettings: monetizationSettings ?? this.monetizationSettings,
      brandingSettings: brandingSettings ?? this.brandingSettings,
      socialLinks: socialLinks ?? this.socialLinks,
      customLinks: customLinks ?? this.customLinks,
      featuredVideoIds: featuredVideoIds ?? this.featuredVideoIds,
      moderationReason: moderationReason ?? this.moderationReason,
      channelType: channelType ?? this.channelType,
      infraConfig: infraConfig ?? this.infraConfig,
      pendingChannelType: pendingChannelType ?? this.pendingChannelType,
      pendingTypeEffectiveDate: pendingTypeEffectiveDate ?? this.pendingTypeEffectiveDate,
      nextBillingCycleDate: nextBillingCycleDate ?? this.nextBillingCycleDate,
      walletBalanceUSD: walletBalanceUSD ?? this.walletBalanceUSD,
      adsRevenueTotal: adsRevenueTotal ?? this.adsRevenueTotal,
      premiumSubsRevenueTotal:
          premiumSubsRevenueTotal ?? this.premiumSubsRevenueTotal,
      membershipRevenueTotal:
          membershipRevenueTotal ?? this.membershipRevenueTotal,
      superchatRevenueTotal:
          superchatRevenueTotal ?? this.superchatRevenueTotal,
      withdrawnRevenueTotal:
          withdrawnRevenueTotal ?? this.withdrawnRevenueTotal,
      clearedWithdrawableRevenueTotal:
          clearedWithdrawableRevenueTotal ?? this.clearedWithdrawableRevenueTotal,
      pendingRevenueTotal: pendingRevenueTotal ?? this.pendingRevenueTotal,
      autoPayoutEnabled: autoPayoutEnabled ?? this.autoPayoutEnabled,
      noAdsForMembers: noAdsForMembers ?? this.noAdsForMembers,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      country: country ?? this.country,
      hasMemberships: hasMemberships ?? this.hasMemberships,
      deletionScheduledAt: deletionScheduledAt ?? this.deletionScheduledAt,
      deletionGracePeriodExpiresAt:
          deletionGracePeriodExpiresAt ?? this.deletionGracePeriodExpiresAt,
    );
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
  final String visibility;
  final bool showLikeCount;
  final bool showDislikeCount;
  final bool showSubscriberCount;
  final bool allowComments;
  final String country;
  final bool hasMemberships;
  final String? moderationReason;
  final Timestamp? deletionScheduledAt;
  final Timestamp? deletionGracePeriodExpiresAt;

  // Monetization & Infrastructure
  final MonetizationTier monetizationTier;
  final Map<String, dynamic>? monetizationSettings;
  final ChannelType channelType;
  final CustomChannelInfraConfig? infraConfig;
  final double walletBalanceUSD;
  final double adsRevenueTotal;
  final double premiumSubsRevenueTotal;
  final double membershipRevenueTotal;
  final double superchatRevenueTotal;
  final double withdrawnRevenueTotal;
  final double? clearedWithdrawableRevenueTotal;
  final double? pendingRevenueTotal;
  final bool autoPayoutEnabled;
  final bool noAdsForMembers;

  /// Computed cleared withdrawable balance in INR (defaults to lifetime total if not yet populated)
  double get clearedBalanceINR =>
      clearedWithdrawableRevenueTotal ??
      (adsRevenueTotal +
          premiumSubsRevenueTotal +
          membershipRevenueTotal +
          superchatRevenueTotal);

  /// Computed pending in-flight revenue in INR
  double get pendingBalanceINR => pendingRevenueTotal ?? 0.0;

  /// Total estimated lifetime earnings in INR
  double get totalEstimatedRevenueINR =>
      adsRevenueTotal +
      premiumSubsRevenueTotal +
      membershipRevenueTotal +
      superchatRevenueTotal;

  /// Available withdrawable cash balance after deducting prior withdrawals
  double get availableWithdrawableINR =>
      (clearedBalanceINR - withdrawnRevenueTotal).clamp(0.0, double.infinity);

  // Billing Cycle Lock & Scheduled Tier Switch
  final ChannelType? pendingChannelType;
  final Timestamp? pendingTypeEffectiveDate;
  final Timestamp? nextBillingCycleDate;

  // Advanced Branding
  final Map<String, dynamic>?
  brandingSettings; // Primary/Secondary colors, Custom font
  final Map<String, dynamic>?
  socialLinks; // { "twitter": "url", "insta": "url" }
  final List<Map<String, dynamic>> customLinks;

  // Optimization:
  // - Banned Users & Mods moved to subcollections or separate docs for millions of users.
  // - Top Video pinned items stored as IDs.
  final List<String> featuredVideoIds;

  // Compatibility Getters
  int get viewCount => metrics.totalViews;
  String get channelId => id;
  String get channelName => name;
  String get userId => ownerId;
  String get bannerImageUrl => bannerUrl;
  bool get isArchived => status == ChannelStatus.deleted;
  bool get isDeleted => status == ChannelStatus.deleted;
  bool get isPendingDeletion =>
      status == ChannelStatus.deleted && !isPermanentDeletionExpired;

  bool get isPermanentDeletionExpired {
    if (status != ChannelStatus.deleted) return false;
    final expiry = scheduledPermanentDeletionDate;
    return DateTime.now().isAfter(expiry);
  }

  int get gracePeriodDaysRemaining {
    if (status != ChannelStatus.deleted) return 0;
    final expiry = scheduledPermanentDeletionDate;
    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining.clamp(0, 30);
  }

  DateTime get scheduledPermanentDeletionDate {
    if (deletionGracePeriodExpiresAt != null) {
      return deletionGracePeriodExpiresAt!.toDate();
    }
    if (deletionScheduledAt != null) {
      return deletionScheduledAt!.toDate().add(const Duration(days: 30));
    }
    return updatedAt.toDate().add(const Duration(days: 30));
  }
  bool get isMembersOnly => visibility.toLowerCase() == 'members' || visibility.toLowerCase() == 'members only';
  String get websiteUrl => socialLinks?['website'] ?? '';
  String get countryCode => CashfreeCountrySupport.normalizeCode(country);
  String get currency => CashfreeCountrySupport.getCurrencyForCountry(country);
  String get currencySymbol => CashfreeCountrySupport.getSymbolForCurrency(currency);
  String get paymentMethodsSummary => CashfreeCountrySupport.getPaymentMethodsSummary(country);
  String get paymentMethodsDescription => CashfreeCountrySupport.getPaymentMethodsDescription(country);

  // Standard Channel Constraints (10 min daily upload limit, up to 10 min duration per day)
  int get maxAllowedVideos => 100000;
  int get minVideoDurationSeconds => 120; // 2 minutes (120s) minimum video duration on Truthworld
  int get maxDailyVideoDurationSeconds =>
      channelType == ChannelType.standard ? 600 : 86400; // 10 minutes (600s) per day
  int get maxVideoDurationSeconds =>
      channelType == ChannelType.standard ? 600 : 86400; // 10 minutes (600s) max per video
  int get maxTotalVideoDurationSeconds =>
      channelType == ChannelType.standard ? 600 : 8640000; // 10 minutes daily total (600s)

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
      'channelImage': avatarUrl,
      'channelAvatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bannerImageUrl': bannerUrl,
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
      'visibility': visibility,
      'isPublic': visibility.toLowerCase() == 'public',
      'showLikeCount': showLikeCount,
      'showDislikeCount': showDislikeCount,
      'showSubscriberCount': showSubscriberCount,
      'allowComments': allowComments,
      'country': country,
      'hasMemberships': hasMemberships,
      'monetizationTier': monetizationTier.name,
      'monetizationSettings': monetizationSettings,
      'channelType': channelType.name,
      'infraConfig': infraConfig?.toMap(),
      'walletBalanceUSD': walletBalanceUSD,
      'walletBalance': walletBalanceUSD,
      'adsRevenueTotal': adsRevenueTotal,
      'premiumSubsRevenueTotal': premiumSubsRevenueTotal,
      'membershipRevenueTotal': membershipRevenueTotal,
      'superchatRevenueTotal': superchatRevenueTotal,
      'withdrawnRevenueTotal': withdrawnRevenueTotal,
      'clearedWithdrawableRevenueTotal': clearedWithdrawableRevenueTotal,
      'pendingRevenueTotal': pendingRevenueTotal,
      'autoPayoutEnabled': autoPayoutEnabled,
      'noAdsForMembers': noAdsForMembers,
      'pendingChannelType': pendingChannelType?.name,
      'pendingTypeEffectiveDate': pendingTypeEffectiveDate,
      'nextBillingCycleDate': nextBillingCycleDate,
      'brandingSettings': brandingSettings,
      'socialLinks': socialLinks,
      'customLinks': customLinks.isNotEmpty ? customLinks : null,
      'featuredVideoIds': featuredVideoIds,
      'moderationReason': moderationReason,
      'deletionScheduledAt': deletionScheduledAt,
      'deletionGracePeriodExpiresAt': deletionGracePeriodExpiresAt,
    };
  }

  /// Converts this data model to a pure domain [ChannelEntity].
  ChannelEntity toEntity() {
    return ChannelEntity(
      id: id,
      name: name,
      handle: handle,
      description: description,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      ownerId: ownerId,
      subscriberCount: subscriberCount,
      videoCount: videoCount,
      totalViews: metrics.totalViews,
      isVerified: isVerified,
      status: status.name,
      category: category,
      categories: categories,
      visibility: visibility,
      showLikeCount: showLikeCount,
      showDislikeCount: showDislikeCount,
      showSubscriberCount: showSubscriberCount,
      allowComments: allowComments,
      country: country,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }

  /// Creates a [Channel] data model from a pure domain [ChannelEntity].
  static Channel fromEntity(ChannelEntity entity) {
    ChannelStatus parsedStatus;
    try {
      parsedStatus = ChannelStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == entity.status.toLowerCase(),
        orElse: () => ChannelStatus.active,
      );
    } catch (_) {
      parsedStatus = ChannelStatus.active;
    }

    return Channel(
      id: entity.id,
      name: entity.name,
      nameLowercase: entity.name.toLowerCase(),
      handle: entity.handle,
      handleLowercase: entity.handle.toLowerCase(),
      description: entity.description,
      avatarUrl: entity.avatarUrl,
      bannerUrl: entity.bannerUrl,
      ownerId: entity.ownerId,
      createdAt: Timestamp.fromDate(entity.createdAt),
      updatedAt: Timestamp.fromDate(entity.updatedAt),
      subscriberCount: entity.subscriberCount,
      videoCount: entity.videoCount,
      metrics: ChannelMetricsV2(totalViews: entity.totalViews),
      isVerified: entity.isVerified,
      status: parsedStatus,
      category: entity.category,
      categories: entity.categories,
      visibility: entity.visibility,
      showLikeCount: entity.showLikeCount,
      showDislikeCount: entity.showDislikeCount,
      showSubscriberCount: entity.showSubscriberCount,
      allowComments: entity.allowComments,
      country: entity.country,
    );
  }
}

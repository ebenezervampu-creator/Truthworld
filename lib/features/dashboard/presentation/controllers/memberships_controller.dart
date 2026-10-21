import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

/// Representation of a Channel Membership Tier in Truthworld Studio.
class ChannelMembershipTier {
  ChannelMembershipTier({
    required this.id,
    required this.name,
    required this.price,
    required this.perks,
    this.currency = 'USD',
    this.badgeColorHex = '0xFF10B981',
    this.badgeIcon = 'star',
    this.description = '',
    this.isEnabled = true,
    this.hasPremiumBundle = false,
    this.memberCount = 0,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ChannelMembershipTier.fromMap(Map<String, dynamic> map, String id) {
    final rawPrice = (map['price'] as num?)?.toDouble() ?? 5.0;
    final rawCurrency = (map['currency'] as String?)?.toUpperCase();
    final inferredCurrency = rawCurrency ?? (rawPrice >= 50 ? 'INR' : 'USD');

    final rawCreated = map['createdAt'];
    final rawUpdated = map['updatedAt'];
    final perksList = List<String>.from(map['perks'] ?? []);
    final hasBundle = (map['hasPremiumBundle'] as bool?) ??
        (map['hasChannelPremium'] as bool?) ??
        perksList.any((p) {
          final s = p.toLowerCase();
          return s.contains('channel premium') ||
              s.contains('ad-free') ||
              s.contains('no ads') ||
              s.contains('2k') ||
              s.contains('4k');
        });

    return ChannelMembershipTier(
      id: id,
      name: map['name'] ?? 'Tier Name',
      price: rawPrice,
      currency: inferredCurrency,
      perks: perksList,
      hasPremiumBundle: hasBundle,
      badgeColorHex: map['badgeColorHex'] ?? '0xFF10B981',
      badgeIcon: map['badgeIcon'] ?? 'star',
      description: map['description'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdAt: rawCreated is Timestamp ? rawCreated.toDate() : (rawCreated is DateTime ? rawCreated : null),
      updatedAt: rawUpdated is Timestamp ? rawUpdated.toDate() : (rawUpdated is DateTime ? rawUpdated : null),
    );
  }

  /// Canonical perk title for Channel Premium Bundle.
  static const String premiumBundlePerkTitle =
      'Channel Premium: Zero ads & high resolutions up to 2K (entire channel)';

  /// Maximum number of membership tiers allowed per channel according to industry standards.
  static const int maxTiersPerChannel = 3;

  static const double minPriceINR = 50.0;
  static const double minPriceUSD = 1.0;

  static double minPriceFor(String currency) =>
      currency.toUpperCase() == 'INR' ? minPriceINR : minPriceUSD;

  static String minPriceLabel(String currency) =>
      currency.toUpperCase() == 'INR' ? '₹50 (50 rupees)' : r'$1 (1 dollar)';

  /// Recommended pricing for Channel Premium Bundle ($5 for USD, ₹150 for INR).
  static const double recommendedBundlePriceINR = 150.0;
  static const double recommendedBundlePriceUSD = 5.0;

  static double recommendedBundlePriceFor(String currency) =>
      currency.toUpperCase() == 'INR'
          ? recommendedBundlePriceINR
          : recommendedBundlePriceUSD;

  static String recommendedBundlePriceLabel(String currency) =>
      currency.toUpperCase() == 'INR' ? '₹150' : r'$5';

  final String id;
  final String name;
  final double price;
  final String currency;
  final List<String> perks;
  final bool hasPremiumBundle;
  final String badgeColorHex;
  final String badgeIcon;
  final String description;
  final bool isEnabled;
  final int memberCount;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether this tier includes the Channel Premium Bundle (zero ads and up to 2K streaming).
  bool get includesPremiumBundle =>
      hasPremiumBundle ||
      perks.any((p) {
        final s = p.toLowerCase();
        return s.contains('channel premium') ||
            (s.contains('no ads') && (s.contains('2k') || s.contains('4k'))) ||
            s.contains('ad-free') ||
            s.contains('up to 2k');
      });

  /// Platform cut rate: 30% if tier includes Channel Premium bundle, 0% commission otherwise.
  double get platformCutPercentage => includesPremiumBundle ? 0.30 : 0.0;

  /// Creator take-home percentage: 70% if tier includes Channel Premium bundle, 100% otherwise.
  double get creatorSharePercentage => includesPremiumBundle ? 0.70 : 1.0;

  /// Recommended price for this tier ($5 USD or ₹150 INR if bundle is included).
  double get recommendedPrice => includesPremiumBundle
      ? recommendedBundlePriceFor(currency)
      : minPriceFor(currency);

  /// Whether this tier includes the Premium Bundle but is priced below the recommended threshold ($5/₹150).
  bool get isBelowRecommendedBundlePrice =>
      includesPremiumBundle && price < recommendedBundlePriceFor(currency);

  String get currencySymbol => currency.toUpperCase() == 'INR' ? '₹' : r'$';

  String get formattedPrice {
    final isWhole = price == price.truncateToDouble();
    if (currency.toUpperCase() == 'INR') {
      return '₹${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
    }
    return '\$${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
  }

  String formattedPriceForUser([bool? isIndianViewer]) {
    final isIndian = isIndianViewer ??
        (!Get.isRegistered<CurrencyLocalizationService>() ||
            CurrencyLocalizationService.to.isIndianUser);

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    // Non-Indian user always sees prices in Dollars ($ USD)
    if (!isIndian) {
      if (currency.toUpperCase() == 'INR') {
        final usd = price / rate;
        return '\$${usd.toStringAsFixed(2)}';
      }
      return '\$${price.toStringAsFixed(2)}';
    }

    // Indian user sees prices in Rupees (₹ INR)
    if (currency.toUpperCase() == 'INR') {
      final isWhole = price == price.truncateToDouble();
      return '₹${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
    }
    final inr = price * rate;
    final isWhole = inr == inr.truncateToDouble();
    return '₹${isWhole ? inr.toInt() : inr.toStringAsFixed(2)}';
  }

  Color get badgeColor {
    try {
      final hex = badgeColorHex.replaceAll('#', '').replaceAll('0x', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return const Color(0xFFF59E0B);
    }
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'currency': currency.toUpperCase(),
    'perks': perks,
    'hasPremiumBundle': includesPremiumBundle,
    'badgeColorHex': badgeColorHex,
    'badgeIcon': badgeIcon,
    'description': description,
    'isEnabled': isEnabled,
    'memberCount': memberCount,
    'order': order,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  ChannelMembershipTier copyWith({
    String? id,
    String? name,
    double? price,
    String? currency,
    List<String>? perks,
    bool? hasPremiumBundle,
    String? badgeColorHex,
    String? badgeIcon,
    String? description,
    bool? isEnabled,
    int? memberCount,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChannelMembershipTier(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      perks: perks ?? this.perks,
      hasPremiumBundle: hasPremiumBundle ?? this.hasPremiumBundle,
      badgeColorHex: badgeColorHex ?? this.badgeColorHex,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      memberCount: memberCount ?? this.memberCount,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Representation of a Channel Member (Subscriber) in Truthworld Studio.
class ChannelMember {
  ChannelMember({
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.tierId,
    required this.tierName,
    required this.price,
    this.currency = 'USD',
    this.status = 'active',
    this.autoPay = true,
    this.joinedAt,
  });

  factory ChannelMember.fromMap(Map<String, dynamic> map, String id) {
    final rawPrice = (map['price'] as num?)?.toDouble() ?? 0.0;
    final rawCurrency = (map['currency'] as String?)?.toUpperCase();
    final inferredCurrency = rawCurrency ?? (rawPrice >= 50 ? 'INR' : 'USD');

    final rawJoined = map['joinedAt'];

    return ChannelMember(
      userId: map['userId'] ?? id,
      userName: map['userName'] ?? map['displayName'] ?? map['name'] ?? 'Channel Member',
      userAvatarUrl: map['userAvatarUrl'] ?? map['avatarUrl'] ?? map['photoUrl'] ?? map['photoURL'] ?? '',
      tierId: map['tierId'] ?? '',
      tierName: map['tierName'] ?? 'Member',
      price: rawPrice,
      currency: inferredCurrency,
      status: map['status'] ?? 'active',
      autoPay: (map['autoPay'] as bool?) ?? (map['isAutoPay'] as bool?) ?? true,
      joinedAt: rawJoined is Timestamp ? rawJoined.toDate() : (rawJoined is DateTime ? rawJoined : null),
    );
  }

  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String tierId;
  final String tierName;
  final double price;
  final String currency;
  final String status;
  final bool autoPay;
  final DateTime? joinedAt;

  String get currencySymbol => currency.toUpperCase() == 'INR' ? '₹' : r'$';

  String get formattedPrice {
    final isWhole = price == price.truncateToDouble();
    if (currency.toUpperCase() == 'INR') {
      return '₹${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
    }
    return '\$${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
  }

  String formattedPriceForUser([bool? isIndianViewer]) {
    final isIndian = isIndianViewer ??
        (!Get.isRegistered<CurrencyLocalizationService>() ||
            CurrencyLocalizationService.to.isIndianUser);

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    // Non-Indian user always sees in Dollars ($ USD)
    if (!isIndian) {
      if (currency.toUpperCase() == 'INR') {
        final usd = price / rate;
        return '\$${usd.toStringAsFixed(2)}';
      }
      return '\$${price.toStringAsFixed(2)}';
    }

    // Indian user sees in Rupees (₹ INR)
    if (currency.toUpperCase() == 'INR') {
      final isWhole = price == price.truncateToDouble();
      return '₹${isWhole ? price.toInt() : price.toStringAsFixed(2)}';
    }
    final inr = price * rate;
    final isWhole = inr == inr.truncateToDouble();
    return '₹${isWhole ? inr.toInt() : inr.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'tierId': tierId,
    'tierName': tierName,
    'price': price,
    'currency': currency.toUpperCase(),
    'status': status,
    'autoPay': autoPay,
    'isAutoPay': autoPay,
    'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
  };
}

/// Predefined starter tier templates according to creator standards.
enum StarterTierBundleType {
  standard3Tier,
  fanClub1Tier,
  elite4Tier,
}

class StarterTierBundle {
  const StarterTierBundle({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tiers,
  });

  final StarterTierBundleType type;
  final String title;
  final String subtitle;
  final List<ChannelMembershipTier> tiers;
}

/// Controller managing all Studio Channel Memberships and Fan Funding.
class MembershipsController extends BaseController with ContentValidationMixin {
  MembershipsController({String? initialChannelId}) {
    if (initialChannelId != null && initialChannelId.isNotEmpty) {
      _channelId.value = initialChannelId;
    }
  }

  static MembershipsController get to => Get.find<MembershipsController>();

  static const List<Map<String, dynamic>> presetBadgeColors = [
    {'hex': '0xFFF59E0B', 'color': Color(0xFFF59E0B)},
    {'hex': '0xFF3B82F6', 'color': Color(0xFF3B82F6)},
    {'hex': '0xFF10B981', 'color': Color(0xFF10B981)},
    {'hex': '0xFFFFFFFF', 'color': Color(0xFFFFFFFF)},
    {'hex': '0xFFE0E0E0', 'color': Color(0xFFE0E0E0)},
    {'hex': '0xFFEF4444', 'color': Color(0xFFEF4444)},
  ];
  static List<Map<String, dynamic>> get availableColors => presetBadgeColors;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reactive Channel ID
  final RxString _channelId = ''.obs;
  String get channelId => _channelId.value;

  // Reactive State
  final RxList<ChannelMembershipTier> tiers = <ChannelMembershipTier>[].obs;
  final RxList<ChannelMember> members = <ChannelMember>[].obs;
  final RxBool isLoadingTiers = true.obs;
  final RxBool isLoadingMembers = false.obs;
  final RxBool isSaving = false.obs;
  final RxInt selectedTab = 0.obs; // 0: Tiers & Perks, 1: Members, 2: Analytics
  final RxString memberSearchQuery = ''.obs;
  final RxString selectedTierFilter = 'all'.obs;
  final RxBool noAdsForMembers = false.obs;
  final RxBool isUpdatingSettings = false.obs;

  // Stream Subscriptions
  StreamSubscription? _tiersSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _channelSub;
  Worker? _channelIdWorker;

  @override
  void onInit() {
    super.onInit();
    _resolveChannelId();

    _channelIdWorker = ever(_channelId, (newId) {
      if (newId.isNotEmpty) {
        _subscribeToData();
      }
    });
    addWorker(_channelIdWorker!);

    if (Get.isRegistered<AuthService>()) {
      addWorker(
        ever(AuthService.to.rxUserChannel, (ch) {
          if (ch != null && ch.id.isNotEmpty && _channelId.value.isEmpty) {
            _channelId.value = ch.id;
          }
        }),
      );
    }

    if (_channelId.value.isNotEmpty) {
      _subscribeToData();
    }
  }

  void clearData() {
    _tiersSub?.cancel();
    _tiersSub = null;
    _membersSub?.cancel();
    _membersSub = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channelIdWorker?.dispose();
    _channelIdWorker = null;
    _channelId.value = '';
    tiers.clear();
    members.clear();
    memberSearchQuery.value = '';
    selectedTierFilter.value = 'all';
  }

  @override
  void onClose() {
    _tiersSub?.cancel();
    _tiersSub = null;
    _membersSub?.cancel();
    _membersSub = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channelIdWorker?.dispose();
    _channelIdWorker = null;
    super.onClose();
  }

  void setChannelId(String id) {
    if (id.isNotEmpty && id != _channelId.value) {
      _channelId.value = id;
    }
  }

  void _resolveChannelId() {
    if (Get.isRegistered<DashboardController>()) {
      final dashCtrl = Get.find<DashboardController>();
      final curChannel = dashCtrl.currentChannel.value;
      if (curChannel != null && curChannel.id.isNotEmpty) {
        _channelId.value = curChannel.id;
        return;
      }
      if (dashCtrl.channelId.isNotEmpty) {
        _channelId.value = dashCtrl.channelId;
        return;
      }
    }

    if (Get.isRegistered<AuthService>()) {
      final userCh = AuthService.to.userChannel;
      if (userCh != null && userCh.id.isNotEmpty) {
        _channelId.value = userCh.id;
        return;
      }
    }

    if (_channelId.value.isNotEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _channelId.value = uid;
    }
  }

  void _subscribeToData() {
    final activeId = _channelId.value;
    if (activeId.isEmpty) return;

    // 1. Tiers Stream
    _tiersSub?.cancel();
    isLoadingTiers.value = true;
    _tiersSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(activeId)
        .collection('membership_tiers')
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ChannelMembershipTier.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) {
          if (a.order != b.order) return a.order.compareTo(b.order);
          return a.price.compareTo(b.price);
        });
        tiers.value = list;
        isLoadingTiers.value = false;
      },
      onError: (err) {
        isLoadingTiers.value = false;
        debugPrint('[MembershipsController] Error listening to tiers: $err');
      },
    );

    // 2. Members Stream
    _membersSub?.cancel();
    isLoadingMembers.value = true;
    _membersSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(activeId)
        .collection('members')
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ChannelMember.fromMap(doc.data(), doc.id))
            .toList();
        members.value = list;
        isLoadingMembers.value = false;
      },
      onError: (err) {
        isLoadingMembers.value = false;
        debugPrint('[MembershipsController] Error listening to members: $err');
      },
    );

    // 3. Channel Settings Stream (noAdsForMembers)
    _channelSub?.cancel();
    _channelSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(activeId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final noAds = (data['noAdsForMembers'] as bool?) ??
              (data['monetizationSettings'] is Map
                  ? ((data['monetizationSettings']['noAdsForMembers'] as bool?) ??
                      (data['monetizationSettings']['memberAdFreeEnabled'] as bool?))
                  : null) ??
              false;
          noAdsForMembers.value = noAds;
        }
      },
      onError: (err) {
        debugPrint('[MembershipsController] Error listening to channel settings: $err');
      },
    );
  }

  // --- Computed Metrics ---

  int get totalActiveMembers {
    if (members.isNotEmpty) {
      return members
          .where((m) => m.status.toLowerCase() == 'active')
          .map((m) => m.userId)
          .toSet()
          .length;
    }
    return tiers.fold<int>(0, (sum, t) => sum + t.memberCount);
  }

  String get primaryCurrencySymbol {
    final activeMember = members.firstWhereOrNull((m) => m.status.toLowerCase() == 'active');
    if (activeMember != null) {
      return activeMember.currencySymbol;
    }
    final activeTier = tiers.firstWhereOrNull((t) => t.isEnabled);
    if (activeTier != null) {
      return activeTier.currencySymbol;
    }
    return r'$';
  }

  double get monthlyRecurringRevenue {
    var total = 0.0;
    final isUsd = primaryCurrencySymbol == r'$';
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    if (members.isNotEmpty) {
      for (final m in members.where((m) => m.status.toLowerCase() == 'active')) {
        final memberIsUsd = m.currency.toUpperCase() == 'USD';
        if (isUsd && !memberIsUsd) {
          total += m.price / rate;
        } else if (!isUsd && memberIsUsd) {
          total += m.price * rate;
        } else {
          total += m.price;
        }
      }
    } else {
      for (final t in tiers.where((t) => t.isEnabled)) {
        final tierIsUsd = t.currency.toUpperCase() == 'USD';
        final rawTierTotal = t.price * t.memberCount;
        if (isUsd && !tierIsUsd) {
          total += rawTierTotal / rate;
        } else if (!isUsd && tierIsUsd) {
          total += rawTierTotal * rate;
        } else {
          total += rawTierTotal;
        }
      }
    }
    return total;
  }

  /// Net monthly recurring revenue for creator (accounts for 30% platform cut on tiers with Channel Premium bundle).
  double get creatorMonthlyRecurringRevenue {
    if (noAdsForMembers.value) {
      return monthlyRecurringRevenue * 0.70;
    }

    var netTotal = 0.0;
    final isUsd = primaryCurrencySymbol == r'$';
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    if (members.isNotEmpty) {
      for (final m in members.where((m) => m.status.toLowerCase() == 'active')) {
        final tier = tiers.firstWhereOrNull((t) => t.id == m.tierId);
        final hasBundle = tier?.includesPremiumBundle ?? false;
        final share = hasBundle ? 0.70 : 1.0;

        final memberIsUsd = m.currency.toUpperCase() == 'USD';
        final double memberPrice;
        if (isUsd && !memberIsUsd) {
          memberPrice = m.price / rate;
        } else if (!isUsd && memberIsUsd) {
          memberPrice = m.price * rate;
        } else {
          memberPrice = m.price;
        }
        netTotal += memberPrice * share;
      }
    } else {
      for (final t in tiers.where((t) => t.isEnabled)) {
        final hasBundle = t.includesPremiumBundle;
        final share = hasBundle ? 0.70 : 1.0;

        final tierIsUsd = t.currency.toUpperCase() == 'USD';
        final rawTierTotal = t.price * t.memberCount;
        final double tierTotal;
        if (isUsd && !tierIsUsd) {
          tierTotal = rawTierTotal / rate;
        } else if (!isUsd && tierIsUsd) {
          tierTotal = rawTierTotal * rate;
        } else {
          tierTotal = rawTierTotal;
        }
        netTotal += tierTotal * share;
      }
    }
    return netTotal;
  }

  /// Monthly recurring revenue retained by platform when member ad-free playback is active (30%).
  double get platformMonthlyRecurringRevenue {
    final gross = monthlyRecurringRevenue;
    final creatorNet = creatorMonthlyRecurringRevenue;
    return (gross - creatorNet).clamp(0.0, double.infinity);
  }

  int get activeTiersCount => tiers.where((t) => t.isEnabled).length;

  /// Maximum number of membership tiers allowed per channel according to industry standards (3).
  static const int maxTiersPerChannel = ChannelMembershipTier.maxTiersPerChannel;

  /// Whether the channel has reached the maximum allowed membership tiers (3).
  bool get hasReachedMaxTiers => tiers.length >= maxTiersPerChannel;

  /// Number of tier slots remaining for this channel (out of 3).
  int get remainingTierSlots => (maxTiersPerChannel - tiers.length).clamp(0, maxTiersPerChannel);

  /// User-friendly label for current tier capacity (e.g. "2/3 tiers").
  String get tierLimitLabel => '${tiers.length}/$maxTiersPerChannel tiers';

  List<ChannelMember> get filteredMembers {
    var list = members.toList();
    if (selectedTierFilter.value != 'all') {
      list = list.where((m) => m.tierId == selectedTierFilter.value).toList();
    }
    final q = memberSearchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) =>
          m.userName.toLowerCase().contains(q) ||
          m.tierName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  // --- Channel Member Ad-Free Feature Toggle ---

  Future<bool> toggleNoAdsForMembers(bool enabled) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) {
      AppSnackbar.warning('Unable to resolve channel ID. Please refresh.');
      return false;
    }

    isUpdatingSettings.value = true;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .set({
        'noAdsForMembers': enabled,
        'monetizationSettings': {
          'noAdsForMembers': enabled,
          'memberAdFreeEnabled': enabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      noAdsForMembers.value = enabled;
      AppSnackbar.success(
        enabled
            ? 'Channel Premium enabled! Members get zero ads and 4K Ultra HD streaming on your channel (30% platform cut).'
            : 'Channel Premium disabled. Standard ad policy restored with 0% platform commission.',
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e, tag: 'MembershipsController.toggleNoAdsForMembers');
      AppSnackbar.error('Unable to update member ad-free playback setting. Please try again.');
      return false;
    } finally {
      isUpdatingSettings.value = false;
    }
  }

  // --- Tier CRUD Operations ---

  Future<bool> createTier({
    required String name,
    required double price,
    required List<String> perks,
    String currency = 'USD',
    String badgeColorHex = '0xFF10B981',
    String badgeIcon = 'star',
    String description = '',
    bool isEnabled = true,
    bool hasPremiumBundle = false,
  }) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) {
      AppSnackbar.warning('Unable to resolve channel ID. Please refresh.');
      return false;
    }

    if (tiers.length >= maxTiersPerChannel) {
      AppSnackbar.warning(
        'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to add a new one.',
      );
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      AppSnackbar.warning('Tier name is required.');
      return false;
    }

    final normalizedCurrency = currency.toUpperCase() == 'INR' ? 'INR' : 'USD';
    final minAllowed = ChannelMembershipTier.minPriceFor(normalizedCurrency);
    if (price < minAllowed) {
      AppSnackbar.warning(
        'Minimum price for $normalizedCurrency membership plans is ${ChannelMembershipTier.minPriceLabel(normalizedCurrency)}.',
      );
      return false;
    }

    // Validate name
    final nameVal = ContentValidator.validate(trimmedName, fieldName: 'Tier Name');
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return false;
    }

    // Validate description if present
    if (description.trim().isNotEmpty) {
      final descVal = ContentValidator.validate(description.trim(), fieldName: 'Description');
      if (!descVal.isValid) {
        AppSnackbar.warning(descVal.message);
        return false;
      }
    }

    // Validate perks
    final cleanPerks = perks.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (cleanPerks.isEmpty) {
      AppSnackbar.warning('Please include at least one perk.', title: 'Perks Required');
      return false;
    }

    for (final perk in cleanPerks) {
      final pVal = ContentValidator.validate(perk, fieldName: 'Perk');
      if (!pVal.isValid) {
        AppSnackbar.warning(pVal.message);
        return false;
      }
    }

    isSaving.value = true;
    try {
      final docRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers')
          .doc();

      final newTier = ChannelMembershipTier(
        id: docRef.id,
        name: trimmedName,
        price: price,
        currency: normalizedCurrency,
        perks: cleanPerks,
        badgeColorHex: badgeColorHex,
        badgeIcon: badgeIcon,
        description: description.trim(),
        isEnabled: isEnabled,
        hasPremiumBundle: hasPremiumBundle,
        order: tiers.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newTier.toMap());
      if (isEnabled) {
        _firestore
            .collection(FirestoreCollections.channels)
            .doc(activeId)
            .update({
          'hasMemberships': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'MembershipsController.createTier.syncHasMemberships');
        });
      }
      AppSnackbar.success('Tier "$trimmedName" created successfully!');
      isSaving.value = false;
      return true;
    } catch (e) {
      isSaving.value = false;
      ErrorHandler.log(e, tag: 'MembershipsController');
      AppSnackbar.error('Unable to create tier. Please try again.');
      return false;
    }
  }

  Future<bool> updateTier(ChannelMembershipTier tier) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return false;

    final trimmedName = tier.name.trim();
    if (trimmedName.isEmpty) {
      AppSnackbar.warning('Tier name is required.');
      return false;
    }

    final normalizedCurrency = tier.currency.toUpperCase() == 'INR' ? 'INR' : 'USD';
    final minAllowed = ChannelMembershipTier.minPriceFor(normalizedCurrency);
    if (tier.price < minAllowed) {
      AppSnackbar.warning(
        'Minimum price for $normalizedCurrency membership plans is ${ChannelMembershipTier.minPriceLabel(normalizedCurrency)}.',
      );
      return false;
    }

    final nameVal = ContentValidator.validate(trimmedName, fieldName: 'Tier Name');
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return false;
    }

    if (tier.description.trim().isNotEmpty) {
      final descVal = ContentValidator.validate(tier.description.trim(), fieldName: 'Description');
      if (!descVal.isValid) {
        AppSnackbar.warning(descVal.message);
        return false;
      }
    }

    final cleanPerks = tier.perks.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    for (final perk in cleanPerks) {
      final pVal = ContentValidator.validate(perk, fieldName: 'Perk');
      if (!pVal.isValid) {
        AppSnackbar.warning(pVal.message);
        return false;
      }
    }

    isSaving.value = true;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers')
          .doc(tier.id)
          .update(tier.copyWith(perks: cleanPerks, currency: normalizedCurrency).toMap());

      AppSnackbar.success('Tier "${tier.name}" updated successfully.');
      isSaving.value = false;
      return true;
    } catch (e) {
      isSaving.value = false;
      ErrorHandler.log(e, tag: 'MembershipsController');
      AppSnackbar.error('Unable to update tier. Please try again.');
      return false;
    }
  }

  Future<void> toggleTierStatus(String tierId, bool isEnabled) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return;

    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers')
          .doc(tierId)
          .update({
        'isEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final hasAnyEnabled = tiers.any((t) => t.id == tierId ? isEnabled : t.isEnabled);
      _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .update({
        'hasMemberships': hasAnyEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'MembershipsController.toggleTierStatus.syncHasMemberships');
      });

      AppSnackbar.info(
        isEnabled ? 'Tier is now active for fans to join.' : 'Tier is paused and hidden from new fans.',
        title: isEnabled ? 'Tier Enabled' : 'Tier Paused',
      );
    } catch (e) {
      ErrorHandler.log(e, tag: 'MembershipsController');
      AppSnackbar.error('Unable to update tier status. Please try again.');
    }
  }

  Future<void> deleteTier(String tierId, String tierName) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return;

    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers')
          .doc(tierId)
          .delete();

      final hasAnyRemaining = tiers
          .where((t) => t.id != tierId)
          .any((t) => t.isEnabled);
      _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .update({
        'hasMemberships': hasAnyRemaining,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'MembershipsController.deleteTier.syncHasMemberships');
      });

      AppSnackbar.info('Tier "$tierName" has been removed.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'MembershipsController');
      AppSnackbar.error('Unable to delete tier. Please try again.');
    }
  }

  Future<void> duplicateTier(ChannelMembershipTier tier) async {
    if (tiers.length >= maxTiersPerChannel) {
      AppSnackbar.warning(
        'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to duplicate one.',
      );
      return;
    }
    final copyName = '${tier.name} (Copy)';
    await createTier(
      name: copyName,
      price: tier.price,
      currency: tier.currency,
      perks: List<String>.from(tier.perks),
      badgeColorHex: tier.badgeColorHex,
      badgeIcon: tier.badgeIcon,
      description: tier.description,
      isEnabled: false,
    );
  }

  // --- Starter Tier Templates ---

  static final List<StarterTierBundle> starterBundles = [
    StarterTierBundle(
      type: StarterTierBundleType.standard3Tier,
      title: 'Standard 3-Tier Bundle (Recommended)',
      subtitle: 'Industry-standard tier progression from Bronze to Gold Patron.',
      tiers: [
        ChannelMembershipTier(
          id: 'tier_bronze',
          name: 'Bronze Supporter',
          price: 2.0,
          badgeColorHex: '0xFFCD7F32',
          badgeIcon: 'shield',
          description: 'Join the channel family and stand out in the comments.',
          perks: [
            'Loyalty badge beside your name in comments & live chat',
            'Exclusive member-only community posts & updates',
            'Custom channel emojis in comments',
          ],
        ),
        ChannelMembershipTier(
          id: 'tier_silver',
          name: 'Silver VIP',
          price: 5.0,
          badgeColorHex: '0xFF94A3B8',
          description: 'Get early access to videos and direct priority replies.',
          perks: [
            'No ads while watching this channel',
            '4K Ultra HD (2160p) video streaming',
            'All Bronze Supporter perks included',
            'Early access to newly uploaded videos (24-48 hrs)',
            'Priority reply to your comments on all videos',
            'Members-only polls & content voting rights',
          ],
          order: 1,
        ),
        ChannelMembershipTier(
          id: 'tier_gold',
          name: 'Gold Patron',
          price: 10.0,
          badgeIcon: 'crown',
          description: 'Ultimate fan tier with live stream Q&A and video shoutouts.',
          perks: [
            'All Silver VIP perks included',
            'Monthly exclusive live stream Q&A sessions',
            'Special name shoutout in video credits',
            'Behind-the-scenes bloopers & bonus cuts',
          ],
          order: 2,
        ),
      ],
    ),
    StarterTierBundle(
      type: StarterTierBundleType.fanClub1Tier,
      title: 'Fan Club (Simple 1-Tier Setup)',
      subtitle: 'One accessible tier for all channel supporters.',
      tiers: [
        ChannelMembershipTier(
          id: 'tier_fan_club',
          name: 'Channel Fan Club',
          price: 3.0,
          badgeIcon: 'heart',
          description: 'Directly support the channel and get exclusive member perks.',
          perks: [
            'Channel Premium: Ad-free & 4K Ultra HD streaming',
            'Exclusive loyalty badge beside channel comments',
            'Custom emojis in live chat',
            'Early access to all new videos',
            'Members-only community posts & polls',
          ],
        ),
      ],
    ),
    StarterTierBundle(
      type: StarterTierBundleType.elite4Tier,
      title: 'Creator VIP (3-Tier Progression)',
      subtitle: 'Complete creator ladder up to high-tier Executive Producer.',
      tiers: [
        ChannelMembershipTier(
          id: 'tier_supporter',
          name: 'Supporter',
          price: 2.0,
          badgeColorHex: '0xFF64748B',
          badgeIcon: 'shield',
          description: 'Show your channel support with exclusive loyalty badges.',
          perks: [
            'Loyalty badge in comments & chat',
            'Custom channel emojis',
          ],
        ),
        ChannelMembershipTier(
          id: 'tier_vip_elite',
          name: 'VIP Elite',
          price: 10.0,
          badgeColorHex: '0xFFFFFFFF',
          badgeIcon: 'diamond',
          description: 'Behind the scenes and live Q&A access.',
          perks: [
            'All Supporter perks included',
            'Monthly live stream Q&A',
            'Priority replies to comments',
            'Exclusive BTS content & wallpapers',
          ],
          order: 1,
        ),
        ChannelMembershipTier(
          id: 'tier_producer',
          name: 'Executive Producer',
          price: 25.0,
          badgeColorHex: '0xFFEC4899',
          badgeIcon: 'crown',
          description: 'Highest tier of channel backing with credit shoutouts.',
          perks: [
            'All VIP Elite perks included',
            'Producer credit at the end of every video',
            'Direct input on upcoming video topics',
            'Private Discord/Community VIP role',
          ],
          order: 2,
        ),
      ],
    ),
  ];

  Future<void> setupStarterBundle(StarterTierBundle bundle) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return;

    if (bundle.tiers.length > maxTiersPerChannel) {
      AppSnackbar.warning('Membership bundles cannot exceed 3 tiers.');
      return;
    }

    isSaving.value = true;
    try {
      final batch = _firestore.batch();
      final collection = _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers');

      // Clear existing tiers first to guarantee channel stays within 3-tier limit
      for (final existing in tiers) {
        batch.delete(collection.doc(existing.id));
      }

      for (var i = 0; i < bundle.tiers.length; i++) {
        final t = bundle.tiers[i];
        final docRef = collection.doc(t.id);
        batch.set(
          docRef,
          t.copyWith(order: i, createdAt: DateTime.now(), updatedAt: DateTime.now()).toMap(),
        );
      }

      await batch.commit();
      AppSnackbar.success('Configured ${bundle.tiers.length} starter membership tiers!');
    } catch (e) {
      ErrorHandler.log(e, tag: 'MembershipsController');
      AppSnackbar.error('Unable to configure starter tiers. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

  // Pre-configured popular perks list for 1-click addition in tier builder
  static const List<String> popularPerkSuggestions = [
    ChannelMembershipTier.premiumBundlePerkTitle,
    'No ads while watching this channel',
    '4K Ultra HD (2160p) video streaming',
    'Channel Premium: Ad-free & 4K streaming',
    'Loyalty badge beside channel comments',
    'Custom emojis in live chat & comments',
    'Early access to new videos (24-48 hrs)',
    'Members-only community posts & polls',
    'Exclusive monthly live stream Q&A',
    'Priority reply to your comments',
    'Special shoutout in video credits',
    'Behind-the-scenes clips & bloopers',
    'Exclusive VIP Discord channel role',
    'Monthly digital wallpapers & downloads',
    'Topic suggestions & content voting rights',
  ];
}

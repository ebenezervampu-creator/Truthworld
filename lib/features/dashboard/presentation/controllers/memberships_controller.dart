import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

/// Representation of a Channel Membership Tier in Truthworld Studio.
class ChannelMembershipTier {
  ChannelMembershipTier({
    required this.id,
    required this.name,
    required this.price,
    required this.perks,
    this.badgeColorHex = '0xFFF59E0B',
    this.badgeIcon = 'star',
    this.description = '',
    this.isEnabled = true,
    this.memberCount = 0,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ChannelMembershipTier.fromMap(Map<String, dynamic> map, String id) {
    return ChannelMembershipTier(
      id: id,
      name: map['name'] ?? 'Tier Name',
      price: (map['price'] as num?)?.toDouble() ?? 4.99,
      perks: List<String>.from(map['perks'] ?? []),
      badgeColorHex: map['badgeColorHex'] ?? '0xFFF59E0B',
      badgeIcon: map['badgeIcon'] ?? 'star',
      description: map['description'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String name;
  final double price;
  final List<String> perks;
  final String badgeColorHex;
  final String badgeIcon;
  final String description;
  final bool isEnabled;
  final int memberCount;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    'perks': perks,
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
    List<String>? perks,
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
      perks: perks ?? this.perks,
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
    this.status = 'active',
    this.joinedAt,
  });

  factory ChannelMember.fromMap(Map<String, dynamic> map, String id) {
    return ChannelMember(
      userId: map['userId'] ?? id,
      userName: map['userName'] ?? map['displayName'] ?? 'Channel Member',
      userAvatarUrl: map['userAvatarUrl'] ?? map['avatarUrl'] ?? '',
      tierId: map['tierId'] ?? '',
      tierName: map['tierName'] ?? 'Member',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'active',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String tierId;
  final String tierName;
  final double price;
  final String status;
  final DateTime? joinedAt;

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'tierId': tierId,
    'tierName': tierName,
    'price': price,
    'status': status,
    'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
  };
}

/// Predefined starter tier templates according to YouTube Studio & Patreon standards.
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

  // Stream Subscriptions
  StreamSubscription? _tiersSub;
  StreamSubscription? _membersSub;
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

    if (Get.isRegistered<AuthService>()) {
      ever(AuthService.to.rxUserChannel, (ch) {
        if (ch != null && ch.id.isNotEmpty && _channelId.value.isEmpty) {
          _channelId.value = ch.id;
        }
      });
    }

    if (_channelId.value.isNotEmpty) {
      _subscribeToData();
    }
  }

  @override
  void onClose() {
    _tiersSub?.cancel();
    _membersSub?.cancel();
    _channelIdWorker?.dispose();
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
  }

  // --- Computed Metrics ---

  int get totalActiveMembers =>
      members.where((m) => m.status.toLowerCase() == 'active').length +
      tiers.fold<int>(0, (sum, t) => sum + t.memberCount);

  double get monthlyRecurringRevenue {
    var total = 0.0;
    if (members.isNotEmpty) {
      for (final m in members.where((m) => m.status.toLowerCase() == 'active')) {
        total += m.price;
      }
    } else {
      for (final t in tiers.where((t) => t.isEnabled)) {
        total += t.price * t.memberCount;
      }
    }
    return total;
  }

  int get activeTiersCount => tiers.where((t) => t.isEnabled).length;

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

  // --- Tier CRUD Operations ---

  Future<bool> createTier({
    required String name,
    required double price,
    required List<String> perks,
    String badgeColorHex = '0xFFF59E0B',
    String badgeIcon = 'star',
    String description = '',
    bool isEnabled = true,
  }) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) {
      AppSnackbar.show('Error', 'Unable to resolve channel ID. Please refresh.');
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      AppSnackbar.show('Validation Error', 'Tier name is required.');
      return false;
    }

    if (price <= 0) {
      AppSnackbar.show('Validation Error', r'Price must be greater than $0.00.');
      return false;
    }

    // Validate name
    final nameVal = ContentValidator.validate(trimmedName, fieldName: 'Tier Name');
    if (!nameVal.isValid) {
      AppSnackbar.show('Content Warning', nameVal.message);
      return false;
    }

    // Validate description if present
    if (description.trim().isNotEmpty) {
      final descVal = ContentValidator.validate(description.trim(), fieldName: 'Description');
      if (!descVal.isValid) {
        AppSnackbar.show('Content Warning', descVal.message);
        return false;
      }
    }

    // Validate perks
    final cleanPerks = perks.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (cleanPerks.isEmpty) {
      AppSnackbar.show('Validation Error', 'Please include at least one perk.');
      return false;
    }

    for (final perk in cleanPerks) {
      final pVal = ContentValidator.validate(perk, fieldName: 'Perk');
      if (!pVal.isValid) {
        AppSnackbar.show('Content Warning', pVal.message);
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
        perks: cleanPerks,
        badgeColorHex: badgeColorHex,
        badgeIcon: badgeIcon,
        description: description.trim(),
        isEnabled: isEnabled,
        order: tiers.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newTier.toMap());
      AppSnackbar.show('Success', 'Tier "$trimmedName" created successfully!');
      isSaving.value = false;
      return true;
    } catch (e) {
      isSaving.value = false;
      debugPrint('[MembershipsController] Error creating tier: $e');
      AppSnackbar.show('Error', 'Failed to create tier: $e');
      return false;
    }
  }

  Future<bool> updateTier(ChannelMembershipTier tier) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return false;

    final trimmedName = tier.name.trim();
    if (trimmedName.isEmpty) {
      AppSnackbar.show('Validation Error', 'Tier name is required.');
      return false;
    }

    final nameVal = ContentValidator.validate(trimmedName, fieldName: 'Tier Name');
    if (!nameVal.isValid) {
      AppSnackbar.show('Content Warning', nameVal.message);
      return false;
    }

    final cleanPerks = tier.perks.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    for (final perk in cleanPerks) {
      final pVal = ContentValidator.validate(perk, fieldName: 'Perk');
      if (!pVal.isValid) {
        AppSnackbar.show('Content Warning', pVal.message);
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
          .update(tier.copyWith(perks: cleanPerks).toMap());

      AppSnackbar.show('Updated', 'Tier "${tier.name}" updated successfully.');
      isSaving.value = false;
      return true;
    } catch (e) {
      isSaving.value = false;
      debugPrint('[MembershipsController] Error updating tier: $e');
      AppSnackbar.show('Error', 'Failed to update tier: $e');
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

      AppSnackbar.show(
        isEnabled ? 'Tier Enabled' : 'Tier Paused',
        isEnabled ? 'Tier is now active for fans to join.' : 'Tier is paused and hidden from new fans.',
      );
    } catch (e) {
      AppSnackbar.show('Error', 'Failed to update tier status: $e');
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

      AppSnackbar.show('Deleted', 'Tier "$tierName" has been removed.');
    } catch (e) {
      AppSnackbar.show('Error', 'Failed to delete tier: $e');
    }
  }

  Future<void> duplicateTier(ChannelMembershipTier tier) async {
    final copyName = '${tier.name} (Copy)';
    await createTier(
      name: copyName,
      price: tier.price,
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
          price: 1.99,
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
          price: 4.99,
          badgeColorHex: '0xFF94A3B8',
          description: 'Get early access to videos and direct priority replies.',
          perks: [
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
          price: 9.99,
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
          price: 2.99,
          badgeColorHex: '0xFF10B981',
          badgeIcon: 'heart',
          description: 'Directly support the channel and get exclusive member perks.',
          perks: [
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
      title: 'Creator VIP (4-Tier Progression)',
      subtitle: 'Complete creator ladder including high-tier Executive Producer.',
      tiers: [
        ChannelMembershipTier(
          id: 'tier_supporter',
          name: 'Supporter',
          price: 1.99,
          badgeColorHex: '0xFF64748B',
          badgeIcon: 'shield',
          description: 'Show your channel support with exclusive loyalty badges.',
          perks: [
            'Loyalty badge in comments & chat',
            'Custom channel emojis',
          ],
        ),
        ChannelMembershipTier(
          id: 'tier_insider',
          name: 'Insider',
          price: 4.99,
          badgeColorHex: '0xFF3B82F6',
          description: 'Early access and member-only updates.',
          perks: [
            'All Supporter perks included',
            'Early access to videos',
            'Member-only community posts',
          ],
          order: 1,
        ),
        ChannelMembershipTier(
          id: 'tier_vip_elite',
          name: 'VIP Elite',
          price: 9.99,
          badgeColorHex: '0xFF8B5CF6',
          badgeIcon: 'diamond',
          description: 'Behind the scenes and live Q&A access.',
          perks: [
            'All Insider perks included',
            'Monthly live stream Q&A',
            'Priority replies to comments',
            'Exclusive BTS content & wallpapers',
          ],
          order: 2,
        ),
        ChannelMembershipTier(
          id: 'tier_producer',
          name: 'Executive Producer',
          price: 24.99,
          badgeColorHex: '0xFFEC4899',
          badgeIcon: 'crown',
          description: 'Highest tier of channel backing with credit shoutouts.',
          perks: [
            'All VIP Elite perks included',
            'Producer credit at the end of every video',
            'Direct input on upcoming video topics',
            'Private Discord/Community VIP role',
          ],
          order: 3,
        ),
      ],
    ),
  ];

  Future<void> setupStarterBundle(StarterTierBundle bundle) async {
    _resolveChannelId();
    final activeId = _channelId.value;
    if (activeId.isEmpty) return;

    isSaving.value = true;
    try {
      final batch = _firestore.batch();
      final collection = _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeId)
          .collection('membership_tiers');

      for (var i = 0; i < bundle.tiers.length; i++) {
        final t = bundle.tiers[i];
        final docRef = collection.doc(t.id);
        batch.set(
          docRef,
          t.copyWith(order: i, createdAt: DateTime.now(), updatedAt: DateTime.now()).toMap(),
        );
      }

      await batch.commit();
      AppSnackbar.show('Success', 'Configured ${bundle.tiers.length} starter membership tiers!');
    } catch (e) {
      debugPrint('[MembershipsController] Error setting up starter bundle: $e');
      AppSnackbar.show('Error', 'Failed to configure starter tiers: $e');
    } finally {
      isSaving.value = false;
    }
  }

  // Pre-configured popular perks list for 1-click addition in tier builder
  static const List<String> popularPerkSuggestions = [
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

  // Preset palette of creator tier badge colors
  static const List<Map<String, dynamic>> presetBadgeColors = [
    {'name': 'Amber Gold', 'hex': '0xFFF59E0B', 'color': Color(0xFFF59E0B)},
    {'name': 'Emerald Green', 'hex': '0xFF10B981', 'color': Color(0xFF10B981)},
    {'name': 'Sapphire Blue', 'hex': '0xFF3B82F6', 'color': Color(0xFF3B82F6)},
    {'name': 'Royal Purple', 'hex': '0xFF8B5CF6', 'color': Color(0xFF8B5CF6)},
    {'name': 'Rose Pink', 'hex': '0xFFEC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Bronze Copper', 'hex': '0xFFCD7F32', 'color': Color(0xFFCD7F32)},
    {'name': 'Silver Platinum', 'hex': '0xFF94A3B8', 'color': Color(0xFF94A3B8)},
    {'name': 'Ruby Red', 'hex': '0xFFEF4444', 'color': Color(0xFFEF4444)},
    {'name': 'Teal Cyan', 'hex': '0xFF06B6D4', 'color': Color(0xFF06B6D4)},
  ];
}

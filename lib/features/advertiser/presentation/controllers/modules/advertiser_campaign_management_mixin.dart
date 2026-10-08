import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

mixin AdvertiserCampaignManagementMixin {
  StreamSubscription<QuerySnapshot>? _presetsSub;
  StreamSubscription<QuerySnapshot>? _proposalsSub;
  StreamSubscription<QuerySnapshot>? _assetsSub;
  StreamSubscription<QuerySnapshot>? _experimentsSub;

  // 1. Audience Presets
  final RxList<Map<String, dynamic>> audiencePresets = <Map<String, dynamic>>[].obs;

  // 2. Creator Sponsorships
  final RxString selectedSponsorshipCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creatorsList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> sponsorshipProposals = <Map<String, dynamic>>[].obs;

  // 3. Creative Assets
  final RxString selectedAssetCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creativeAssetsList = <Map<String, dynamic>>[].obs;

  // 4. A/B Testing & Optimization
  final RxList<Map<String, dynamic>> abExperimentsList = <Map<String, dynamic>>[].obs;

  // 5. Brand Profile & Settings
  final RxString brandName = 'Truthworld'.obs;
  final RxString brandTagline = 'Truthworld Change the World'.obs;
  final RxString brandWebsite = 'https://truthworld.in'.obs;
  final RxString brandEmail = ''.obs;
  final RxString brandCategory = 'Technology & Media'.obs;
  final RxBool isBrandVerified = true.obs;

  final RxBool lowBudgetAlert = true.obs;
  final RxBool dailyPerformanceDigest = true.obs;
  final RxBool campaignStatusNotifications = true.obs;
  final RxBool sponsorshipAlerts = true.obs;

  final RxString conversionApiKey = ''.obs;

  final RxList<Map<String, dynamic>> teamMembers = <Map<String, dynamic>>[].obs;

  void disposeCampaignManagement() {
    _presetsSub?.cancel();
    _proposalsSub?.cancel();
    _assetsSub?.cancel();
    _experimentsSub?.cancel();
  }

  void initCampaignManagement() {
    disposeCampaignManagement();
    fetchSponsorshipCreators();
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      audiencePresets.clear();
      sponsorshipProposals.clear();
      creativeAssetsList.clear();
      abExperimentsList.clear();
      teamMembers.clear();
      return;
    }

    _loadBrandProfile(uid);
    _listenToPresets(uid);
    _listenToProposals(uid);
    _listenToAssets(uid);
    _listenToExperiments(uid);
  }

  Future<void> _loadBrandProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('advertiser_profiles').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['brandName'] != null) brandName.value = data['brandName'] as String;
        if (data['brandTagline'] != null) brandTagline.value = data['brandTagline'] as String;
        if (data['brandWebsite'] != null) brandWebsite.value = data['brandWebsite'] as String;
        if (data['brandEmail'] != null) {
          brandEmail.value = data['brandEmail'] as String;
        } else {
          brandEmail.value = AuthService.to.user?.email ?? '';
        }
        if (data['brandCategory'] != null) brandCategory.value = data['brandCategory'] as String;
        if (data['isBrandVerified'] != null) isBrandVerified.value = data['isBrandVerified'] == true;
        if (data['conversionApiKey'] != null) {
          conversionApiKey.value = data['conversionApiKey'] as String;
        } else {
          conversionApiKey.value = 'tw_live_ak_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        }

        if (data['teamMembers'] is List) {
          teamMembers.value = (data['teamMembers'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
        } else {
          _setDefaultTeamMember();
        }
      } else {
        brandEmail.value = AuthService.to.user?.email ?? '';
        conversionApiKey.value = 'tw_live_ak_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        _setDefaultTeamMember();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin._loadBrandProfile');
      _setDefaultTeamMember();
    }
  }

  void _setDefaultTeamMember() {
    final user = AuthService.to.user;
    teamMembers.value = [
      {
        'name': user?.displayName ?? 'Account Owner',
        'email': user?.email ?? 'hello@truthworld.in',
        'role': 'Owner (Full Access)',
        'status': 'Active',
      }
    ];
  }

  void _listenToPresets(String uid) {
    _presetsSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .collection('audience_presets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      audiencePresets.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }, onError: (Object e) {
      ErrorHandler.log(e);
    });
  }

  void _listenToProposals(String uid) {
    _proposalsSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .collection('sponsorship_proposals')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
      sponsorshipProposals.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }, onError: (Object e) {
      ErrorHandler.log(e);
    });
  }

  void _listenToAssets(String uid) {
    _assetsSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .collection('creative_assets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      creativeAssetsList.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }, onError: (Object e) {
      ErrorHandler.log(e);
    });
  }

  void _listenToExperiments(String uid) {
    _experimentsSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .collection('ab_experiments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      abExperimentsList.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }, onError: (Object e) {
      ErrorHandler.log(e);
    });
  }

  Future<void> fetchSponsorshipCreators() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('channels').limit(20).get();
      creatorsList.value = snap.docs.map((doc) {
        final data = doc.data();
        final subCount = (data['subscriberCount'] as num?)?.toInt() ?? 0;
        final viewsCount = (data['totalViews'] as num?)?.toInt() ?? 0;
        return {
          'id': doc.id,
          'name': data['channelName'] ?? data['name'] ?? 'Creator',
          'handle': data['channelHandle'] ?? data['handle'] ?? '@channel',
          'category': data['category'] ?? 'General',
          'subscribers': subCount >= 1000000
              ? '${(subCount / 1000000).toStringAsFixed(1)}M'
              : (subCount >= 1000 ? '${(subCount / 1000).toStringAsFixed(0)}K' : '$subCount'),
          'subscribersCount': subCount,
          'avgViews': viewsCount >= 1000 ? '${(viewsCount / 1000).toStringAsFixed(0)}K' : '$viewsCount',
          'engagement': '${(data['engagementRate'] as num?)?.toStringAsFixed(1) ?? "8.5"}%',
          'avatarColor': 0xFF3B82F6,
          'bio': data['description'] ?? data['bio'] ?? 'Truthworld content partner.',
          'packages': [
            {'type': '15s Mid-roll Sponsor', 'price': 3000.0},
            {'type': 'Pinned Comment Link', 'price': 1000.0},
          ],
        };
      }).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.fetchSponsorshipCreators');
    }
  }

  Future<void> createAudiencePreset(Map<String, dynamic> preset) async {
    final uid = AuthService.to.uid;
    preset['createdAt'] = FieldValue.serverTimestamp();
    preset['estimatedReach'] = preset['estimatedReach'] ?? 'Dynamic Network Reach';

    if (uid.isNotEmpty) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('audience_presets')
            .add(preset);
        preset['id'] = docRef.id;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.createAudiencePreset');
      }
    } else {
      preset['id'] = preset['id'] ?? 'aud_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!audiencePresets.any((p) => p['id'] == preset['id'])) {
      audiencePresets.insert(0, preset);
    }

    AppSnackbar.show(
      'Audience Preset Created',
      'Targeting preset "${preset['name']}" is ready to apply to ad campaigns.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> deleteAudiencePreset(String id) async {
    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('audience_presets')
            .doc(id)
            .delete();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.deleteAudiencePreset');
      }
    }
    audiencePresets.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Preset Removed',
      'Audience preset deleted.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> sendSponsorshipProposal(Map<String, dynamic> proposal) async {
    final uid = AuthService.to.uid;
    proposal['createdAt'] = FieldValue.serverTimestamp();

    if (uid.isNotEmpty) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('sponsorship_proposals')
            .add(proposal);
        proposal['id'] = docRef.id;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.sendSponsorshipProposal');
      }
    } else {
      proposal['id'] = proposal['id'] ?? 'prop_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!sponsorshipProposals.any((p) => p['id'] == proposal['id'])) {
      sponsorshipProposals.insert(0, proposal);
    }

    AppSnackbar.show(
      'Proposal Sent',
      'Sponsorship proposal dispatched to ${proposal['creatorName']}.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> cancelProposal(String id) async {
    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('sponsorship_proposals')
            .doc(id)
            .delete();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.cancelProposal');
      }
    }
    sponsorshipProposals.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Proposal Retracted',
      'Sponsorship proposal was cancelled.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> addCreativeAsset(Map<String, dynamic> asset) async {
    final uid = AuthService.to.uid;
    asset['createdAt'] = FieldValue.serverTimestamp();

    if (uid.isNotEmpty) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('creative_assets')
            .add(asset);
        asset['id'] = docRef.id;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.addCreativeAsset');
      }
    } else {
      asset['id'] = asset['id'] ?? 'asset_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!creativeAssetsList.any((a) => a['id'] == asset['id'])) {
      creativeAssetsList.insert(0, asset);
    }

    AppSnackbar.show(
      'Asset Uploaded',
      'Creative asset "${asset['title']}" saved to library.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> deleteCreativeAsset(String id) async {
    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('creative_assets')
            .doc(id)
            .delete();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.deleteCreativeAsset');
      }
    }
    creativeAssetsList.removeWhere((a) => a['id'] == id);
    AppSnackbar.show(
      'Asset Deleted',
      'Creative asset removed from your media library.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> createAbExperiment(Map<String, dynamic> experiment) async {
    final exp = Map<String, dynamic>.of(experiment);
    final uid = AuthService.to.uid;
    exp['createdAt'] = FieldValue.serverTimestamp();

    if (uid.isNotEmpty) {
      try {
        final docRef = await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .collection('ab_experiments')
            .add(exp);
        exp['id'] = docRef.id;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.createAbExperiment');
      }
    } else {
      exp['id'] = exp['id'] ?? 'exp_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!abExperimentsList.any((e) => e['id'] == exp['id'])) {
      abExperimentsList.insert(0, exp);
    }

    AppSnackbar.show(
      'A/B Test Launched',
      'Experiment "${experiment['title']}" is now splitting campaign traffic.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> declareExperimentWinner(String experimentId, String winningVariant) async {
    final idx = abExperimentsList.indexWhere((e) => e['id'] == experimentId);
    if (idx != -1) {
      abExperimentsList[idx]['status'] = 'Concluded';
      abExperimentsList.refresh();

      final uid = AuthService.to.uid;
      if (uid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('advertiser_profiles')
              .doc(uid)
              .collection('ab_experiments')
              .doc(experimentId)
              .update({'status': 'Concluded', 'winner': winningVariant});
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.declareExperimentWinner');
        }
      }

      AppSnackbar.show(
        'Winner Applied',
        '$winningVariant has been declared the winner and set as default.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> saveBrandSettings({
    required String name,
    required String tagline,
    required String website,
    required String email,
    required String category,
  }) async {
    brandName.value = name;
    brandTagline.value = tagline;
    brandWebsite.value = website;
    brandEmail.value = email;
    brandCategory.value = category;

    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('advertiser_profiles').doc(uid).set({
          'brandName': name,
          'brandTagline': tagline,
          'brandWebsite': website,
          'brandEmail': email,
          'brandCategory': category,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.saveBrandSettings');
      }
    }

    AppSnackbar.show(
      'Profile Saved',
      'Advertiser brand profile updated successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> inviteTeamMember(String name, String email, String role) async {
    final member = {
      'name': name,
      'email': email,
      'role': role,
      'status': 'Invited',
    };
    teamMembers.add(member);

    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('advertiser_profiles').doc(uid).set({
          'teamMembers': teamMembers.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.inviteTeamMember');
      }
    }

    AppSnackbar.show(
      'Invitation Sent',
      'An invitation to join Advertiser Studio was sent to $email.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> removeTeamMember(String email) async {
    teamMembers.removeWhere((m) => m['email'] == email);

    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('advertiser_profiles').doc(uid).set({
          'teamMembers': teamMembers.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.removeTeamMember');
      }
    }

    AppSnackbar.show(
      'Member Removed',
      'User $email was removed from team access.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> regenerateApiKey() async {
    final newKey = 'tw_live_ak_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    conversionApiKey.value = newKey;

    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('advertiser_profiles').doc(uid).set({
          'conversionApiKey': newKey,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdvertiserCampaignManagementMixin.regenerateApiKey');
      }
    }

    AppSnackbar.show(
      'API Key Regenerated',
      'New conversion tracking key generated.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }
}

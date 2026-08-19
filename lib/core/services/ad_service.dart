import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final String
  adType; // 'skippable', 'homepage', 'scroll', 'search', 'comment', 'video_sponsor'
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

  String get sponsorBumperText =>
      'This video is brought to you by ${advertiser.isNotEmpty ? advertiser : "our sponsor"}';

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
    };
  }
}

class AdService extends GetxService {
  static AdService get to {
    if (!Get.isRegistered<AdService>()) {
      Get.put(AdService(), permanent: true);
    }
    return Get.find<AdService>();
  }

  final RxList<AdItem> customCampaigns = <AdItem>[].obs;
  final _storage = GetStorage();

  Timer? _adRefreshTimer;
  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    _loadFromLocalCache();
    _listenToAdCampaigns();
    if (Get.isRegistered<AuthService>()) {
      _authWorker = ever(AuthService.to.currentUser, (_) {
        listenToUserInteractions();
      });
      listenToUserInteractions();
    }
  }

  @override
  void onClose() {
    _adRefreshTimer?.cancel();
    _authWorker?.dispose();
    super.onClose();
  }

  void _listenToAdCampaigns() {
    try {
      FirebaseFirestore.instance
          .collection('ad_campaigns')
          .snapshots()
          .listen(
            (snapshot) {
              final campaigns = <AdItem>[];
              for (final doc in snapshot.docs) {
                try {
                  campaigns.add(
                    AdItem.fromMap(Map<String, dynamic>.from(doc.data())),
                  );
                } catch (e) {
                  debugPrint('Failed to parse ad campaign from Firestore: $e');
                }
              }
              customCampaigns.assignAll(campaigns);
              _syncToLocalCache();
              if (Get.isRegistered<HomeFeedController>()) {
                Get.find<HomeFeedController>().mixHomeFeed();
              }
            },
            onError: (err) {
              if (err.toString().contains('permission-denied')) {
                debugPrint(
                  '[AdService] Ad campaigns stream restricted by Firestore security rules. Local cache/mock database is active. Please update your Firestore security rules to allow read on "ad_campaigns" to synchronize custom advertiser campaigns globally.',
                );
              } else {
                debugPrint('Ad campaigns Firestore stream error: $err');
              }
            },
          );
    } catch (e) {
      debugPrint('Ad campaigns Firestore listen failed: $e');
    }
  }

  void _syncToLocalCache() {
    try {
      final rawList = customCampaigns.map((ad) => ad.toMap()).toList();
      _storage.write('local_ad_campaigns', rawList);
    } catch (e) {
      debugPrint('Failed to save ad campaigns to cache: $e');
    }
  }

  void _loadFromLocalCache() {
    try {
      _loadUserInteractionCounts();
      final cachedHidden = _storage.read<List<dynamic>>('hidden_ad_ids');
      if (cachedHidden != null) {
        hiddenAdIds.assignAll(cachedHidden.cast<String>());
      }
      final cached = _storage.read<List<dynamic>>('local_ad_campaigns');
      if (cached != null) {
        customCampaigns.assignAll(
          cached
              .map((item) => AdItem.fromMap(Map<String, dynamic>.from(item)))
              .toList(),
        );
        _syncLocalCampaignsToFirestore();
      }
    } catch (e) {
      debugPrint('Failed to load ad campaigns from cache: $e');
    }
  }

  Future<bool> createCampaign(AdItem ad) async {
    try {
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .set(ad.toMap());

      if (ad.videoId != null && ad.videoId!.isNotEmpty) {
        _setupAdResolutions(ad.id, ad.videoId!);
      }

      // The Firestore stream listener will update the list and sync cache
      _syncLocalCampaignsToFirestore();
      return true;
    } catch (e) {
      debugPrint('Save campaign to Firestore failed: $e');
      // Offline fallback: update local memory and cache directly
      customCampaigns.add(ad);
      _syncToLocalCache();
      return true;
    }
  }

  void _syncLocalCampaignsToFirestore() {
    for (final ad in customCampaigns) {
      FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .set(ad.toMap())
          .catchError((e) {
        debugPrint('[AdService] Syncing local campaign to Firestore error: $e');
      });
    }
  }

  Future<void> _setupAdResolutions(String adId, String videoId) async {
    try {
      debugPrint(
        '[AdService] 🔄 Setting up separate ad resolutions for video: $videoId',
      );

      final sourceDoc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(videoId)
          .get();

      if (!sourceDoc.exists) {
        debugPrint(
          '[AdService] ⚠️ No source resolutions found in resolution_jobs for video: $videoId',
        );
        return;
      }

      final data = sourceDoc.data();
      if (data == null || data['variants'] == null) return;

      final variants = data['variants'] as Map<String, dynamic>;
      final newVariants = <String, dynamic>{};
      final campaignResolutions = <Map<String, dynamic>>[];

      for (final entry in variants.entries) {
        final variantLabel = entry.key;
        final variantData = entry.value as Map<String, dynamic>;

        if (variantData['status'] == 'completed') {
          final sourcePath = variantData['outputPath'] as String?;
          if (sourcePath != null && sourcePath.isNotEmpty) {
            final targetPath = 'ad_resolutions/$videoId/$variantLabel.mp4';

            try {
              debugPrint(
                '[AdService] 📦 Copying Storage file: $sourcePath -> $targetPath',
              );
              final sourceRef = FirebaseStorage.instance.ref().child(
                sourcePath,
              );
              final targetRef = FirebaseStorage.instance.ref().child(
                targetPath,
              );

              final bytes = await sourceRef.getData();
              if (bytes != null) {
                await targetRef.putData(
                  bytes,
                  SettableMetadata(contentType: 'video/mp4'),
                );
                debugPrint(
                  '[AdService] ✅ Copied Storage file successfully to $targetPath',
                );

                // Fetch direct download URL for the target file
                String downloadUrl;
                try {
                  downloadUrl = await targetRef.getDownloadURL();
                } catch (sdkError) {
                  downloadUrl = StorageUtils.getFastDownloadUrl(targetPath);
                }

                campaignResolutions.add({
                  'label': variantLabel,
                  'url': downloadUrl,
                  'width': variantData['width'] ?? 0,
                  'height': variantData['height'] ?? 0,
                  'bitrate': variantData['bitrate'] ?? 0,
                });
              }
            } catch (storageErr) {
              debugPrint(
                '[AdService] ❌ Failed to copy Storage file: $storageErr',
              );
            }

            newVariants[variantLabel] = {
              ...variantData,
              'outputPath': targetPath,
            };
          }
        } else {
          newVariants[variantLabel] = variantData;
        }
      }

      final newJobData = {
        ...data,
        'variants': newVariants,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('ad_resolution_jobs')
          .doc(videoId)
          .set(newJobData);

      debugPrint(
        '[AdService] 🎉 Successfully created ad resolutions document in ad_resolution_jobs for video: $videoId',
      );

      // Update the campaign document directly in Firestore with the resolutions list
      if (campaignResolutions.isNotEmpty) {
        debugPrint(
          '[AdService] 📝 Saving resolved links directly to ad_campaigns document: $adId',
        );
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(adId)
            .update({'resolutions': campaignResolutions});
      }
    } catch (e) {
      debugPrint('[AdService] ❌ Error setting up ad resolutions: $e');
    }
  }

  Future<bool> toggleCampaignStatus(String adId) async {
    try {
      final index = customCampaigns.indexWhere((ad) => ad.id == adId);
      if (index == -1) return false;
      final currentAd = customCampaigns[index];

      if (currentAd.status == 'underReview' ||
          currentAd.status == 'verification_rejected') {
        AppSnackbar.show(
          'Moderation Gated',
          'Cannot activate campaign. The campaign is currently ${currentAd.status == 'underReview' ? 'under review' : 'rejected'}.',
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final newStatus = currentAd.status == 'active' ? 'paused' : 'active';
      final updatedAd = currentAd.copyWith(status: newStatus);

      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(adId)
          .update({'status': newStatus});

      customCampaigns[index] = updatedAd;
      _syncToLocalCache();
      return true;
    } catch (e) {
      debugPrint('Toggle campaign status failed: $e');
      final index = customCampaigns.indexWhere((ad) => ad.id == adId);
      if (index != -1) {
        final currentAd = customCampaigns[index];
        final newStatus = currentAd.status == 'active' ? 'paused' : 'active';
        customCampaigns[index] = currentAd.copyWith(status: newStatus);
        _syncToLocalCache();
      }
      return true;
    }
  }

  Future<bool> updateCampaign(AdItem ad) async {
    try {
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .set(ad.toMap(), SetOptions(merge: true));

      final index = customCampaigns.indexWhere((item) => item.id == ad.id);
      if (index != -1) {
        customCampaigns[index] = ad;
      }
      _syncToLocalCache();
      return true;
    } catch (e) {
      debugPrint('Update campaign failed: $e');
      final index = customCampaigns.indexWhere((item) => item.id == ad.id);
      if (index != -1) {
        customCampaigns[index] = ad;
      }
      _syncToLocalCache();
      return true;
    }
  }

  Future<bool> deleteCampaign(String adId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(adId)
          .delete();

      customCampaigns.removeWhere((ad) => ad.id == adId);
      _syncToLocalCache();
      return true;
    } catch (e) {
      debugPrint('Delete campaign failed: $e');
      customCampaigns.removeWhere((ad) => ad.id == adId);
      _syncToLocalCache();
      return true;
    }
  }

  final Map<String, DateTime> _lastImpressionTimes = {};
  final Map<String, DateTime> _lastClickTimes = {};
  final Map<String, int> _userAdImpressionCounts = {};
  final Map<String, int> _userAdClickCounts = {};

  void _loadUserInteractionCounts() {
    try {
      final cachedClicks =
          _storage.read<Map<String, dynamic>>('user_ad_clicks');
      if (cachedClicks != null) {
        _userAdClickCounts.clear();
        cachedClicks.forEach((k, v) {
          if (v is int) _userAdClickCounts[k] = v;
          if (v is num) _userAdClickCounts[k] = v.toInt();
        });
      }
      final cachedImpressions =
          _storage.read<Map<String, dynamic>>('user_ad_impressions');
      if (cachedImpressions != null) {
        _userAdImpressionCounts.clear();
        cachedImpressions.forEach((k, v) {
          if (v is int) _userAdImpressionCounts[k] = v;
          if (v is num) _userAdImpressionCounts[k] = v.toInt();
        });
      }
    } catch (e) {
      debugPrint('[AdService] Error loading user interaction counts: $e');
    }
  }

  void _saveUserClickCount(String key, int count) {
    _userAdClickCounts[key] = count;
    try {
      final raw = _storage.read('user_ad_clicks');
      final map = raw != null ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      map[key] = count;
      _storage.write('user_ad_clicks', map);
    } catch (_) {}
  }

  void _saveUserImpressionCount(String key, int count) {
    _userAdImpressionCounts[key] = count;
    try {
      final raw = _storage.read('user_ad_impressions');
      final map = raw != null ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      map[key] = count;
      _storage.write('user_ad_impressions', map);
    } catch (_) {}
  }

  Future<void> recordImpression(String adId) async {
    final uid = AuthService.to.uid.isNotEmpty ? AuthService.to.uid : 'guest';
    final key = '${uid}_$adId';

    // Maximum 10 impressions per user per ad campaign to prevent impression inflation
    final currentCount = _userAdImpressionCounts[key] ?? 0;
    if (currentCount >= 10) {
      debugPrint(
        '[AdService] Impression limit reached (max 10) for user $uid on campaign $adId',
      );
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastImpressionTimes[key];
    // 3-second viewability cooldown per user per ad
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) return;
    _lastImpressionTimes[key] = now;
    _saveUserImpressionCount(key, currentCount + 1);

    // Update in-memory state instantly for zero-latency UI updates
    final idx = customCampaigns.indexWhere((a) => a.id == adId);
    if (idx != -1) {
      final current = customCampaigns[idx];
      customCampaigns[idx] = current.copyWith(
        impressions: current.impressions + 1,
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(adId)
          .update({'impressions': FieldValue.increment(1)});
      debugPrint('Recorded impression for campaign: $adId');
    } catch (e) {
      debugPrint('Failed to record impression for $adId: $e');
    }
  }

  Future<void> recordClick(String adId) async {
    final uid = AuthService.to.uid.isNotEmpty ? AuthService.to.uid : 'guest';
    final key = '${uid}_$adId';

    // Maximum 3 clicks per user per ad campaign to prevent click spam/fraud
    final currentCount = _userAdClickCounts[key] ?? 0;
    if (currentCount >= 3) {
      debugPrint(
        '[AdService] Click limit reached (max 3) for user $uid on campaign $adId',
      );
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastClickTimes[key];
    // 5-second anti-spam cooldown per user per ad
    if (lastTime != null && now.difference(lastTime).inSeconds < 5) return;
    _lastClickTimes[key] = now;
    _saveUserClickCount(key, currentCount + 1);

    // Update in-memory state instantly for zero-latency UI updates
    final idx = customCampaigns.indexWhere((a) => a.id == adId);
    if (idx != -1) {
      final current = customCampaigns[idx];
      customCampaigns[idx] = current.copyWith(clicks: current.clicks + 1);
    }

    try {
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(adId)
          .update({'clicks': FieldValue.increment(1)});
      debugPrint('Recorded click for campaign: $adId');
    } catch (e) {
      debugPrint('Failed to record click for $adId: $e');
    }
  }

  /// Check if ads should be rendered based on user's premium status and real campaigns availability
  RxBool get showAds => RxBool(
    Get.isRegistered<AuthService>() &&
        !AuthService.to.isPremiumUser.value &&
        customCampaigns.any((ad) => ad.status == 'active'),
  );

  bool hasAdsForType(String type) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value) {
      return false;
    }
    return customCampaigns.any(
      (ad) => ad.adType == type && ad.status == 'active',
    );
  }

  /// Retrieve ad dynamically by list/grid index
  AdItem getAdForIndex(int index) {
    final activeCampaigns = customCampaigns
        .where((ad) => ad.status == 'active')
        .toList();
    if (activeCampaigns.isEmpty) {
      return const AdItem(
        id: 'fallback',
        userId: 'mock',
        advertiser: 'Sponsor',
        title: 'Premium Advertisement',
        description: 'Support Truthworld.',
        imageUrl: '',
        ctaText: 'Learn More',
        ctaTarget: 'fallback',
        gradientColors: [AppColors.bgPage, AppColors.bgPage],
      );
    }
    return activeCampaigns[index % activeCampaigns.length];
  }

  /// Get specific ads based on target adType
  List<AdItem> getAdsForType(String type) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value) {
      return [];
    }
    return customCampaigns
        .where(
          (ad) =>
              ad.adType == type &&
              ad.status == 'active' &&
              !hiddenAdIds.contains(ad.id),
        )
        .toList();
  }

  /// Get list of active skippable video ads
  List<AdItem> getSkippableVideoAds() {
    if (Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value) {
      return [];
    }
    return customCampaigns
        .where(
          (ad) =>
              ad.isSkippableAd &&
              ad.videoUrl != null &&
              ad.videoUrl!.isNotEmpty &&
              ad.status == 'active',
        )
        .toList();
  }

  /// Get active video sponsor campaign for a given video ID (or fallback to any active sponsor ad)
  AdItem? getSponsorAdForVideo(String? videoId) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value) {
      return null;
    }
    if (videoId == null || videoId.isEmpty) {
      return customCampaigns.firstWhereOrNull(
        (ad) => ad.adType == 'video_sponsor' && ad.status == 'active',
      );
    }
    return customCampaigns.firstWhereOrNull(
          (ad) =>
              ad.adType == 'video_sponsor' &&
              ad.status == 'active' &&
              ad.videoId == videoId,
        ) ??
        customCampaigns.firstWhereOrNull(
          (ad) => ad.adType == 'video_sponsor' && ad.status == 'active',
        );
  }

  /// Launch Call-To-Action (CTA) target URL in external browser/app
  Future<void> launchCtaUrl(AdItem ad) async {
    recordClick(ad.id);
    final rawTarget = ad.ctaTarget.trim();
    if (rawTarget.isEmpty) return;

    if (rawTarget == '/premium') {
      Get.toNamed('/premium');
      return;
    }

    var formattedUrl = rawTarget;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      final uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[AdService] Error launching CTA URL $formattedUrl: $e');
    }
  }

  /// Interactive Premium Ad Dialog Showcase
  void showAdPromoDialog(BuildContext context, AdItem ad) {
    recordClick(ad.id);
    if (ad.ctaTarget == '/premium') {
      Get.toNamed('/premium');
      return;
    }

    final isSimulatingVisit = false.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Semantics(
          label: 'Advertisement Dialog',
          container: true,
          namesRoute: true,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161616).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgPage.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header Sponsor Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'SPONSORED',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ad Visual Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ad.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Backdrop effect or fallback icon
                        Center(
                          child: Icon(
                            ad.fallbackIcon ?? Icons.ads_click_rounded,
                            size: 72,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(
                            ad.advertiser,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: AppColors.bgPage.withValues(
                                    alpha: 0.6,
                                  ),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title and Description
                Text(
                  ad.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ad.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Loader or Buttons
                Obx(() {
                  if (isSimulatingVisit.value) {
                    return Column(
                      children: [
                        Shimmer.fromColors(
                          baseColor: AppColors.error.withValues(alpha: 0.3),
                          highlightColor: AppColors.error,
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Opening sponsored page securely...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      // Primary Visit Button
                      ElevatedButton(
                        onPressed: () async {
                          isSimulatingVisit.value = true;
                          await launchCtaUrl(ad);
                          isSimulatingVisit.value = false;
                          if (Get.isDialogOpen ?? false) {
                            Get.back();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.bgPage,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ad.ctaText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bypass/Remove Ads Option
                      TextButton(
                        onPressed: () {
                          Get.back();
                          Get.toNamed('/premium');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text(
                          'Remove Ads (Get Premium)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // USER AD INTERACTIONS (LIKE, SAVE, COMMENT)
  // ========================================================================
  final RxSet<String> likedAdIds = <String>{}.obs;
  final RxSet<String> savedAdIds = <String>{}.obs;
  StreamSubscription? _likesSubscription;
  StreamSubscription? _savesSubscription;

  void listenToUserInteractions() {
    _likesSubscription?.cancel();
    _savesSubscription?.cancel();
    likedAdIds.clear();
    savedAdIds.clear();

    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    _likesSubscription = FirebaseFirestore.instance
        .collection('ad_likes')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            likedAdIds.assignAll(
              snapshot.docs.map((doc) => doc.data()['adId'] as String),
            );
          },
          onError: (err) {
            if (err.toString().contains('permission-denied')) {
              debugPrint(
                '[AdService] ad_likes stream restricted by Firestore security rules. Local memory state active.',
              );
            } else {
              debugPrint('[AdService] ad_likes stream error: $err');
            }
          },
        );

    _savesSubscription = FirebaseFirestore.instance
        .collection('ad_saves')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            savedAdIds.assignAll(
              snapshot.docs.map((doc) => doc.data()['adId'] as String),
            );
          },
          onError: (err) {
            if (err.toString().contains('permission-denied')) {
              debugPrint(
                '[AdService] ad_saves stream restricted by Firestore security rules. Local memory state active.',
              );
            } else {
              debugPrint('[AdService] ad_saves stream error: $err');
            }
          },
        );
  }

  Future<void> toggleLikeAd(String adId) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to like ads.');
      return;
    }

    final isLiked = likedAdIds.contains(adId);
    if (isLiked) {
      likedAdIds.remove(adId);
    } else {
      likedAdIds.add(adId);
    }

    try {
      final docId = '${uid}_$adId';
      final ref = FirebaseFirestore.instance.collection('ad_likes').doc(docId);
      if (isLiked) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': uid,
          'adId': adId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[AdService] Firestore ad_likes write notice: $e');
    }
  }

  Future<void> toggleSaveAd(String adId) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to save ads.');
      return;
    }

    final isSaved = savedAdIds.contains(adId);
    if (isSaved) {
      savedAdIds.remove(adId);
    } else {
      savedAdIds.add(adId);
    }

    try {
      final docId = '${uid}_$adId';
      final ref = FirebaseFirestore.instance.collection('ad_saves').doc(docId);
      if (isSaved) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': uid,
          'adId': adId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[AdService] Firestore ad_saves write notice: $e');
    }
  }

  final RxSet<String> hiddenAdIds = <String>{}.obs;

  Future<void> reportAd({
    required AdItem ad,
    required String reason,
    String details = '',
  }) async {
    final uid = AuthService.to.uid;
    final userName = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : 'Anonymous User';
    final userEmail = AuthService.to.user?.email ?? '';

    // Hide ad locally for this user session & persist permanently
    hiddenAdIds.add(ad.id);
    try {
      _storage.write('hidden_ad_ids', hiddenAdIds.toList());
    } catch (_) {}

    customCampaigns.refresh();
    if (Get.isRegistered<HomeFeedController>()) {
      Get.find<HomeFeedController>().mixHomeFeed();
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('ad_reports').doc();
      await docRef.set({
        'id': docRef.id,
        'adId': ad.id,
        'advertiser': ad.advertiser,
        'campaignTitle': ad.title,
        'userId': uid,
        'userName': userName,
        'userEmail': userEmail,
        'reason': reason,
        'details': details,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      // Increment report count on ad_campaigns doc
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AdService] Report ad Firestore write notice: $e');
    }

    AppSnackbar.show(
      'Ad Reported',
      'Thank you for your feedback. We have hidden this ad.',
    );
  }

  void showReportAdDialog(BuildContext context, AdItem ad) {
    final reasons = [
      'Inappropriate or Offensive Content',
      'Misleading, False or Scam Ad',
      "Repetitive / Don't want to see this ad",
      'Copyright or Intellectual Property Violation',
      'Harmful, Dangerous or illegal',
      'Other',
    ];

    final selectedReason = reasons.first.obs;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgDivider),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.report_problem_rounded,
                color: AppColors.warning,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Report Advertisement',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you reporting "${ad.title}" by ${ad.advertiser}?',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => Column(
                    children: reasons.map((r) {
                      final isSelected = selectedReason.value == r;
                      return RadioListTile<String>(
                        value: r,
                        groupValue: selectedReason.value,
                        activeColor: AppColors.warning,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          r,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            selectedReason.value = val;
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                reportAd(
                  ad: ad,
                  reason: selectedReason.value,
                  details: detailsController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> addAdComment(String adId, String text) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to comment.');
      return;
    }

    final userName = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : 'Anonymous';
    final userProfilePicUrl = AuthService.to.activePhotoUrl;

    final ref = FirebaseFirestore.instance.collection('ad_comments').doc();
    await ref.set({
      'id': ref.id,
      'adId': adId,
      'userId': uid,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> replyToAdComment(
    String commentId,
    String replyText,
    String advertiserName,
  ) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('ad_comments')
        .doc(commentId)
        .update({
          'replyText': replyText,
          'repliedAt': DateTime.now().toIso8601String(),
          'repliedBy': advertiserName,
        });
  }

  Stream<List<AdComment>> getAdCommentsStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_comments')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map((doc) => AdComment.fromMap(doc.data(), doc.id))
              .toList();
          comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return comments;
        })
        .handleError((err) {
          debugPrint('[AdService] ad_comments stream notice: $err');
          return <AdComment>[];
        });
  }

  Stream<int> getAdCommentsCountStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_comments')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((err) {
          debugPrint('[AdService] ad_comments count stream notice: $err');
          return 0;
        });
  }

  Stream<int> getAdLikesCountStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_likes')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((err) {
          debugPrint('[AdService] ad_likes count stream notice: $err');
          return 0;
        });
  }

  void showAdCommentsBottomSheet(BuildContext context, AdItem ad) {
    final textController = TextEditingController();

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Comments for ${ad.advertiser}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: Get.back,
                ),
              ],
            ),
            const Divider(color: AppColors.bgDivider),
            Expanded(
              child: StreamBuilder<List<AdComment>>(
                stream: getAdCommentsStream(ad.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.warning,
                      ),
                    );
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Be the first to share your thoughts!',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  radius: 14,
                                  photoUrl: comment.userProfilePicUrl,
                                  displayName: comment.userName,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 36, top: 4),
                              child: Text(
                                comment.text,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (comment.replyText != null)
                              Container(
                                margin: const EdgeInsets.only(left: 36, top: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.campaign_rounded,
                                          size: 14,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${comment.repliedBy ?? 'Advertiser'} (Sponsor)',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment.replyText!,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(color: AppColors.bgDivider),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppColors.warning,
                  ),
                  onPressed: () {
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      addAdComment(ad.id, text);
                      textController.clear();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class AdComment {
  AdComment({
    required this.id,
    required this.adId,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.text,
    required this.createdAt,
    this.replyText,
    this.repliedAt,
    this.repliedBy,
  });

  factory AdComment.fromMap(Map<String, dynamic> map, String docId) {
    return AdComment(
      id: docId,
      adId: map['adId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      userProfilePicUrl: map['userProfilePicUrl'] ?? '',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      replyText: map['replyText'],
      repliedAt: map['repliedAt'] != null
          ? DateTime.parse(map['repliedAt'])
          : null,
      repliedBy: map['repliedBy'],
    );
  }
  final String id;
  final String adId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String text;
  final DateTime createdAt;
  final String? replyText;
  final DateTime? repliedAt;
  final String? repliedBy;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adId': adId,
      'userId': userId,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'replyText': replyText,
      'repliedAt': repliedAt?.toIso8601String(),
      'repliedBy': repliedBy,
    };
  }
}

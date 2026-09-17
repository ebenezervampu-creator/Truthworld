import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

mixin AdCampaignMixin on GetxService {
  final RxList<AdItem> customCampaigns = <AdItem>[].obs;

  /// Persisted set of ad IDs this user has reported/hidden.
  /// Declared here because _loadFromLocalCache (below) reads it on startup.
  final RxSet<String> hiddenAdIds = <String>{}.obs;

  GetStorage? _storageInstance;
  GetStorage? get storage {
    try {
      return _storageInstance ??= GetStorage();
    } catch (_) {
      return null;
    }
  }

  void loadFromLocalCache() => _loadFromLocalCache();
  void listenToAdCampaigns() => _listenToAdCampaigns();
  void syncToLocalCache() => _syncToLocalCache();

  // Overridden by AdMetricsMixin to load per-user impression/click counts.
  void loadUserInteractionCounts() {}

  void _listenToAdCampaigns() {
    try {
      // Bounded query: only active campaigns, limit 100.
      // Prevents full collection download as ad inventory grows.
      // Inactive/archived campaigns are excluded client-side — they are
      // never served to users and should not occupy client memory.
      FirebaseFirestore.instance
          .collection('ad_campaigns')
          .where('status', isEqualTo: 'active')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final campaigns = <AdItem>[];
              for (final doc in snapshot.docs) {
                try {
                  campaigns.add(
                    AdItem.fromMap(Map<String, dynamic>.from(doc.data())),
                  );
                } catch (e, s) {
                  ErrorHandler.log(e, stackTrace: s, tag: 'AdService.parseCampaign');
                }
              }
              customCampaigns.assignAll(campaigns);
              _syncToLocalCache();
              if (Get.isRegistered<HomeFeedController>()) {
                Get.find<HomeFeedController>().mixHomeFeed();
              }
            },
            onError: (e, stackTrace) {
              ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdService.campaignListener');
            },
          );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdService.campaignSetup');
    }
  }

  void _syncToLocalCache() {
    try {
      final rawList = customCampaigns.map((ad) => ad.toMap()).toList();
      storage?.write('local_ad_campaigns', rawList);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.syncToLocalCache');
    }
  }

  void _loadFromLocalCache() {
    try {
      loadUserInteractionCounts();
      final cachedHidden = storage?.read<List<dynamic>>('hidden_ad_ids');
      if (cachedHidden != null) {
        hiddenAdIds.assignAll(cachedHidden.cast<String>());
      }
      final cached = storage?.read<List<dynamic>>('local_ad_campaigns');
      if (cached != null) {
        customCampaigns.assignAll(
          cached
              .map((item) => AdItem.fromMap(Map<String, dynamic>.from(item)))
              .toList(),
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.loadFromLocalCache');
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
      return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.createCampaign');
      // Offline fallback: update local memory and cache directly
      customCampaigns.add(ad);
      _syncToLocalCache();
      return true;
    }
  }

  void _syncLocalCampaignsToFirestore() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    for (final ad in customCampaigns) {
      if (ad.userId == currentUser.uid) {
        FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(ad.id)
            .set(ad.toMap())
            .catchError((e) {
          debugPrint('[AdService] Syncing local campaign to Firestore error: $e');
        });
      }
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
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                await targetRef.putData(
                  bytes,
                  SettableMetadata(
                    contentType: 'video/mp4',
                    customMetadata: {
                      'uploaderId': ?currentUid,
                    },
                  ),
                );
                debugPrint(
                  '[AdService] ✅ Copied Storage file successfully to $targetPath',
                );

                // Fetch direct download URL for the target file
                String downloadUrl;
                try {
                  downloadUrl = await targetRef.getDownloadURL();
                } catch (sdkError, sdkStack) {
                  ErrorHandler.log(sdkError, stackTrace: sdkStack, tag: 'AdService.setupAdResolutions.downloadUrl');
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
            } catch (storageErr, storageStack) {
              ErrorHandler.log(
                storageErr,
                stackTrace: storageStack,
                tag: 'AdService.setupAdResolutions.copyStorage',
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.setupAdResolutions');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.toggleCampaignStatus');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.updateCampaign');
      final index = customCampaigns.indexWhere((item) => item.id == ad.id);
      if (index != -1) {
        customCampaigns[index] = ad;
      }
      _syncToLocalCache();
      return true;
    }
  }

  Future<bool> addFundsToCampaign(
    String campaignId,
    double additionalAmount, {
    bool syncRemoteBudget = true,
  }) async {
    try {
      final index = customCampaigns.indexWhere((item) => item.id == campaignId);
      AdItem? updatedAd;
      if (index != -1) {
        final current = customCampaigns[index];
        final newBudget = current.totalBudget + additionalAmount;
        final newStatus = (current.status == 'paused' && current.remaining <= 0)
            ? 'active'
            : current.status;
        updatedAd = current.copyWith(
          budgetAmount: newBudget,
          status: newStatus,
        );
        customCampaigns[index] = updatedAd;
        _syncToLocalCache();
      }

      if (syncRemoteBudget) {
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(campaignId)
            .set({
              'budgetAmount': FieldValue.increment(additionalAmount),
              if (updatedAd != null && updatedAd.status == 'active')
                'status': 'active',
            }, SetOptions(merge: true));
      } else if (updatedAd != null && updatedAd.status == 'active') {
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(campaignId)
            .set({
              'status': 'active',
            }, SetOptions(merge: true));
      }

      _syncToLocalCache();
      return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.addFundsToCampaign');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.deleteCampaign');
      customCampaigns.removeWhere((ad) => ad.id == adId);
      _syncToLocalCache();
      return true;
    }
  }
}

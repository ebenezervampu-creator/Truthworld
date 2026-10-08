import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/modules/advertiser_modules.dart';

export 'package:truthworld/features/advertiser/presentation/controllers/modules/advertiser_modules.dart';

class AdvertiserPortalController extends BaseController
    with
        AdvertiserLanguagesMixin,
        AdvertiserSubtitlesMixin,
        AdvertiserAudioDubsMixin,
        AdvertiserBillingMixin,
        AdvertiserCampaignManagementMixin {
  final RxInt selectedIndex = 0.obs;
  final RxString selectedMetric = 'spend'.obs; // 'spend', 'impressions', 'clicks', 'ctr'
  final RxList<Map<String, dynamic>> channelVideos = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingVideos = false.obs;
  final RxBool isSigningIn = false.obs;

  final List<String> tabTitles = [
    'Advertiser Dashboard',
    'My Campaigns',
    'Performance Reports',
    'AI Video Subtitles',
    'AI Audio Dubbing',
    'Billing & Invoices',
    'Audience & Targeting',
    'Creator Sponsorships',
    'Creative Assets',
    'A/B Testing & Optimization',
    'Brand Settings',
  ];

  @override
  void onInit() {
    super.onInit();
    if (Get.testMode) return;
    fetchChannelVideos();
    listenToBillingData();
    initCampaignManagement();
    // Fetch videos and billing data when user gets authenticated
    addWorker(ever(AuthService.to.isAuthenticated, (_) {
      fetchChannelVideos();
      listenToBillingData();
      initCampaignManagement();
    }));
    // Sync active campaign selections with real-time AdService campaigns list
    if (Get.isRegistered<AdService>()) {
      addWorker(ever(AdService.to.customCampaigns, _syncSelectedAds));
    }
  }

  @override
  void onClose() {
    disposeSubtitles();
    disposeAudioDubs();
    disposeBilling();
    disposeCampaignManagement();
    super.onClose();
  }

  void _syncSelectedAds(List<AdItem> campaigns) {
    if (selectedAdForSubtitles.value != null) {
      final updated = campaigns.firstWhereOrNull((a) => a.id == selectedAdForSubtitles.value!.id);
      if (updated != null) {
        selectedAdForSubtitles.value = updated;
      }
    }
    if (selectedAdForAudio.value != null) {
      final updated = campaigns.firstWhereOrNull((a) => a.id == selectedAdForAudio.value!.id);
      if (updated != null) {
        selectedAdForAudio.value = updated;
      }
    }
  }

  Future<void> fetchChannelVideos() async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      channelVideos.clear();
      return;
    }

    try {
      isLoadingVideos.value = true;
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      channelVideos.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Video',
          'thumbnail': data['thumbnailUrl'] ?? '',
          'views': data['viewsCount'] ?? 0,
          'duration': data['duration'] ?? 0,
        };
      }).toList();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AdvertiserPortalController.fetchChannelVideos',
      );
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> handleGoogleSignIn() async {
    try {
      isSigningIn.value = true;
      await AuthService.to.signInWithGoogle();
      AppSnackbar.success(
        'Successfully signed into Advertiser Studio!',
        title: 'Welcome Back',
      );
    } catch (e) {
      if (e is GoogleSignInException && e.code == 'redirecting') {
        return;
      }
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete Google sign-in. Please try again.',
      );
    } finally {
      isSigningIn.value = false;
    }
  }
}

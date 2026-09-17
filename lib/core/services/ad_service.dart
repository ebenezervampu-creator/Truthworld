import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad/ad_components.dart';
import 'package:truthworld/core/services/auth_service.dart';

// 100% Backward Compatibility re-export
export 'package:truthworld/core/services/ad/ad_components.dart';

/// Redesigned Industry-Standard Modular Ad Service for Truthworld.
///
/// Coordinates campaign lifecycles, user targeting, metrics tracking,
/// social feedback, and presentation modal dialogs through clean,
/// single-responsibility mixins and components.
class AdService extends GetxService
    with AdCampaignMixin, AdMetricsMixin, AdTargetingMixin, AdSocialMixin {
  static AdService get to {
    if (!Get.isRegistered<AdService>()) {
      Get.put(AdService(), permanent: true);
    }
    return Get.find<AdService>();
  }

  Timer? _adRefreshTimer;
  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    loadFromLocalCache();
    listenToAdCampaigns();
    loadUserInteractionCounts();
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

  // ========================================================================
  // PRESENTATION DIALOGS DELEGATION
  // ========================================================================

  /// Interactive Premium Ad Dialog Showcase
  void showAdPromoDialog(BuildContext context, AdItem ad) {
    showAdPromoDialogModal(
      context: context,
      ad: ad,
      onRecordClick: () => recordClick(ad.id),
      onLaunchCtaUrl: launchCtaUrl,
    );
  }

  /// Interactive Ad Reporting Dialog
  void showReportAdDialog(BuildContext context, AdItem ad) {
    showReportAdDialogModal(
      context: context,
      ad: ad,
      onReportAd: reportAd,
    );
  }

  /// Real-time Streaming Comments Bottom Sheet for Ads
  void showAdCommentsBottomSheet(BuildContext context, AdItem ad) {
    showAdCommentsBottomSheetModal(
      context: context,
      ad: ad,
      onAddComment: addAdComment,
    );
  }
}

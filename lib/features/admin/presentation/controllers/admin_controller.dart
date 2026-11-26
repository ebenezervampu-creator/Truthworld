import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_components.dart';
import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_entity_moderation_service.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_analytics_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_audit_log_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_auth_team_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_content_moderation_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_dubbing_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_feedback_language_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_security_alerts_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_user_management_mixin.dart';

export 'admin/admin_components.dart';

/// Central Administration Controller for TruthWorld.
/// Integrates domain-specific mixins for authentication, content moderation,
/// user management, platform analytics, security escalation, user feedback, and dubbing administration.
class AdminController extends BaseController
    with
        AdminAuditLogMixin,
        AdminAuthTeamMixin,
        AdminContentModerationMixin,
        AdminUserManagementMixin,
        AdminDubbingMixin,
        AdminAnalyticsMixin,
        AdminSecurityAlertsMixin,
        AdminFeedbackLanguageMixin,
        AdminModerationModesMixin {
  static AdminController get to => Get.find<AdminController>();

  @override
  final RxBool rxIsLoading = false.obs;

  // Backward-compatible delegators for mixin-provided methods
  void _restoreAdminSession() => restoreAdminSession();
  void _listenToAdminMembers() => listenToAdminMembers();
  Future<void> _ensureDefaultAdminSeeded() => ensureDefaultAdminSeeded();
  void _navigateToDashboardIfOnLogin() => navigateToDashboardIfOnLogin();
  void _startAppealsSubscription() => startAppealsSubscription();

  @override
  bool get isLoading => rxIsLoading.value || super.isLoading;
  final RxString currentTab = 'dashboard'.obs;
  final RxInt selectedTabIndex = 0.obs;

  // Real-time audit logs collection
  final RxList<Map<String, dynamic>> auditLogs = <Map<String, dynamic>>[].obs;

  // Channel Economics & Spendings State (Super Admin Only)
  final Rxn<Map<String, dynamic>> channelEconomics = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingChannelEconomics = false.obs;

  bool get isSuperAdmin => AdminRolesConfig.isSuperAdmin(
        isAdmin: isAdmin.value,
        isPrimaryOwner: isPrimaryOwner,
        currentAdminEmail: currentAdminEmail.value,
        currentAdminRole: currentAdminRole.value,
        currentAdminRoles: currentAdminRoles,
      );

  @override
  void clearSelectedItems() {
    selectedVideo.value = null;
    selectedImage.value = null;
    selectedChannel.value = null;
    selectedReport.value = null;
    selectedTopic.value = null;
    selectedAd.value = null;
    channelEconomics.value = null;
  }

  @override
  void startSubscriptions() => _startSubscriptions();

  @override
  void stopSubscriptions() => _stopSubscriptions();

  // ── Roles & Owner Configuration ───────────────────────────
  static const String ownerEmail = AdminRolesConfig.ownerEmail;
  static const List<String> authorizedOwnerEmails =
      AdminRolesConfig.authorizedOwnerEmails;
  static const List<Map<String, dynamic>> availableRoles =
      AdminRolesConfig.availableRoles;
  static const List<String> allRoleNames = AdminRolesConfig.allRoleNames;

  // ── Stream Subscriptions Manager ──────────────────────────
  StreamSubscription<User?>? _authSub;
  final AdminSubscriptionsManager _subscriptionsManager =
      AdminSubscriptionsManager();

  @override
  void onInit() {
    super.onInit();
    if (emailController.text.isEmpty) {
      emailController.text = 'hello@truthworld.in';
    }
    if (passwordController.text.isEmpty) {
      passwordController.text = '12345';
    }
    _restoreAdminSession();
    _listenToAdminMembers();
    _ensureDefaultAdminSeeded();

    ever(selectedChannel, (ch) {
      if (ch != null) {
        final id = (ch['id'] ?? ch['channelId'] ?? '').toString();
        if (id.isNotEmpty) {
          fetchChannelEconomics(id);
        }
      } else {
        channelEconomics.value = null;
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    final isInitialOwner =
        email != null && authorizedOwnerEmails.contains(email);
    if (isInitialOwner) {
      isAdmin.value = true;
      if (currentAdminEmail.value.isEmpty) {
        currentAdminEmail.value = email;
      }
      currentAdminRole.value = 'Super Admin';
      if (!currentAdminRoles.contains('Super Admin')) {
        currentAdminRoles.assignAll(['Super Admin']);
      }
      _startSubscriptions();
    }
    isAuthChecking.value = false;

    _authSub = FirebaseAuth.instance.idTokenChanges().listen((authUser) async {
      if (authUser != null) {
        final authEmail = authUser.email?.toLowerCase() ?? '';
        final isOwner = authorizedOwnerEmails.contains(authEmail);
        try {
          final token = await authUser.getIdTokenResult(true);
          final hasAdminClaim = token.claims?['admin'] == true;
          if (isOwner || hasAdminClaim) {
            isAdmin.value = true;
            if (currentAdminEmail.value.isEmpty) {
              currentAdminEmail.value = authEmail;
            }
            if (isOwner) {
              currentAdminRole.value = 'Super Admin';
              if (!currentAdminRoles.contains('Super Admin')) {
                currentAdminRoles.assignAll(['Super Admin']);
              }
            }
            _startSubscriptions();
            _navigateToDashboardIfOnLogin();
          } else {
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('admin_members')
                  .doc(authEmail)
                  .get();
              if (doc.exists &&
                  (doc.data()?['status'] ?? 'active') != 'suspended') {
                isAdmin.value = true;
                currentAdminEmail.value = authEmail;
                final role =
                    doc.data()?['role']?.toString() ?? 'Content Moderator';
                currentAdminRole.value = role;
                final rawRoles = doc.data()?['roles'];
                if (rawRoles is List && rawRoles.isNotEmpty) {
                  currentAdminRoles
                      .assignAll(rawRoles.map((e) => e.toString()).toList());
                } else {
                  currentAdminRoles.assignAll(role
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList());
                }
                _startSubscriptions();
                _navigateToDashboardIfOnLogin();
              }
            } catch (e, s) {
              ErrorHandler.log(e,
                  stackTrace: s, tag: 'AdminController.authMemberQuery');
            }
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.authCheck');
          if (isOwner) {
            isAdmin.value = true;
            if (currentAdminEmail.value.isEmpty) {
              currentAdminEmail.value = authEmail;
            }
            currentAdminRole.value = 'Super Admin';
            if (!currentAdminRoles.contains('Super Admin')) {
              currentAdminRoles.assignAll(['Super Admin']);
            }
            _startSubscriptions();
            _navigateToDashboardIfOnLogin();
          }
        }
      }
    }, onError: (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        tag: 'AdminController._authSub',
      );
    });
    if (_authSub != null) trackSubscription(_authSub!);

    if (isAdmin.value) {
      applyRouteTargetIfPresent();
      _navigateToDashboardIfOnLogin();
    }
  }

  /// Applies incoming route parameters/arguments to select the target moderation queue or tab.
  void applyRouteTargetIfPresent([dynamic tabOverride, Map<String, dynamic>? extraArgs]) {
    final tabArg = extraArgs?['tab'] ?? (Get.arguments is Map ? Get.arguments['tab'] : null);
    final tabParam = Get.parameters['tab'];
    final tab = tabOverride ?? tabArg ?? tabParam;
    if (tab != null && tab.toString().isNotEmpty) {
      final cleanTab = tab.toString().toLowerCase().trim();
      if (!isAdmin.value || isTabAllowed(cleanTab)) {
        currentTab.value = cleanTab;
      }
    }

    final vId = (extraArgs?['videoId'] as String?) ??
        (Get.arguments is Map ? Get.arguments['videoId'] as String? : null) ??
        Get.parameters['videoId'];
    if (vId != null && vId.isNotEmpty) {
      final v = videos.firstWhereOrNull((item) => (item['id'] ?? item['videoId']) == vId);
      if (v != null) {
        selectedVideo.value = v;
      }
    }

    final chId = (extraArgs?['channelId'] as String?) ??
        (Get.arguments is Map ? Get.arguments['channelId'] as String? : null) ??
        Get.parameters['channelId'];
    if (chId != null && chId.isNotEmpty) {
      final c = channels.firstWhereOrNull((item) => (item['id'] ?? item['channelId']) == chId);
      if (c != null) {
        selectedChannel.value = c;
      }
    }

    final tId = (extraArgs?['topicId'] as String?) ??
        (Get.arguments is Map ? Get.arguments['topicId'] as String? : null) ??
        Get.parameters['topicId'];
    if (tId != null && tId.isNotEmpty) {
      final t = topics.firstWhereOrNull((item) => (item['id'] ?? item['topicId'] ?? item['slug']) == tId);
      if (t != null) {
        selectedTopic.value = t;
      }
    }

    final rId = (extraArgs?['reportId'] as String?) ??
        (Get.arguments is Map ? Get.arguments['reportId'] as String? : null) ??
        Get.parameters['reportId'];
    if (rId != null && rId.isNotEmpty) {
      final r = reports.firstWhereOrNull((item) => (item['id'] ?? item['reportId']) == rId);
      if (r != null) {
        selectedReport.value = r;
      }
    }
  }

  /// Authoritatively fetches and caches channel spendings & revenue analytics (Super Admin only).
  Future<void> fetchChannelEconomics(String channelId) async {
    if (!isSuperAdmin || channelId.isEmpty) {
      channelEconomics.value = null;
      return;
    }

    final channelMap = selectedChannel.value;
    if (channelMap != null) {
      // Build immediate local optimistic snapshot for 0ms lag
      final adsINR = (channelMap['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final premiumINR = (channelMap['premiumSubsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final membershipsINR = ((channelMap['membershipRevenueTotal'] ?? channelMap['membershipsRevenueTotal']) as num?)?.toDouble() ?? 0.0;
      final superchatsINR = (channelMap['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0;
      final grossINR = adsINR + premiumINR + membershipsINR + superchatsINR;
      final grossUSD = grossINR / 84.0;
      final isCustom = (channelMap['channelType'] ?? '').toString().toLowerCase() == 'custom' ||
          (channelMap['channelType'] ?? '').toString().toLowerCase() == 'pro';
      final infraConfig = channelMap['infraConfig'] is Map ? (channelMap['infraConfig'] as Map) : null;
      final flatFee = (infraConfig?['flatPlatformFee'] as num?)?.toDouble() ?? 15.0;
      final platformCutUSD = isCustom ? flatFee : (grossUSD * 0.30);
      final platformCutINR = isCustom ? (platformCutUSD * 84.0) : (grossINR * 0.30);
      final currentMonthInfra = (infraConfig?['currentMonthInfraCost'] as num?)?.toDouble() ?? 0.0;

      channelEconomics.value = {
        'channelId': channelId,
        'channelName': channelMap['name'] ?? channelMap['channelName'] ?? 'Truthworld Channel',
        'channelType': channelMap['channelType'] ?? 'standard',
        'revenue': {
          'grossINR': grossINR,
          'grossUSD': grossUSD,
          'creatorShareINR': isCustom ? grossINR : (grossINR * 0.70),
          'creatorShareUSD': isCustom ? grossUSD : (grossUSD * 0.70),
          'platformShareINR': platformCutINR,
          'platformShareUSD': platformCutUSD,
          'breakdown': {
            'adsINR': adsINR,
            'premiumINR': premiumINR,
            'membershipsINR': membershipsINR,
            'superchatsINR': superchatsINR,
          },
          'payouts': {
            'walletBalanceUSD': (channelMap['walletBalanceUSD'] as num?)?.toDouble() ?? 0.0,
            'clearedWithdrawableINR': (channelMap['clearedWithdrawableRevenueTotal'] as num?)?.toDouble() ?? (grossINR - ((channelMap['withdrawnRevenueTotal'] as num?)?.toDouble() ?? 0.0)).clamp(0.0, double.infinity),
            'pendingINR': (channelMap['pendingRevenueTotal'] as num?)?.toDouble() ?? 0.0,
            'withdrawnINR': (channelMap['withdrawnRevenueTotal'] as num?)?.toDouble() ?? 0.0,
          },
        },
        'spendings': {
          'totalInfraUSD': currentMonthInfra,
          'totalInfraINR': currentMonthInfra * 84.0,
          'currentMonthInfraCostUSD': currentMonthInfra,
          'breakdown': {
            'geminiAI': 0.0,
            'cdnEgress': 0.0,
            'transcription': 0.0,
            'translationDubbing': 0.0,
            'mediaTranscoding': 0.0,
            'compute': 0.0,
            'firestoreOps': 0.0,
          },
          'creatorWalletSpendUSD': 0.0,
        },
        'economics': {
          'netPlatformContributionUSD': platformCutUSD - currentMonthInfra,
          'netPlatformContributionINR': platformCutINR - (currentMonthInfra * 84.0),
          'marginPercent': platformCutUSD > 0 ? (((platformCutUSD - currentMonthInfra) / platformCutUSD) * 100) : 0.0,
          'isProfitable': (platformCutUSD - currentMonthInfra) >= 0,
        },
        'transactions': <Map<String, dynamic>>[],
      };
    }

    isLoadingChannelEconomics.value = true;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('getChannelSpendingsAndRevenue');
      final result = await callable.call<dynamic>({'channelId': channelId});
      if (result.data is Map) {
        channelEconomics.value = Map<String, dynamic>.from(result.data as Map);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.fetchChannelEconomics');
    } finally {
      isLoadingChannelEconomics.value = false;
    }
  }

  /// Updates AI Feature discounts (Dubbing & Subtitles) for a specific channel.
  /// Strictly restricted to Super Admin only.
  Future<bool> updateChannelAiDiscounts({
    required String channelId,
    required String dubbingDiscountType,
    required double dubbingDiscountPercent,
    required String subtitlesDiscountType,
    required double subtitlesDiscountPercent,
  }) async {
    if (!isSuperAdmin) {
      AppSnackbar.warning('Access Denied: Only Super Admins can configure channel discounts.');
      return false;
    }
    return AdminEntityModerationService.updateChannelAiDiscounts(
      channelId: channelId,
      dubbingDiscountType: dubbingDiscountType,
      dubbingDiscountPercent: dubbingDiscountPercent,
      subtitlesDiscountType: subtitlesDiscountType,
      subtitlesDiscountPercent: subtitlesDiscountPercent,
      channels: channels,
      selectedChannel: selectedChannel,
      isActionSubmitting: isActionSubmitting,
      logAdminAction: ({
        required String action,
        required String targetType,
        required String targetId,
        required String reason,
        Map<String, dynamic>? metadata,
      }) =>
          logAdminAction(
        action: action,
        targetId: targetId,
        reason: reason,
        extra: {
          'targetType': targetType,
          if (metadata != null) ...metadata,
        },
      ),
    );
  }

  /// Grants free Dubbing Studio credits directly to a particular channel and its owner wallet (Super Admin only).
  Future<bool> grantChannelDubbingCredits({
    required String channelId,
    required int amountCredits,
    required String reason,
  }) async {
    if (!isSuperAdmin) {
      AppSnackbar.warning('Access Denied: Only Super Admins can grant channel dubbing credits.');
      return false;
    }
    return AdminEntityModerationService.grantChannelDubbingCredits(
      channelId: channelId,
      amountCredits: amountCredits,
      reason: reason,
      channels: channels,
      selectedChannel: selectedChannel,
      isActionSubmitting: isActionSubmitting,
      logAdminAction: ({
        required String action,
        required String targetType,
        required String targetId,
        required String reason,
        Map<String, dynamic>? metadata,
      }) =>
          logAdminAction(
        action: action,
        targetId: targetId,
        reason: reason,
        extra: {
          'targetType': targetType,
          if (metadata != null) ...metadata,
        },
      ),
    );
  }

  /// Comprehensive Super Admin Privileges: update discounts, free dubbing studio credits, and upload limit duration atomically.
  Future<bool> updateChannelSuperAdminPrivileges({
    required String channelId,
    required String dubbingDiscountType,
    required double dubbingDiscountPercent,
    required String subtitlesDiscountType,
    required double subtitlesDiscountPercent,
    required int dailyUploadDurationMinutes,
    required int freeCreditsToGrant,
    required String reason,
  }) async {
    if (!isSuperAdmin) {
      AppSnackbar.warning('Access Denied: Only Super Admins can configure channel privileges.');
      return false;
    }
    return AdminEntityModerationService.updateChannelSuperAdminPrivileges(
      channelId: channelId,
      dubbingDiscountType: dubbingDiscountType,
      dubbingDiscountPercent: dubbingDiscountPercent,
      subtitlesDiscountType: subtitlesDiscountType,
      subtitlesDiscountPercent: subtitlesDiscountPercent,
      dailyUploadDurationMinutes: dailyUploadDurationMinutes,
      freeCreditsToGrant: freeCreditsToGrant,
      reason: reason,
      channels: channels,
      selectedChannel: selectedChannel,
      isActionSubmitting: isActionSubmitting,
      logAdminAction: ({
        required String action,
        required String targetType,
        required String targetId,
        required String reason,
        Map<String, dynamic>? metadata,
      }) =>
          logAdminAction(
        action: action,
        targetId: targetId,
        reason: reason,
        extra: {
          'targetType': targetType,
          if (metadata != null) ...metadata,
        },
      ),
    );
  }

  /// Checks whether a given tab ID is allowed for the currently logged in administrator
  bool isTabAllowed(String tabId) {
    return AdminRolesConfig.isTabAllowed(
      tabId: tabId,
      isAdmin: isAdmin.value,
      isPrimaryOwner: isPrimaryOwner,
      currentAdminEmail: currentAdminEmail.value,
      currentAdminRole: currentAdminRole.value,
      currentAdminRoles: currentAdminRoles,
    );
  }

  /// Returns the set of all tab IDs allowed for the current administrator
  Set<String> getAllowedTabs() {
    return AdminRolesConfig.getAllowedTabs(
      isPrimaryOwner: isPrimaryOwner,
      currentAdminEmail: currentAdminEmail.value,
      currentAdminRole: currentAdminRole.value,
      currentAdminRoles: currentAdminRoles,
    );
  }

  @override
  void ensureSubscriptionsStarted() {
    if (isAdmin.value &&
        (!_subscriptionsManager.hasActiveSubscriptions || videos.isEmpty)) {
      _startSubscriptions();
    }
  }

  /// Alias for [refreshAllData] to maintain compatibility with AdminHeader UI widget.
  Future<void> refreshData() => refreshAllData();

  Future<void> refreshAllData() async {
    await AdminDataRefreshManager.refreshAllData(
      videos: videos,
      pendingVideos: pendingVideos,
      totalVideos: totalVideos,
      isVideoPending: isVideoPending,
      channels: channels,
      pendingChannels: pendingChannels,
      totalChannels: totalChannels,
      isChannelPending: isChannelPending,
      topics: topics,
      pendingTopics: pendingTopics,
      totalTopics: totalTopics,
      isTopicPending: isTopicPending,
      onCombineImages: ({communityList, flaggedList}) =>
          _subscriptionsManager.combineImagesAndPosts(
        communityList: communityList,
        flaggedList: flaggedList,
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: isImagePostPending,
      ),
      onCombineReports: ({mainReports}) =>
          _subscriptionsManager.combineReports(
        mainReports: mainReports,
        videos: videos,
        reports: reports,
        pendingReports: pendingReports,
        totalReports: totalReports,
        isReportPending: isReportPending,
      ),
      fetchUsers: fetchUsers,
      startSubscriptions: _startSubscriptions,
    );
  }

  void _startSubscriptions({bool forceRestart = false}) {
    if (forceRestart) {
      _stopSubscriptions();
    }

    _subscriptionsManager.startSubscriptions(
      trackSubscription: trackSubscription,
      applyModerationModes: applyModerationModes,
      fetchFallbackModerationModes: fetchFallbackModerationModes,
      startLanguageRequestsSubscription: startLanguageRequestsSubscription,
      listenToAdminMembers: _listenToAdminMembers,
      startAppealsSubscription: _startAppealsSubscription,
      videos: videos,
      pendingVideos: pendingVideos,
      totalVideos: totalVideos,
      isVideoPending: isVideoPending,
      images: images,
      pendingImages: pendingImages,
      totalImages: totalImages,
      isImagePostPending: isImagePostPending,
      topics: topics,
      pendingTopics: pendingTopics,
      totalTopics: totalTopics,
      isTopicPending: isTopicPending,
      channels: channels,
      pendingChannels: pendingChannels,
      totalChannels: totalChannels,
      isChannelPending: isChannelPending,
      reports: reports,
      pendingReports: pendingReports,
      totalReports: totalReports,
      isReportPending: isReportPending,
      auditLogs: auditLogs,
      ads: ads,
      pendingAds: pendingAds,
      totalAds: totalAds,
      userSearchQuery: userSearchQuery,
      allUsers: allUsers,
      mapUserDoc: mapUserDoc,
      sortAndSetUsers: sortAndSetUsers,
    );
  }

  void _stopSubscriptions() {
    _subscriptionsManager.stopSubscriptions(
      stopAdminMembersSubscription: stopAdminMembersSubscription,
      stopLanguageRequestsSubscription: stopLanguageRequestsSubscription,
      stopAppealsSubscription: stopAppealsSubscription,
    );
  }

  @override
  void onClose() {
    if (_authSub != null) unawaited(_authSub!.cancel());
    _authSub = null;
    _stopSubscriptions();
    super.onClose();
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_components.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_analytics_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_audit_log_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_auth_team_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_content_moderation_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_feedback_language_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_security_alerts_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_user_management_mixin.dart';

export 'admin/admin_components.dart';

/// Central Administration Controller for TruthWorld.
/// Integrates domain-specific mixins for authentication, content moderation,
/// user management, platform analytics, security escalation, and user feedback.
class AdminController extends BaseController
    with
        AdminAuditLogMixin,
        AdminAuthTeamMixin,
        AdminContentModerationMixin,
        AdminUserManagementMixin,
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

  @override
  void clearSelectedItems() {
    selectedVideo.value = null;
    selectedImage.value = null;
    selectedChannel.value = null;
    selectedReport.value = null;
    selectedTopic.value = null;
    selectedAd.value = null;
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
      _navigateToDashboardIfOnLogin();
    }
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

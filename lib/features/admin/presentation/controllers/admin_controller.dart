import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_analytics_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_audit_log_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_auth_team_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_content_moderation_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_feedback_language_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_security_alerts_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/mixins/admin_user_management_mixin.dart';

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
        AdminFeedbackLanguageMixin {
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

  // FEATURE: Security, Owner & Team Access Management
  // ═══════════════════════════════════════════════════════════════════════════
  static const String ownerEmail = String.fromEnvironment(
    'ADMIN_OWNER_EMAIL',
    defaultValue: 'ebenezervampy@towervsp.com',
  );
  static const List<String> authorizedOwnerEmails = [
    'ebenezervampy@towervsp.com',
    'ebenezervampu@towervsp.com',
    'ebenezervampu4@gmail.com',
    'admin@truthworld.com',
    'support@truthworld.com',
    String.fromEnvironment('ADMIN_OWNER_EMAIL', defaultValue: 'ebenezervampy@towervsp.com'),
    String.fromEnvironment('ADMIN_SECONDARY_EMAIL', defaultValue: 'support@truthworld.com'),
  ];
  /// List of all 8 standard admin roles with their allowed tabs and descriptions
  static const List<Map<String, dynamic>> availableRoles = [
    {
      'name': 'Super Admin',
      'description': 'Full unrestricted master access to all tabs, queues, actions, and team management.',
      'tabs': [
        'dashboard',
        'videos',
        'topics',
        'images',
        'channels',
        'reports',
        'logs',
        'users',
        'team',
        'ads',
        'ad_reports',
        'analytics',
        'appeals',
        'feedbacks',
        'alerts',
        'security',
        'help',
      ],
    },
    {
      'name': 'Content Moderator',
      'description': 'Review and approve/reject Video Queue, Topics Queue, Image Posts, and Channel reviews.',
      'tabs': ['dashboard', 'videos', 'topics', 'images', 'channels'],
    },
    {
      'name': 'Trust & Safety Reviewer',
      'description': 'Process user-submitted Video Reports, User Appeals, and community Feedbacks.',
      'tabs': ['reports', 'appeals', 'feedbacks'],
    },
    {
      'name': 'User Manager',
      'description': 'Inspect registered user accounts, manage bans, suspensions, and safety profiles.',
      'tabs': ['users'],
    },
    {
      'name': 'Advertising Manager',
      'description': 'Review and moderate Advertiser Campaigns and dispute Reports.',
      'tabs': ['ads', 'ad_reports'],
    },
    {
      'name': 'Audit & Compliance Officer',
      'description': 'Review Quarantined Audit Logs, Security Lockdowns, and System Alerts.',
      'tabs': ['logs', 'security', 'alerts'],
    },
    {
      'name': 'Analytics & Performance',
      'description': 'View platform Analytics and Overview health dashboard metrics.',
      'tabs': ['dashboard', 'analytics'],
    },
    {
      'name': 'Team Manager',
      'description': 'Manage team members, create credentials, and assign access roles.',
      'tabs': ['team'],
    },
  ];

  static const List<String> allRoleNames = [
    'Super Admin',
    'Content Moderator',
    'Trust & Safety Reviewer',
    'User Manager',
    'Advertising Manager',
    'Audit & Compliance Officer',
    'Analytics & Performance',
    'Team Manager',
  ];


  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Moderation Modes (Direct Admin Approval vs Google Cloud Vision)
  // ═══════════════════════════════════════════════════════════════════════════
  final RxBool rxBypassChannelBanners = false.obs;
  final RxBool rxBypassChannelAvatars = false.obs;
  final RxBool rxBypassVideoThumbnails = false.obs;
  final RxBool rxBypassCommunityPosts = false.obs;
  final RxBool rxBypassTopicThumbnails = false.obs;
  final RxBool rxBypassTopics = false.obs;
  final RxBool rxBypassPlaylistThumbnails = false.obs;
  final RxBool rxBypassVideos = false.obs;
  final RxBool rxBypassChannels = false.obs;
  final RxBool rxBypassAds = false.obs;
  final RxBool isLoadingModerationModes = false.obs;
  final RxBool isTogglingModerationMode = false.obs;

  // Subscriptions
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _modesSub;
  StreamSubscription<QuerySnapshot>? _videosSub;
  StreamSubscription<QuerySnapshot>? _topicsSub;
  StreamSubscription<QuerySnapshot>? _imagesSub;
  StreamSubscription<QuerySnapshot>? _communitySub;
  StreamSubscription<QuerySnapshot>? _playlistsThumbnailsSub;
  StreamSubscription<QuerySnapshot>? _verificationQueueSub;
  StreamSubscription<QuerySnapshot>? _logsSub;
  StreamSubscription<QuerySnapshot>? _actionsLogSub;
  StreamSubscription<QuerySnapshot>? _channelsSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _videoReportsSub;
  StreamSubscription<QuerySnapshot>? _altVideoReportsSub;
  StreamSubscription<QuerySnapshot>? _adsSub;
  StreamSubscription<QuerySnapshot>? _usersSub;

  List<Map<String, dynamic>> _rawCommunityPosts = [];
  List<Map<String, dynamic>> _rawFlaggedImages = [];
  List<Map<String, dynamic>> _rawPlaylistThumbnails = [];
  List<Map<String, dynamic>> _rawVerificationQueue = [];
  List<Map<String, dynamic>> _rawReportsDocs = [];
  List<Map<String, dynamic>> _rawVideoReportsDocs = [];
  List<Map<String, dynamic>> _rawVideoReportsAltDocs = [];
  List<Map<String, dynamic>> _rawActionLogs = [];
  List<Map<String, dynamic>> _rawRejectedImageLogs = [];

  /// Filtered queues taking search query and category into account

  @override
  void onInit() {
    super.onInit();
    if (emailController.text.isEmpty) {
      emailController.text = 'ebenezervampu@towervsp.com';
    }
    if (passwordController.text.isEmpty) {
      passwordController.text = '12345';
    }
    _restoreAdminSession();
    _listenToAdminMembers();
    _ensureDefaultAdminSeeded();

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    final isInitialOwner = email != null && authorizedOwnerEmails.contains(email);
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
              final doc = await FirebaseFirestore.instance.collection('admin_members').doc(authEmail).get();
              if (doc.exists && (doc.data()?['status'] ?? 'active') != 'suspended') {
                isAdmin.value = true;
                currentAdminEmail.value = authEmail;
                final role = doc.data()?['role']?.toString() ?? 'Content Moderator';
                currentAdminRole.value = role;
                final rawRoles = doc.data()?['roles'];
                if (rawRoles is List && rawRoles.isNotEmpty) {
                  currentAdminRoles.assignAll(rawRoles.map((e) => e.toString()).toList());
                } else {
                  currentAdminRoles.assignAll(role.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
                }
                _startSubscriptions();
                _navigateToDashboardIfOnLogin();
              }
            } catch (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.authMemberQuery');
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
    if (!isAdmin.value) return false;

    // Language requests queue is exclusively for the primary platform owner ("only me")
    if (tabId == 'language_requests') {
      return isPrimaryOwner;
    }

    // Help tab is universally accessible to any logged-in administrator
    if (tabId == 'help') return true;

    final email = currentAdminEmail.value.toLowerCase();
    // Primary authorized owners always have full access to everything
    if (authorizedOwnerEmails.contains(email)) return true;

    // Check if roles include Super Admin
    if (currentAdminRoles.any((r) => r.toLowerCase().contains('super') || r.toLowerCase().contains('owner'))) {
      return true;
    }
    if (currentAdminRole.value.toLowerCase().contains('super') || currentAdminRole.value.toLowerCase().contains('owner')) {
      return true;
    }

    final allowed = getAllowedTabs();
    return allowed.contains(tabId);
  }

  /// Returns the set of all tab IDs allowed for the current administrator
  Set<String> getAllowedTabs() {
    final email = currentAdminEmail.value.toLowerCase();
    if (isPrimaryOwner) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help', 'language_requests',
      };
    }

    if (authorizedOwnerEmails.contains(email)) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help',
      };
    }

    if (currentAdminRoles.any((r) => r.toLowerCase().contains('super') || r.toLowerCase().contains('owner')) ||
        currentAdminRole.value.toLowerCase().contains('super') ||
        currentAdminRole.value.toLowerCase().contains('owner')) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help',
      };
    }

    final allowed = <String>{'help'};

    void addTabsForRole(String roleStr) {
      final r = roleStr.toLowerCase().trim();
      if (r.contains('super') || r.contains('owner')) {
        allowed.addAll([
          'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
          'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
          'alerts', 'security', 'help'
        ]);
        return;
      }
      if (r.contains('content') || r.contains('moderator') || r.contains('queue')) {
        allowed.addAll(['dashboard', 'videos', 'topics', 'images', 'channels']);
      }
      if (r.contains('trust') || r.contains('safety') || r.contains('support') || r.contains('appeal')) {
        allowed.addAll(['reports', 'appeals', 'feedbacks']);
      }
      if (r.contains('user')) {
        allowed.add('users');
      }
      if (r.contains('ad') || r.contains('campaign')) {
        allowed.addAll(['ads', 'ad_reports']);
      }
      if (r.contains('audit') || r.contains('compliance') || r.contains('security') || r.contains('alert')) {
        allowed.addAll(['logs', 'security', 'alerts']);
      }
      if (r.contains('analytics') || r.contains('performance')) {
        allowed.addAll(['dashboard', 'analytics']);
      }
      if (r.contains('team')) {
        allowed.add('team');
      }
    }

    currentAdminRoles.forEach(addTabsForRole);
    if (currentAdminRole.value.isNotEmpty) {
      addTabsForRole(currentAdminRole.value);
    }

    if (allowed.isEmpty) {
      allowed.add('dashboard');
    }
    return allowed;
  }


  @override
  void ensureSubscriptionsStarted() {
    if (isAdmin.value && (_videosSub == null || videos.isEmpty)) {
      _startSubscriptions();
    }
  }

  /// Alias for [refreshAllData] to maintain compatibility with AdminHeader UI widget.
  Future<void> refreshData() => refreshAllData();

  Future<void> refreshAllData() async {
    // 1. Fetch videos directly
    try {
      final vSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .limit(100)
          .get();
      final vList = vSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (vList.isNotEmpty) {
        vList.sort((a, b) {
          final timeA = a['createdAt'] ?? a['uploadedAt'] ?? a['timestamp'];
          final timeB = b['createdAt'] ?? b['uploadedAt'] ?? b['timestamp'];
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          final dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          final dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          return dtB.compareTo(dtA);
        });
        videos.assignAll(vList);
        pendingVideos.value = vList.where(isVideoPending).length;
        totalVideos.value = vList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshVideos');
    }

    // 2. Fetch channels directly
    try {
      final cSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .limit(100)
          .get();
      final cList = cSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (cList.isNotEmpty) {
        cList.sort((a, b) {
          final timeA = a['updatedAt'];
          final timeB = b['updatedAt'];
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          final dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          final dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          return dtB.compareTo(dtA);
        });
        channels.assignAll(cList);
        pendingChannels.value = cList.where(isChannelPending).length;
        totalChannels.value = cList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshChannels');
    }

    // 3. Fetch topics directly
    try {
      final tSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.topics)
          .limit(100)
          .get();
      final tList = tSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (tList.isNotEmpty) {
        tList.sort((a, b) {
          final timeA = a['updatedAt'] ?? a['createdAt'];
          final timeB = b['updatedAt'] ?? b['createdAt'];
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          final dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          final dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
          return dtB.compareTo(dtA);
        });
        topics.assignAll(tList);
        pendingTopics.value = tList.where(isTopicPending).length;
        totalTopics.value = tList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshTopics');
    }

    // 4. Fetch community & flagged images directly
    try {
      final flaggedSnap = await FirebaseFirestore.instance.collection('flagged_images_review').limit(100).get();
      final communitySnap = await FirebaseFirestore.instance.collection(FirestoreCollections.community).limit(100).get();
      final fList = flaggedSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final commList = communitySnap.docs.map((doc) => {'id': doc.id, 'category': 'Community Post', ...doc.data()}).toList();
      _combineImagesAndPosts(communityList: commList, flaggedList: fList);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshImages');
    }

    // 5. Fetch reports directly
    try {
      final reportsSnap = await FirebaseFirestore.instance.collection(FirestoreCollections.reports).limit(100).get();
      final rList = reportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      _combineReports(mainReports: rList);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshReports');
    }

    // 6. Fetch users directly
    try {
      await fetchUsers();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.refreshUsers');
    }

    // Ensure stream subscriptions are active
    _startSubscriptions();

    AppSnackbar.success(
      'Moderation queues synchronized successfully.',
      duration: const Duration(seconds: 2),
    );
  }


  void _startSubscriptions({bool forceRestart = false}) {
    if (forceRestart) {
      _stopSubscriptions();
    }

    _listenToAdminMembers();

    // 0. Monitor moderation modes config (admin_settings/moderation_modes)
    if (_modesSub == null) {
      _modesSub = FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('moderation_modes')
          .snapshots()
          .listen(
            (doc) {
              if (doc.exists && doc.data() != null) {
                _applyModerationModes(doc.data()!);
              } else {
                _fetchFallbackModerationModes();
              }
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.modesStream');
              _fetchFallbackModerationModes();
            },
          );
      if (_modesSub != null) trackSubscription(_modesSub!);
    }

    // 0.1 Monitor language requests
    startLanguageRequestsSubscription(trackSubscription);

    // 1. Monitor videos collection
    if (_videosSub == null) {
      _videosSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();

              list.sort((a, b) {
                final timeA = a['createdAt'] ?? a['uploadedAt'] ?? a['timestamp'];
                final timeB = b['createdAt'] ?? b['uploadedAt'] ?? b['timestamp'];
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                final dtA = timeA is Timestamp
                    ? timeA.toDate()
                    : (DateTime.tryParse(timeA.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                final dtB = timeB is Timestamp
                    ? timeB.toDate()
                    : (DateTime.tryParse(timeB.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                return dtB.compareTo(dtA);
              });

              if (list.isNotEmpty || videos.isEmpty) {
                videos.assignAll(list);
              }

              pendingVideos.value = videos.where(isVideoPending).length;
              totalVideos.value = videos.length;
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.videoStream');
            },
          );
      if (_videosSub != null) trackSubscription(_videosSub!);
    }

    // 2. Monitor community posts, flagged images, topics, and playlists queue
    if (_imagesSub == null) {
      _imagesSub = FirebaseFirestore.instance
          .collection('flagged_images_review')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineImagesAndPosts(flaggedList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.imageStream');
            },
          );
      if (_imagesSub != null) trackSubscription(_imagesSub!);
    }

    if (_verificationQueueSub == null) {
      _verificationQueueSub = FirebaseFirestore.instance
          .collection('image_verification')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineImagesAndPosts(verificationList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.verificationQueueStream');
            },
          );
      if (_verificationQueueSub != null) trackSubscription(_verificationQueueSub!);
    }

    if (_communitySub == null) {
      _communitySub = FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, 'category': 'Community Post', ...doc.data()};
              }).toList();
              _combineImagesAndPosts(communityList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.communityStream');
            },
          );
      if (_communitySub != null) trackSubscription(_communitySub!);
    }

    if (_topicsSub == null) {
      _topicsSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.topics)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();

              list.sort((a, b) {
                final timeA = a['updatedAt'] ?? a['createdAt'];
                final timeB = b['updatedAt'] ?? b['createdAt'];
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                final dtA = timeA is Timestamp
                    ? timeA.toDate()
                    : (DateTime.tryParse(timeA.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                final dtB = timeB is Timestamp
                    ? timeB.toDate()
                    : (DateTime.tryParse(timeB.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                return dtB.compareTo(dtA);
              });

              if (list.isNotEmpty || topics.isEmpty) {
                topics.assignAll(list);
              }

              pendingTopics.value = topics.where(isTopicPending).length;
              totalTopics.value = topics.length;
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.topicsStream');
            },
          );
      if (_topicsSub != null) trackSubscription(_topicsSub!);
    }

    if (_playlistsThumbnailsSub == null) {
      _playlistsThumbnailsSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.playlists)
          .limit(50)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, 'category': 'Playlist Thumbnail', ...doc.data()};
              }).toList();
              _combineImagesAndPosts(playlistList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.playlistsThumbnailsStream');
            },
          );
      if (_playlistsThumbnailsSub != null) trackSubscription(_playlistsThumbnailsSub!);
    }

    // 3. Monitor rejection / audit logs and administrative actions
    if (_logsSub == null) {
      _logsSub = FirebaseFirestore.instance
          .collection('rejected_images_log')
          .limit(50)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineAuditLogs(rejectedImages: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.logsStream');
            },
          );
      if (_logsSub != null) trackSubscription(_logsSub!);
    }

    if (_actionsLogSub == null) {
      _actionsLogSub = FirebaseFirestore.instance
          .collection('admin_actions_log')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineAuditLogs(actions: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.actionsLogStream');
            },
          );
      if (_actionsLogSub != null) trackSubscription(_actionsLogSub!);
    }

    // 4. Monitor channels collection
    if (_channelsSub == null) {
      _channelsSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();

              list.sort((a, b) {
                final timeA = a['updatedAt'];
                final timeB = b['updatedAt'];
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                final dtA = timeA is Timestamp
                    ? timeA.toDate()
                    : (DateTime.tryParse(timeA.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                final dtB = timeB is Timestamp
                    ? timeB.toDate()
                    : (DateTime.tryParse(timeB.toString()) ??
                          DateTime.fromMillisecondsSinceEpoch(0));
                return dtB.compareTo(dtA);
              });

              if (list.isNotEmpty || channels.isEmpty) {
                channels.assignAll(list);
              }

              pendingChannels.value = channels.where(isChannelPending).length;
              totalChannels.value = channels.length;
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.channelsStream');
            },
          );
      if (_channelsSub != null) trackSubscription(_channelsSub!);
    }

    // 5. Monitor reports, video_reports, and videoReports collections
    if (_reportsSub == null) {
      _reportsSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineReports(mainReports: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.reportsStream');
            },
          );
      if (_reportsSub != null) trackSubscription(_reportsSub!);
    }

    if (_videoReportsSub == null) {
      _videoReportsSub = FirebaseFirestore.instance
          .collection('video_reports')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineReports(videoReportsList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.videoReportsStream');
              // Optional fallback collection - cancel stream if restricted
              _videoReportsSub?.cancel();
              _videoReportsSub = null;
            },
          );
      if (_videoReportsSub != null) trackSubscription(_videoReportsSub!);
    }

    if (_altVideoReportsSub == null) {
      _altVideoReportsSub = FirebaseFirestore.instance
          .collection('videoReports')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();
              _combineReports(altVideoReportsList: list);
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.altVideoReportsStream');
              // Optional fallback collection - cancel stream if restricted
              _altVideoReportsSub?.cancel();
              _altVideoReportsSub = null;
            },
          );
      if (_altVideoReportsSub != null) trackSubscription(_altVideoReportsSub!);
    }

    // 6. Monitor content_appeals collection
    startAppealsSubscription();

    // 7. Monitor ad_campaigns collection
    if (_adsSub == null) {
      _adsSub = FirebaseFirestore.instance
          .collection('ad_campaigns')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return {'id': doc.id, ...doc.data()};
              }).toList();

              list.sort((a, b) {
                final timeA = a['createdAt'] ?? a['timestamp'];
                final timeB = b['createdAt'] ?? b['timestamp'];
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                final dtA = timeA is Timestamp
                    ? timeA.toDate()
                    : (DateTime.tryParse(timeA.toString()) ??
                        DateTime.fromMillisecondsSinceEpoch(0));
                final dtB = timeB is Timestamp
                    ? timeB.toDate()
                    : (DateTime.tryParse(timeB.toString()) ??
                        DateTime.fromMillisecondsSinceEpoch(0));
                return dtB.compareTo(dtA);
              });

              ads.assignAll(list);
              pendingAds.value =
                  ads.where((a) => a['status'] == 'underReview').length;
              totalAds.value = ads.length;
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.adsStream');
            },
          );
      if (_adsSub != null) trackSubscription(_adsSub!);
    }

    // 8. Monitor users collection
    if (_usersSub == null) {
      _usersSub = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              final list = snapshot.docs.map((doc) {
                return mapUserDoc(doc.id, doc.data());
              }).toList();
              if (userSearchQuery.value.trim().isEmpty) {
                sortAndSetUsers(list);
              } else {
                allUsers.assignAll(list);
              }
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.usersStream');
            },
          );
      if (_usersSub != null) trackSubscription(_usersSub!);
    }
  }


  void _combineImagesAndPosts({
    List<Map<String, dynamic>>? communityList,
    List<Map<String, dynamic>>? flaggedList,
    List<Map<String, dynamic>>? verificationList,
    List<Map<String, dynamic>>? playlistList,
  }) {
    if (communityList != null) _rawCommunityPosts = communityList;
    if (flaggedList != null) _rawFlaggedImages = flaggedList;
    if (verificationList != null) _rawVerificationQueue = verificationList;
    if (playlistList != null) _rawPlaylistThumbnails = playlistList;

    final combinedMap = <String, Map<String, dynamic>>{};

    void addItem(Map<String, dynamic> rawItem, {String defaultCategory = 'Image'}) {
      final id = (rawItem['id'] ?? rawItem['docId'] ?? rawItem['verificationId'] ?? '').toString();
      if (id.isEmpty) return;

      final item = Map<String, dynamic>.from(rawItem);
      final rawCat = (item['category'] ?? '').toString().toLowerCase();
      final path = (item['filePath'] ?? item['gcsUri'] ?? item['path'] ?? '').toString().toLowerCase();

      // NEVER allow topic items inside images queue
      if (rawCat.contains('topic') || path.contains('topics')) {
        return;
      }

      // Normalize category names
      if (rawCat.contains('banner') || path.contains('banners')) {
        item['category'] = 'Channel Banner';
      } else if (rawCat.contains('avatar') || path.contains('avatars')) {
        item['category'] = 'Channel Avatar';
      } else if (rawCat.contains('playlist') || path.contains('playlists')) {
        item['category'] = 'Playlist Thumbnail';
      } else if (rawCat.contains('community') || path.contains('community')) {
        item['category'] = 'Community Post';
      } else if (rawCat.contains('thumbnail') || path.contains('thumbnails')) {
        item['category'] = 'Video Thumbnail';
      } else if (item['category'] == null || item['category'].toString().isEmpty) {
        item['category'] = defaultCategory;
      }

      combinedMap[id] = item;
    }

    for (final item in _rawFlaggedImages) {
      addItem(item, defaultCategory: 'Flagged Image');
    }
    for (final item in _rawVerificationQueue) {
      addItem(item, defaultCategory: 'Image Verification');
    }
    for (final item in _rawCommunityPosts) {
      addItem(item, defaultCategory: 'Community Post');
    }
    for (final item in _rawPlaylistThumbnails) {
      final hasThumb = (item['thumbnailUrl'] ?? item['coverImage'] ?? item['imageUrl'] ?? '').toString().isNotEmpty;
      if (hasThumb) {
        addItem(item, defaultCategory: 'Playlist Thumbnail');
      }
    }

    final combined = combinedMap.values.toList();
    combined.sort((a, b) {
      final timeA = a['flaggedAt'] ?? a['createdAt'] ?? a['timestamp'] ?? a['updatedAt'];
      final timeB = b['flaggedAt'] ?? b['createdAt'] ?? b['timestamp'] ?? b['updatedAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final dtA = timeA is Timestamp
          ? timeA.toDate()
          : (DateTime.tryParse(timeA.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      final dtB = timeB is Timestamp
          ? timeB.toDate()
          : (DateTime.tryParse(timeB.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      return dtB.compareTo(dtA);
    });

    images.assignAll(combined);

    pendingImages.value = combined.where(isImagePostPending).length;
    totalImages.value = combined.length;
  }

  void _applyModerationModes(Map<String, dynamic> data) {
    if (data.containsKey('thumbnails') || data.containsKey('videoThumbnails') || data.containsKey('videos_thumbnails')) {
      rxBypassVideoThumbnails.value = data['thumbnails'] == true ||
          data['videos_thumbnails'] == true ||
          data['videoThumbnails'] == true;
    }
    if (data.containsKey('banner') || data.containsKey('channelBanner') || data.containsKey('channel_banner')) {
      rxBypassChannelBanners.value = data['banner'] == true ||
          data['channelBanner'] == true ||
          data['channel_banner'] == true;
    }
    if (data.containsKey('avatar') || data.containsKey('channelAvatar') || data.containsKey('channel_avatar')) {
      rxBypassChannelAvatars.value = data['avatar'] == true ||
          data['channelAvatar'] == true ||
          data['channel_avatar'] == true;
    }
    if (data.containsKey('community') || data.containsKey('communityPosts') || data.containsKey('community_posts')) {
      rxBypassCommunityPosts.value = data['community'] == true ||
          data['community_posts'] == true ||
          data['communityPosts'] == true;
    }
    if (data.containsKey('topics') || data.containsKey('topicThumbnails') || data.containsKey('topic_thumbnails')) {
      rxBypassTopicThumbnails.value = data['topics'] == true ||
          data['topic_thumbnails'] == true ||
          data['topicThumbnails'] == true;
      rxBypassTopics.value = rxBypassTopicThumbnails.value;
    }
    if (data.containsKey('playlists') || data.containsKey('playlistThumbnails') || data.containsKey('playlist_thumbnails')) {
      rxBypassPlaylistThumbnails.value = data['playlists'] == true ||
          data['playlist_thumbnails'] == true ||
          data['playlistThumbnails'] == true;
    }
    if (data.containsKey('videos')) {
      rxBypassVideos.value = data['videos'] == true;
    }
    if (data.containsKey('channels') || data.containsKey('channelDetails')) {
      rxBypassChannels.value = data['channels'] == true || data['channelDetails'] == true;
    }
    if (data.containsKey('ads') ||
        data.containsKey('campaigns') ||
        data.containsKey('adCampaigns') ||
        data.containsKey('advertiser_campaigns')) {
      rxBypassAds.value = data['ads'] == true ||
          data['campaigns'] == true ||
          data['adCampaigns'] == true ||
          data['advertiser_campaigns'] == true;
    }
  }

  Future<void> _fetchFallbackModerationModes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('moderation_modes')
          .get();
      if (snap.exists && snap.data() != null) {
        _applyModerationModes(snap.data()!);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.fetchFallbackModerationModes');
    }
  }

  Future<bool> toggleModerationMode(String modeKey, bool value) async {
    // 0ms Instant UI update for the specific switch
    switch (modeKey) {
      case 'thumbnails':
      case 'videoThumbnails':
        rxBypassVideoThumbnails.value = value;
      case 'banner':
      case 'channelBanner':
        rxBypassChannelBanners.value = value;
      case 'avatar':
      case 'channelAvatar':
        rxBypassChannelAvatars.value = value;
      case 'community':
      case 'communityPosts':
        rxBypassCommunityPosts.value = value;
      case 'topics':
      case 'topicThumbnails':
        rxBypassTopicThumbnails.value = value;
      case 'playlists':
      case 'playlistThumbnails':
        rxBypassPlaylistThumbnails.value = value;
      case 'videos':
        rxBypassVideos.value = value;
      case 'channels':
        rxBypassChannels.value = value;
      case 'ads':
      case 'campaigns':
      case 'adCampaigns':
      case 'advertiser_campaigns':
        rxBypassAds.value = value;
    }

    try {
      final updateMap = <String, dynamic>{
        modeKey: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      };

      if (modeKey == 'thumbnails' || modeKey == 'videoThumbnails') {
        updateMap['thumbnails'] = value;
        updateMap['videos_thumbnails'] = value;
        updateMap['videoThumbnails'] = value;
      } else if (modeKey == 'banner' || modeKey == 'channelBanner') {
        updateMap['banner'] = value;
        updateMap['channelBanner'] = value;
        updateMap['channel_banner'] = value;
      } else if (modeKey == 'avatar' || modeKey == 'channelAvatar') {
        updateMap['avatar'] = value;
        updateMap['channelAvatar'] = value;
        updateMap['channel_avatar'] = value;
      } else if (modeKey == 'community' || modeKey == 'communityPosts') {
        updateMap['community'] = value;
        updateMap['community_posts'] = value;
        updateMap['communityPosts'] = value;
      } else if (modeKey == 'topics' || modeKey == 'topicThumbnails') {
        updateMap['topics'] = value;
        updateMap['topic_thumbnails'] = value;
        updateMap['topicThumbnails'] = value;
      } else if (modeKey == 'playlists' || modeKey == 'playlistThumbnails') {
        updateMap['playlists'] = value;
        updateMap['playlist_thumbnails'] = value;
        updateMap['playlistThumbnails'] = value;
      } else if (modeKey == 'ads' ||
          modeKey == 'campaigns' ||
          modeKey == 'adCampaigns' ||
          modeKey == 'advertiser_campaigns') {
        updateMap['ads'] = value;
        updateMap['campaigns'] = value;
        updateMap['adCampaigns'] = value;
        updateMap['advertiser_campaigns'] = value;
      }

      // 1. Attempt direct Firestore write
      try {
        await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));
      } catch (fsErr, s) {
        ErrorHandler.log(fsErr, stackTrace: s, tag: 'AdminController.moderationModesDirectWrite');
      }

      // 2. Call Cloud Function endpoint with Admin SDK privileges
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              '${AppConfig.cloudFunctionsBaseUrl}/setModerationModesManual',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'modeKey': modeKey,
              'value': value,
              'modes': updateMap,
            }),
          );
        } catch (cfErr, s) {
          ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminController.moderationModesCloudFunction');
        }
      }

      return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.toggleModerationMode');
      return true;
    }
  }

  Future<void> toggleAllMediaModes(bool enableDirectApproval) async {
    rxBypassVideoThumbnails.value = enableDirectApproval;
    rxBypassChannelBanners.value = enableDirectApproval;
    rxBypassChannelAvatars.value = enableDirectApproval;
    rxBypassCommunityPosts.value = enableDirectApproval;
    rxBypassTopicThumbnails.value = enableDirectApproval;
    rxBypassPlaylistThumbnails.value = enableDirectApproval;
    rxBypassAds.value = enableDirectApproval;

    final updateMap = <String, dynamic>{
      'thumbnails': enableDirectApproval,
      'videos_thumbnails': enableDirectApproval,
      'videoThumbnails': enableDirectApproval,
      'banner': enableDirectApproval,
      'channelBanner': enableDirectApproval,
      'channel_banner': enableDirectApproval,
      'avatar': enableDirectApproval,
      'channelAvatar': enableDirectApproval,
      'channel_avatar': enableDirectApproval,
      'community': enableDirectApproval,
      'community_posts': enableDirectApproval,
      'communityPosts': enableDirectApproval,
      'topics': enableDirectApproval,
      'topic_thumbnails': enableDirectApproval,
      'topicThumbnails': enableDirectApproval,
      'playlists': enableDirectApproval,
      'playlist_thumbnails': enableDirectApproval,
      'playlistThumbnails': enableDirectApproval,
      'ads': enableDirectApproval,
      'campaigns': enableDirectApproval,
      'adCampaigns': enableDirectApproval,
      'advertiser_campaigns': enableDirectApproval,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
    };

    try {
      try {
        await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));
      } catch (fsErr, s) {
        ErrorHandler.log(fsErr, stackTrace: s, tag: 'AdminController.toggleAllMediaModesDirectWrite');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              '${AppConfig.cloudFunctionsBaseUrl}/setModerationModesManual',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'modes': updateMap,
            }),
          );
        } catch (cfErr, s) {
          ErrorHandler.log(cfErr, stackTrace: s, tag: 'AdminController.toggleAllMediaModesCloudFunction');
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminController.toggleAllMediaModes');
    }
  }

  void _combineReports({
    List<Map<String, dynamic>>? mainReports,
    List<Map<String, dynamic>>? videoReportsList,
    List<Map<String, dynamic>>? altVideoReportsList,
  }) {
    if (mainReports != null) _rawReportsDocs = mainReports;
    if (videoReportsList != null) _rawVideoReportsDocs = videoReportsList;
    if (altVideoReportsList != null) {
      _rawVideoReportsAltDocs = altVideoReportsList;
    }

    final combinedMap = <String, Map<String, dynamic>>{};

    for (final item in _rawReportsDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty) combinedMap[id] = item;
    }

    for (final item in _rawVideoReportsDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty && !combinedMap.containsKey(id)) {
        combinedMap[id] = item;
      }
    }

    for (final item in _rawVideoReportsAltDocs) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty && !combinedMap.containsKey(id)) {
        combinedMap[id] = item;
      }
    }

    // Also include reported/flagged videos from video queue
    for (final v in videos) {
      final vId = (v['id'] ?? '').toString();
      final isRep = v['isReported'] == true ||
          v['flagged'] == true ||
          v['status'] == 'reported' ||
          (v['reportsCount'] is num && (v['reportsCount'] as num) > 0) ||
          (v['reportCount'] is num && (v['reportCount'] as num) > 0);

      if (isRep && vId.isNotEmpty) {
        final synthId = 'reported_video_$vId';
        if (!combinedMap.containsKey(synthId) &&
            !combinedMap.values.any((r) => r['videoId'] == vId)) {
          combinedMap[synthId] = {
            'id': synthId,
            'videoId': vId,
            'channelId': v['channelId'] ?? '',
            'type': 'video',
            'status': v['moderation']?['status'] == 'rejected'
                ? 'resolved_rejected'
                : 'pending',
            'reason':
                v['reportReason'] ?? v['reason'] ?? 'User Reported Video',
            'comment': v['reportComment'] ??
                v['comment'] ??
                'Reported directly on video queue',
            'userEmail':
                v['reporterEmail'] ?? v['userEmail'] ?? 'Community User',
            'createdAt': v['createdAt'] ??
                v['updatedAt'] ??
                FieldValue.serverTimestamp(),
          };
        }
      }
    }

    final combined = combinedMap.values.toList();
    combined.sort((a, b) {
      final timeA = a['createdAt'] ?? a['timestamp'] ?? a['reportedAt'];
      final timeB = b['createdAt'] ?? b['timestamp'] ?? b['reportedAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final dtA = timeA is Timestamp
          ? timeA.toDate()
          : (DateTime.tryParse(timeA.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      final dtB = timeB is Timestamp
          ? timeB.toDate()
          : (DateTime.tryParse(timeB.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      return dtB.compareTo(dtA);
    });

    reports.assignAll(combined);
    pendingReports.value = combined.where(isReportPending).length;
    totalReports.value = combined.length;
  }

  void _combineAuditLogs({
    List<Map<String, dynamic>>? rejectedImages,
    List<Map<String, dynamic>>? actions,
  }) {
    if (rejectedImages != null) _rawRejectedImageLogs = rejectedImages;
    if (actions != null) _rawActionLogs = actions;

    final combined = <Map<String, dynamic>>[];

    for (final raw in _rawRejectedImageLogs) {
      final item = Map<String, dynamic>.from(raw);
      item['logType'] = 'rejected_image';
      item['displayType'] = 'Image Quarantine';
      item['action'] = item['action'] ?? 'Quarantine Image';
      item['actor'] = item['actor'] ?? item['adminEmail'] ?? 'Automated / Admin';
      item['target'] = item['originalPath'] ?? item['quarantinePath'] ?? item['userId'] ?? 'Image';
      item['timestamp'] = item['rejectedAt'] ?? item['timestamp'] ?? item['createdAt'];
      combined.add(item);
    }

    for (final raw in _rawActionLogs) {
      final item = Map<String, dynamic>.from(raw);
      item['logType'] = 'admin_action';
      item['displayType'] = 'Admin Action';
      item['action'] = (item['action'] ?? 'Admin Action').toString().replaceAll('_', ' ').toUpperCase();
      item['actor'] = item['adminEmail'] ?? item['adminId'] ?? 'Admin';
      item['target'] = item['userId'] ?? item['targetId'] ?? item['videoId'] ?? (item['itemCount'] != null ? '${item['itemCount']} items' : 'System');
      item['timestamp'] = item['timestamp'] ?? item['createdAt'];
      combined.add(item);
    }

    combined.sort((a, b) {
      final timeA = a['timestamp'] ?? a['rejectedAt'] ?? a['createdAt'];
      final timeB = b['timestamp'] ?? b['rejectedAt'] ?? b['createdAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final dtA = timeA is Timestamp
          ? timeA.toDate()
          : (DateTime.tryParse(timeA.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      final dtB = timeB is Timestamp
          ? timeB.toDate()
          : (DateTime.tryParse(timeB.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0));
      return dtB.compareTo(dtA);
    });

    auditLogs.assignAll(combined);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS CLASSIFICATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if a video is in pending/under-review state

  void _stopSubscriptions() {
    // Relying on trackSubscription for lifecycle management.
    // However, if we need to manually stop them during logout, we can still do it.
    if (_authSub != null) unawaited(_authSub!.cancel());
    if (_modesSub != null) unawaited(_modesSub!.cancel());
    if (_videosSub != null) unawaited(_videosSub!.cancel());
    if (_topicsSub != null) unawaited(_topicsSub!.cancel());
    if (_imagesSub != null) unawaited(_imagesSub!.cancel());
    if (_communitySub != null) unawaited(_communitySub!.cancel());
    if (_playlistsThumbnailsSub != null) unawaited(_playlistsThumbnailsSub!.cancel());
    if (_verificationQueueSub != null) unawaited(_verificationQueueSub!.cancel());
    if (_logsSub != null) unawaited(_logsSub!.cancel());
    if (_actionsLogSub != null) unawaited(_actionsLogSub!.cancel());
    if (_channelsSub != null) unawaited(_channelsSub!.cancel());
    if (_reportsSub != null) unawaited(_reportsSub!.cancel());
    if (_videoReportsSub != null) unawaited(_videoReportsSub!.cancel());
    if (_altVideoReportsSub != null) unawaited(_altVideoReportsSub!.cancel());
    if (_adsSub != null) unawaited(_adsSub!.cancel());
    if (_usersSub != null) unawaited(_usersSub!.cancel());
    stopAdminMembersSubscription();
    stopLanguageRequestsSubscription();
    stopAppealsSubscription();
    _authSub = null;
    _modesSub = null;
    _videosSub = null;
    _topicsSub = null;
    _imagesSub = null;
    _communitySub = null;
    _playlistsThumbnailsSub = null;
    _verificationQueueSub = null;
    _logsSub = null;
    _actionsLogSub = null;
    _channelsSub = null;
    _reportsSub = null;
    _videoReportsSub = null;
    _altVideoReportsSub = null;
    _adsSub = null;
    _usersSub = null;
  }

  @override
  void onClose() {
    _stopSubscriptions();
    super.onClose();
  }


}

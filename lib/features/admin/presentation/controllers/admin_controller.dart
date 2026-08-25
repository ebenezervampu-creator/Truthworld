import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminController extends BaseController {
  static AdminController get to {
    try {
      return Get.find<AdminController>();
    } catch (_) {
      return Get.put(AdminController());
    }
  }

  // State flags
  final RxBool rxIsLoading = false.obs;
  @override
  bool get isLoading => rxIsLoading.value || super.isLoading;
  final RxBool isAuthChecking = false.obs;
  final RxBool isAdmin = true.obs;
  final RxString currentTab = 'dashboard'.obs;
  final RxInt selectedTabIndex = 0.obs;
  final RxBool isActionSubmitting = false.obs;

  // Real-time Lists
  final RxList<Map<String, dynamic>> videos = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topics = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> images = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> auditLogs = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> channels = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> reports = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> ads = <Map<String, dynamic>>[].obs;

  // Selected Detail views
  final Rxn<Map<String, dynamic>> selectedVideo = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedTopic = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedImage = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedChannel = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedReport = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedAd = Rxn<Map<String, dynamic>>();

  // System statistics
  final RxInt pendingVideos = 0.obs;
  final RxInt pendingTopics = 0.obs;
  final RxInt pendingImages = 0.obs;
  final RxInt pendingChannels = 0.obs;
  final RxInt pendingReports = 0.obs;
  final RxInt pendingAds = 0.obs;
  final RxInt totalVideos = 0.obs;
  final RxInt totalTopics = 0.obs;
  final RxInt totalImages = 0.obs;
  final RxInt totalChannels = 0.obs;
  final RxInt totalReports = 0.obs;
  final RxInt totalAds = 0.obs;
  final RxString adFilterTab = 'all'.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Search & Filter
  // ═══════════════════════════════════════════════════════════════════════════
  final RxString searchQuery = ''.obs;
  final RxString filterStatus = ''.obs;
  final RxString filterCategory = ''.obs;
  final RxString filterTrustTier = ''.obs;
  final RxString videoFilterTab = 'all'.obs;
  final RxString topicFilterTab = 'pending'.obs;
  final RxString imageFilterTab = 'all'.obs;
  final RxString channelFilterTab = 'all'.obs;
  final RxString reportFilterTab = 'all'.obs;
  final RxBool isSearching = false.obs;
  final RxSet<String> selectedItemIds = <String>{}.obs;
  final RxBool isBulkActionSubmitting = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: User Management
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchedUsers =
      <Map<String, dynamic>>[].obs;
  final RxString userSearchQuery = ''.obs;
  final RxString userFilterStatus = 'all'.obs;
  final Rxn<Map<String, dynamic>> selectedUser = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> userSafetyProfile =
      Rxn<Map<String, dynamic>>();
  final RxBool isSearchingUsers = false.obs;
  final RxBool isLoadingProfile = false.obs;
  final RxInt pendingAppeals = 0.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Analytics
  // ═══════════════════════════════════════════════════════════════════════════
  final RxMap<String, dynamic> analyticsData = <String, dynamic>{}.obs;
  final RxString analyticsTimeRange = '7d'.obs;
  final RxBool isLoadingAnalytics = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Alerts & Escalation
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> activeAlerts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> alertRules = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingAlerts = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Appeals
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> appeals = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedAppeal = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingAppeals = false.obs;
  final TextEditingController appealReasonController = TextEditingController();
  final TextEditingController userSearchController = TextEditingController();

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Feedbacks
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> feedbacks = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedFeedback = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingFeedbacks = true.obs;
  final RxString feedbackFilterType = 'All'.obs;
  final RxString feedbackFilterStatus = 'All'.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Security & Anti-Abuse
  // ═══════════════════════════════════════════════════════════════════════════
  final RxMap<String, dynamic> securityMetrics = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> anomalyAlerts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> accountClusters =
      <Map<String, dynamic>>[].obs;
  final RxBool isLockdownMode = false.obs;
  final RxBool isLoadingSecurity = false.obs;

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
  StreamSubscription<QuerySnapshot>? _channelsSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _videoReportsSub;
  StreamSubscription<QuerySnapshot>? _altVideoReportsSub;
  StreamSubscription<QuerySnapshot>? _appealsSub;
  StreamSubscription<QuerySnapshot>? _adsSub;
  StreamSubscription<QuerySnapshot>? _usersSub;

  List<Map<String, dynamic>> _rawCommunityPosts = [];
  List<Map<String, dynamic>> _rawFlaggedImages = [];
  List<Map<String, dynamic>> _rawPlaylistThumbnails = [];
  List<Map<String, dynamic>> _rawVerificationQueue = [];
  List<Map<String, dynamic>> _rawReportsDocs = [];
  List<Map<String, dynamic>> _rawVideoReportsDocs = [];
  List<Map<String, dynamic>> _rawVideoReportsAltDocs = [];
  int _appealsRetryCount = 0;

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = FirebaseAuth.instance.currentUser != null;
    isAuthChecking.value = false;

    _authSub = FirebaseAuth.instance.idTokenChanges().listen((user) {
      if (user != null) {
        isAdmin.value = true;
        _startSubscriptions();
        _navigateToDashboardIfOnLogin();
      } else {
        isAdmin.value = false;
      }
    });
    if (_authSub != null) trackSubscription(_authSub!);

    // Always start real-time queue subscriptions so data is available on dashboard
    _startSubscriptions();

    if (FirebaseAuth.instance.currentUser != null) {
      _navigateToDashboardIfOnLogin();
    }
  }

  void ensureSubscriptionsStarted() {
    if (_videosSub == null || videos.isEmpty) {
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
    } catch (e) {
      debugPrint('AdminController refresh videos error: $e');
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
    } catch (e) {
      debugPrint('AdminController refresh channels error: $e');
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
    } catch (e) {
      debugPrint('AdminController refresh topics error: $e');
    }

    // 4. Fetch community & flagged images directly
    try {
      final flaggedSnap = await FirebaseFirestore.instance.collection('flagged_images_review').limit(100).get();
      final communitySnap = await FirebaseFirestore.instance.collection(FirestoreCollections.community).limit(100).get();
      final fList = flaggedSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final commList = communitySnap.docs.map((doc) => {'id': doc.id, 'category': 'Community Post', ...doc.data()}).toList();
      _combineImagesAndPosts(communityList: commList, flaggedList: fList);
    } catch (e) {
      debugPrint('AdminController refresh images error: $e');
    }

    // 5. Fetch reports directly
    try {
      final reportsSnap = await FirebaseFirestore.instance.collection(FirestoreCollections.reports).limit(100).get();
      final rList = reportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      _combineReports(mainReports: rList);
    } catch (e) {
      debugPrint('AdminController refresh reports error: $e');
    }

    // 6. Fetch users directly
    try {
      await fetchUsers();
    } catch (e) {
      debugPrint('AdminController refresh users error: $e');
    }

    // Ensure stream subscriptions are active
    _startSubscriptions();

    Get.snackbar(
      'Data Refreshed',
      'Moderation queues synchronized with Firestore.',
      backgroundColor: const Color(0xFF2BA640),
      colorText: AppColors.textPrimary,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _navigateToDashboardIfOnLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = Get.currentRoute;
      if (route == '/admin' || route == '/admin/login' || route.isEmpty) {
        Get.offAllNamed('/admin/dashboard');
      }
    });
  }

  // Email & Password login controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool needsPasswordSetup = false.obs;

  /// Signs in using email and password
  Future<void> signInWithEmailAndPassword({
    String? emailInput,
    String? passwordInput,
  }) async {
    final email = (emailInput ?? emailController.text).trim();
    final password = (passwordInput ?? passwordController.text).trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Input Error',
        'Please enter both email and password.',
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    rxIsLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Get.offAllNamed('/admin/dashboard');
    } catch (e) {
      debugPrint('Admin Email Sign In failed: $e');
      Get.snackbar(
        'Authentication Failed',
        e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Directly enables admin console and starts data streams
  Future<void> checkAdminClaims() async {
    isAdmin.value = true;
    isAuthChecking.value = false;
    _startSubscriptions();
  }

  /// Checks if the owner account needs initial admin password setup
  Future<void> _checkPasswordSetupStatus(User user) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('owner_config')
          .get();

      if (!ownerDoc.exists || ownerDoc.data()?['isPasswordSet'] != true) {
        needsPasswordSetup.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showSetPasswordDialog();
        });
      }
    } catch (e) {
      debugPrint('Error checking password setup status: $e');
    }
  }

  /// Prompts a dialog to set the admin password for ebenezervampu4@gmail.com
  void showSetPasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isSaving = false.obs;
    final dialogError = ''.obs;

    unawaited(
      Get.dialog(
        Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set Admin Password',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a secure password for ebenezervampu4@gmail.com to sign in directly to the Admin Portal.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Admin Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textPrimary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm Admin Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textPrimary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                Obx(
                  () => dialogError.value.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            dialogError.value,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 28),
                Obx(
                  () => ElevatedButton(
                    onPressed: isSaving.value
                        ? null
                        : () async {
                            final pass = newPassCtrl.text.trim();
                            final confirm = confirmPassCtrl.text.trim();
                            if (pass.length < 6) {
                              dialogError.value =
                                  'Password must be at least 6 characters.';
                              return;
                            }
                            if (pass != confirm) {
                              dialogError.value = 'Passwords do not match.';
                              return;
                            }
                            dialogError.value = '';
                            isSaving.value = true;

                            try {
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              if (currentUser != null) {
                                await currentUser.updatePassword(pass);
                                await FirebaseFirestore.instance
                                    .collection('admin_settings')
                                    .doc('owner_config')
                                    .set({
                                      'ownerEmail': currentUser.email,
                                      'isPasswordSet': true,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                              }
                              needsPasswordSetup.value = false;
                              Get.back();
                              Get.snackbar(
                                'Password Saved',
                                'Admin password set successfully! You can now log in with your email and password.',
                                backgroundColor: const Color(0xFF2BA640),
                                colorText: AppColors.textPrimary,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } catch (e) {
                              dialogError.value = e.toString().replaceAll(
                                RegExp(r'\[.*?\]\s*'),
                                '',
                              );
                            } finally {
                              isSaving.value = false;
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Admin Password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      ),
    );
  }

  /// Start Firestore real-time synchronization safely without tearing down active streams
  void _startSubscriptions({bool forceRestart = false}) {
    if (forceRestart) {
      _stopSubscriptions();
    }

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
            onError: (e) {
              debugPrint('AdminController Moderation Modes Stream Error: $e');
              _fetchFallbackModerationModes();
            },
          );
      if (_modesSub != null) trackSubscription(_modesSub!);
    }

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
            onError: (e) {
              debugPrint('AdminController Video Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Image Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Verification Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Community Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Topics Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Playlists Stream Error: $e');
            },
          );
      if (_playlistsThumbnailsSub != null) trackSubscription(_playlistsThumbnailsSub!);
    }

    // 3. Monitor rejection / audit logs
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
              if (list.isNotEmpty || auditLogs.isEmpty) {
                auditLogs.assignAll(list);
              }
            },
            onError: (e) {
              debugPrint('AdminController Audit Log Stream Error: $e');
            },
          );
      if (_logsSub != null) trackSubscription(_logsSub!);
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
            onError: (e) {
              debugPrint('AdminController Channels Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Reports Stream Error: $e');
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
            onError: (_) {
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
            onError: (_) {
              // Optional fallback collection - cancel stream if restricted
              _altVideoReportsSub?.cancel();
              _altVideoReportsSub = null;
            },
          );
      if (_altVideoReportsSub != null) trackSubscription(_altVideoReportsSub!);
    }

    // 6. Monitor content_appeals collection
    _startAppealsSubscription();

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
            onError: (e) {
              debugPrint('AdminController Ads Stream Error: $e');
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
                return _mapUserDoc(doc.id, doc.data());
              }).toList();
              if (userSearchQuery.value.trim().isEmpty) {
                _sortAndSetUsers(list);
              } else {
                allUsers.assignAll(list);
              }
            },
            onError: (e) {
              debugPrint('AdminController Users Stream Error: $e');
            },
          );
      if (_usersSub != null) trackSubscription(_usersSub!);
    }
  }

  void _startAppealsSubscription() {
    _appealsSub?.cancel();
    _appealsSub = FirebaseFirestore.instance
        .collection('content_appeals')
        .snapshots()
        .listen(
          (snapshot) {
            _appealsRetryCount = 0;
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();

            list.sort((a, b) {
              final timeA = a['submittedAt'] ?? a['createdAt'];
              final timeB = b['submittedAt'] ?? b['createdAt'];
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

            appeals.assignAll(list);
            pendingAppeals.value = list
                .where(
                  (a) => a['status'] == 'pending' || a['status'] == 'PENDING',
                )
                .length;
          },
          onError: (e) {
            debugPrint('AdminController Appeals Stream Error: $e');
            if (_appealsRetryCount < 2 &&
                FirebaseAuth.instance.currentUser != null) {
              _appealsRetryCount++;
              Future.delayed(const Duration(seconds: 1), () {
                if (FirebaseAuth.instance.currentUser != null) {
                  _startAppealsSubscription();
                }
              });
            }
          },
        );
    if (_appealsSub != null) trackSubscription(_appealsSub!);
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
    } catch (_) {}
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
      } catch (fsErr) {
        debugPrint('Direct Firestore write info: $fsErr');
      }

      // 2. Call Cloud Function endpoint with Admin SDK privileges
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              'https://asia-south1-truthworld-1.cloudfunctions.net/setModerationModesManual',
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
        } catch (cfErr) {
          debugPrint('Cloud Function setModerationModesManual info: $cfErr');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error toggling moderation mode: $e');
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
      } catch (fsErr) {
        debugPrint('Direct Firestore write info: $fsErr');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              'https://asia-south1-truthworld-1.cloudfunctions.net/setModerationModesManual',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'modes': updateMap,
            }),
          );
        } catch (cfErr) {
          debugPrint('Cloud Function setModerationModesManual info: $cfErr');
        }
      }
    } catch (e) {
      debugPrint('Error saving all media modes: $e');
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

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS CLASSIFICATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if a video is in pending/under-review state
  bool isVideoPending(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (mod?['violationCategories']?.contains('timeout_passthrough') == true) {
      return true;
    }
    if (status == null) {
      if (v['isApproved'] == false) return true;
      return false;
    }
    return status == 'pending' ||
        status == 'processing' ||
        status == 'error' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'pending_review' ||
        status == 'flagged' ||
        status == 'uploading' ||
        status == 'unverified' ||
        status == 'pending_approval';
  }

  /// Checks if a video is approved/published/active
  bool isVideoApproved(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    if (isVideoPending(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (status == 'approved' ||
        status == 'published' ||
        status == 'active' ||
        status == 'ready' ||
        status == 'passed') {
      return true;
    }
    if (v['isApproved'] == true || v['visibility'] == 'public') {
      return true;
    }
    return true; // Default fallback for existing videos without status
  }

  /// Checks if a video is rejected
  bool isVideoRejected(Map<String, dynamic> v) {
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    return modStatus == 'rejected' || vStatus == 'rejected';
  }

  /// Checks if a channel is pending verification/review
  bool isChannelPending(Map<String, dynamic> c) {
    if (isChannelRejected(c)) return false;
    final status = (c['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'verification_pending' ||
        status == 'in_review') {
      return true;
    }
    if (status.isEmpty && (c['isVerified'] == false || c['geminiApproved'] == false)) {
      return true;
    }
    return false;
  }

  /// Checks if a channel is active/verified
  bool isChannelActive(Map<String, dynamic> c) {
    if (isChannelRejected(c)) return false;
    if (isChannelPending(c)) return false;
    final status = (c['status'] ?? 'active').toString().toLowerCase();
    return status == 'active' ||
        status == 'verified' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'ready' ||
        c['isApproved'] == true ||
        c['isVerified'] == true ||
        c['geminiApproved'] == true ||
        c['status'] == null;
  }

  /// Checks if a channel verification was rejected or banned
  bool isChannelRejected(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if a topic is pending review / verification
  bool isTopicPending(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'in_review' ||
        status == 'flagged') {
      return true;
    }
    if (t['geminiApproved'] == false && status != 'active' && status != 'approved') {
      return true;
    }
    return false;
  }

  /// Checks if a topic is active / approved
  bool isTopicApproved(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    if (isTopicPending(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'active' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'verified' ||
        t['isApproved'] == true ||
        t['geminiApproved'] == true;
  }

  /// Checks if a topic was rejected
  bool isTopicRejected(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if an image/post is confirmed rejected by admin
  bool isImagePostRejected(Map<String, dynamic> img) {
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'REJECTED' ||
        status == 'MANUALLY_REJECTED' ||
        status == 'ADMIN_REJECTED' ||
        status == 'DELETED' ||
        status == 'REMOVED' ||
        status == 'BANNED' ||
        modStatus == 'REJECTED' ||
        modStatus == 'MANUALLY_REJECTED';
  }

  /// Checks if an image/post is pending review (including items flagged by SafeSearch/Vision AI)
  bool isImagePostPending(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase().replaceAll('_', '').replaceAll(' ', '');
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase().replaceAll('_', '').replaceAll(' ', '');

    if (status == 'PENDINGREVIEW' ||
        status == 'PENDING' ||
        status == 'PROCESSING' ||
        status == 'UNDERREVIEW' ||
        status == 'PENDINGAPPROVAL' ||
        status == 'UNVERIFIED' ||
        status == 'INREVIEW' ||
        status == 'FLAGGED' ||
        status == 'FLAGGEDFORREVIEW' ||
        status == 'FLAGGEDBYAI' ||
        status == 'VERIFICATIONREJECTED' ||
        status == 'QUARANTINED' ||
        status == 'NEEDSREVIEW' ||
        status == 'AWAITINGREVIEW' ||
        status == 'AWAITINGAPPROVAL' ||
        status == 'FAILED' ||
        modStatus == 'PENDING' ||
        modStatus == 'PENDINGREVIEW' ||
        modStatus == 'FLAGGED' ||
        modStatus == 'VERIFICATIONREJECTED') {
      return true;
    }

    if (img['isApproved'] == false &&
        status != 'APPROVED' &&
        status != 'ACTIVE' &&
        status != 'PUBLISHED' &&
        status != 'PASSED') {
      return true;
    }
    return false;
  }

  /// Checks if an image/post is approved/published
  bool isImagePostApproved(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    if (isImagePostPending(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus = (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'APPROVED' ||
        status == 'ACTIVE' ||
        status == 'PUBLISHED' ||
        status == 'PASSED' ||
        status == 'SUCCESS' ||
        modStatus == 'APPROVED' ||
        img['isApproved'] == true;
  }

  /// Checks if a video/content report is pending
  bool isReportPending(Map<String, dynamic> r) {
    if (isReportResolved(r)) return false;
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    return status == 'pending' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'unresolved' ||
        status == 'new';
  }

  /// Checks if a video/content report is resolved or dismissed
  bool isReportResolved(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().toLowerCase();
    return r['isResolved'] == true ||
        r['resolved'] == true ||
        status == 'resolved' ||
        status == 'dismissed' ||
        status == 'resolved_rejected' ||
        status == 'resolved_dismissed' ||
        status == 'closed';
  }

  /// Cancels all active Firestore listeners
  void _stopSubscriptions() {
    // Relying on trackSubscription for lifecycle management.
    // However, if we need to manually stop them during logout, we can still do it.
    if (_videosSub != null) unawaited(_videosSub!.cancel());
    if (_topicsSub != null) unawaited(_topicsSub!.cancel());
    if (_imagesSub != null) unawaited(_imagesSub!.cancel());
    if (_communitySub != null) unawaited(_communitySub!.cancel());
    if (_playlistsThumbnailsSub != null) unawaited(_playlistsThumbnailsSub!.cancel());
    if (_logsSub != null) unawaited(_logsSub!.cancel());
    if (_channelsSub != null) unawaited(_channelsSub!.cancel());
    if (_reportsSub != null) unawaited(_reportsSub!.cancel());
    if (_appealsSub != null) unawaited(_appealsSub!.cancel());
    if (_adsSub != null) unawaited(_adsSub!.cancel());
    if (_usersSub != null) unawaited(_usersSub!.cancel());
    _videosSub = null;
    _topicsSub = null;
    _imagesSub = null;
    _communitySub = null;
    _playlistsThumbnailsSub = null;
    _logsSub = null;
    _channelsSub = null;
    _reportsSub = null;
    _appealsSub = null;
    _adsSub = null;
    _usersSub = null;
  }

  /// Initiates Google Sign In
  Future<void> signInWithGoogle() async {
    rxIsLoading.value = true;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await AuthService.to.signOut();
      }
      await AuthService.to.signInWithGoogle();
      if (FirebaseAuth.instance.currentUser != null) {
        Get.offAllNamed('/admin/dashboard');
      }
    } catch (e) {
      debugPrint('Admin Google Sign In failed: $e');
      Get.snackbar(
        'Authentication Error',
        'Google Sign In failed: ${e.toString().replaceAll("Exception: ", "")}',
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Signs out of the administrative console
  Future<void> signOutAdmin() async {
    rxIsLoading.value = true;
    try {
      selectedVideo.value = null;
      selectedImage.value = null;
      selectedChannel.value = null;
      selectedReport.value = null;
      await AuthService.to.signOut();
      Get.offAllNamed('/admin/login');
    } catch (e) {
      debugPrint('Admin Sign Out failed: $e');
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Executes manual video moderation action (Approve/Reject/Override)
  Future<bool> moderateVideo(
    String videoId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final newStatus = action == 'approve' ? 'approved' : 'rejected';
      final adminUid = user?.uid ?? 'admin';

      // 0ms Optimistic UI update
      final vIdx = videos.indexWhere((v) => v['id'] == videoId);
      if (vIdx != -1) {
        if (action == 'reject') {
          videos.removeAt(vIdx);
        } else {
          final item = Map<String, dynamic>.from(videos[vIdx]);
          item['status'] = 'published';
          item['isApproved'] = true;
          item['visibility'] = 'public';
          item['moderation'] = {
            'status': 'approved',
            'moderationReason': reason,
            'overriddenByAdmin': true,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'moderatedBy': adminUid,
          };
          videos[vIdx] = item;
        }
        videos.refresh();
        pendingVideos.value = videos.where(isVideoPending).length;
      }

      // 1. Direct Firestore update/delete for immediate real-time sync
      if (action == 'reject') {
        unawaited(
          FirebaseFirestore.instance.collection('videos').doc(videoId).delete().catchError((e) {
            debugPrint('Firestore moderateVideo delete error: $e');
          }),
        );
      } else {
        unawaited(
          FirebaseFirestore.instance.collection('videos').doc(videoId).set({
            'moderation': {
              'status': 'approved',
              'moderationReason': reason,
              'overriddenByAdmin': true,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
              'moderatedBy': adminUid,
            },
            'status': 'published',
            'isApproved': true,
            'visibility': 'public',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e) {
            debugPrint('Firestore moderateVideo set error: $e');
          }),
        );
      }

      // 2. Call Cloud Function endpoint if user is authenticated
      if (user != null) {
        unawaited(
          (() async {
            try {
              final idToken = await user.getIdToken();
              await http.post(
                Uri.parse(
                  'https://asia-south1-truthworld-1.cloudfunctions.net/moderateVideoManual',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'videoId': videoId,
                  'action': action,
                  'reason': reason,
                }),
              );
            } catch (cfErr) {
              debugPrint(
                'Cloud function moderateVideo warning: $cfErr',
              );
            }
          })(),
        );
      }

      Get.snackbar(
        'Video ${newStatus == 'approved' ? 'Approved' : 'Rejected'}',
        'Video status updated to ${newStatus.toUpperCase()}${newStatus == 'rejected' ? ' (Admin Override)' : ''}.',
        backgroundColor: newStatus == 'approved' ? const Color(0xFF2BA640) : AppColors.error,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedVideo.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual image moderation action (Approve/Reject)
  Future<bool> moderateImage(
    String verificationId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final newStatus = action == 'approve' ? 'APPROVED' : 'REJECTED';
      final adminUid = user.uid;

      // 0ms Optimistic UI update
      final imgIdx = images.indexWhere((img) => img['id'] == verificationId);
      if (imgIdx != -1) {
        final item = Map<String, dynamic>.from(images[imgIdx]);
        item['status'] = newStatus;
        item['isApproved'] = action == 'approve';
        item['moderation'] = {
          'status': newStatus,
          'moderationReason': reason,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'moderatedBy': adminUid,
        };
        images[imgIdx] = item;
        images.refresh();
        pendingImages.value = images.where(isImagePostPending).length;
      }

      // Direct Firestore updates for immediate real-time UI sync
      final updateData = <String, dynamic>{
        'status': newStatus,
        'isApproved': action == 'approve',
        'moderation': {
          'status': newStatus,
          'moderationReason': reason,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'moderatedBy': adminUid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .doc(verificationId)
            .set(updateData, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('flagged_images_review')
            .doc(verificationId)
            .set(updateData, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('image_verification')
            .doc(verificationId)
            .set({
              'status': action == 'approve' ? 'APPROVED' : 'REJECTED',
              'reason': reason.isNotEmpty
                  ? reason
                  : 'Manually ${action}d by administrator.',
              'reviewedBy': adminUid,
              'reviewedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .doc(verificationId)
            .set({
              'isApproved': action == 'approve',
              'thumbnailStatus': newStatus,
              'status': action == 'approve' ? 'active' : 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.playlists)
            .doc(verificationId)
            .set({
              'isApproved': action == 'approve',
              'thumbnailStatus': newStatus,
              'status': action == 'approve' ? 'active' : 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );

      try {
        final idToken = await user.getIdToken();
        final response = await http.post(
          Uri.parse(
            'https://asia-south1-truthworld-1.cloudfunctions.net/moderateImageManual',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'verificationId': verificationId,
            'action': action,
            'reason': reason,
          }),
        );

        if (response.statusCode != 200) {
          debugPrint('Cloud function moderateImage warning: ${response.body}');
        }
      } catch (cfErr) {
        debugPrint('Cloud function moderateImage warning: $cfErr');
      }

      Get.snackbar(
        'Success',
        'Image successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedImage.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual channel moderation action (Approve/Reject)
  Future<bool> moderateChannel(
    String channelId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final status = action == 'approve' ? 'active' : 'verificationRejected';

      // 0ms Optimistic UI update
      final chIdx = channels.indexWhere((c) => c['id'] == channelId);
      if (chIdx != -1) {
        final item = Map<String, dynamic>.from(channels[chIdx]);
        item['status'] = status;
        if (action == 'approve') {
          item.remove('moderationReason');
        } else {
          item['moderationReason'] = reason;
        }
        item['geminiApproved'] = action == 'approve';
        channels[chIdx] = item;
        channels.refresh();
        pendingChannels.value = channels.where(isChannelPending).length;
      }

      // Update the channel document in Firestore directly
      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .update({
              'status': status,
              'moderationReason': action == 'approve'
                  ? FieldValue.delete()
                  : reason,
              'geminiApproved': action == 'approve',
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((e) {
              debugPrint('Firestore moderateChannel error: $e');
            }),
      );

      Get.snackbar(
        'Success',
        'Channel successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedChannel.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString(),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual topic moderation action (Approve/Reject)
  Future<bool> moderateTopic(
    String topicId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final status = action == 'approve' ? 'active' : 'verificationRejected';
      final isApproved = action == 'approve';
      final adminUid = user?.uid ?? 'admin';

      // 0ms Optimistic UI update
      final tIdx = topics.indexWhere((t) => t['id'] == topicId);
      if (tIdx != -1) {
        final item = Map<String, dynamic>.from(topics[tIdx]);
        item['status'] = status;
        item['isApproved'] = isApproved;
        item['geminiApproved'] = isApproved;
        item['moderationReason'] = reason;
        item['manuallyVerified'] = true;
        item['verifiedBy'] = adminUid;
        topics[tIdx] = item;
        topics.refresh();
        pendingTopics.value = topics.where(isTopicPending).length;
      }

      // Direct Firestore update for real-time synchronization
      unawaited(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .doc(topicId)
            .set({
              'status': status,
              'isApproved': isApproved,
              'geminiApproved': isApproved,
              'moderationReason': reason,
              'manuallyVerified': true,
              'verifiedBy': adminUid,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((e) {
              debugPrint('Firestore moderateTopic error: $e');
            }),
      );

      // Call Cloud Function endpoint if available
      if (user != null) {
        unawaited(
          (() async {
            try {
              final idToken = await user.getIdToken();
              await http.post(
                Uri.parse(
                  'https://asia-south1-truthworld-1.cloudfunctions.net/moderateTopicManual',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'topicId': topicId,
                  'action': action,
                  'reason': reason,
                }),
              );
            } catch (cfErr) {
              debugPrint('Cloud function moderateTopic warning: $cfErr');
            }
          })(),
        );
      }

      Get.snackbar(
        'Topic ${action == 'approve' ? 'Approved' : 'Rejected'}',
        'Topic status updated to ${status.toUpperCase()}.',
        backgroundColor: action == 'approve' ? const Color(0xFF2BA640) : AppColors.error,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedTopic.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  Future<bool> moderateAd(
    String adId,
    String action, {
    String? reason,
  }) async {
    isActionSubmitting.value = true;
    try {
      final status = action == 'approve' ? 'active' : 'verification_rejected';

      // 0ms Optimistic UI update
      final adIdx = ads.indexWhere((a) => a['id'] == adId);
      if (adIdx != -1) {
        final item = Map<String, dynamic>.from(ads[adIdx]);
        item['status'] = status;
        if (action == 'approve') {
          item.remove('moderationReason');
        } else {
          item['moderationReason'] = reason ?? 'Violates advertising policy';
        }
        item['geminiApproved'] = action == 'approve';
        ads[adIdx] = item;
        ads.refresh();
        pendingAds.value =
            ads.where((a) => a['status'] == 'underReview').length;
      }

      // Update Firestore ad_campaigns document
      unawaited(
        FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(adId)
            .update({
              'status': status,
              'moderationReason': action == 'approve'
                  ? FieldValue.delete()
                  : (reason ?? 'Violates advertising policy'),
              'geminiApproved': action == 'approve',
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((e) {
              debugPrint('Firestore moderateAd error: $e');
            }),
      );

      Get.snackbar(
        'Success',
        'Campaign successfully ${action}d.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedAd.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        'Failed to $action ad campaign: $e',
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Search & Bulk Moderation Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Toggles selection of an item for bulk operations
  void toggleItemSelection(String id) {
    if (selectedItemIds.contains(id)) {
      selectedItemIds.remove(id);
    } else {
      selectedItemIds.add(id);
    }
  }

  /// Clears all selected items
  void clearSelection() => selectedItemIds.clear();

  /// Selects all items in the current view
  void selectAllItems(List<Map<String, dynamic>> items) {
    selectedItemIds.assignAll(items.map((e) => e['id'] as String));
  }

  /// Executes bulk moderation action on selected items
  Future<void> bulkModerate(
    String contentType,
    String action,
    String reason,
  ) async {
    if (selectedItemIds.isEmpty) return;
    isBulkActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired.');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
          'https://asia-south1-truthworld-1.cloudfunctions.net/adminBulkModerate',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'contentType': contentType,
          'action': action,
          'itemIds': selectedItemIds.toList(),
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['error'] ?? 'Bulk moderation failed.');
      }

      final result = jsonDecode(response.body);
      final successCount =
          (result['results'] as List?)
              ?.where((r) => r['success'] == true)
              .length ??
          0;

      Get.snackbar(
        'Bulk Action Complete',
        '$successCount/${selectedItemIds.length} items ${action}ed successfully.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      clearSelection();
    } catch (e) {
      Get.snackbar(
        'Bulk Action Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isBulkActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: User Management Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maps raw Firestore user document into standard Map structure for admin UI
  Map<String, dynamic> _mapUserDoc(String id, Map<String, dynamic>? rawData) {
    final data = rawData ?? {};
    final displayName = (data['displayName'] ?? data['name'] ?? data['username'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final fallbackName = displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@')[0] : 'User ${id.length > 6 ? id.substring(0, 6) : id}');

    final isBanned = data['isBanned'] == true || data['role'] == 'banned' || data['accountStatus'] == 'BANNED';
    final isSuspended = data['accountStatus'] == 'SUSPENDED' ||
        (data['suspendedUntil'] != null &&
            data['suspendedUntil'] is num &&
            (data['suspendedUntil'] as num) > DateTime.now().millisecondsSinceEpoch);

    final status = isBanned ? 'banned' : (isSuspended ? 'suspended' : 'active');
    final trustScore = (data['trustScore'] is num)
        ? (data['trustScore'] as num).toInt()
        : ((data['score'] is num) ? (data['score'] as num).toInt() : 100);
    final strikes = (data['strikes'] is num)
        ? (data['strikes'] as num).toInt()
        : ((data['strikeCount'] is num) ? (data['strikeCount'] as num).toInt() : 0);

    return {
      'id': id,
      'uid': id,
      'name': fallbackName,
      'displayName': displayName,
      'email': email,
      'photoURL': data['photoURL'] ?? data['avatarUrl'] ?? '',
      'avatarUrl': data['photoURL'] ?? data['avatarUrl'] ?? '',
      'trustScore': trustScore,
      'status': status,
      'accountStatus': data['accountStatus'] ?? status.toUpperCase(),
      'strikes': strikes,
      'role': data['role'] ?? (data['isAdmin'] == true ? 'admin' : 'user'),
      'channelId': data['channelId'],
      'createdAt': data['createdAt'],
      'lastLoginAt': data['lastLoginAt'],
      'phoneNumber': data['phoneNumber'] ?? '',
      'banReason': data['banReason'],
      'suspendedUntil': data['suspendedUntil'],
      ...data,
    };
  }

  /// Sorts users by creation date and applies current filters
  void _sortAndSetUsers(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final timeA = a['createdAt'] ?? a['lastLoginAt'];
      final timeB = b['createdAt'] ?? b['lastLoginAt'];
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final dtA = timeA is Timestamp
          ? timeA.toDate()
          : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
      final dtB = timeB is Timestamp
          ? timeB.toDate()
          : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
      return dtB.compareTo(dtA);
    });

    allUsers.assignAll(list);
    _applyUserFilters();
  }

  /// Applies search query and status filter to `allUsers` and updates `searchedUsers`
  void _applyUserFilters() {
    var filtered = List<Map<String, dynamic>>.from(allUsers);
    final query = userSearchQuery.value.trim().toLowerCase();
    final statusFilter = userFilterStatus.value;

    if (statusFilter != 'all') {
      filtered = filtered.where((u) => u['status'] == statusFilter).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((u) {
        final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final uid = (u['id'] ?? u['uid'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || uid.contains(query) || phone.contains(query);
      }).toList();
    }

    searchedUsers.assignAll(filtered);

    // Auto-select user if current selection is missing or not in list
    if (selectedUser.value == null && searchedUsers.isNotEmpty) {
      selectedUser.value = searchedUsers.first;
      getUserSafetyProfile(searchedUsers.first['id'] ?? '');
    } else if (selectedUser.value != null) {
      final currentId = selectedUser.value!['id'];
      final updated = searchedUsers.firstWhereOrNull((u) => u['id'] == currentId);
      if (updated != null) {
        selectedUser.value = updated;
      }
    }
  }

  /// Sets the user status filter ('all', 'active', 'banned', 'suspended')
  void setUserFilterStatus(String status) {
    userFilterStatus.value = status;
    _applyUserFilters();
  }

  /// Fetches users directly from Firestore and updates [searchedUsers]
  Future<void> fetchUsers({String? query, bool force = false}) async {
    if (query != null) {
      userSearchQuery.value = query;
    }
    isSearchingUsers.value = true;
    try {
      QuerySnapshot<Map<String, dynamic>> usersSnap;
      try {
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
      } catch (_) {
        // Fallback without orderBy in case index or field is missing
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .limit(100)
            .get();
      }

      final list = usersSnap.docs.map((doc) => _mapUserDoc(doc.id, doc.data())).toList();
      _sortAndSetUsers(list);
    } catch (e) {
      debugPrint('AdminController fetchUsers error: $e');
    } finally {
      isSearchingUsers.value = false;
    }
  }

  /// Searches users by email or display name
  Future<void> searchUsers(String queryText) async {
    userSearchQuery.value = queryText;
    if (allUsers.isNotEmpty) {
      _applyUserFilters();
      return;
    }
    await fetchUsers(query: queryText);
  }

  /// Loads the full safety profile for a user
  Future<void> getUserSafetyProfile(String userId) async {
    if (userId.isEmpty) return;
    isLoadingProfile.value = true;
    try {
      final db = FirebaseFirestore.instance;

      // 1. Fetch user doc
      final userDoc = await db.collection(FirestoreCollections.users).doc(userId).get();
      final userData = userDoc.exists
          ? _mapUserDoc(userId, userDoc.data() ?? {})
          : <String, dynamic>{'id': userId, 'uid': userId, 'name': 'User', 'email': ''};

      // 2. Fetch userTrust doc
      var trustData = <String, dynamic>{};
      try {
        final trustDoc = await db.collection('userTrust').doc(userId).get();
        if (trustDoc.exists && trustDoc.data() != null) {
          trustData = trustDoc.data()!;
        }
      } catch (_) {}

      // 3. Fetch user's channels
      var userChannels = <Map<String, dynamic>>[];
      try {
        final channelsSnap = await db
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: userId)
            .limit(10)
            .get();
        userChannels = channelsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (userChannels.isEmpty) {
          final fallbackChannelsSnap = await db
              .collection(FirestoreCollections.channels)
              .where('userId', isEqualTo: userId)
              .limit(10)
              .get();
          userChannels = fallbackChannelsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        }
      } catch (_) {}

      // 4. Fetch user's videos for upload statistics
      var totalUploads = 0;
      var approvedCount = 0;
      var rejectedCount = 0;
      try {
        final videosSnap = await db
            .collection(FirestoreCollections.videos)
            .where('ownerId', isEqualTo: userId)
            .limit(100)
            .get();
        totalUploads = videosSnap.docs.length;
        for (final v in videosSnap.docs) {
          final s = (v.data()['status'] ?? (v.data()['isApproved'] == true ? 'approved' : '')).toString().toLowerCase();
          if (s == 'approved' || v.data()['isApproved'] == true) approvedCount++;
          if (s == 'rejected') rejectedCount++;
        }
        if (totalUploads == 0) {
          final fallbackVideosSnap = await db
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: userId)
              .limit(100)
              .get();
          totalUploads = fallbackVideosSnap.docs.length;
          for (final v in fallbackVideosSnap.docs) {
            final s = (v.data()['status'] ?? (v.data()['isApproved'] == true ? 'approved' : '')).toString().toLowerCase();
            if (s == 'approved' || v.data()['isApproved'] == true) approvedCount++;
            if (s == 'rejected') rejectedCount++;
          }
        }
      } catch (_) {}

      // 5. Fetch user's reports/violations
      var violations = <Map<String, dynamic>>[];
      try {
        final repSnap = await db
            .collection(FirestoreCollections.reports)
            .where('reportedUserId', isEqualTo: userId)
            .limit(20)
            .get();
        violations = repSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {}

      // 6. Fetch moderation history
      var modHistory = <Map<String, dynamic>>[];
      try {
        final logsSnap = await db
            .collection('admin_actions_log')
            .where('userId', isEqualTo: userId)
            .limit(20)
            .get();
        modHistory = logsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {}

      final trustScore = (trustData['score'] is num)
          ? (trustData['score'] as num).toInt()
          : (userData['trustScore'] as int? ?? 100);
      final strikes = (trustData['strikes'] is num)
          ? (trustData['strikes'] as num).toInt()
          : (userData['strikes'] as int? ?? 0);
      final approvalRate = totalUploads > 0 ? ((approvedCount / totalUploads) * 100).round() : 100;
      final rejectionRate = totalUploads > 0 ? ((rejectedCount / totalUploads) * 100).round() : 0;

      userSafetyProfile.value = {
        'userId': userId,
        'user': userData,
        'trustScore': trustScore,
        'strikes': strikes,
        'status': userData['status'] ?? 'active',
        'accountStatus': userData['accountStatus'] ?? 'ACTIVE',
        'totalUploads': totalUploads,
        'approvalRate': approvalRate,
        'rejectionRate': rejectionRate,
        'channels': userChannels,
        'violations': violations,
        'appeals': [],
        'moderationHistory': modHistory,
      };
    } catch (e) {
      debugPrint('User profile error: $e');
    } finally {
      isLoadingProfile.value = false;
    }
  }

  /// Executes a moderation action on a user account
  Future<bool> moderateUser(
    String userId,
    String action,
    String reason, {
    int? durationDays,
  }) async {
    isActionSubmitting.value = true;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminId = currentUser?.uid ?? 'admin';
      final adminEmail = currentUser?.email ?? 'admin@truthworld.com';
      final db = FirebaseFirestore.instance;

      final normalizedAction = action.trim().toLowerCase();
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalizedAction == 'ban' || normalizedAction == 'ban user') {
        updates['isBanned'] = true;
        updates['role'] = 'banned';
        updates['accountStatus'] = 'BANNED';
        updates['status'] = 'banned';
        updates['banReason'] = reason;
        updates['bannedAt'] = FieldValue.serverTimestamp();
      } else if (normalizedAction == 'unban' || normalizedAction == 'unban user' || normalizedAction == 'reactivate' || normalizedAction == 'reactivate user') {
        updates['isBanned'] = false;
        updates['role'] = 'user';
        updates['accountStatus'] = 'ACTIVE';
        updates['status'] = 'active';
        updates['banReason'] = FieldValue.delete();
        updates['suspendedUntil'] = FieldValue.delete();
      } else if (normalizedAction.startsWith('suspend')) {
        final days = durationDays ?? 7;
        final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
        updates['isBanned'] = false;
        updates['accountStatus'] = 'SUSPENDED';
        updates['status'] = 'suspended';
        updates['suspendedUntil'] = until;
        updates['banReason'] = reason;
      } else if (normalizedAction == 'warn' || normalizedAction == 'warn user') {
        updates['strikes'] = FieldValue.increment(1);
        updates['lastWarningReason'] = reason;
        updates['lastWarningAt'] = FieldValue.serverTimestamp();
      } else if (normalizedAction == 'reset trust' || normalizedAction == 'reset_trust' || normalizedAction == 'reset') {
        updates['trustScore'] = 100;
        updates['strikes'] = 0;
        try {
          await db.collection('userTrust').doc(userId).set({
            'score': 100,
            'strikes': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      } else if (normalizedAction == 'delete' || normalizedAction == 'delete user' || normalizedAction == 'delete account') {
        updates['isDeleted'] = true;
        updates['status'] = 'deleted';
        updates['accountStatus'] = 'DELETED';
      }

      // 1. Direct Firestore Update
      await db.collection(FirestoreCollections.users).doc(userId).set(updates, SetOptions(merge: true));

      // 2. Log Action
      try {
        await db.collection('admin_actions_log').add({
          'adminId': adminId,
          'adminEmail': adminEmail,
          'userId': userId,
          'action': normalizedAction,
          'reason': reason,
          'durationDays': durationDays,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      Get.snackbar(
        'Action Applied',
        'User action "$action" processed successfully.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );

      // 3. Update in-memory user list
      final index = allUsers.indexWhere((u) => u['id'] == userId);
      if (index != -1) {
        final updatedUser = Map<String, dynamic>.from(allUsers[index]);
        if (normalizedAction.contains('ban')) {
          updatedUser['status'] = 'banned';
          updatedUser['isBanned'] = true;
          updatedUser['accountStatus'] = 'BANNED';
        } else if (normalizedAction.contains('unban') || normalizedAction.contains('reactivate')) {
          updatedUser['status'] = 'active';
          updatedUser['isBanned'] = false;
          updatedUser['accountStatus'] = 'ACTIVE';
        } else if (normalizedAction.startsWith('suspend')) {
          updatedUser['status'] = 'suspended';
          updatedUser['accountStatus'] = 'SUSPENDED';
        } else if (normalizedAction.contains('warn')) {
          updatedUser['strikes'] = (updatedUser['strikes'] as int? ?? 0) + 1;
        } else if (normalizedAction.contains('reset')) {
          updatedUser['trustScore'] = 100;
          updatedUser['strikes'] = 0;
        }
        allUsers[index] = updatedUser;
        _applyUserFilters();
      }

      await getUserSafetyProfile(userId);
      return true;
    } catch (e) {
      Get.snackbar(
        'Action Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Analytics Methods
  // ═══════════════════════════════════════════════════════════════════════════

  DateTime? _getAnalyticsFilterDate() {
    final range = analyticsTimeRange.value;
    final now = DateTime.now();
    switch (range) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case 'all':
      default:
        return null;
    }
  }

  DateTime? _extractTimestamp(dynamic rawTime) {
    if (rawTime == null) return null;
    if (rawTime is Timestamp) return rawTime.toDate();
    if (rawTime is DateTime) return rawTime;
    if (rawTime is int) return DateTime.fromMillisecondsSinceEpoch(rawTime);
    if (rawTime is String) return DateTime.tryParse(rawTime);
    return null;
  }

  bool _isNotViolationCategory(String cat) {
    final lower = cat.trim().toLowerCase();
    const nonViolations = {
      'general',
      'technology',
      'tech',
      'entertainment',
      'music',
      'gaming',
      'education',
      'news',
      'sports',
      'comedy',
      'science',
      'travel',
      'vlog',
      'people',
      'lifestyle',
      'community post',
      'community',
      'video thumbnail',
      'thumbnail',
      'channel avatar',
      'avatar',
      'channel banner',
      'banner',
      'playlist thumbnail',
      'topic thumbnail',
      'video',
      'image',
      'all',
      'none',
      'n/a',
      'unknown',
      'approved',
      'pending',
      'clean',
    };
    return nonViolations.contains(lower);
  }

  String _normalizeViolationCategory(String raw) {
    final lower = raw.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    if (lower.contains('hate')) return 'Hate Speech & Harassment';
    if (lower.contains('harass') || lower.contains('bully')) return 'Harassment & Bullying';
    if (lower.contains('copyright') || lower.contains('dmca') || lower.contains('ip ')) return 'Copyright Infringement';
    if (lower.contains('adult') || lower.contains('nsfw') || lower.contains('nudity') || lower.contains('sexual')) return 'Adult / NSFW Content';
    if (lower.contains('violence') || lower.contains('gore') || lower.contains('graphic')) return 'Graphic Violence';
    if (lower.contains('spam') || lower.contains('scam') || lower.contains('fraud') || lower.contains('phish')) return 'Spam & Deceptive Practices';
    if (lower.contains('misinformation') || lower.contains('fake news')) return 'Misinformation';
    if (lower.contains('child') || lower.contains('csam')) return 'Child Safety Violation';
    if (lower.contains('terror') || lower.contains('dangerous')) return 'Dangerous & Illegal Acts';
    if (lower.contains('racy')) return 'Racy / Borderline Content';
    if (lower.contains('medical')) return 'Sensitive Medical Content';
    if (lower.contains('spoof')) return 'Spoof & Impersonation';
    if (lower.contains('guideline') || lower.contains('community')) return 'Community Guideline Breach';

    return raw.split(RegExp(r'[_\s]+')).map((w) => w.capitalizeFirst ?? w).join(' ');
  }

  /// Fetches real aggregated analytics data from Firestore for the selected time range
  Future<void> fetchAnalytics() async {
    isLoadingAnalytics.value = true;
    try {
      final filterDate = _getAnalyticsFilterDate();

      // 1. Fetch Real Videos from Firestore
      QuerySnapshot<Map<String, dynamic>>? videosSnap;
      try {
        videosSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching videos for analytics: $e');
      }

      // 2. Fetch Real Channels from Firestore
      QuerySnapshot<Map<String, dynamic>>? channelsSnap;
      try {
        channelsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching channels for analytics: $e');
      }

      // 3. Fetch Real Reports from Firestore
      QuerySnapshot<Map<String, dynamic>>? reportsSnap;
      try {
        reportsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.reports)
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching reports for analytics: $e');
      }

      QuerySnapshot<Map<String, dynamic>>? videoReportsSnap;
      try {
        videoReportsSnap = await FirebaseFirestore.instance
            .collection('video_reports')
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching video_reports for analytics: $e');
      }

      QuerySnapshot<Map<String, dynamic>>? altVideoReportsSnap;
      try {
        altVideoReportsSnap = await FirebaseFirestore.instance
            .collection('videoReports')
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching alt videoReports for analytics: $e');
      }

      // 4. Fetch Real Flagged & Moderated Media from Firestore
      QuerySnapshot<Map<String, dynamic>>? flaggedImagesSnap;
      try {
        flaggedImagesSnap = await FirebaseFirestore.instance
            .collection('flagged_images_review')
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching flagged images for analytics: $e');
      }

      QuerySnapshot<Map<String, dynamic>>? rejectedLogsSnap;
      try {
        rejectedLogsSnap = await FirebaseFirestore.instance
            .collection('rejected_images_log')
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching rejected logs for analytics: $e');
      }

      QuerySnapshot<Map<String, dynamic>>? communitySnap;
      try {
        communitySnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.community)
            .limit(300)
            .get();
      } catch (e) {
        debugPrint('Error fetching community posts for analytics: $e');
      }

      // 5. Fetch Appeals from Firestore
      QuerySnapshot<Map<String, dynamic>>? appealsSnap;
      try {
        appealsSnap = await FirebaseFirestore.instance
            .collection('content_appeals')
            .limit(200)
            .get();
      } catch (e) {
        debugPrint('Error fetching appeals for analytics: $e');
      }

      // 6. Fetch Users from Firestore for Strikes & Profile Lookups
      QuerySnapshot<Map<String, dynamic>>? usersSnap;
      try {
        usersSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .limit(500)
            .get();
      } catch (e) {
        debugPrint('Error fetching users for analytics: $e');
      }

      final userLookup = <String, Map<String, dynamic>>{};
      var totalPlatformUsers = 0;
      var bannedUsersCount = 0;

      if (usersSnap != null) {
        totalPlatformUsers = usersSnap.docs.length;
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          final uid = doc.id;
          final isBanned = data['isBanned'] == true || data['role'] == 'banned';
          final strikes = (data['strikes'] is num) ? (data['strikes'] as num).toInt() : 0;
          if (isBanned) bannedUsersCount++;

          userLookup[uid] = {
            'name': data['displayName'] ?? data['name'] ?? data['username'] ?? uid,
            'email': data['email'] ?? '',
            'strikes': strikes,
            'isBanned': isBanned,
          };
        }
      }

      // Aggregate Violation Categories (ONLY real violations)
      final violationCounts = <String, int>{};
      final userOffenses = <String, Map<String, dynamic>>{};

      void recordOffense(String userId, {String? email, String? name}) {
        if (userId.isEmpty || userId == 'unknown') return;
        final existing = userOffenses[userId] ?? {
          'user': name ?? userLookup[userId]?['name'] ?? email ?? userLookup[userId]?['email'] ?? userId,
          'email': email ?? userLookup[userId]?['email'] ?? '',
          'violationsCount': 0,
          'strikes': userLookup[userId]?['strikes'] ?? 0,
          'isBanned': userLookup[userId]?['isBanned'] ?? false,
        };
        existing['violationsCount'] = (existing['violationsCount'] as int) + 1;
        userOffenses[userId] = existing;
      }

      // Process Videos
      var totalVideosInPeriod = 0;
      var approvedVideos = 0;
      var rejectedVideos = 0;
      var pendingVideosCount = 0;
      final allVideosDocs = videosSnap?.docs ?? [];

      for (final doc in allVideosDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['createdAt'] ?? data['uploadedAt'] ?? data['timestamp']);

        // Check if within time filter
        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalVideosInPeriod++;
        final mod = data['moderation'] as Map<String, dynamic>?;
        final status = (mod?['status'] ?? data['status'] ?? '').toString().toLowerCase();

        if (status == 'approved') {
          approvedVideos++;
        } else if (status == 'rejected') {
          rejectedVideos++;
          final uId = (data['userId'] ?? data['creatorId'] ?? data['uploaderId'] ?? '').toString();
          recordOffense(uId, email: data['userEmail']?.toString());

          // Extract real violation categories
          final categories = mod?['violationCategories'];
          if (categories is List) {
            for (final c in categories) {
              if (c != null && !_isNotViolationCategory(c.toString())) {
                final catName = _normalizeViolationCategory(c.toString());
                violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
              }
            }
          }
          final reason = mod?['rejectionReason'] ?? mod?['moderationReason'] ?? data['rejectionReason'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else {
          pendingVideosCount++;
        }
      }

      // Process Channels
      var totalChannelsInPeriod = 0;
      var approvedChannels = 0;
      var rejectedChannels = 0;
      var pendingChannelsCount = 0;
      final allChannelsDocs = channelsSnap?.docs ?? [];

      for (final doc in allChannelsDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['updatedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalChannelsInPeriod++;
        final status = (data['status'] ?? data['verificationStatus'] ?? 'approved').toString().toLowerCase();
        if (status == 'approved' || status == 'verified') {
          approvedChannels++;
        } else if (status == 'rejected') {
          rejectedChannels++;
          final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
          recordOffense(ownerId);
          final reason = data['rejectionReason'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else {
          pendingChannelsCount++;
        }
      }

      // Process Reports (reports, video_reports, videoReports)
      var totalReportsInPeriod = 0;
      var pendingReportsCount = 0;
      var resolvedReportsCount = 0;
      var dismissedReportsCount = 0;

      final allReportDocs = [
        ...?reportsSnap?.docs,
        ...?videoReportsSnap?.docs,
        ...?altVideoReportsSnap?.docs,
      ];

      final processedReportIds = <String>{};
      for (final doc in allReportDocs) {
        if (processedReportIds.contains(doc.id)) continue;
        processedReportIds.add(doc.id);

        final data = doc.data();
        final timestamp = _extractTimestamp(data['timestamp'] ?? data['createdAt'] ?? data['reportedAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalReportsInPeriod++;
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'resolved' || status == 'actioned' || status == 'approved' || status == 'closed') {
          resolvedReportsCount++;
        } else if (status == 'dismissed' || status == 'rejected') {
          dismissedReportsCount++;
        } else {
          pendingReportsCount++;
        }

        // Extract real report violation reason
        final reason = data['reason'] ?? data['category'] ?? data['reportReason'] ?? data['violationType'];
        if (reason != null && !_isNotViolationCategory(reason.toString())) {
          final catName = _normalizeViolationCategory(reason.toString());
          violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
        }

        // Track reported offender
        final reportedUser = (data['reportedUserId'] ?? data['targetUserId'] ?? data['uploaderId'] ?? '').toString();
        if (reportedUser.isNotEmpty) {
          recordOffense(reportedUser);
        }
      }

      // Process Flagged Media, Rejected Images Log & Community Posts
      var totalMediaInPeriod = 0;
      var approvedMedia = 0;
      var rejectedMedia = 0;
      var pendingMediaCount = 0;

      final allMediaDocs = [
        ...?flaggedImagesSnap?.docs,
        ...?rejectedLogsSnap?.docs,
        ...?communitySnap?.docs,
      ];

      final processedMediaIds = <String>{};
      for (final doc in allMediaDocs) {
        if (processedMediaIds.contains(doc.id)) continue;
        processedMediaIds.add(doc.id);

        final data = doc.data();
        final timestamp = _extractTimestamp(data['timestamp'] ?? data['flaggedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalMediaInPeriod++;
        final status = (data['status'] ?? '').toString().toUpperCase();

        if (status == 'APPROVED') {
          approvedMedia++;
        } else if (status == 'REJECTED' || doc.reference.parent.id == 'rejected_images_log') {
          rejectedMedia++;
          final uId = (data['uploaderId'] ?? data['userId'] ?? data['authorId'] ?? '').toString();
          recordOffense(uId, email: data['userEmail']?.toString());

          // SafeSearch Scores: only count if likelihood score >= 4 (LIKELY / VERY_LIKELY)
          final scores = data['safeSearchScores'] as Map<String, dynamic>?;
          if (scores != null) {
            scores.forEach((key, value) {
              if (value is num && value >= 4) {
                final catName = _normalizeViolationCategory(key);
                violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
              }
            });
          }

          final reason = data['rejectionReason'] ?? data['reason'] ?? data['violationCategory'];
          if (reason != null && !_isNotViolationCategory(reason.toString())) {
            final catName = _normalizeViolationCategory(reason.toString());
            violationCounts[catName] = (violationCounts[catName] ?? 0) + 1;
          }
        } else if (status == 'PENDING_REVIEW' || data['isFlagged'] == true) {
          pendingMediaCount++;
        } else {
          approvedMedia++;
        }
      }

      // Process Appeals
      var totalAppealsInPeriod = 0;
      var pendingAppealsCount = 0;
      var upheldAppeals = 0;
      var overturnedAppeals = 0;
      final allAppealsDocs = appealsSnap?.docs ?? [];

      for (final doc in allAppealsDocs) {
        final data = doc.data();
        final timestamp = _extractTimestamp(data['submittedAt'] ?? data['createdAt']);

        if (filterDate != null && timestamp != null && timestamp.isBefore(filterDate)) {
          continue;
        }

        totalAppealsInPeriod++;
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'overturned' || status == 'approved') {
          overturnedAppeals++;
        } else if (status == 'upheld' || status == 'rejected') {
          upheldAppeals++;
        } else {
          pendingAppealsCount++;
        }
      }

      // Include users with recorded strikes from the users collection in the offenses map
      userLookup.forEach((uid, info) {
        final strikes = info['strikes'] as int? ?? 0;
        final isBanned = info['isBanned'] as bool? ?? false;
        if (strikes > 0 || isBanned) {
          final existing = userOffenses[uid] ?? {
            'user': info['name'],
            'email': info['email'],
            'violationsCount': strikes,
            'strikes': strikes,
            'isBanned': isBanned,
          };
          userOffenses[uid] = existing;
        }
      });

      // Sort Top Offenders by violations & strikes
      final sortedOffenders = userOffenses.values.where((off) {
        final vCount = off['violationsCount'] as int? ?? 0;
        final strikes = off['strikes'] as int? ?? 0;
        final isBanned = off['isBanned'] == true;
        return vCount > 0 || strikes > 0 || isBanned;
      }).toList()
        ..sort((a, b) {
          final cmp = (b['violationsCount'] as int).compareTo(a['violationsCount'] as int);
          if (cmp != 0) return cmp;
          final sB = b['strikes'] as int;
          final sA = a['strikes'] as int;
          return sB.compareTo(sA);
        });

      final topOffenders = sortedOffenders.take(8).toList();

      // Aggregate Platform Totals
      final totalModerated = totalVideosInPeriod + totalMediaInPeriod + totalChannelsInPeriod + totalReportsInPeriod;
      final totalApproved = approvedVideos + approvedMedia + approvedChannels;
      final totalRejected = rejectedVideos + rejectedMedia + rejectedChannels;
      final totalPending = pendingVideosCount + pendingMediaCount + pendingChannelsCount + pendingReportsCount;
      final activeViolations = pendingReportsCount + rejectedVideos + rejectedMedia;

      final autoApprovalRate = totalModerated > 0
          ? ((totalApproved / (totalApproved + totalRejected + 0.0001)) * 100).clamp(0, 100).round()
          : 100;

      // Platform Safety Score Calculation
      // 100 base, decreased by rejection rate & open active violations
      var calculatedScore = 100.0;
      if (totalModerated > 0) {
        final rejectRatio = totalRejected / totalModerated;
        calculatedScore -= rejectRatio * 40.0;
      }
      if (activeViolations > 0) {
        calculatedScore -= activeViolations.clamp(0, 20) * 1.5;
      }
      if (totalPending > 20) {
        calculatedScore -= (totalPending - 20).clamp(0, 30) * 0.3;
      }
      final safetyScore = calculatedScore.round().clamp(0, 100);

      analyticsData.assignAll({
        'safetyScore': safetyScore,
        'totalModerated': totalModerated,
        'totalModerated24h': totalModerated,
        'moderated24h': totalModerated,
        'autoApprovalRate': autoApprovalRate,
        'autoApproveRate': autoApprovalRate,
        'activeViolations': activeViolations,
        'totalApproved': totalApproved,
        'totalRejected': totalRejected,
        'totalPending': totalPending,
        'violationCategories': violationCounts,
        'topOffenders': topOffenders,
        'breakdown': {
          'videos': {
            'total': totalVideosInPeriod,
            'approved': approvedVideos,
            'rejected': rejectedVideos,
            'pending': pendingVideosCount,
          },
          'media': {
            'total': totalMediaInPeriod,
            'approved': approvedMedia,
            'rejected': rejectedMedia,
            'pending': pendingMediaCount,
          },
          'channels': {
            'total': totalChannelsInPeriod,
            'approved': approvedChannels,
            'rejected': rejectedChannels,
            'pending': pendingChannelsCount,
          },
          'reports': {
            'total': totalReportsInPeriod,
            'pending': pendingReportsCount,
            'resolved': resolvedReportsCount,
            'dismissed': dismissedReportsCount,
          },
          'appeals': {
            'total': totalAppealsInPeriod,
            'pending': pendingAppealsCount,
            'upheld': upheldAppeals,
            'overturned': overturnedAppeals,
          },
        },
        'platformTotals': {
          'totalUsers': totalPlatformUsers > 0 ? totalPlatformUsers : allVideosDocs.length,
          'totalVideos': allVideosDocs.length,
          'totalChannels': allChannelsDocs.length,
          'totalReports': allReportDocs.length,
          'totalAppeals': allAppealsDocs.length,
          'bannedUsers': bannedUsersCount,
        },
        'timeRange': analyticsTimeRange.value,
        'lastUpdated': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Analytics fetch error: $e');
    } finally {
      isLoadingAnalytics.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Alerts & Escalation Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Loads alert rules and active alerts from Firestore
  Future<void> fetchAlerts() async {
    isLoadingAlerts.value = true;
    try {
      // Load active alerts
      final alertsSnap = await FirebaseFirestore.instance
          .collection('admin_alerts')
          .orderBy('triggeredAt', descending: true)
          .limit(50)
          .get();
      activeAlerts.assignAll(
        alertsSnap.docs.map((d) => {'id': d.id, ...d.data()}),
      );

      // Load alert rules configuration
      final rulesDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('alert_rules')
          .get();
      if (rulesDoc.exists && rulesDoc.data()?['rules'] != null) {
        alertRules.assignAll(
          List<Map<String, dynamic>>.from(rulesDoc.data()!['rules']),
        );
      } else {
        // Default alert rules
        alertRules.assignAll([
          {
            'name': 'Queue Backlog Alert',
            'threshold': 500,
            'enabled': true,
            'channels': ['push'],
          },
          {
            'name': 'Repeat Offender Alert',
            'threshold': 3,
            'enabled': true,
            'channels': ['push', 'email'],
          },
          {
            'name': 'Vision API Error Rate',
            'threshold': 10,
            'enabled': true,
            'channels': ['push'],
          },
          {
            'name': 'DLQ Depth Alert',
            'threshold': 50,
            'enabled': true,
            'channels': ['push'],
          },
          {
            'name': 'Safety Score Drop',
            'threshold': 80,
            'enabled': true,
            'channels': ['push', 'email'],
          },
          {
            'name': 'Tier 4 Emergency (CSAM)',
            'threshold': 1,
            'enabled': true,
            'channels': ['push', 'email', 'sms'],
          },
        ]);
      }
    } catch (e) {
      debugPrint('Alerts fetch error: $e');
    } finally {
      isLoadingAlerts.value = false;
    }
  }

  /// Saves updated alert rules to Firestore
  Future<void> saveAlertRules() async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('alert_rules')
          .set({
            'rules': alertRules.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      Get.snackbar(
        'Alert Rules Saved',
        'Alert configuration updated successfully.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Alert rules save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Appeals Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Loads pending appeals from Firestore
  Future<void> fetchAppeals() async {
    isLoadingAppeals.value = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('content_appeals')
          .limit(100)
          .get();
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final timeA = a['submittedAt'] ?? a['createdAt'];
        final timeB = b['submittedAt'] ?? b['createdAt'];
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
      appeals.assignAll(list);
      pendingAppeals.value = list
          .where((a) => (a['status'] ?? '').toString().toLowerCase() == 'pending')
          .length;
    } catch (e) {
      debugPrint('Appeals fetch error: $e');
    } finally {
      isLoadingAppeals.value = false;
    }
  }

  /// Resolves an appeal with the given action
  Future<bool> resolveAppeal(
    String appealId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('content_appeals')
          .doc(appealId)
          .update({
            'status': action == 'overturn'
                ? 'overturned'
                : (action == 'escalate' ? 'escalated' : 'upheld'),
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
            'resolutionNote': reason,
          });

      Get.snackbar(
        'Appeal Resolved',
        'Appeal ${action}ed successfully.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedAppeal.value = null;
      await fetchAppeals();
      return true;
    } catch (e) {
      Get.snackbar(
        'Appeal Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Security & Anti-Abuse Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches security metrics and anomaly data
  Future<void> fetchSecurityMetrics() async {
    isLoadingSecurity.value = true;
    try {
      // Load anomaly alerts
      final alertsSnap = await FirebaseFirestore.instance
          .collection('security_anomalies')
          .orderBy('detectedAt', descending: true)
          .limit(50)
          .get();
      anomalyAlerts.assignAll(
        alertsSnap.docs.map((d) => {'id': d.id, ...d.data()}),
      );

      // Load account clusters
      final clustersSnap = await FirebaseFirestore.instance
          .collection('account_clusters')
          .orderBy('detectedAt', descending: true)
          .limit(20)
          .get();
      accountClusters.assignAll(
        clustersSnap.docs.map((d) => {'id': d.id, ...d.data()}),
      );

      // Load lockdown status
      final settingsDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('security_config')
          .get();
      isLockdownMode.value = settingsDoc.data()?['lockdownMode'] == true;

      // Compute upload velocity (hourly counts for last 24h from existing data)
      final now = DateTime.now();
      final hourlyUploads = <String, int>{};
      for (var i = 0; i < 24; i++) {
        final hour = now.subtract(Duration(hours: i));
        hourlyUploads['${hour.hour}:00'] = 0;
      }
      for (final img in images) {
        final flaggedAt = img['flaggedAt'];
        if (flaggedAt is Timestamp) {
          final dt = flaggedAt.toDate();
          if (now.difference(dt).inHours < 24) {
            final key = '${dt.hour}:00';
            hourlyUploads[key] = (hourlyUploads[key] ?? 0) + 1;
          }
        }
      }

      securityMetrics.assignAll({
        'hourlyUploads': hourlyUploads,
        'totalAnomalies': anomalyAlerts.length,
        'activeClusters': accountClusters.length,
        'lockdownMode': isLockdownMode.value,
        'globalRateLimit': {'uploadsPerHour': 100, 'uploadsPerDay': 1000},
      });
    } catch (e) {
      debugPrint('Security metrics fetch error: $e');
    } finally {
      isLoadingSecurity.value = false;
    }
  }

  /// Toggles lockdown mode (halts all uploads)
  Future<void> toggleLockdownMode() async {
    try {
      final newState = !isLockdownMode.value;
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('security_config')
          .set({
            'lockdownMode': newState,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      isLockdownMode.value = newState;
      Get.snackbar(
        newState ? 'Lockdown Activated' : 'Lockdown Deactivated',
        newState ? 'All uploads are now paused.' : 'Uploads have been resumed.',
        backgroundColor: newState
            ? const Color(0xFFCF6679)
            : const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Lockdown toggle error: $e');
    }
  }

  /// Executes manual report moderation action (resolve_keep/resolve_reject)
  Future<bool> moderateReport(
    String reportId,
    String action,
    String reviewReason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final reportRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .doc(reportId);
      final reportSnap = await reportRef.get();
      if (!reportSnap.exists) {
        throw Exception('Report not found');
      }
      final reportData = reportSnap.data()!;
      final videoId = reportData['videoId'] as String?;

      if (action == 'reject' && videoId != null) {
        // Reject the video as well (this will call moderateVideoCloudFunction)
        final success = await moderateVideo(videoId, 'reject', reviewReason);
        if (!success) {
          throw Exception(
            'Failed to reject the video associated with this report.',
          );
        }
      }

      // 0ms Optimistic UI update
      final rIdx = reports.indexWhere((r) => r['id'] == reportId);
      if (rIdx != -1) {
        final item = Map<String, dynamic>.from(reports[rIdx]);
        item['status'] = action == 'reject' ? 'resolved_rejected' : 'resolved_dismissed';
        item['isResolved'] = true;
        item['resolutionComment'] = reviewReason;
        reports[rIdx] = item;
        reports.refresh();
        pendingReports.value = reports.where(isReportPending).length;
      }

      unawaited(
        reportRef.update({
          'status': action == 'reject'
              ? 'resolved_rejected'
              : 'resolved_dismissed',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolutionComment': reviewReason,
        }).catchError((e) {
          debugPrint('Firestore moderateReport update error: $e');
        }),
      );

      Get.snackbar(
        'Success',
        'Report successfully resolved.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedReport.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: const Color(0xFFCF6679),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Feedbacks Methods
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> loadFeedbacks() async {
    isLoadingFeedbacks.value = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.feedback)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      feedbacks.value = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      isLoadingFeedbacks.value = false;
    } catch (e) {
      debugPrint('Error loading feedbacks: $e');
      isLoadingFeedbacks.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredFeedbacks {
    return feedbacks.where((fb) {
      if (feedbackFilterType.value != 'All' &&
          fb['feedbackType'] != feedbackFilterType.value) {
        return false;
      }
      if (feedbackFilterStatus.value != 'All' &&
          fb['status'] != feedbackFilterStatus.value) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> updateFeedbackStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.feedback)
          .doc(id)
          .update({
            'status': newStatus,
            'reviewedAt': FieldValue.serverTimestamp(),
          });
      await loadFeedbacks();
      if (selectedFeedback.value != null &&
          selectedFeedback.value!['id'] == id) {
        selectedFeedback.value = feedbacks.firstWhere(
          (f) => f['id'] == id,
          orElse: () => selectedFeedback.value!,
        );
      }
    } catch (e) {
      debugPrint('Error updating feedback status: $e');
    }
  }
}

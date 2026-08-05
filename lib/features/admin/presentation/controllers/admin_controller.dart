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
  final RxBool isActionSubmitting = false.obs;

  // Real-time Lists
  final RxList<Map<String, dynamic>> videos = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> images = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> auditLogs = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> channels = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> reports = <Map<String, dynamic>>[].obs;

  // Selected Detail views
  final Rxn<Map<String, dynamic>> selectedVideo = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedImage = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedChannel = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedReport = Rxn<Map<String, dynamic>>();

  // System statistics
  final RxInt pendingVideos = 0.obs;
  final RxInt pendingImages = 0.obs;
  final RxInt pendingChannels = 0.obs;
  final RxInt pendingReports = 0.obs;
  final RxInt totalVideos = 0.obs;
  final RxInt totalImages = 0.obs;
  final RxInt totalChannels = 0.obs;
  final RxInt totalReports = 0.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: Search & Filter
  // ═══════════════════════════════════════════════════════════════════════════
  final RxString searchQuery = ''.obs;
  final RxString filterStatus = ''.obs;
  final RxString filterCategory = ''.obs;
  final RxString filterTrustTier = ''.obs;
  final RxString videoFilterTab = 'all'.obs;
  final RxString imageFilterTab = 'all'.obs;
  final RxString channelFilterTab = 'all'.obs;
  final RxString reportFilterTab = 'all'.obs;
  final RxBool isSearching = false.obs;
  final RxSet<String> selectedItemIds = <String>{}.obs;
  final RxBool isBulkActionSubmitting = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE: User Management
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> searchedUsers =
      <Map<String, dynamic>>[].obs;
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

  // Subscriptions
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot>? _videosSub;
  StreamSubscription<QuerySnapshot>? _imagesSub;
  StreamSubscription<QuerySnapshot>? _communitySub;
  StreamSubscription<QuerySnapshot>? _logsSub;
  StreamSubscription<QuerySnapshot>? _channelsSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _videoReportsSub;
  StreamSubscription<QuerySnapshot>? _altVideoReportsSub;
  StreamSubscription<QuerySnapshot>? _appealsSub;

  List<Map<String, dynamic>> _rawCommunityPosts = [];
  List<Map<String, dynamic>> _rawFlaggedImages = [];
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

  Future<void> refreshAllData() async {
    try {
      // 1. Fetch videos directly
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

      // 2. Fetch channels directly
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

      // 3. Fetch community & flagged images directly
      final flaggedSnap = await FirebaseFirestore.instance.collection('flagged_images_review').limit(100).get();
      final communitySnap = await FirebaseFirestore.instance.collection(FirestoreCollections.community).limit(100).get();
      final fList = flaggedSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final commList = communitySnap.docs.map((doc) => {'id': doc.id, 'category': 'Community Post', ...doc.data()}).toList();
      _combineImagesAndPosts(communityList: commList, flaggedList: fList);

      // 4. Fetch reports, video_reports, and videoReports directly
      final reportsSnap = await FirebaseFirestore.instance.collection(FirestoreCollections.reports).limit(100).get();
      final videoReportsSnap = await FirebaseFirestore.instance.collection('video_reports').limit(100).get();
      final altVideoReportsSnap = await FirebaseFirestore.instance.collection('videoReports').limit(100).get();
      final rList = reportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final vrList = videoReportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final altVrList = altVideoReportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      _combineReports(mainReports: rList, videoReportsList: vrList, altVideoReportsList: altVrList);

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
    } catch (e) {
      debugPrint('AdminController refresh error: $e');
    }
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

    // 2. Monitor community posts and flagged images queue
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
            onError: (e) {
              debugPrint('AdminController Video Reports Stream Error: $e');
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
            onError: (e) {
              debugPrint('AdminController Alt Video Reports Stream Error: $e');
            },
          );
      if (_altVideoReportsSub != null) trackSubscription(_altVideoReportsSub!);
    }

    // 6. Monitor content_appeals collection
    _startAppealsSubscription();
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
  }) {
    if (communityList != null) _rawCommunityPosts = communityList;
    if (flaggedList != null) _rawFlaggedImages = flaggedList;

    final combinedMap = <String, Map<String, dynamic>>{};
    for (final item in _rawFlaggedImages) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty) combinedMap[id] = item;
    }
    for (final item in _rawCommunityPosts) {
      final id = (item['id'] ?? item['docId'] ?? '').toString();
      if (id.isNotEmpty && !combinedMap.containsKey(id)) {
        combinedMap[id] = item;
      }
    }

    final combined = combinedMap.values.toList();
    combined.sort((a, b) {
      final timeA = a['flaggedAt'] ?? a['createdAt'] ?? a['timestamp'];
      final timeB = b['flaggedAt'] ?? b['createdAt'] ?? b['timestamp'];
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

  /// Checks if an image/post is pending review
  bool isImagePostPending(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase();
    if (status == 'PENDING_REVIEW' ||
        status == 'PENDING' ||
        status == 'PROCESSING' ||
        status == 'UNDER_REVIEW' ||
        status == 'PENDING_APPROVAL' ||
        status == 'UNVERIFIED' ||
        status == 'IN_REVIEW') {
      return true;
    }
    if (status.isEmpty && img['isApproved'] == false) {
      return true;
    }
    return false;
  }

  /// Checks if an image/post is approved/published
  bool isImagePostApproved(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    if (isImagePostPending(img)) return false;
    final status = (img['status'] ?? 'APPROVED').toString().toUpperCase();
    return status == 'APPROVED' ||
        status == 'ACTIVE' ||
        status == 'PUBLISHED' ||
        status == 'PASSED' ||
        img['isApproved'] == true ||
        img['status'] == null;
  }

  /// Checks if an image/post is rejected
  bool isImagePostRejected(Map<String, dynamic> img) {
    final status = (img['status'] ?? '').toString().toUpperCase();
    return status == 'REJECTED' || status == 'DELETED' || status == 'REMOVED';
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
    if (_imagesSub != null) unawaited(_imagesSub!.cancel());
    if (_communitySub != null) unawaited(_communitySub!.cancel());
    if (_logsSub != null) unawaited(_logsSub!.cancel());
    if (_channelsSub != null) unawaited(_channelsSub!.cancel());
    if (_reportsSub != null) unawaited(_reportsSub!.cancel());
    if (_appealsSub != null) unawaited(_appealsSub!.cancel());
    _videosSub = null;
    _imagesSub = null;
    _communitySub = null;
    _logsSub = null;
    _channelsSub = null;
    _reportsSub = null;
    _appealsSub = null;
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
        final item = Map<String, dynamic>.from(videos[vIdx]);
        item['status'] = newStatus == 'approved' ? 'published' : 'rejected';
        item['isApproved'] = newStatus == 'approved';
        item['visibility'] = newStatus == 'approved' ? 'public' : 'rejected';
        item['moderation'] = {
          'status': newStatus,
          'moderationReason': reason,
          'overriddenByAdmin': true,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'moderatedBy': adminUid,
        };
        videos[vIdx] = item;
        videos.refresh();
        pendingVideos.value = videos.where(isVideoPending).length;
      }

      // 1. Direct Firestore update for immediate override & real-time sync
      unawaited(
        FirebaseFirestore.instance.collection('videos').doc(videoId).set({
          'moderation': {
            'status': newStatus,
            'moderationReason': reason,
            'overriddenByAdmin': true,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'moderatedBy': adminUid,
          },
          'status': newStatus == 'approved' ? 'published' : 'rejected',
          'isApproved': newStatus == 'approved',
          'visibility': newStatus == 'approved' ? 'public' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Firestore moderateVideo set error: $e');
        }),
      );

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

  /// Searches users by email or display name
  Future<void> searchUsers(String queryText) async {
    if (queryText.trim().isEmpty) {
      searchedUsers.clear();
      return;
    }
    isSearchingUsers.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired.');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
          'https://asia-south1-truthworld-1.cloudfunctions.net/adminSearchUsers',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'query': queryText.trim(), 'limit': 50}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        searchedUsers.assignAll(
          List<Map<String, dynamic>>.from(data['users'] ?? []),
        );
      } else {
        throw Exception('Search failed.');
      }
    } catch (e) {
      debugPrint('User search error: $e');
    } finally {
      isSearchingUsers.value = false;
    }
  }

  /// Loads the full safety profile for a user
  Future<void> getUserSafetyProfile(String userId) async {
    isLoadingProfile.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired.');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
          'https://asia-south1-truthworld-1.cloudfunctions.net/adminGetUserSafetyProfile',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        userSafetyProfile.value = jsonDecode(response.body);
      } else {
        throw Exception('Failed to load user profile.');
      }
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired.');
      final idToken = await user.getIdToken();

      final body = <String, dynamic>{
        'userId': userId,
        'action': action,
        'reason': reason,
      };
      if (durationDays != null) body['duration'] = durationDays;

      final response = await http.post(
        Uri.parse(
          'https://asia-south1-truthworld-1.cloudfunctions.net/adminModerateUser',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['error'] ?? 'Failed to moderate user.');
      }

      Get.snackbar(
        'Success',
        'User action "$action" applied successfully.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Refresh profile
      await getUserSafetyProfile(userId);
      return true;
    } catch (e) {
      Get.snackbar(
        'User Action Error',
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

  /// Fetches aggregated analytics data for the selected time range
  Future<void> fetchAnalytics() async {
    isLoadingAnalytics.value = true;
    try {
      // Image stats
      final totalModeratedImages = images.length;
      final approvedImages = images
          .where((img) => img['status'] == 'APPROVED')
          .length;
      final rejectedImages = images
          .where((img) => img['status'] == 'REJECTED')
          .length;
      final pendingImgCount = images
          .where((img) => img['status'] == 'PENDING_REVIEW')
          .length;

      // Video stats
      final totalModeratedVideos = videos.length;
      final approvedVideos = videos.where((v) {
        final mod = v['moderation'] as Map<String, dynamic>?;
        return mod?['status'] == 'approved';
      }).length;
      final rejectedVideos = videos.where((v) {
        final mod = v['moderation'] as Map<String, dynamic>?;
        return mod?['status'] == 'rejected';
      }).length;

      // Compute violation categories from images & videos
      final violationCounts = <String, int>{};
      for (final img in images) {
        final scores = img['safeSearchScores'] as Map<String, dynamic>?;
        if (scores != null) {
          scores.forEach((key, value) {
            if (value is num && value >= 2) {
              final cat = key.replaceAll('_', ' ').capitalizeFirst ?? key;
              violationCounts[cat] = (violationCounts[cat] ?? 0) + 1;
            }
          });
        }
        final cat = img['violationCategory'] ?? img['category'];
        if (cat != null && cat.toString().isNotEmpty) {
          final catStr = cat.toString().replaceAll('_', ' ').capitalizeFirst ?? cat.toString();
          violationCounts[catStr] = (violationCounts[catStr] ?? 0) + 1;
        }
      }

      for (final v in videos) {
        final mod = v['moderation'] as Map<String, dynamic>?;
        final violations = mod?['violationCategories'] as List<dynamic>?;
        if (violations != null) {
          for (final cat in violations) {
            final catStr = cat.toString().replaceAll('_', ' ').capitalizeFirst ?? cat.toString();
            violationCounts[catStr] = (violationCounts[catStr] ?? 0) + 1;
          }
        }
      }

      // Compute top offenders
      final userRejections = <String, int>{};
      for (final img in images) {
        if (img['status'] == 'REJECTED') {
          final u = (img['uploaderId'] ?? img['userId'] ?? img['userEmail'] ?? 'Unknown User').toString();
          userRejections[u] = (userRejections[u] ?? 0) + 1;
        }
      }
      for (final v in videos) {
        final mod = v['moderation'] as Map<String, dynamic>?;
        if (mod?['status'] == 'rejected') {
          final u = (v['userId'] ?? v['creatorId'] ?? v['userEmail'] ?? 'Unknown Creator').toString();
          userRejections[u] = (userRejections[u] ?? 0) + 1;
        }
      }

      final sortedOffenders = userRejections.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topOffenders = sortedOffenders.take(5).map((e) => {
        'user': e.key,
        'violationsCount': e.value,
      }).toList();

      final totalModerated = totalModeratedImages + totalModeratedVideos;
      final totalApproved = approvedImages + approvedVideos;
      final autoApprovalRate = totalModerated > 0
          ? (totalApproved / totalModerated * 100).round()
          : 100;

      final rejectionRate = totalModerated > 0
          ? ((rejectedImages + rejectedVideos) / totalModerated)
          : 0.0;
      final queueHealth = (pendingImgCount + pendingVideos.value) < 50
          ? 1.0
          : 0.5;
      final safetyScore = ((1 - rejectionRate) * 70 + queueHealth * 30)
          .round()
          .clamp(0, 100);

      analyticsData.assignAll({
        'safetyScore': safetyScore,
        'moderated24h': totalModerated,
        'totalModerated24h': totalModerated,
        'autoApproveRate': autoApprovalRate,
        'autoApprovalRate': autoApprovalRate,
        'activeViolations': pendingImgCount + pendingVideos.value,
        'violationCategories': violationCounts,
        'totalApproved': totalApproved,
        'totalRejected': rejectedImages + rejectedVideos,
        'totalPending': pendingImgCount + pendingVideos.value,
        'topOffenders': topOffenders,
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
}

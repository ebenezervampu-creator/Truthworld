import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminController extends GetxController {
  static AdminController get to => Get.find<AdminController>();

  // State flags
  final RxBool isLoading = false.obs;
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
  StreamSubscription<QuerySnapshot>? _logsSub;
  StreamSubscription<QuerySnapshot>? _channelsSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = FirebaseAuth.instance.currentUser != null;
    isAuthChecking.value = false;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        isAdmin.value = true;
        _startSubscriptions();
      } else {
        isAdmin.value = false;
        _stopSubscriptions();
      }
    });

    if (FirebaseAuth.instance.currentUser != null) {
      _startSubscriptions();
    }
  }

  @override
  void onClose() {
    if (_authSub != null) unawaited(_authSub!.cancel());
    _stopSubscriptions();
    super.onClose();
  }

  // Email & Password login controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool needsPasswordSetup = false.obs;

  /// Signs in using email and password
  Future<void> signInWithEmailAndPassword() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

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

    isLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      isLoading.value = false;
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

  /// Start Firestore real-time synchronization
  void _startSubscriptions() {
    _stopSubscriptions();

    // 1. Monitor videos collection
    _videosSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();
            videos.assignAll(list);

            // Recalculate pending videos
            final pendingCount = list.where((v) {
              final mod = v['moderation'] as Map<String, dynamic>?;
              if (mod == null) return false;
              final status = mod['status'] as String?;
              final violations = mod['violationCategories'] as List<dynamic>?;
              return status == 'processing' ||
                  status == 'error' ||
                  (status == 'approved' &&
                      violations != null &&
                      violations.contains('timeout_passthrough'));
            }).length;

            pendingVideos.value = pendingCount;
            totalVideos.value = list.length;
          },
          onError: (e) {
            debugPrint('AdminController Video Stream Error: $e');
          },
        );

    // 2. Monitor flagged images queue
    _imagesSub = FirebaseFirestore.instance
        .collection('flagged_images_review')
        .orderBy('flaggedAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();
            images.assignAll(list);

            final pendingCount = list
                .where((img) => img['status'] == 'PENDING_REVIEW')
                .length;
            pendingImages.value = pendingCount;
            totalImages.value = list.length;
          },
          onError: (e) {
            debugPrint('AdminController Image Stream Error: $e');
          },
        );

    // 3. Monitor rejection / audit logs
    _logsSub = FirebaseFirestore.instance
        .collection('rejected_images_log')
        .orderBy('rejectedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();
            auditLogs.assignAll(list);
          },
          onError: (e) {
            debugPrint('AdminController Audit Log Stream Error: $e');
          },
        );

    // 4. Monitor channels collection
    _channelsSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();

            // Sort by updatedAt descending in memory to handle missing fields gracefully
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

            channels.assignAll(list);

            final pendingCount = list
                .where(
                  (c) =>
                      c['status'] == 'underReview' ||
                      c['status'] == 'verificationRejected',
                )
                .length;
            pendingChannels.value = pendingCount;
            totalChannels.value = list.length;
          },
          onError: (e) {
            debugPrint('AdminController Channels Stream Error: $e');
          },
        );

    // 5. Monitor reports collection
    _reportsSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.reports)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            final list = snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).toList();

            list.sort((a, b) {
              final timeA = a['createdAt'];
              final timeB = b['createdAt'];
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

            reports.assignAll(list);

            final pendingCount = list
                .where(
                  (r) => r['status'] == 'pending' || r['status'] == 'PENDING',
                )
                .length;
            pendingReports.value = pendingCount;
            totalReports.value = list.length;
          },
          onError: (e) {
            debugPrint('AdminController Reports Stream Error: $e');
          },
        );
  }

  /// Cancels all active Firestore listeners
  void _stopSubscriptions() {
    if (_videosSub != null) unawaited(_videosSub!.cancel());
    if (_imagesSub != null) unawaited(_imagesSub!.cancel());
    if (_logsSub != null) unawaited(_logsSub!.cancel());
    if (_channelsSub != null) unawaited(_channelsSub!.cancel());
    if (_reportsSub != null) unawaited(_reportsSub!.cancel());
    _videosSub = null;
    _imagesSub = null;
    _logsSub = null;
    _channelsSub = null;
    _reportsSub = null;
  }

  /// Initiates Google Sign In
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await AuthService.to.signOut();
      }
      await AuthService.to.signInWithGoogle();
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
      isLoading.value = false;
    }
  }

  /// Signs out of the administrative console
  Future<void> signOutAdmin() async {
    isLoading.value = true;
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
      isLoading.value = false;
    }
  }

  /// Executes manual video moderation action (Approve/Reject)
  Future<bool> moderateVideo(
    String videoId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final idToken = await user.getIdToken();
      final response = await http.post(
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

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['error'] ?? 'Failed to moderate video.');
      }

      Get.snackbar(
        'Success',
        'Video successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
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
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['error'] ?? 'Failed to moderate image.');
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

      // Update the channel document in Firestore directly
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update({
            'status': status,
            'moderationReason': action == 'approve'
                ? FieldValue.delete()
                : reason,
            'geminiApproved': action == 'approve',
            'updatedAt': FieldValue.serverTimestamp(),
          });

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

      // Compute violation categories from images
      final violationCounts = <String, int>{};
      for (final img in images) {
        final scores = img['safeSearchScores'] as Map<String, dynamic>?;
        if (scores != null) {
          scores.forEach((key, value) {
            if (value is num && value >= 2) {
              violationCounts[key] = (violationCounts[key] ?? 0) + 1;
            }
          });
        }
      }

      final totalModerated = totalModeratedImages + totalModeratedVideos;
      final totalApproved = approvedImages + approvedVideos;
      final autoApprovalRate = totalModerated > 0
          ? (totalApproved / totalModerated * 100).round()
          : 0;

      // Compute safety score (0-100)
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
        'totalModerated24h': totalModerated,
        'autoApprovalRate': autoApprovalRate,
        'avgReviewTimeMinutes':
            12, // Placeholder — would need timestamp diff calculation
        'activeViolations': pendingImgCount + pendingVideos.value,
        'violationCategories': violationCounts,
        'totalApproved': totalApproved,
        'totalRejected': rejectedImages + rejectedVideos,
        'totalPending': pendingImgCount + pendingVideos.value,
        'topOffenders':
            <Map<String, dynamic>>[], // Would need userTrust aggregation
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
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .get();
      appeals.assignAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
      pendingAppeals.value = appeals
          .where((a) => a['status'] == 'pending')
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

      await reportRef.update({
        'status': action == 'reject'
            ? 'resolved_rejected'
            : 'resolved_dismissed',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionComment': reviewReason,
      });

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

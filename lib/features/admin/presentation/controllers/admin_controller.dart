import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/services/auth_service.dart';

class AdminController extends GetxController {
  static AdminController get to => Get.find<AdminController>();

  // State flags
  final RxBool isLoading = false.obs;
  final RxBool isAuthChecking = true.obs;
  final RxBool isAdmin = false.obs;
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
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await checkAdminClaims();
        if (isAdmin.value) {
          if (Get.currentRoute != '/admin/dashboard') {
            Get.offAllNamed('/admin/dashboard');
          }
        }
      } else {
        isAdmin.value = false;
        _stopSubscriptions();
        isAuthChecking.value = false;
        if (Get.currentRoute.startsWith('/admin') && Get.currentRoute != '/admin/login') {
          Get.offAllNamed('/admin/login');
        }
      }
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _stopSubscriptions();
    super.onClose();
  }

  /// Verifies token claims for custom admin flag
  Future<void> checkAdminClaims() async {
    isAuthChecking.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final tokenResult = await user.getIdTokenResult(true);
        final isUserAdmin = tokenResult.claims?['admin'] == true;
        isAdmin.value = isUserAdmin;
        if (isUserAdmin) {
          _startSubscriptions();
        } else {
          _stopSubscriptions();
          Get.snackbar(
            'Access Denied',
            'Your account does not have administrator privileges.',
            backgroundColor: const Color(0xFFCF6679),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          await AuthService.to.signOut();
        }
      } else {
        isAdmin.value = false;
        _stopSubscriptions();
      }
    } catch (e) {
      isAdmin.value = false;
      _stopSubscriptions();
    } finally {
      isAuthChecking.value = false;
    }
  }

  /// Start Firestore real-time synchronization
  void _startSubscriptions() {
    _stopSubscriptions();

    // 1. Monitor videos collection
    _videosSub = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
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
        return status == 'processing' || status == 'error' || 
               (status == 'approved' && violations != null && violations.contains('timeout_passthrough'));
      }).length;

      pendingVideos.value = pendingCount;
      totalVideos.value = list.length;
    }, onError: (e) {
      debugPrint('AdminController Video Stream Error: $e');
    });

    // 2. Monitor flagged images queue
    _imagesSub = FirebaseFirestore.instance
        .collection('flagged_images_review')
        .orderBy('flaggedAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
      images.assignAll(list);

      final pendingCount = list.where((img) => img['status'] == 'PENDING_REVIEW').length;
      pendingImages.value = pendingCount;
      totalImages.value = list.length;
    }, onError: (e) {
      debugPrint('AdminController Image Stream Error: $e');
    });

    // 3. Monitor rejection / audit logs
    _logsSub = FirebaseFirestore.instance
        .collection('rejected_images_log')
        .orderBy('rejectedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
      auditLogs.assignAll(list);
    }, onError: (e) {
      debugPrint('AdminController Audit Log Stream Error: $e');
    });

    // 4. Monitor channels collection
    _channelsSub = FirebaseFirestore.instance
        .collection('channels')
        .snapshots()
        .listen((snapshot) {
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
        final DateTime dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
        final DateTime dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
        return dtB.compareTo(dtA);
      });
      
      channels.assignAll(list);

      final pendingCount = list.where((c) => c['status'] == 'underReview' || c['status'] == 'verificationRejected').length;
      pendingChannels.value = pendingCount;
      totalChannels.value = list.length;
    }, onError: (e) {
      debugPrint('AdminController Channels Stream Error: $e');
    });

    // 5. Monitor reports collection
    _reportsSub = FirebaseFirestore.instance
        .collection('reports')
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      list.sort((a, b) {
        final timeA = a['createdAt'];
        final timeB = b['createdAt'];
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        final DateTime dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
        final DateTime dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0));
        return dtB.compareTo(dtA);
      });

      reports.assignAll(list);

      final pendingCount = list.where((r) => r['status'] == 'pending' || r['status'] == 'PENDING').length;
      pendingReports.value = pendingCount;
      totalReports.value = list.length;
    }, onError: (e) {
      debugPrint('AdminController Reports Stream Error: $e');
    });
  }

  /// Cancels all active Firestore listeners
  void _stopSubscriptions() {
    _videosSub?.cancel();
    _imagesSub?.cancel();
    _logsSub?.cancel();
    _channelsSub?.cancel();
    _reportsSub?.cancel();
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
      await AuthService.to.signInWithGoogle();
    } catch (e) {
      debugPrint("Admin Google Sign In failed: $e");
      Get.snackbar(
        'Authentication Error',
        'Google Sign In failed: ${e.toString().replaceAll("Exception: ", "")}',
        backgroundColor: const Color(0xFFCF6679),
        colorText: Colors.white,
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
      debugPrint("Admin Sign Out failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Executes manual video moderation action (Approve/Reject)
  Future<bool> moderateVideo(String videoId, String action, String reason) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Session expired. Please log in again.");

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('https://asia-south1-truthworld-1.cloudfunctions.net/moderateVideoManual'),
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
        throw Exception(errBody['error'] ?? "Failed to moderate video.");
      }

      Get.snackbar(
        'Success',
        'Video successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedVideo.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll("Exception: ", ""),
        backgroundColor: const Color(0xFFCF6679),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual image moderation action (Approve/Reject)
  Future<bool> moderateImage(String verificationId, String action, String reason) async {
    isActionSubmitting.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Session expired. Please log in again.");

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('https://asia-south1-truthworld-1.cloudfunctions.net/moderateImageManual'),
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
        throw Exception(errBody['error'] ?? "Failed to moderate image.");
      }

      Get.snackbar(
        'Success',
        'Image successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedImage.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll("Exception: ", ""),
        backgroundColor: const Color(0xFFCF6679),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual channel moderation action (Approve/Reject)
  Future<bool> moderateChannel(String channelId, String action, String reason) async {
    isActionSubmitting.value = true;
    try {
      final status = action == 'approve' ? 'active' : 'verificationRejected';
      
      // Update the channel document in Firestore directly
      await FirebaseFirestore.instance.collection('channels').doc(channelId).update({
        'status': status,
        'moderationReason': action == 'approve' ? FieldValue.delete() : reason,
        'geminiApproved': action == 'approve',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        'Success',
        'Channel successfully ${action}ed.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedChannel.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString(),
        backgroundColor: const Color(0xFFCF6679),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }

  /// Executes manual report moderation action (resolve_keep/resolve_reject)
  Future<bool> moderateReport(String reportId, String action, String reviewReason) async {
    isActionSubmitting.value = true;
    try {
      final reportRef = FirebaseFirestore.instance.collection('reports').doc(reportId);
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
          throw Exception('Failed to reject the video associated with this report.');
        }
      }

      await reportRef.update({
        'status': action == 'reject' ? 'resolved_rejected' : 'resolved_dismissed',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionComment': reviewReason,
      });

      Get.snackbar(
        'Success',
        'Report successfully resolved.',
        backgroundColor: const Color(0xFF2BA640),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedReport.value = null;
      return true;
    } catch (e) {
      Get.snackbar(
        'Moderation Error',
        e.toString().replaceAll("Exception: ", ""),
        backgroundColor: const Color(0xFFCF6679),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isActionSubmitting.value = false;
    }
  }
}

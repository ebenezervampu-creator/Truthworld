import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Mixin managing administrative security alerts, user appeals, lockdowns, and rate limits.
mixin AdminSecurityAlertsMixin on BaseController {
  /// Base controller contracts
  RxBool get isActionSubmitting;
  RxList<Map<String, dynamic>> get images;

  Future<void> logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  });

  // Backward-compatible alias
  Future<void> _logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  }) =>
      logAdminAction(
        action: action,
        targetId: targetId,
        userId: userId,
        reason: reason,
        extra: extra,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Observables & State
  // ═══════════════════════════════════════════════════════════════════════════
  final RxList<Map<String, dynamic>> activeAlerts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> alertRules = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingAlerts = false.obs;

  final RxList<Map<String, dynamic>> appeals = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedAppeal = Rxn<Map<String, dynamic>>();
  final RxInt pendingAppeals = 0.obs;
  final RxBool isLoadingAppeals = false.obs;
  final TextEditingController appealReasonController = TextEditingController();

  final RxMap<String, dynamic> securityMetrics = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> anomalyAlerts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> accountClusters = <Map<String, dynamic>>[].obs;
  final RxBool isLockdownMode = false.obs;
  final RxBool isLoadingSecurity = false.obs;
  final RxInt perUserUploadRateLimit = 50.obs;
  final RxInt globalUploadRateLimit = 5000.obs;
  final RxBool isSavingRateLimits = false.obs;

  StreamSubscription<QuerySnapshot>? _appealsSub;
  int _appealsRetryCount = 0;

  void stopAppealsSubscription() {
    _appealsSub?.cancel();
    _appealsSub = null;
  }
  void startAppealsSubscription() {
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
          onError: (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.appealsStream');
            if (_appealsRetryCount < 2 &&
                FirebaseAuth.instance.currentUser != null) {
              _appealsRetryCount++;
              Future.delayed(const Duration(seconds: 1), () {
                if (FirebaseAuth.instance.currentUser != null) {
                  startAppealsSubscription();
                }
              });
            }
          },
        );
    if (_appealsSub != null) trackSubscription(_appealsSub!);
  }

  /// Refreshes all active alerts and system alerts from Firestore
  Future<void> fetchAlerts() async {
    isLoadingAlerts.value = true;
    try {
      final combinedAlerts = <Map<String, dynamic>>[];

      // Load active alerts from system_alerts (automated agent pipeline)
      try {
        final sysSnap = await FirebaseFirestore.instance
            .collection('system_alerts')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
        for (final d in sysSnap.docs) {
          final data = d.data();
          if (data['status'] != 'resolved') {
            combinedAlerts.add({'id': d.id, '_source': 'system_alerts', ...data});
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.fetchSystemAlerts');
      }

      // Load active alerts from admin_alerts (console escalation output)
      try {
        final adminSnap = await FirebaseFirestore.instance
            .collection('admin_alerts')
            .orderBy('triggeredAt', descending: true)
            .limit(50)
            .get();
        for (final d in adminSnap.docs) {
          final data = d.data();
          if (data['status'] != 'resolved') {
            combinedAlerts.add({'id': d.id, '_source': 'admin_alerts', ...data});
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.fetchAdminAlerts');
      }

      // Sort by triggeredAt / timestamp descending
      combinedAlerts.sort((a, b) {
        final timeA = a['triggeredAt'] ?? a['timestamp'] ?? a['createdAt'];
        final timeB = b['triggeredAt'] ?? b['timestamp'] ?? b['createdAt'];
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        final dtA = timeA is Timestamp ? timeA.toDate() : (DateTime.tryParse(timeA.toString()) ?? DateTime(0));
        final dtB = timeB is Timestamp ? timeB.toDate() : (DateTime.tryParse(timeB.toString()) ?? DateTime(0));
        return dtB.compareTo(dtA);
      });

      activeAlerts.assignAll(combinedAlerts);

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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.fetchAlerts');
    } finally {
      isLoadingAlerts.value = false;
    }
  }

  /// Resolves an active alert across system_alerts or admin_alerts
  Future<void> resolveAlert(String alertId, {String? sourceCollection}) async {
    try {
      final col = sourceCollection ?? 'system_alerts';
      await FirebaseFirestore.instance
          .collection(col)
          .doc(alertId)
          .set({
            'status': 'resolved',
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
          }, SetOptions(merge: true));

      // Also ensure it's marked resolved in admin_alerts
      if (col == 'system_alerts') {
        try {
          await FirebaseFirestore.instance
              .collection('admin_alerts')
              .doc(alertId)
              .set({
                'status': 'resolved',
                'resolvedAt': FieldValue.serverTimestamp(),
                'resolvedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
              }, SetOptions(merge: true));
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.resolveAlertAdminAlerts');
        }
      }

      activeAlerts.removeWhere((a) => a['id'] == alertId);

      await _logAdminAction(
        action: 'resolve_alert',
        targetId: alertId,
        reason: 'Alert marked as resolved',
      );

      AppSnackbar.success(
        'Alert $alertId marked as resolved.',
        title: 'Alert Resolved',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to resolve alert. Please try again.',
      );
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
      AppSnackbar.success(
        'Alert configuration updated successfully.',
        title: 'Alert Rules Saved',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.saveAlertRules');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.fetchAppeals');
    } finally {
      isLoadingAppeals.value = false;
    }
  }

  /// Resolves an appeal with the given action and restores content on overturn
  Future<bool> resolveAppeal(
    String appealId,
    String action,
    String reason,
  ) async {
    isActionSubmitting.value = true;
    try {
      final normalizedAction = action.toLowerCase();
      final currentAppeal = appeals.cast<Map<String, dynamic>?>().firstWhere(
            (a) => a?['id'] == appealId,
            orElse: () => null,
          );

      final newStatus = normalizedAction == 'overturn'
          ? 'overturned'
          : (normalizedAction == 'escalate' ? 'escalated' : 'upheld');

      await FirebaseFirestore.instance
          .collection('content_appeals')
          .doc(appealId)
          .update({
            'status': newStatus,
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
            'resolvedByEmail': FirebaseAuth.instance.currentUser?.email,
            'resolutionNote': reason,
          });

      // If appeal is overturned, restore underlying content in Firestore
      final targetType = (currentAppeal?['contentType'] ?? currentAppeal?['type'] ?? '').toString().toLowerCase();
      final targetId = (currentAppeal?['contentId'] ??
              currentAppeal?['videoId'] ??
              currentAppeal?['channelId'] ??
              currentAppeal?['imageId'] ??
              '')
          .toString();

      if (normalizedAction == 'overturn' && targetId.isNotEmpty) {
        if (targetType.contains('video') || currentAppeal?['videoId'] != null) {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .doc(targetId)
              .set({
            'status': 'published',
            'isApproved': true,
            'moderation': {
              'status': 'approved',
              'appealOverturned': true,
              'reviewedAt': FieldValue.serverTimestamp(),
              'reviewerId': FirebaseAuth.instance.currentUser?.uid,
              'reason': reason,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (targetType.contains('channel') || currentAppeal?['channelId'] != null) {
          await FirebaseFirestore.instance.collection('channels').doc(targetId).set({
            'status': 'active',
            'isApproved': true,
            'isVerified': true,
            'appealOverturned': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (targetType.contains('image') ||
            targetType.contains('post') ||
            currentAppeal?['imageId'] != null) {
          await FirebaseFirestore.instance
              .collection('image_verification')
              .doc(targetId)
              .set({
            'status': 'approved',
            'appealOverturned': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      await _logAdminAction(
        action: 'appeal_$normalizedAction',
        targetId: appealId,
        reason: 'Appeal $normalizedAction: $reason (target: $targetType/$targetId)',
      );

      AppSnackbar.success(
        'Appeal ${normalizedAction}ed successfully.',
        title: 'Appeal Resolved',
      );
      selectedAppeal.value = null;
      await fetchAppeals();
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to resolve appeal. Please try again.',
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

      // Load lockdown and rate limit status
      final settingsDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('security_config')
          .get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        isLockdownMode.value = data['lockdownMode'] == true;
        if (data['perUserUploadRateLimit'] is num) {
          perUserUploadRateLimit.value = (data['perUserUploadRateLimit'] as num).toInt();
        }
        if (data['globalUploadRateLimit'] is num) {
          globalUploadRateLimit.value = (data['globalUploadRateLimit'] as num).toInt();
        }
      }

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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.fetchSecurityMetrics');
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
      AppSnackbar.info(
        newState ? 'All uploads are now paused.' : 'Uploads have been resumed.',
        title: newState ? 'Lockdown Activated' : 'Lockdown Deactivated',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdminSecurityAlertsMixin.toggleLockdownMode');
      AppSnackbar.error('Unable to update lockdown mode. Please try again.');
    }
  }

  /// Saves per-user and global upload rate limits to Firestore admin_settings/security_config
  Future<void> saveRateLimits({int? perUser, int? global}) async {
    isSavingRateLimits.value = true;
    try {
      final perUserVal = perUser ?? perUserUploadRateLimit.value;
      final globalVal = global ?? globalUploadRateLimit.value;

      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('security_config')
          .set({
            'perUserUploadRateLimit': perUserVal,
            'globalUploadRateLimit': globalVal,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
          }, SetOptions(merge: true));

      perUserUploadRateLimit.value = perUserVal;
      globalUploadRateLimit.value = globalVal;

      await _logAdminAction(
        action: 'update_rate_limits',
        reason: 'Per-user: $perUserVal, Global: $globalVal',
      );

      AppSnackbar.success(
        'Upload throttling policy saved: $perUserVal/hr user, $globalVal/hr global.',
        title: 'Rate Limits Updated',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to save rate limits. Please try again.',
      );
    } finally {
      isSavingRateLimits.value = false;
    }
  }

  /// Opens an investigation dialog for a security anomaly or cluster and logs action
  void investigateAnomaly(Map<String, dynamic> item) {
    final title = item['name'] ?? item['title'] ?? item['type'] ?? 'Security Incident';
    final desc = item['description'] ?? item['details'] ?? 'No further details available.';
    final id = item['id'] ?? 'unknown';
    final accounts = (item['accounts'] as List?)?.map((e) => e.toString()).toList() ?? [];

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Investigate: $title',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  desc.toString(),
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (item['ipAddress'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Origin IP: ${item['ipAddress']}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (item['deviceId'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Device ID: ${item['deviceId']}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Linked Accounts:',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: accounts.length,
                        itemBuilder: (ctx, i) => Text(
                          accounts[i],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              await _logAdminAction(
                action: 'investigate_flag_anomaly',
                targetId: id.toString(),
                reason: 'Security investigation escalated: $title',
              );
              AppSnackbar.warning(
                'Incident $id logged and escalated for security containment.',
                title: 'Incident Flagged',
              );
            },
            child: const Text('Escalate / Log Action'),
          ),
        ],
      ),
    );
  }

  /// Executes manual report moderation action (resolve_keep/resolve_reject)

}

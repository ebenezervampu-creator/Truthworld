import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

class CreatorIntelligenceController extends BaseController {
  CreatorIntelligenceController({
    required this.channelId,
    required this.creatorId,
  });
  final String channelId;
  final String creatorId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<UserNotification> notifications = <UserNotification>[].obs;
  final RxBool rxIsLoading = true.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxString searchQuery = ''.obs;
  final RxInt unreadCount = 0.obs;

  final Rx<Channel?> currentChannel = Rx<Channel?>(null);
  final RxInt copyrightClaimsCount = 0.obs;

  StreamSubscription? _channelSubscription;
  StreamSubscription? _copyrightSubscription;

  @override
  void onInit() {
    super.onInit();
    listenToNotifications();
    _listenToChannel();
    _listenToCopyrightClaims();
  }

  @override
  void onClose() {
    _channelSubscription?.cancel();
    _copyrightSubscription?.cancel();
    super.onClose();
  }

  void _listenToChannel() {
    if (channelId.isEmpty) return;
    trackSubscription(
      _channelSubscription = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          currentChannel.value = Channel.fromDocumentSnapshot(snapshot);
        }
      }, onError: (err) {
        debugPrint('[CreatorIntelligence] Channel fetch error: $err');
      }),
    );
  }

  void _listenToCopyrightClaims() {
    if (channelId.isEmpty) return;
    trackSubscription(
      _copyrightSubscription = _firestore
          .collection('copyright_claims')
          .where('channelId', isEqualTo: channelId)
          .snapshots()
          .listen((snapshot) {
        copyrightClaimsCount.value = snapshot.docs.length;
      }, onError: (err) {
        debugPrint('[CreatorIntelligence] Copyright claims fetch error: $err');
      }),
    );
  }

  bool get hasActiveIssues {
    final ch = currentChannel.value;
    final hasChannelStatusNotice = ch != null &&
        (ch.status == ChannelStatus.verificationRejected ||
            ch.status == ChannelStatus.underReview ||
            ch.status == ChannelStatus.verificationPending ||
            ch.status == ChannelStatus.suspended ||
            ch.status == ChannelStatus.active ||
            ch.geminiApproved == true ||
            (ch.infraConfig?.isWithdrawalHeld == true));
    final hasAvatarNotice = ch != null &&
        (ch.avatarStatus == 'REJECTED' ||
            ch.avatarStatus == 'FLAGGED' ||
            ch.avatarStatus == 'MANUAL_REVIEW' ||
            ch.avatarStatus == 'PENDING' ||
            ch.avatarStatus == 'APPROVED');
    final hasBannerNotice = ch != null &&
        (ch.bannerStatus == 'REJECTED' ||
            ch.bannerStatus == 'FLAGGED' ||
            ch.bannerStatus == 'MANUAL_REVIEW' ||
            ch.bannerStatus == 'PENDING' ||
            ch.bannerStatus == 'APPROVED');
    final hasCopyrightIssues = copyrightClaimsCount.value > 0;
    final hasCriticalNotifications = filteredNotifications
        .any((n) => n.priority == NotificationPriority.critical);

    return hasChannelStatusNotice ||
        hasAvatarNotice ||
        hasBannerNotice ||
        hasCopyrightIssues ||
        hasCriticalNotifications;
  }

  int get totalIssuesCount {
    var count = 0;
    final ch = currentChannel.value;
    if (ch != null) {
      if (ch.status == ChannelStatus.verificationRejected ||
          ch.status == ChannelStatus.suspended) {
        count++;
      }
      if (ch.avatarStatus == 'REJECTED' ||
          ch.avatarStatus == 'FLAGGED' ||
          ch.avatarStatus == 'MANUAL_REVIEW') {
        count++;
      }
      if (ch.bannerStatus == 'REJECTED' ||
          ch.bannerStatus == 'FLAGGED' ||
          ch.bannerStatus == 'MANUAL_REVIEW') {
        count++;
      }
      if (ch.infraConfig?.isWithdrawalHeld == true) {
        count++;
      }
    }
    if (copyrightClaimsCount.value > 0) count += copyrightClaimsCount.value;
    count += filteredNotifications
        .where((n) => n.priority == NotificationPriority.critical)
        .length;
    return count;
  }

  Future<void> requestAvatarManualReview() async {
    final ch = currentChannel.value;
    if (ch == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(ch.id)
          .update({
        'avatarStatus': 'MANUAL_REVIEW',
        'avatarStatusReason':
            'User requested manual review from Creator Intelligence.',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      AppSnackbar.success('Avatar queued for manual admin review.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatorIntelligenceController');
      AppSnackbar.error('Unable to submit avatar for review. Please try again.');
    }
  }

  Future<void> bypassAvatarVerification() async {
    final ch = currentChannel.value;
    if (ch == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(ch.id)
          .update({
        'avatarStatus': 'APPROVED',
        'avatarStatusReason': 'Bypassed in local/debug environment.',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (ch.avatarFileId != null && ch.avatarFileId!.isNotEmpty) {
        await _firestore
            .collection('image_verification')
            .doc(ch.avatarFileId)
            .set({
          'status': 'APPROVED',
          'reason': 'Bypassed in local/debug environment.',
          'category': 'avatar',
          'processedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      AppSnackbar.success('Avatar approved successfully.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatorIntelligenceController');
      AppSnackbar.error('Unable to verify avatar. Please try again.');
    }
  }

  Future<void> requestBannerManualReview() async {
    final ch = currentChannel.value;
    if (ch == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(ch.id)
          .update({
        'bannerStatus': 'MANUAL_REVIEW',
        'bannerStatusReason':
            'User requested manual review from Creator Intelligence.',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      AppSnackbar.success('Banner queued for manual admin review.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatorIntelligenceController');
      AppSnackbar.error('Unable to submit banner for review. Please try again.');
    }
  }

  Future<void> bypassBannerVerification() async {
    final ch = currentChannel.value;
    if (ch == null) return;
    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(ch.id)
          .update({
        'bannerStatus': 'APPROVED',
        'bannerStatusReason': 'Bypassed in local/debug environment.',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (ch.bannerFileId != null && ch.bannerFileId!.isNotEmpty) {
        await _firestore
            .collection('image_verification')
            .doc(ch.bannerFileId)
            .set({
          'status': 'APPROVED',
          'reason': 'Bypassed in local/debug environment.',
          'category': 'banner',
          'processedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      AppSnackbar.success('Banner approved successfully.');
    } catch (e) {
      ErrorHandler.log(e, tag: 'CreatorIntelligenceController');
      AppSnackbar.error('Unable to verify banner. Please try again.');
    }
  }

  final Map<String, UserNotification> _activeDocs = {};
  final Map<String, UserNotification> _legacyDocs = {};
  final Map<String, UserNotification> _channelNotifDocs = {};

  void _syncMergedNotifications() {
    final merged = <String, UserNotification>{};
    merged.addAll(_legacyDocs);
    merged.addAll(_activeDocs);
    merged.addAll(_channelNotifDocs);
    final list = merged.values.toList();
    list.sort((a, b) {
      if (a.priority == NotificationPriority.critical &&
          b.priority != NotificationPriority.critical) {
        return -1;
      }
      if (b.priority == NotificationPriority.critical &&
          a.priority != NotificationPriority.critical) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    notifications.value = list;
    unreadCount.value = list.where((n) => !n.read).length;
    rxIsLoading.value = false;
  }

  void listenToNotifications() {
    if (creatorId.isEmpty && channelId.isEmpty) {
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;

    if (creatorId.isNotEmpty) {
      // Listen to users/{creatorId}/notifications_active collection
      trackSubscription(_firestore
          .collection(FirestoreCollections.users)
          .doc(creatorId)
          .collection('notifications_active')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              _activeDocs.clear();
              for (final doc in snapshot.docs) {
                _activeDocs[doc.id] = UserNotification.fromDocumentSnapshot(doc);
              }
              _syncMergedNotifications();
            },
            onError: (err) {
              debugPrint('[CreatorIntelligence] Firestore Stream Error: $err');
              _syncMergedNotifications();
            },
          ));

      // Also listen to user_notifications collection for creatorId
      trackSubscription(_firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              _legacyDocs.clear();
              for (final doc in snapshot.docs) {
                _legacyDocs[doc.id] = UserNotification.fromDocumentSnapshot(doc);
              }
              _syncMergedNotifications();
            },
            onError: (err) {
              debugPrint('[CreatorIntelligence] Legacy Fetch Error: $err');
              _syncMergedNotifications();
            },
          ));
    }

    // Also listen to user_notifications specifically addressed to this channelId
    if (channelId.isNotEmpty && channelId != creatorId) {
      trackSubscription(_firestore
          .collection('user_notifications')
          .where('channelId', isEqualTo: channelId)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              _channelNotifDocs.clear();
              for (final doc in snapshot.docs) {
                _channelNotifDocs[doc.id] =
                    UserNotification.fromDocumentSnapshot(doc);
              }
              _syncMergedNotifications();
            },
            onError: (err) {
              debugPrint(
                  '[CreatorIntelligence] Channel Notifications Stream Error: $err');
              _syncMergedNotifications();
            },
          ));
    }
  }

  List<UserNotification> get filteredNotifications {
    var result = notifications.toList();

    // Sort by rankingScore first (critical priority items), then createdAt
    result.sort((a, b) {
      if (a.priority == NotificationPriority.critical &&
          b.priority != NotificationPriority.critical) {
        return -1;
      }
      if (b.priority == NotificationPriority.critical &&
          a.priority != NotificationPriority.critical) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    if (selectedCategory.value != 'all') {
      final cat = selectedCategory.value.toLowerCase();
      if (cat == 'critical') {
        result = result
            .where(
              (n) =>
                  n.priority == NotificationPriority.critical ||
                  n.severity == NotificationSeverity.priority,
            )
            .toList();
      } else if (cat == 'growth') {
        result = result
            .where(
              (n) => n.category == 'growth' || n.type.contains('milestone'),
            )
            .toList();
      } else if (cat == 'verification') {
        result = result
            .where(
              (n) =>
                  n.category == 'verification' ||
                  n.type.contains('verification'),
            )
            .toList();
      } else if (cat == 'performance') {
        result = result
            .where(
              (n) =>
                  n.category == 'analytics' ||
                  n.type.contains('performance') ||
                  n.type.contains('retention'),
            )
            .toList();
      } else if (cat == 'coach') {
        result = result
            .where((n) => n.category == 'education' || n.type.contains('coach'))
            .toList();
      }
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result
          .where(
            (n) =>
                n.title.toLowerCase().contains(query) ||
                n.message.toLowerCase().contains(query) ||
                n.type.toLowerCase().contains(query),
          )
          .toList();
    }

    return result;
  }

  List<UserNotification> get todayNotifications =>
      filteredNotifications.where((n) => n.isToday).toList();

  List<UserNotification> get yesterdayNotifications =>
      filteredNotifications.where((n) => n.isYesterday).toList();

  List<UserNotification> get thisWeekNotifications =>
      filteredNotifications.where((n) => n.isThisWeek).toList();

  List<UserNotification> get earlierNotifications => filteredNotifications
      .where((n) => !n.isToday && !n.isYesterday && !n.isThisWeek)
      .toList();

  Future<void> markAsRead(String notificationId) async {
    try {
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(
          read: true,
          status: NotificationLifecycle.read,
        );
        unreadCount.value = notifications.where((n) => !n.read).length;
      }

      await Future.wait([
        _firestore
            .collection('user_notifications')
            .doc(notificationId)
            .update({'read': true, 'status': 'read'})
            .catchError((_) {}),
        _firestore
            .collection(FirestoreCollections.users)
            .doc(creatorId)
            .collection('notifications_active')
            .doc(notificationId)
            .update({'read': true, 'status': 'read'})
            .catchError((_) {}),
      ]);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreatorIntelligenceController.markAsRead',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      notifications.value = notifications
          .map(
            (n) => n.copyWith(read: true, status: NotificationLifecycle.read),
          )
          .toList();
      unreadCount.value = 0;

      final futures = <Future>[];

      // Update in user_notifications
      futures.add(() async {
        final legacySnap = await _firestore
            .collection('user_notifications')
            .where('userId', isEqualTo: creatorId)
            .where('read', isEqualTo: false)
            .get();
        if (legacySnap.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in legacySnap.docs) {
            batch.update(doc.reference, {'read': true, 'status': 'read'});
          }
          await batch.commit();
        }
      }().catchError((_) {}));

      // Update in notifications_active
      futures.add(() async {
        final activeSnap = await _firestore
            .collection(FirestoreCollections.users)
            .doc(creatorId)
            .collection('notifications_active')
            .where('read', isEqualTo: false)
            .get();
        if (activeSnap.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in activeSnap.docs) {
            batch.update(doc.reference, {'read': true, 'status': 'read'});
          }
          await batch.commit();
        }
      }().catchError((_) {}));

      // Update in user_notifications for channelId
      if (channelId.isNotEmpty && channelId != creatorId) {
        futures.add(() async {
          final chanSnap = await _firestore
              .collection('user_notifications')
              .where('channelId', isEqualTo: channelId)
              .where('read', isEqualTo: false)
              .get();
          if (chanSnap.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in chanSnap.docs) {
              batch.update(doc.reference, {'read': true, 'status': 'read'});
            }
            await batch.commit();
          }
        }().catchError((_) {}));
      }

      await Future.wait(futures);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreatorIntelligenceController.markAllAsRead',
      );
    }
  }

  Future<void> archiveNotification(String notificationId) async {
    try {
      final notif = notifications.firstWhereOrNull(
        (n) => n.id == notificationId,
      );
      notifications.removeWhere((n) => n.id == notificationId);
      unreadCount.value = notifications.where((n) => !n.read).length;

      if (notif != null) {
        await Future.wait([
          // Move to archive collection
          _firestore
              .collection(FirestoreCollections.users)
              .doc(creatorId)
              .collection('notifications_archive')
              .doc(notificationId)
              .set(notif.toJson())
              .catchError((_) {}),
          _firestore
              .collection(FirestoreCollections.users)
              .doc(creatorId)
              .collection('notifications_active')
              .doc(notificationId)
              .delete()
              .catchError((_) {}),
          _firestore
              .collection('user_notifications')
              .doc(notificationId)
              .delete()
              .catchError((_) {}),
        ]);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreatorIntelligenceController.archiveNotification',
      );
    }
  }

  Future<Map<String, dynamic>?> fetchVerificationReport(String reportId) async {
    try {
      final doc = await _firestore
          .collection('verificationReports')
          .doc(reportId)
          .get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreatorIntelligenceController.fetchVerificationReport',
      );
    }
    return null;
  }

  Future<void> approveFactCheck(String videoId, {String? notificationId}) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'isFactCheckApproved': true,
        'aiFeatures.isFactCheckApproved': true,
      });

      if (notificationId != null && notificationId.isNotEmpty) {
        await Future.wait([
          if (creatorId.isNotEmpty)
            _firestore
                .collection(FirestoreCollections.users)
                .doc(creatorId)
                .collection('notifications_active')
                .doc(notificationId)
                .set({
                  'metadata': {'approved': true, 'isFactCheckApproved': true},
                  'read': true,
                }, SetOptions(merge: true))
                .catchError((_) {}),
          _firestore
              .collection('user_notifications')
              .doc(notificationId)
              .set({
                'metadata': {'approved': true, 'isFactCheckApproved': true},
                'read': true,
              }, SetOptions(merge: true))
              .catchError((_) {}),
        ]);

        final idx = notifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          final notif = notifications[idx];
          final updatedMeta = Map<String, dynamic>.from(notif.metadata ?? {});
          updatedMeta['approved'] = true;
          updatedMeta['isFactCheckApproved'] = true;
          notifications[idx] = notif.copyWith(
            metadata: updatedMeta,
            read: true,
          );
        }
      }

      AppSnackbar.success(
        'Fact-checking results approved! Viewers can now watch verification results on the video screen.',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CreatorIntelligenceController.approveFactCheck',
      );
      AppSnackbar.error('Failed to approve fact-check. Please try again.');
    }
  }
}

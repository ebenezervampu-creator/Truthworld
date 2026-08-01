import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

class CreatorIntelligenceController extends GetxController {
  CreatorIntelligenceController({
    required this.channelId,
    required this.creatorId,
  });
  final String channelId;
  final String creatorId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<UserNotification> notifications = <UserNotification>[].obs;
  final RxBool isLoading = true.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxString searchQuery = ''.obs;
  final RxInt unreadCount = 0.obs;

  StreamSubscription? _notificationsSub;

  @override
  void onInit() {
    super.onInit();
    listenToNotifications();
  }

  @override
  void onClose() {
    _notificationsSub?.cancel();
    super.onClose();
  }

  void listenToNotifications() {
    if (creatorId.isEmpty) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;

    // Listen to users/{creatorId}/notifications_active collection
    _notificationsSub = _firestore
        .collection(FirestoreCollections.users)
        .doc(creatorId)
        .collection('notifications_active')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final list = snapshot.docs
                  .map(UserNotification.fromDocumentSnapshot)
                  .toList();
              notifications.value = list;
              unreadCount.value = list.where((n) => !n.read).length;
            } else {
              // Fallback to legacy user_notifications if active subcollection is empty
              _listenToLegacyNotifications();
            }
            isLoading.value = false;
          },
          onError: (err) {
            debugPrint('[CreatorIntelligence] Firestore Stream Error: $err');
            _listenToLegacyNotifications();
          },
        );
  }

  void _listenToLegacyNotifications() {
    _firestore
        .collection('user_notifications')
        .where('userId', isEqualTo: creatorId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get()
        .then((snapshot) {
          final list = snapshot.docs
              .map(UserNotification.fromDocumentSnapshot)
              .toList();
          notifications.value = list;
          unreadCount.value = list.where((n) => !n.read).length;
          isLoading.value = false;
        })
        .catchError((err) {
          debugPrint('[CreatorIntelligence] Legacy Fetch Error: $err');
          isLoading.value = false;
        });
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

      await _firestore
          .collection(FirestoreCollections.users)
          .doc(creatorId)
          .collection('notifications_active')
          .doc(notificationId)
          .update({'read': true, 'status': 'read'});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
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

      final snap = await _firestore
          .collection(FirestoreCollections.users)
          .doc(creatorId)
          .collection('notifications_active')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true, 'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
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
        // Move to archive collection
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(creatorId)
            .collection('notifications_archive')
            .doc(notificationId)
            .set(notif.toJson());

        await _firestore
            .collection(FirestoreCollections.users)
            .doc(creatorId)
            .collection('notifications_active')
            .doc(notificationId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error archiving notification: $e');
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
    } catch (e) {
      debugPrint('Error fetching verification report: $e');
    }
    return null;
  }
}

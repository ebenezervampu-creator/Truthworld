import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_combiner.dart';

/// Manager for direct manual queue queries and data synchronization.
class AdminDataRefreshManager {
  /// Fetches and updates all moderation queues directly from Firestore
  static Future<void> refreshAllData({
    required RxList<Map<String, dynamic>> videos,
    required RxInt pendingVideos,
    required RxInt totalVideos,
    required bool Function(Map<String, dynamic>) isVideoPending,
    required RxList<Map<String, dynamic>> channels,
    required RxInt pendingChannels,
    required RxInt totalChannels,
    required bool Function(Map<String, dynamic>) isChannelPending,
    required RxList<Map<String, dynamic>> topics,
    required RxInt pendingTopics,
    required RxInt totalTopics,
    required bool Function(Map<String, dynamic>) isTopicPending,
    required void Function({
      List<Map<String, dynamic>>? communityList,
      List<Map<String, dynamic>>? flaggedList,
    }) onCombineImages,
    required void Function({
      List<Map<String, dynamic>>? mainReports,
    }) onCombineReports,
    required Future<void> Function() fetchUsers,
    required void Function() startSubscriptions,
  }) async {
    // 1. Fetch videos directly
    try {
      final vSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .limit(100)
          .get();
      final vList =
          vSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (vList.isNotEmpty) {
        vList.sort((a, b) {
          final timeA = a['createdAt'] ?? a['uploadedAt'] ?? a['timestamp'];
          final timeB = b['createdAt'] ?? b['uploadedAt'] ?? b['timestamp'];
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });
        videos.assignAll(vList);
        pendingVideos.value = vList.where(isVideoPending).length;
        totalVideos.value = vList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshVideos');
    }

    // 2. Fetch channels directly
    try {
      final cSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .limit(100)
          .get();
      final cList =
          cSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (cList.isNotEmpty) {
        cList.sort((a, b) {
          final timeA = a['updatedAt'];
          final timeB = b['updatedAt'];
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });
        channels.assignAll(cList);
        pendingChannels.value = cList.where(isChannelPending).length;
        totalChannels.value = cList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshChannels');
    }

    // 3. Fetch topics directly
    try {
      final tSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.topics)
          .limit(100)
          .get();
      final tList =
          tSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (tList.isNotEmpty) {
        tList.sort((a, b) {
          final timeA = a['updatedAt'] ?? a['createdAt'];
          final timeB = b['updatedAt'] ?? b['createdAt'];
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });
        topics.assignAll(tList);
        pendingTopics.value = tList.where(isTopicPending).length;
        totalTopics.value = tList.length;
      }
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshTopics');
    }

    // 4. Fetch community & flagged images directly
    try {
      final flaggedSnap = await FirebaseFirestore.instance
          .collection('flagged_images_review')
          .limit(100)
          .get();
      final communitySnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.community)
          .limit(100)
          .get();
      final fList =
          flaggedSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final commList = communitySnap.docs
          .map((doc) =>
              {'id': doc.id, 'category': 'Community Post', ...doc.data()})
          .toList();
      onCombineImages(communityList: commList, flaggedList: fList);
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshImages');
    }

    // 5. Fetch reports directly
    try {
      final reportsSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.reports)
          .limit(100)
          .get();
      final rList =
          reportsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      onCombineReports(mainReports: rList);
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshReports');
    }

    // 6. Fetch users directly
    try {
      await fetchUsers();
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminDataRefreshManager.refreshUsers');
    }

    // Ensure stream subscriptions are active
    startSubscriptions();

    AppSnackbar.success(
      'Moderation queues synchronized successfully.',
      duration: const Duration(seconds: 2),
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_content_stream_listeners.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_buffer.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_combiner.dart';

/// Centralized manager for real-time Firestore stream subscriptions across all admin queues.
class AdminSubscriptionsManager {
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

  final AdminQueueBuffer queueBuffer = AdminQueueBuffer();

  bool get hasActiveSubscriptions => _videosSub != null;

  void combineImagesAndPosts({
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
    List<Map<String, dynamic>>? communityList,
    List<Map<String, dynamic>>? flaggedList,
    List<Map<String, dynamic>>? verificationList,
    List<Map<String, dynamic>>? playlistList,
  }) {
    queueBuffer.combineImagesAndPosts(
      images: images,
      pendingImages: pendingImages,
      totalImages: totalImages,
      isImagePostPending: isImagePostPending,
      communityList: communityList,
      flaggedList: flaggedList,
      verificationList: verificationList,
      playlistList: playlistList,
    );
  }

  void combineReports({
    required List<Map<String, dynamic>> videos,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required RxInt totalReports,
    required bool Function(Map<String, dynamic>) isReportPending,
    List<Map<String, dynamic>>? mainReports,
    List<Map<String, dynamic>>? videoReportsList,
    List<Map<String, dynamic>>? altVideoReportsList,
  }) {
    queueBuffer.combineReports(
      videos: videos,
      reports: reports,
      pendingReports: pendingReports,
      totalReports: totalReports,
      isReportPending: isReportPending,
      mainReports: mainReports,
      videoReportsList: videoReportsList,
      altVideoReportsList: altVideoReportsList,
    );
  }

  void combineAuditLogs({
    required RxList<Map<String, dynamic>> auditLogs,
    List<Map<String, dynamic>>? rejectedImages,
    List<Map<String, dynamic>>? actions,
  }) {
    queueBuffer.combineAuditLogs(
      auditLogs: auditLogs,
      rejectedImages: rejectedImages,
      actions: actions,
    );
  }

  /// Start all real-time Firestore listeners for admin queues
  void startSubscriptions({
    required void Function(StreamSubscription) trackSubscription,
    required void Function(Map<String, dynamic>) applyModerationModes,
    required Future<void> Function() fetchFallbackModerationModes,
    required void Function(void Function(StreamSubscription))
        startLanguageRequestsSubscription,
    required void Function() listenToAdminMembers,
    required void Function() startAppealsSubscription,
    required RxList<Map<String, dynamic>> videos,
    required RxInt pendingVideos,
    required RxInt totalVideos,
    required bool Function(Map<String, dynamic>) isVideoPending,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
    required RxList<Map<String, dynamic>> topics,
    required RxInt pendingTopics,
    required RxInt totalTopics,
    required bool Function(Map<String, dynamic>) isTopicPending,
    required RxList<Map<String, dynamic>> channels,
    required RxInt pendingChannels,
    required RxInt totalChannels,
    required bool Function(Map<String, dynamic>) isChannelPending,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required RxInt totalReports,
    required bool Function(Map<String, dynamic>) isReportPending,
    required RxList<Map<String, dynamic>> auditLogs,
    required RxList<Map<String, dynamic>> ads,
    required RxInt pendingAds,
    required RxInt totalAds,
    required RxString userSearchQuery,
    required RxList<Map<String, dynamic>> allUsers,
    required Map<String, dynamic> Function(String, Map<String, dynamic>?)
        mapUserDoc,
    required void Function(List<Map<String, dynamic>>) sortAndSetUsers,
  }) {
    listenToAdminMembers();

    // 0. Monitor moderation modes config (admin_settings/moderation_modes)
    if (_modesSub == null) {
      _modesSub = FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('moderation_modes')
          .snapshots()
          .listen(
        (doc) {
          if (doc.exists && doc.data() != null) {
            applyModerationModes(doc.data()!);
          } else {
            fetchFallbackModerationModes();
          }
        },
        onError: (e, s) {
          ErrorHandler.log(e,
              stackTrace: s, tag: 'AdminSubscriptionsManager.modesStream');
          fetchFallbackModerationModes();
        },
      );
      if (_modesSub != null) trackSubscription(_modesSub!);
    }

    // 0.1 Monitor language requests
    startLanguageRequestsSubscription(trackSubscription);

    // 1. Content moderation streams
    if (_videosSub == null) {
      _videosSub = AdminContentStreamListeners.listenToVideos(
        videos: videos,
        pendingVideos: pendingVideos,
        totalVideos: totalVideos,
        isVideoPending: isVideoPending,
      );
      trackSubscription(_videosSub!);
    }

    if (_imagesSub == null) {
      _imagesSub = AdminContentStreamListeners.listenToFlaggedImages(
        queueBuffer: queueBuffer,
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: isImagePostPending,
      );
      trackSubscription(_imagesSub!);
    }

    if (_verificationQueueSub == null) {
      _verificationQueueSub =
          AdminContentStreamListeners.listenToImageVerification(
        queueBuffer: queueBuffer,
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: isImagePostPending,
      );
      trackSubscription(_verificationQueueSub!);
    }

    if (_communitySub == null) {
      _communitySub = AdminContentStreamListeners.listenToCommunityPosts(
        queueBuffer: queueBuffer,
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: isImagePostPending,
      );
      trackSubscription(_communitySub!);
    }

    if (_topicsSub == null) {
      _topicsSub = AdminContentStreamListeners.listenToTopics(
        topics: topics,
        pendingTopics: pendingTopics,
        totalTopics: totalTopics,
        isTopicPending: isTopicPending,
      );
      trackSubscription(_topicsSub!);
    }

    if (_playlistsThumbnailsSub == null) {
      _playlistsThumbnailsSub = AdminContentStreamListeners.listenToPlaylists(
        queueBuffer: queueBuffer,
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: isImagePostPending,
      );
      trackSubscription(_playlistsThumbnailsSub!);
    }

    if (_channelsSub == null) {
      _channelsSub = AdminContentStreamListeners.listenToChannels(
        channels: channels,
        pendingChannels: pendingChannels,
        totalChannels: totalChannels,
        isChannelPending: isChannelPending,
      );
      trackSubscription(_channelsSub!);
    }

    if (_reportsSub == null) {
      _reportsSub = AdminContentStreamListeners.listenToReports(
        queueBuffer: queueBuffer,
        videos: videos,
        reports: reports,
        pendingReports: pendingReports,
        totalReports: totalReports,
        isReportPending: isReportPending,
      );
      trackSubscription(_reportsSub!);
    }

    if (_videoReportsSub == null) {
      _videoReportsSub = AdminContentStreamListeners.listenToVideoReports(
        queueBuffer: queueBuffer,
        videos: videos,
        reports: reports,
        pendingReports: pendingReports,
        totalReports: totalReports,
        isReportPending: isReportPending,
        onCancel: () {
          _videoReportsSub?.cancel();
          _videoReportsSub = null;
        },
      );
      trackSubscription(_videoReportsSub!);
    }

    if (_altVideoReportsSub == null) {
      _altVideoReportsSub = AdminContentStreamListeners.listenToAltVideoReports(
        queueBuffer: queueBuffer,
        videos: videos,
        reports: reports,
        pendingReports: pendingReports,
        totalReports: totalReports,
        isReportPending: isReportPending,
        onCancel: () {
          _altVideoReportsSub?.cancel();
          _altVideoReportsSub = null;
        },
      );
      trackSubscription(_altVideoReportsSub!);
    }

    // 2. Monitor rejection / audit logs and administrative actions
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
          combineAuditLogs(rejectedImages: list, auditLogs: auditLogs);
        },
        onError: (e, s) {
          ErrorHandler.log(e,
              stackTrace: s, tag: 'AdminSubscriptionsManager.logsStream');
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
          combineAuditLogs(actions: list, auditLogs: auditLogs);
        },
        onError: (e, s) {
          ErrorHandler.log(e,
              stackTrace: s, tag: 'AdminSubscriptionsManager.actionsLogStream');
        },
      );
      if (_actionsLogSub != null) trackSubscription(_actionsLogSub!);
    }

    // 3. Monitor content_appeals collection
    startAppealsSubscription();

    // 4. Monitor ad_campaigns collection
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
            final dtA = AdminQueueCombiner.parseTimestamp(timeA);
            final dtB = AdminQueueCombiner.parseTimestamp(timeB);
            return dtB.compareTo(dtA);
          });

          ads.assignAll(list);
          pendingAds.value =
              ads.where((a) => a['status'] == 'underReview').length;
          totalAds.value = ads.length;
        },
        onError: (e, s) {
          ErrorHandler.log(e,
              stackTrace: s, tag: 'AdminSubscriptionsManager.adsStream');
        },
      );
      if (_adsSub != null) trackSubscription(_adsSub!);
    }

    // 5. Monitor users collection
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
          ErrorHandler.log(e,
              stackTrace: s, tag: 'AdminSubscriptionsManager.usersStream');
        },
      );
      if (_usersSub != null) trackSubscription(_usersSub!);
    }
  }

  /// Cancels all active Firestore subscriptions and resets state
  void stopSubscriptions({
    required void Function() stopAdminMembersSubscription,
    required void Function() stopLanguageRequestsSubscription,
    required void Function() stopAppealsSubscription,
  }) {
    if (_modesSub != null) unawaited(_modesSub!.cancel());
    if (_videosSub != null) unawaited(_videosSub!.cancel());
    if (_topicsSub != null) unawaited(_topicsSub!.cancel());
    if (_imagesSub != null) unawaited(_imagesSub!.cancel());
    if (_communitySub != null) unawaited(_communitySub!.cancel());
    if (_playlistsThumbnailsSub != null) {
      unawaited(_playlistsThumbnailsSub!.cancel());
    }
    if (_verificationQueueSub != null) {
      unawaited(_verificationQueueSub!.cancel());
    }
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
}

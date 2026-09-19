import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_buffer.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_combiner.dart';

/// Helper establishing real-time Firestore stream listeners for content moderation queues.
class AdminContentStreamListeners {
  static StreamSubscription<QuerySnapshot> listenToVideos({
    required RxList<Map<String, dynamic>> videos,
    required RxInt pendingVideos,
    required RxInt totalVideos,
    required bool Function(Map<String, dynamic>) isVideoPending,
  }) {
    return FirebaseFirestore.instance
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
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });

        if (list.isNotEmpty || videos.isEmpty) {
          videos.assignAll(list);
        }

        pendingVideos.value = videos.where(isVideoPending).length;
        totalVideos.value = videos.length;
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s, tag: 'AdminContentStreamListeners.videoStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToFlaggedImages({
    required AdminQueueBuffer queueBuffer,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
  }) {
    return FirebaseFirestore.instance
        .collection('flagged_images_review')
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        queueBuffer.combineImagesAndPosts(
          flaggedList: list,
          images: images,
          pendingImages: pendingImages,
          totalImages: totalImages,
          isImagePostPending: isImagePostPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s, tag: 'AdminContentStreamListeners.imageStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToImageVerification({
    required AdminQueueBuffer queueBuffer,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
  }) {
    return FirebaseFirestore.instance
        .collection('image_verification')
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        queueBuffer.combineImagesAndPosts(
          verificationList: list,
          images: images,
          pendingImages: pendingImages,
          totalImages: totalImages,
          isImagePostPending: isImagePostPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s,
            tag: 'AdminContentStreamListeners.verificationQueueStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToCommunityPosts({
    required AdminQueueBuffer queueBuffer,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
  }) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.community)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, 'category': 'Community Post', ...doc.data()};
        }).toList();
        queueBuffer.combineImagesAndPosts(
          communityList: list,
          images: images,
          pendingImages: pendingImages,
          totalImages: totalImages,
          isImagePostPending: isImagePostPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s,
            tag: 'AdminContentStreamListeners.communityStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToTopics({
    required RxList<Map<String, dynamic>> topics,
    required RxInt pendingTopics,
    required RxInt totalTopics,
    required bool Function(Map<String, dynamic>) isTopicPending,
  }) {
    return FirebaseFirestore.instance
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
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });

        if (list.isNotEmpty || topics.isEmpty) {
          topics.assignAll(list);
        }

        pendingTopics.value = topics.where(isTopicPending).length;
        totalTopics.value = topics.length;
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s, tag: 'AdminContentStreamListeners.topicsStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToPlaylists({
    required AdminQueueBuffer queueBuffer,
    required RxList<Map<String, dynamic>> images,
    required RxInt pendingImages,
    required RxInt totalImages,
    required bool Function(Map<String, dynamic>) isImagePostPending,
  }) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.playlists)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, 'category': 'Playlist Thumbnail', ...doc.data()};
        }).toList();
        queueBuffer.combineImagesAndPosts(
          playlistList: list,
          images: images,
          pendingImages: pendingImages,
          totalImages: totalImages,
          isImagePostPending: isImagePostPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s,
            tag: 'AdminContentStreamListeners.playlistsThumbnailsStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToChannels({
    required RxList<Map<String, dynamic>> channels,
    required RxInt pendingChannels,
    required RxInt totalChannels,
    required bool Function(Map<String, dynamic>) isChannelPending,
  }) {
    return FirebaseFirestore.instance
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
          final dtA = AdminQueueCombiner.parseTimestamp(timeA);
          final dtB = AdminQueueCombiner.parseTimestamp(timeB);
          return dtB.compareTo(dtA);
        });

        if (list.isNotEmpty || channels.isEmpty) {
          channels.assignAll(list);
        }

        pendingChannels.value = channels.where(isChannelPending).length;
        totalChannels.value = channels.length;
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s, tag: 'AdminContentStreamListeners.channelsStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToReports({
    required AdminQueueBuffer queueBuffer,
    required List<Map<String, dynamic>> videos,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required RxInt totalReports,
    required bool Function(Map<String, dynamic>) isReportPending,
  }) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.reports)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        queueBuffer.combineReports(
          mainReports: list,
          videos: videos,
          reports: reports,
          pendingReports: pendingReports,
          totalReports: totalReports,
          isReportPending: isReportPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s, tag: 'AdminContentStreamListeners.reportsStream');
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToVideoReports({
    required AdminQueueBuffer queueBuffer,
    required List<Map<String, dynamic>> videos,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required RxInt totalReports,
    required bool Function(Map<String, dynamic>) isReportPending,
    required void Function() onCancel,
  }) {
    return FirebaseFirestore.instance
        .collection('video_reports')
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        queueBuffer.combineReports(
          videoReportsList: list,
          videos: videos,
          reports: reports,
          pendingReports: pendingReports,
          totalReports: totalReports,
          isReportPending: isReportPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s,
            tag: 'AdminContentStreamListeners.videoReportsStream');
        onCancel();
      },
    );
  }

  static StreamSubscription<QuerySnapshot> listenToAltVideoReports({
    required AdminQueueBuffer queueBuffer,
    required List<Map<String, dynamic>> videos,
    required RxList<Map<String, dynamic>> reports,
    required RxInt pendingReports,
    required RxInt totalReports,
    required bool Function(Map<String, dynamic>) isReportPending,
    required void Function() onCancel,
  }) {
    return FirebaseFirestore.instance
        .collection('videoReports')
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        queueBuffer.combineReports(
          altVideoReportsList: list,
          videos: videos,
          reports: reports,
          pendingReports: pendingReports,
          totalReports: totalReports,
          isReportPending: isReportPending,
        );
      },
      onError: (e, s) {
        ErrorHandler.log(e,
            stackTrace: s,
            tag: 'AdminContentStreamListeners.altVideoReportsStream');
        onCancel();
      },
    );
  }
}

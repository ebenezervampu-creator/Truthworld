import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_queue_combiner.dart';

/// In-memory buffer and aggregator for multi-stream admin queues.
class AdminQueueBuffer {
  List<Map<String, dynamic>> rawCommunityPosts = [];
  List<Map<String, dynamic>> rawFlaggedImages = [];
  List<Map<String, dynamic>> rawPlaylistThumbnails = [];
  List<Map<String, dynamic>> rawVerificationQueue = [];
  List<Map<String, dynamic>> rawReportsDocs = [];
  List<Map<String, dynamic>> rawVideoReportsDocs = [];
  List<Map<String, dynamic>> rawVideoReportsAltDocs = [];
  List<Map<String, dynamic>> rawActionLogs = [];
  List<Map<String, dynamic>> rawRejectedImageLogs = [];

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
    if (communityList != null) rawCommunityPosts = communityList;
    if (flaggedList != null) rawFlaggedImages = flaggedList;
    if (verificationList != null) rawVerificationQueue = verificationList;
    if (playlistList != null) rawPlaylistThumbnails = playlistList;

    final combined = AdminQueueCombiner.combineImagesAndPosts(
      rawFlaggedImages: rawFlaggedImages,
      rawVerificationQueue: rawVerificationQueue,
      rawCommunityPosts: rawCommunityPosts,
      rawPlaylistThumbnails: rawPlaylistThumbnails,
    );

    images.assignAll(combined);
    pendingImages.value = combined.where(isImagePostPending).length;
    totalImages.value = combined.length;
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
    if (mainReports != null) rawReportsDocs = mainReports;
    if (videoReportsList != null) rawVideoReportsDocs = videoReportsList;
    if (altVideoReportsList != null) {
      rawVideoReportsAltDocs = altVideoReportsList;
    }

    final combined = AdminQueueCombiner.combineReports(
      rawReportsDocs: rawReportsDocs,
      rawVideoReportsDocs: rawVideoReportsDocs,
      rawVideoReportsAltDocs: rawVideoReportsAltDocs,
      videos: videos,
    );

    reports.assignAll(combined);
    pendingReports.value = combined.where(isReportPending).length;
    totalReports.value = combined.length;
  }

  void combineAuditLogs({
    required RxList<Map<String, dynamic>> auditLogs,
    List<Map<String, dynamic>>? rejectedImages,
    List<Map<String, dynamic>>? actions,
  }) {
    if (rejectedImages != null) rawRejectedImageLogs = rejectedImages;
    if (actions != null) rawActionLogs = actions;

    final combined = AdminQueueCombiner.combineAuditLogs(
      rawRejectedImageLogs: rawRejectedImageLogs,
      rawActionLogs: rawActionLogs,
    );

    auditLogs.assignAll(combined);
  }
}

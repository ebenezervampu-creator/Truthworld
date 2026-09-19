import 'dart:async';

import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_barrel.dart';

export 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_barrel.dart';

/// Mixin providing real-time content moderation queues, predicates, and moderation actions.
mixin AdminContentModerationMixin on GetxController {
  /// Base controller contracts
  RxString get currentAdminEmail;

  Future<void> logAdminAction({
    required String action,
    String? targetId,
    String? userId,
    String? reason,
    Map<String, dynamic>? extra,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Content Moderation Queues & Observables
  // ═══════════════════════════════════════════════════════════════════════════
  final RxBool isActionSubmitting = false.obs;

  // Real-time Lists
  final RxList<Map<String, dynamic>> videos = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topics = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> images = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> channels = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> reports = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> ads = <Map<String, dynamic>>[].obs;

  // Selected Detail views
  final Rxn<Map<String, dynamic>> selectedVideo = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedTopic = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedImage = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedChannel = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedReport = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> selectedAd = Rxn<Map<String, dynamic>>();

  // System statistics
  final RxInt pendingVideos = 0.obs;
  final RxInt pendingTopics = 0.obs;
  final RxInt pendingImages = 0.obs;
  final RxInt pendingChannels = 0.obs;
  final RxInt pendingReports = 0.obs;
  final RxInt pendingAds = 0.obs;
  final RxInt totalVideos = 0.obs;
  final RxInt totalTopics = 0.obs;
  final RxInt totalImages = 0.obs;
  final RxInt totalChannels = 0.obs;
  final RxInt totalReports = 0.obs;
  final RxInt totalAds = 0.obs;
  final RxString adFilterTab = 'all'.obs;

  // Search & Filter
  final RxString searchQuery = ''.obs;
  final RxString filterStatus = ''.obs;
  final RxString filterCategory = ''.obs;
  final RxString filterTrustTier = ''.obs;
  final RxString videoFilterTab = 'all'.obs;
  final RxString topicFilterTab = 'pending'.obs;
  final RxString imageFilterTab = 'all'.obs;
  final RxString channelFilterTab = 'all'.obs;
  final RxString reportFilterTab = 'all'.obs;
  final RxBool isSearching = false.obs;
  final RxSet<String> selectedItemIds = <String>{}.obs;
  final RxBool isBulkActionSubmitting = false.obs;
  final RxBool isGeneratingAllVideoAdsAI = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // Content Predicates (Delegated to AdminModerationPredicates)
  // ═══════════════════════════════════════════════════════════════════════════

  bool isVideoPending(Map<String, dynamic> v) =>
      AdminModerationPredicates.isVideoPending(v);

  bool isVideoApproved(Map<String, dynamic> v) =>
      AdminModerationPredicates.isVideoApproved(v);

  bool isVideoRejected(Map<String, dynamic> v) =>
      AdminModerationPredicates.isVideoRejected(v);

  bool isChannelPending(Map<String, dynamic> c) =>
      AdminModerationPredicates.isChannelPending(c);

  bool isChannelActive(Map<String, dynamic> c) =>
      AdminModerationPredicates.isChannelActive(c);

  bool isChannelApproved(Map<String, dynamic> c) =>
      AdminModerationPredicates.isChannelApproved(c);

  bool isChannelRejected(Map<String, dynamic> c) =>
      AdminModerationPredicates.isChannelRejected(c);

  bool isTopicPending(Map<String, dynamic> t) =>
      AdminModerationPredicates.isTopicPending(t);

  bool isTopicApproved(Map<String, dynamic> t) =>
      AdminModerationPredicates.isTopicApproved(t);

  bool isTopicRejected(Map<String, dynamic> t) =>
      AdminModerationPredicates.isTopicRejected(t);

  bool isImagePostRejected(Map<String, dynamic> img) =>
      AdminModerationPredicates.isImagePostRejected(img);

  bool isImagePostPending(Map<String, dynamic> img) =>
      AdminModerationPredicates.isImagePostPending(img);

  bool isImagePostApproved(Map<String, dynamic> img) =>
      AdminModerationPredicates.isImagePostApproved(img);

  bool isReportPending(Map<String, dynamic> r) =>
      AdminModerationPredicates.isReportPending(r);

  bool isReportResolved(Map<String, dynamic> r) =>
      AdminModerationPredicates.isReportResolved(r);

  // ═══════════════════════════════════════════════════════════════════════════
  // Content Moderation Actions (Delegated to Moderation Services)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Executes manual video moderation action (Approve/Reject)
  Future<bool> moderateVideo(
    String videoId,
    String action,
    String reason,
  ) =>
      AdminMediaModerationService.moderateVideo(
        videoId: videoId,
        action: action,
        reason: reason,
        videos: videos,
        pendingVideos: pendingVideos,
        selectedVideo: selectedVideo,
        isActionSubmitting: isActionSubmitting,
      );

  /// Executes manual image moderation action (Approve/Reject)
  Future<bool> moderateImage(
    String verificationId,
    String action,
    String reason,
  ) =>
      AdminMediaModerationService.moderateImage(
        verificationId: verificationId,
        action: action,
        reason: reason,
        images: images,
        pendingImages: pendingImages,
        selectedImage: selectedImage,
        isActionSubmitting: isActionSubmitting,
      );

  /// Executes manual channel moderation action (Approve/Reject)
  Future<bool> moderateChannel(
    String channelId,
    String action,
    String reason,
  ) =>
      AdminEntityModerationService.moderateChannel(
        channelId: channelId,
        action: action,
        reason: reason,
        channels: channels,
        pendingChannels: pendingChannels,
        selectedChannel: selectedChannel,
        isActionSubmitting: isActionSubmitting,
      );

  /// Executes manual topic moderation action (Approve/Reject)
  Future<bool> moderateTopic(
    String topicId,
    String action,
    String reason,
  ) =>
      AdminEntityModerationService.moderateTopic(
        topicId: topicId,
        action: action,
        reason: reason,
        topics: topics,
        pendingTopics: pendingTopics,
        selectedTopic: selectedTopic,
        isActionSubmitting: isActionSubmitting,
      );

  /// Executes manual ad moderation action (Approve/Reject)
  Future<bool> moderateAd(
    String adId,
    String action, {
    String? reason,
  }) =>
      AdminEntityModerationService.moderateAd(
        adId: adId,
        action: action,
        reason: reason,
        ads: ads,
        pendingAds: pendingAds,
        selectedAd: selectedAd,
        isActionSubmitting: isActionSubmitting,
      );

  /// Trigger batch AI dubbing and subtitles generation for all video ads
  Future<void> generateAllVideoAdsAI({
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    bool forceRegenerate = false,
  }) =>
      AdminEntityModerationService.generateAllVideoAdsAI(
        features: features,
        targetLanguages: targetLanguages,
        voiceStyle: voiceStyle,
        forceRegenerate: forceRegenerate,
        isGeneratingAllVideoAdsAI: isGeneratingAllVideoAdsAI,
      );

  /// Executes bulk moderation action on selected items
  Future<void> bulkModerate(
    String contentType,
    String action,
    String reason,
  ) =>
      AdminEntityModerationService.bulkModerate(
        contentType: contentType,
        action: action,
        reason: reason,
        selectedItemIds: selectedItemIds,
        isBulkActionSubmitting: isBulkActionSubmitting,
        onClearSelection: clearSelection,
      );

  /// Executes manual report resolution
  Future<bool> moderateReport(
    String reportId,
    String action,
    String reviewReason,
  ) =>
      AdminMediaModerationService.moderateReport(
        reportId: reportId,
        action: action,
        reviewReason: reviewReason,
        reports: reports,
        pendingReports: pendingReports,
        selectedReport: selectedReport,
        isActionSubmitting: isActionSubmitting,
        videos: videos,
        pendingVideos: pendingVideos,
        selectedVideo: selectedVideo,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Search & Bulk Moderation Selection Methods
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
    selectedItemIds.assignAll(
      items
          .map((e) => (e['id'] ?? '').toString())
          .where((id) => id.isNotEmpty),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Filtered Queue Getters (Delegated to AdminModerationFilters)
  // ═══════════════════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get filteredVideos =>
      AdminModerationFilters.filterVideos(
        videos: videos,
        searchQuery: searchQuery.value,
        filterCategory: filterCategory.value,
        videoFilterTab: videoFilterTab.value,
      );

  List<Map<String, dynamic>> get filteredChannels =>
      AdminModerationFilters.filterChannels(
        channels: channels,
        searchQuery: searchQuery.value,
        channelFilterTab: channelFilterTab.value,
      );

  List<Map<String, dynamic>> get filteredTopics =>
      AdminModerationFilters.filterTopics(
        topics: topics,
        searchQuery: searchQuery.value,
        topicFilterTab: topicFilterTab.value,
      );

  List<Map<String, dynamic>> get filteredImages =>
      AdminModerationFilters.filterImages(
        images: images,
        searchQuery: searchQuery.value,
        imageFilterTab: imageFilterTab.value,
      );

  List<Map<String, dynamic>> get filteredReports =>
      AdminModerationFilters.filterReports(
        reports: reports,
        searchQuery: searchQuery.value,
        reportFilterTab: reportFilterTab.value,
      );
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_controller_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/controllers/downloads/download_controller_barrel.dart';

/// Represents an active in-flight video/audio download task.
class ActiveDownloadTask {
  ActiveDownloadTask({
    required this.video,
    required this.isAudioOnly,
    this.quality = 'Standard',
    double initialProgress = 0.0,
    String initialStatus = 'Preparing download...',
  })  : progress = initialProgress.obs,
        status = initialStatus.obs;

  final Video video;
  final bool isAudioOnly;
  final String quality;
  final RxDouble progress;
  final RxString status;
}

/// Central coordinator controller for managing offline video downloads, storage, and filtering.
class DownloadsController extends BaseController {
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;
  RxBool isSearchExpanded = false.obs;
  RxString sortBy = 'recent'.obs;
  RxBool isAscending = false.obs;
  RxList<OfflineVideo> videos = <OfflineVideo>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;
  RxString selectedCategory = 'All'.obs;
  RxBool isListView = true.obs;

  /// Active downloads tracking: videoId -> ActiveDownloadTask
  final RxMap<String, ActiveDownloadTask> activeDownloads =
      <String, ActiveDownloadTask>{}.obs;

  /// Active downloads progress tracking: videoId -> progress (0.0 to 1.0)
  final RxMap<String, double> downloadProgressMap = <String, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadVideos();
  }

  /// Loads all offline videos from local storage database.
  Future<void> loadVideos() async {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';
    clearError();
    try {
      final data = await getAllVideosData();
      final loaded = <OfflineVideo>[];
      for (final e in data) {
        try {
          final meta = e['meta'];
          if (meta is Map) {
            loaded.add(OfflineVideo.fromJson(Map<String, dynamic>.from(meta)));
          }
        } catch (itemErr, itemStack) {
          ErrorHandler.log(
            itemErr,
            stackTrace: itemStack,
            tag: 'DownloadsController.loadVideos.item',
          );
        }
      }
      videos.assignAll(loaded);

      // Sort locally based on downloadedAt
      videos.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DownloadsController.loadVideos');
      const msg = 'Unable to load offline videos. Please try again.';
      rxErrorMessage.value = msg;
      setError(msg);
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Deletes an offline video item from local storage.
  Future<void> deleteVideoItem(String id) async {
    await deleteVideo(id);
    await loadVideos();
    AppSnackbar.info(
      'Video removed from downloads.',
      title: 'Removed',
    );
  }

  /// Sets active search query for offline list.
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  /// Toggles search bar active state.
  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
    HapticFeedback.lightImpact();
  }

  /// Toggles between list view and grid view.
  void toggleView() {
    isListView.value = !isListView.value;
    HapticFeedback.lightImpact();
  }

  /// Changes sorting column and direction.
  void setSortBy(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }

    if (sortBy.value == 'recent') {
      videos.sort(
        (a, b) => isAscending.value
            ? a.downloadedAt.compareTo(b.downloadedAt)
            : b.downloadedAt.compareTo(a.downloadedAt),
      );
    } else if (sortBy.value == 'title') {
      videos.sort(
        (a, b) => isAscending.value
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title),
      );
    }

    HapticFeedback.lightImpact();
  }

  /// Sets active category tab ('All', 'Videos', 'Audio').
  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  /// Navigates to player view in offline playback mode.
  void playVideo(OfflineVideo offlineVideo) {
    Get.toNamed(
      '/watch?v=${offlineVideo.id}',
      arguments: {
        'video': Video.fromOffline(offlineVideo),
        'isOffline': true,
        'isAudioOnly': offlineVideo.isAudioOnly,
        'quality': offlineVideo.quality,
      },
    );
  }

  /// Returns filtered and searched offline video items.
  List<OfflineVideo> get filteredVideos {
    return DownloadFilterHelper.filterVideos(
      videos: videos,
      category: selectedCategory.value,
      searchQuery: searchQuery.value,
    );
  }

  /// Formats time difference into standard English.
  String formatTimeAgo(DateTime timestamp) {
    return DownloadFilterHelper.formatTimeAgo(timestamp);
  }

  /// Groups offline videos chronologically into date sections.
  Map<String, List<OfflineVideo>> groupVideosByDate(
    List<OfflineVideo> videosList,
  ) {
    return DownloadFilterHelper.groupVideosByDate(videosList);
  }

  /// Discovers all available resolutions for a given video.
  Future<List<VideoResolutionV2>> getAvailableResolutionsForVideo(
    Video video,
  ) {
    return DownloadResolutionManager.getAvailableResolutionsForVideo(video);
  }

  /// Resolves the fastest direct downloadable stream URL for a given video / quality.
  Future<String> resolveDownloadUrl(
    Video video, {
    required bool isAudioOnly,
    VideoResolutionV2? resolution,
  }) {
    return DownloadUrlResolver.resolveDownloadUrl(
      video,
      isAudioOnly: isAudioOnly,
      resolution: resolution,
    );
  }

  /// Checks if a video is currently being downloaded.
  bool isVideoDownloading(String videoId) =>
      downloadProgressMap.containsKey(videoId) ||
      activeDownloads.containsKey(videoId);

  /// Checks if a video is already saved in offline downloads.
  bool isVideoDownloaded(String videoId) =>
      videos.any((v) => v.id == videoId);

  /// Retrieves offline video metadata for a given video ID if downloaded.
  Future<OfflineVideo?> getOfflineVideo(String id) async {
    final existing = videos.firstWhereOrNull((v) => v.id == id);
    if (existing != null) return existing;
    return getOfflineVideoMetadata(id);
  }

  /// Cancels an active download task.
  void cancelDownload(String videoId) {
    activeDownloads.remove(videoId);
    downloadProgressMap.remove(videoId);
    AppSnackbar.info('Download cancelled.');
  }

  /// Downloads video or audio for offline playback.
  Future<bool> downloadVideoOffline({
    required Video video,
    BuildContext? context,
    VideoResolutionV2? resolution,
    bool isAudioOnly = false,
    Function(double progress)? onProgress,
  }) async {
    if (!DownloadPipelineExecutor.validateDownloadSettings()) return false;

    // Content moderation and policy validation check
    if (video.isRejected ||
        video.status == VideoStatus.rejected ||
        !video.isApprovedByGeminiOrManual ||
        !VideoVisibilityPolicy.canViewVideo(video)) {
      AppSnackbar.warning(
        'This video is unavailable for offline viewing.',
      );
      return false;
    }

    // 1. Check if already downloaded
    if (isVideoDownloaded(video.id)) {
      AppSnackbar.info(
        "'${video.title}' is already saved in your downloads.",
        title: 'Already Downloaded',
      );
      return true;
    }

    // 2. Check if currently in progress
    if (isVideoDownloading(video.id)) {
      AppSnackbar.info(
        "'${video.title}' is currently downloading. Check the Downloads tab for live progress.",
        title: 'Download In Progress',
      );
      return false;
    }

    // 3. Check premium requirement for resolutions > 720p
    if (resolution != null && !isAudioOnly) {
      if (DownloadQualityDialog.isPremiumResolution(resolution)) {
        final hasPremium = DownloadQualityDialog.hasPremiumAccess(video);
        if (!hasPremium) {
          AppSnackbar.info(
            'Downloading in ${resolution.label} requires a Premium subscription.',
            title: 'Premium Required',
          );
          DownloadQualityDialog.showUpgradeSheet(context ?? Get.context, video);
          return false;
        }
      }
    }

    final qualityLabel = isAudioOnly
        ? 'Audio only'
        : (resolution?.label.isNotEmpty == true
            ? resolution!.label
            : 'Standard');

    final task = ActiveDownloadTask(
      video: video,
      isAudioOnly: isAudioOnly,
      quality: qualityLabel,
      initialStatus: 'Starting download...',
    );

    activeDownloads[video.id] = task;
    downloadProgressMap[video.id] = 0.0;
    onProgress?.call(0.0);

    void handleProgress(double prog) {
      downloadProgressMap[video.id] = prog;
      task.progress.value = prog;
      final percent = (prog * 100).toInt();
      task.status.value = percent > 0 ? 'Downloading $percent%' : 'Downloading...';
      onProgress?.call(prog);
    }

    // Provide immediate user feedback that download is starting
    AppSnackbar.show(
      'Downloading',
      isAudioOnly
          ? "Downloading '${video.title}' for offline listening..."
          : "Downloading '${video.title}' offline...",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1E1E1E),
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      duration: const Duration(seconds: 3),
    );

    try {
      task.status.value = 'Connecting to stream...';
      final targetUrl = await resolveDownloadUrl(
        video,
        resolution: resolution,
        isAudioOnly: isAudioOnly,
      );

      if (targetUrl.isEmpty) {
        throw Exception(
          'No direct media stream available to save offline for this video.',
        );
      }

      final offlineVideo = OfflineVideo(
        id: video.id,
        title: isAudioOnly
            ? '${video.title} (Audio)'
            : (resolution != null
                ? '${video.title} (${resolution.label})'
                : video.title),
        channelName: video.channelName,
        channelImage: video.channelImage.isNotEmpty
            ? video.channelImage
            : video.channelAvatarUrl,
        views: FormatUtils.formatCount(video.views),
        thumbnailUrl: video.thumbnailUrl,
        downloadedAt: DateTime.now(),
        isAudioOnly: isAudioOnly,
        quality: qualityLabel,
      );

      task.status.value = 'Downloading media...';
      if (kIsWeb) {
        await DownloadPipelineExecutor.downloadWeb(
          video: video,
          targetUrl: targetUrl,
          offlineVideo: offlineVideo,
          progressMap: downloadProgressMap,
          onProgress: handleProgress,
        );
      } else {
        await DownloadPipelineExecutor.downloadNative(
          video: video,
          targetUrl: targetUrl,
          offlineVideo: offlineVideo,
          progressMap: downloadProgressMap,
          onProgress: handleProgress,
        );
      }

      task.status.value = 'Encrypting & saving...';
      await loadVideos();

      AppSnackbar.show(
        isAudioOnly ? 'Audio Saved Offline' : 'Video Download Complete',
        "'${video.title}' is ready for offline ${isAudioOnly ? 'listening' : 'viewing'}.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withValues(alpha: 0.85),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadsController.downloadVideoOffline',
      );
      AppSnackbar.error(
        'Unable to download video. Please check your connection and try again.',
      );
      return false;
    } finally {
      activeDownloads.remove(video.id);
      downloadProgressMap.remove(video.id);
      onProgress?.call(0.0);
    }
  }

  /// Convenience method to download audio only.
  Future<bool> downloadAudioOffline({
    required Video video,
    BuildContext? context,
    Function(double progress)? onProgress,
  }) {
    return downloadVideoOffline(
      video: video,
      context: context,
      isAudioOnly: true,
      onProgress: onProgress,
    );
  }

  /// Displays the interactive quality & resolution selection bottom sheet.
  void showDownloadQualityDialog(
    BuildContext? context,
    Video video, {
    Function(VideoResolutionV2 resolution)? onResolutionSelected,
    VoidCallback? onAudioSelected,
  }) {
    // Content moderation and policy validation check
    if (video.isRejected ||
        video.status == VideoStatus.rejected ||
        !video.isApprovedByGeminiOrManual ||
        !VideoVisibilityPolicy.canViewVideo(video)) {
      AppSnackbar.warning(
        'This video is unavailable for offline viewing.',
      );
      return;
    }

    DownloadQualityDialog.show(
      context,
      video,
      getResolutions: getAvailableResolutionsForVideo,
      onResolutionSelected: (res) {
        if (onResolutionSelected != null) {
          onResolutionSelected(res);
        } else {
          downloadVideoOffline(
            video: video,
            resolution: res,
          );
        }
      },
      onAudioSelected: () {
        if (onAudioSelected != null) {
          onAudioSelected();
        } else {
          downloadAudioOffline(
            video: video,
          );
        }
      },
    );
  }
}

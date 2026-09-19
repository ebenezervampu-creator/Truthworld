import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_controller_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/controllers/downloads/download_controller_barrel.dart';

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
    try {
      final data = await getAllVideosData();
      videos.value = data
          .map((e) => OfflineVideo.fromJson(e['meta'] as Map<String, dynamic>))
          .toList();

      // Sort locally based on downloadedAt
      videos.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DownloadsController.loadVideos');
      rxErrorMessage.value = 'Unable to load offline videos. Please try again.';
    }
    rxIsLoading.value = false;
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

  /// Downloads video or audio for offline playback.
  Future<bool> downloadVideoOffline({
    required Video video,
    BuildContext? context,
    VideoResolutionV2? resolution,
    bool isAudioOnly = false,
    Function(double progress)? onProgress,
  }) async {
    if (!DownloadPipelineExecutor.validateDownloadSettings()) return false;

    if (downloadProgressMap.containsKey(video.id)) {
      AppSnackbar.show(
        'Download In Progress',
        'This item is already being downloaded.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    downloadProgressMap[video.id] = 0.0;
    onProgress?.call(0.0);

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

      final qualityLabel = isAudioOnly
          ? 'Audio only'
          : (resolution?.label.isNotEmpty == true
              ? resolution!.label
              : 'Standard');

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

      if (kIsWeb) {
        await DownloadPipelineExecutor.downloadWeb(
          video: video,
          targetUrl: targetUrl,
          offlineVideo: offlineVideo,
          progressMap: downloadProgressMap,
          onProgress: onProgress,
        );
      } else {
        await DownloadPipelineExecutor.downloadNative(
          video: video,
          targetUrl: targetUrl,
          offlineVideo: offlineVideo,
          progressMap: downloadProgressMap,
          onProgress: onProgress,
        );
      }

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

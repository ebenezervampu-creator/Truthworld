import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    } catch (e) {
      rxErrorMessage.value = e.toString();
    }
    rxIsLoading.value = false;
  }

  Future<void> deleteVideoItem(String id) async {
    await deleteVideo(id);
    await loadVideos();
    Get.snackbar(
      'Deleted',
      'Video removed from downloads.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF6366F1),
      colorText: AppColors.textPrimary,
    );
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
    HapticFeedback.lightImpact();
  }

  void toggleView() {
    isListView.value = !isListView.value;
    HapticFeedback.lightImpact();
  }

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

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

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

  List<OfflineVideo> get filteredVideos {
    var filtered = videos.toList();
    if (selectedCategory.value == 'Videos') {
      filtered = filtered.where((v) => !v.isAudioOnly).toList();
    } else if (selectedCategory.value == 'Audio') {
      filtered = filtered.where((v) => v.isAudioOnly).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (v) =>
                v.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                v.channelName.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }
    return filtered;
  }

  String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, List<OfflineVideo>> groupVideosByDate(
    List<OfflineVideo> videosList,
  ) {
    final groups = <String, List<OfflineVideo>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final video in videosList) {
      final date = video.downloadedAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      String key;
      if (dateOnly == today) {
        key = 'Today';
      } else if (dateOnly == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(video);
    }
    return groups;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // ===========================================================================
  // RESOLUTION DISCOVERY & UNIFIED DOWNLOAD ENGINE
  // ===========================================================================

  /// Discovers all available resolutions for a given video.
  /// Checks resolution_jobs variants, video.adaptiveResolutions, and provides standard tiers.
  Future<List<VideoResolutionV2>> getAvailableResolutionsForVideo(
    Video video,
  ) async {
    final resolvedResolutions = <VideoResolutionV2>[];

    // 1. Check Firestore resolution_jobs document variants
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(video.id)
          .getCacheFirst();

      if (doc.exists && doc.data() != null && doc.data()!['variants'] != null) {
        final variants = doc.data()!['variants'] as Map<String, dynamic>;
        final fetchTasks = <Future<VideoResolutionV2?>>[];

        for (final entry in variants.entries) {
          final variantData = entry.value as Map<String, dynamic>;
          final status = variantData['status'];
          final label = variantData['label'] ?? entry.key;

          if (status == 'completed') {
            final directDownloadUrl = variantData['downloadUrl'] as String?;
            final outputPath = variantData['outputPath'] as String?;

            if (directDownloadUrl != null &&
                directDownloadUrl.isNotEmpty &&
                !directDownloadUrl.contains('.m3u8') &&
                !directDownloadUrl.contains('.mpd')) {
              resolvedResolutions.add(
                VideoResolutionV2(
                  label: label,
                  url: directDownloadUrl,
                  width: (variantData['width'] as num?)?.toInt() ?? 0,
                  height: (variantData['height'] as num?)?.toInt() ??
                      _inferHeightFromLabel(label),
                  bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                ),
              );
            } else if (outputPath != null &&
                outputPath.isNotEmpty &&
                !outputPath.contains('.m3u8') &&
                !outputPath.contains('.mpd')) {
              fetchTasks.add(() async {
                try {
                  var downloadUrl = '';
                  try {
                    downloadUrl = await FirebaseStorage.instance
                        .ref(outputPath)
                        .getDownloadURL();
                  } catch (_) {
                    downloadUrl = StorageUtils.getFastDownloadUrl(outputPath);
                  }
                  return VideoResolutionV2(
                    label: label,
                    url: downloadUrl,
                    width: (variantData['width'] as num?)?.toInt() ?? 0,
                    height: (variantData['height'] as num?)?.toInt() ??
                        _inferHeightFromLabel(label),
                    bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                  );
                } catch (_) {
                  return null;
                }
              }());
            }
          }
        }

        if (fetchTasks.isNotEmpty) {
          final results = await Future.wait(fetchTasks);
          resolvedResolutions.addAll(results.whereType<VideoResolutionV2>());
        }
      }
    } catch (_) {}

    // 2. Check video.adaptiveResolutions
    if (resolvedResolutions.isEmpty && video.adaptiveResolutions.isNotEmpty) {
      for (final res in video.adaptiveResolutions) {
        if (res.url.isNotEmpty &&
            !res.url.contains('.m3u8') &&
            !res.url.contains('.mpd')) {
          resolvedResolutions.add(res);
        }
      }
    }

    // 3. Probe Firebase Storage for standard progressive video files if nothing found yet
    if (resolvedResolutions.isEmpty) {
      final probePaths = [
        'videos/${video.id}/1080p.mp4',
        'videos/${video.id}/720p.mp4',
        'videos/${video.id}/480p.mp4',
        'videos/${video.id}/360p.mp4',
        'videos/${video.id}/original.mp4',
        'videos/${video.id}/video.mp4',
        'videos/${video.id}.mp4',
      ];
      for (final path in probePaths) {
        try {
          final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
          if (url.isNotEmpty) {
            final filename = path.split('/').last;
            final label = filename.replaceAll('.mp4', '').toUpperCase();
            resolvedResolutions.add(
              VideoResolutionV2(
                label: label.contains('P') ? label : '$label (Standard)',
                url: url,
                width: 0,
                height: _inferHeightFromLabel(label),
                bitrate: 0,
              ),
            );
          }
        } catch (_) {}
      }
    }

    // 4. Fallback standard resolution ladder if only single/empty progressive streams found
    if (resolvedResolutions.isEmpty) {
      final baseMediaUrl = video.originalUrl.isNotEmpty &&
              !video.originalUrl.contains('.m3u8') &&
              !video.originalUrl.contains('.mpd')
          ? video.originalUrl
          : (video.videoUrl.isNotEmpty &&
                  !video.videoUrl.contains('.m3u8') &&
                  !video.videoUrl.contains('.mpd')
              ? video.videoUrl
              : '');

      resolvedResolutions.addAll([
        VideoResolutionV2(
          label: '1080p',
          url: baseMediaUrl,
          width: 1920,
          height: 1080,
          bitrate: 4500000,
        ),
        VideoResolutionV2(
          label: '720p',
          url: baseMediaUrl,
          width: 1280,
          height: 720,
          bitrate: 2500000,
        ),
        VideoResolutionV2(
          label: '480p',
          url: baseMediaUrl,
          width: 854,
          height: 480,
          bitrate: 1200000,
        ),
        VideoResolutionV2(
          label: '360p',
          url: baseMediaUrl,
          width: 640,
          height: 360,
          bitrate: 800000,
        ),
        VideoResolutionV2(
          label: '240p',
          url: baseMediaUrl,
          width: 426,
          height: 240,
          bitrate: 400000,
        ),
        VideoResolutionV2(
          label: '144p',
          url: baseMediaUrl,
          width: 256,
          height: 144,
          bitrate: 200000,
        ),
      ]);
    } else {
      // Sort by height descending
      resolvedResolutions.sort((a, b) => b.height.compareTo(a.height));
    }

    return resolvedResolutions;
  }

  int _inferHeightFromLabel(String label) {
    final clean = label.replaceAll(RegExp('[^0-9]'), '');
    return int.tryParse(clean) ?? 720;
  }

  bool _validateDownloadSettings() {
    if (!Get.isRegistered<UserSettingsController>()) return true;
    final dl = UserSettingsController.to.downloads.value;

    if (dl.wifiOnly) {
      final isWifi = !Get.isRegistered<ConnectivityService>() ||
          ConnectivityService.to.isWifi;
      if (!isWifi) {
        AppSnackbar.show(
          'Wi-Fi Required',
          'Downloads are restricted to Wi-Fi connections in Settings.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1E1E1E),
          colorText: Colors.white,
        );
        return false;
      }
    }
    return true;
  }

  /// Extracts a reliable Firebase Storage Reference from any path or URL format.
  Reference? _getStorageRef(String urlOrPath) {
    if (urlOrPath.isEmpty) return null;
    if (urlOrPath.startsWith('gs://')) {
      try {
        return FirebaseStorage.instance.refFromURL(urlOrPath);
      } catch (_) {}
    }
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      if (urlOrPath.contains('firebasestorage.googleapis.com') ||
          urlOrPath.contains('storage.googleapis.com')) {
        try {
          return FirebaseStorage.instance.refFromURL(urlOrPath);
        } catch (_) {
          try {
            final uri = Uri.parse(urlOrPath);
            final segments = uri.pathSegments;
            final oIndex = segments.indexOf('o');
            if (oIndex != -1 && oIndex + 1 < segments.length) {
              final encodedPath = segments.sublist(oIndex + 1).join('/');
              final decodedPath = Uri.decodeComponent(encodedPath);
              return FirebaseStorage.instance.ref(decodedPath);
            }
          } catch (_) {}
        }
      }
    } else {
      final clean =
          urlOrPath.startsWith('/') ? urlOrPath.substring(1) : urlOrPath;
      if (clean.isNotEmpty) {
        return FirebaseStorage.instance.ref(clean);
      }
    }
    return null;
  }

  /// Resolves the fastest direct downloadable stream URL for a given video / quality.
  Future<String> resolveDownloadUrl(
    Video video, {
    required bool isAudioOnly,
    VideoResolutionV2? resolution,
  }) async {
    // 1. Audio-only specific resolutions
    if (isAudioOnly) {
      if (video.audioTracks.isNotEmpty) {
        final track = video.audioTracks.values.firstWhere(
          (t) => t.isNotEmpty && !t.contains('.m3u8') && !t.contains('.mpd'),
          orElse: () => '',
        );
        if (track.isNotEmpty) {
          final ref = _getStorageRef(track);
          if (ref != null) {
            try {
              final signed = await ref.getDownloadURL();
              if (signed.isNotEmpty) return signed;
            } catch (_) {}
          }
          return StorageUtils.getFastDownloadUrl(track);
        }
      }
      if (video.adaptiveResolutions.isNotEmpty) {
        final mp4List = video.adaptiveResolutions
            .where((r) =>
                r.url.isNotEmpty &&
                !r.url.contains('.m3u8') &&
                !r.url.contains('.mpd'))
            .toList()
          ..sort((a, b) => a.height.compareTo(b.height));
        if (mp4List.isNotEmpty) {
          final url = mp4List.first.url;
          final ref = _getStorageRef(url);
          if (ref != null) {
            try {
              final signed = await ref.getDownloadURL();
              if (signed.isNotEmpty) return signed;
            } catch (_) {}
          }
          return StorageUtils.getFastDownloadUrl(url);
        }
      }
    }

    // 2. Explicit resolution provided
    if (resolution != null &&
        resolution.url.isNotEmpty &&
        !resolution.url.contains('.m3u8') &&
        !resolution.url.contains('.mpd')) {
      final ref = _getStorageRef(resolution.url);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (_) {}
      }
      return StorageUtils.getFastDownloadUrl(resolution.url);
    }

    // 3. Check Firestore resolution_jobs variants
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(video.id)
          .getCacheFirst();

      if (doc.exists && doc.data() != null && doc.data()!['variants'] != null) {
        final variants = doc.data()!['variants'] as Map<String, dynamic>;
        for (final entry in variants.entries) {
          final vData = entry.value as Map<String, dynamic>;
          if (vData['status'] == 'completed') {
            final downloadUrl = vData['downloadUrl'] as String?;
            if (downloadUrl != null &&
                downloadUrl.isNotEmpty &&
                !downloadUrl.contains('.m3u8') &&
                !downloadUrl.contains('.mpd')) {
              return downloadUrl;
            }
            final outputPath = vData['outputPath'] as String?;
            if (outputPath != null &&
                outputPath.isNotEmpty &&
                !outputPath.contains('.m3u8') &&
                !outputPath.contains('.mpd')) {
              final ref = _getStorageRef(outputPath);
              if (ref != null) {
                try {
                  final signedUrl = await ref.getDownloadURL();
                  if (signedUrl.isNotEmpty) return signedUrl;
                } catch (_) {}
              }
              return StorageUtils.getFastDownloadUrl(outputPath);
            }
          }
        }
      }
    } catch (_) {}

    // 4. Check video adaptive resolutions
    if (video.adaptiveResolutions.isNotEmpty) {
      final mp4Res = video.adaptiveResolutions
          .where((r) =>
              r.url.isNotEmpty &&
              !r.url.contains('.m3u8') &&
              !r.url.contains('.mpd'))
          .toList();
      if (mp4Res.isNotEmpty) {
        if (isAudioOnly) {
          mp4Res.sort((a, b) => a.height.compareTo(b.height));
        } else {
          mp4Res.sort((a, b) => b.height.compareTo(a.height));
        }
        final url = mp4Res.first.url;
        final ref = _getStorageRef(url);
        if (ref != null) {
          try {
            final signed = await ref.getDownloadURL();
            if (signed.isNotEmpty) return signed;
          } catch (_) {}
        }
        return StorageUtils.getFastDownloadUrl(url);
      }
    }

    // 5. Check video.originalUrl
    if (video.originalUrl.isNotEmpty &&
        !video.originalUrl.contains('.m3u8') &&
        !video.originalUrl.contains('.mpd')) {
      final ref = _getStorageRef(video.originalUrl);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (_) {}
      }
      return StorageUtils.getFastDownloadUrl(video.originalUrl);
    }

    // 6. Check video.videoUrl
    if (video.videoUrl.isNotEmpty &&
        !video.videoUrl.contains('.m3u8') &&
        !video.videoUrl.contains('.mpd')) {
      final ref = _getStorageRef(video.videoUrl);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (_) {}
      }
      return StorageUtils.getFastDownloadUrl(video.videoUrl);
    }

    // 7. Probe Firebase Storage for standard video files
    final probePaths = [
      if (resolution != null && resolution.label.isNotEmpty)
        'videos/${video.id}/${resolution.label.toLowerCase()}.mp4',
      'videos/${video.id}/1080p.mp4',
      'videos/${video.id}/720p.mp4',
      'videos/${video.id}/480p.mp4',
      'videos/${video.id}/360p.mp4',
      'videos/${video.id}/original.mp4',
      'videos/${video.id}/video.mp4',
      'videos/${video.id}.mp4',
    ];
    for (final path in probePaths) {
      try {
        final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
        if (url.isNotEmpty) return url;
      } catch (_) {}
    }

    return '';
  }

  /// Downloads video or audio for offline playback.
  Future<bool> downloadVideoOffline({
    required Video video,
    BuildContext? context,
    VideoResolutionV2? resolution,
    bool isAudioOnly = false,
    Function(double progress)? onProgress,
  }) async {
    if (!_validateDownloadSettings()) return false;

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
        await _downloadWeb(video, targetUrl, offlineVideo, onProgress);
      } else {
        await _downloadNative(video, targetUrl, offlineVideo, onProgress);
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
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      AppSnackbar.show(
        'Download Failed',
        'Could not download: $message',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.85),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
      return false;
    } finally {
      downloadProgressMap.remove(video.id);
      onProgress?.call(0.0);
    }
  }

  /// Direct disk-streamed download pipeline for native platforms (Android / iOS / Desktop)
  Future<void> _downloadNative(
    Video video,
    String targetUrl,
    OfflineVideo offlineVideo,
    Function(double progress)? onProgress,
  ) async {
    final dir = await getOfflineDirectory();
    final ext = offlineVideo.isAudioOnly ? 'mp3' : 'mp4';
    final targetFile = File('${dir.path}/${video.id}.$ext');
    final tempFile = File('${dir.path}/${video.id}.part');

    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    var downloadSucceeded = false;
    var activeUrl = targetUrl;

    // 1. Direct HTTP streaming directly into file sink
    for (var attempt = 0; attempt < 2; attempt++) {
      if (activeUrl.startsWith('gs://')) {
        try {
          activeUrl = await FirebaseStorage.instance
              .refFromURL(activeUrl)
              .getDownloadURL();
        } catch (_) {}
      }

      if (activeUrl.startsWith('http://') || activeUrl.startsWith('https://')) {
        http.Client? client;
        IOSink? sink;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(activeUrl));
          request.headers['Accept'] = '*/*';
          request.headers['User-Agent'] = 'Truthworld/1.0';

          final streamedResponse = await client.send(request);
          final status = streamedResponse.statusCode;

          if (status == 200 || status == 206) {
            final contentLength = streamedResponse.contentLength ?? 0;
            sink = tempFile.openWrite();
            var receivedBytes = 0;

            await for (final chunk in streamedResponse.stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (contentLength > 0) {
                final prog = (receivedBytes / contentLength).clamp(0.0, 1.0);
                downloadProgressMap[video.id] = prog;
                onProgress?.call(prog);
              }
            }
            await sink.flush();
            await sink.close();
            sink = null;

            if (receivedBytes >= 512) {
              downloadSucceeded = true;
              break;
            }
          } else if (status == 401 || status == 403) {
            // Unauthenticated/expired token: resolve fresh signed token from Firebase Storage
            if (attempt == 0 &&
                (activeUrl.contains('firebasestorage.googleapis.com') ||
                    activeUrl.contains('storage.googleapis.com'))) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(activeUrl);
                activeUrl = await ref.getDownloadURL();
                continue;
              } catch (_) {}
            }
          }
        } catch (_) {
          if (sink != null) {
            try {
              await sink.close();
            } catch (_) {}
            sink = null;
          }
        } finally {
          client?.close();
        }
      }
    }

    // 2. Fallback: Firebase Storage SDK writeToFile (Direct stream to disk, no 10MB RAM cap)
    if (!downloadSucceeded) {
      try {
        Reference? storageRef;
        if (targetUrl.startsWith('gs://') ||
            targetUrl.startsWith('https://firebasestorage.googleapis.com') ||
            targetUrl.startsWith('https://storage.googleapis.com')) {
          try {
            storageRef = FirebaseStorage.instance.refFromURL(targetUrl);
          } catch (_) {}
        }

        if (storageRef == null) {
          final probePaths = [
            'videos/${video.id}/1080p.mp4',
            'videos/${video.id}/720p.mp4',
            'videos/${video.id}/480p.mp4',
            'videos/${video.id}/360p.mp4',
            'videos/${video.id}/original.mp4',
            'videos/${video.id}/video.mp4',
            'videos/${video.id}.mp4',
          ];
          for (final path in probePaths) {
            try {
              final testRef = FirebaseStorage.instance.ref(path);
              await testRef.getMetadata();
              storageRef = testRef;
              break;
            } catch (_) {}
          }
        }

        if (storageRef != null) {
          final downloadTask = storageRef.writeToFile(tempFile);
          downloadTask.snapshotEvents.listen((event) {
            if (event.totalBytes > 0) {
              final prog =
                  (event.bytesTransferred / event.totalBytes).clamp(0.0, 1.0);
              downloadProgressMap[video.id] = prog;
              onProgress?.call(prog);
            }
          });
          await downloadTask;
          if (await tempFile.exists() && (await tempFile.length()) >= 512) {
            downloadSucceeded = true;
          }
        }
      } catch (_) {}
    }

    if (!downloadSucceeded ||
        !(await tempFile.exists()) ||
        (await tempFile.length()) < 512) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      throw Exception('Media stream download failed or is too small.');
    }

    // Check for M3U8 text playlist header '#EXTM3U'
    final headerBytes =
        await tempFile.openRead(0, 7).expand((e) => e).take(7).toList();
    if (headerBytes.length >= 7 &&
        headerBytes[0] == 0x23 &&
        headerBytes[1] == 0x45 &&
        headerBytes[2] == 0x58 &&
        headerBytes[3] == 0x54 &&
        headerBytes[4] == 0x4D &&
        headerBytes[5] == 0x33 &&
        headerBytes[6] == 0x55) {
      await tempFile.delete();
      throw Exception('Stream URL is an HLS playlist rather than raw media.');
    }

    // Encrypt downloaded raw media into .twenc container
    final encryptedTargetFile = File('${dir.path}/${video.id}.twenc');
    final tempEncryptedFile = File('${dir.path}/${video.id}.twenc.tmp');

    if (await tempEncryptedFile.exists()) {
      try {
        await tempEncryptedFile.delete();
      } catch (_) {}
    }

    await MediaCryptoService.instance.encryptFile(
      tempFile,
      tempEncryptedFile,
      isAudio: offlineVideo.isAudioOnly,
    );

    if (await encryptedTargetFile.exists()) {
      await encryptedTargetFile.delete();
    }
    await tempEncryptedFile.rename(encryptedTargetFile.path);

    // Securely delete plaintext temp file and any legacy files
    try {
      await tempFile.delete();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (_) {}

    await saveOfflineVideoMetadata(video.id, offlineVideo);
  }

  /// Web platform download pipeline (buffers via BytesBuilder and persists to IndexedDB)
  Future<void> _downloadWeb(
    Video video,
    String targetUrl,
    OfflineVideo offlineVideo,
    Function(double progress)? onProgress,
  ) async {
    Uint8List? fileBytes;
    var activeUrl = targetUrl;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (activeUrl.startsWith('gs://')) {
        try {
          activeUrl = await FirebaseStorage.instance
              .refFromURL(activeUrl)
              .getDownloadURL();
        } catch (_) {}
      }

      if (activeUrl.startsWith('http://') || activeUrl.startsWith('https://')) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(activeUrl));
          request.headers['Accept'] = '*/*';

          final streamedResponse = await client.send(request);
          final status = streamedResponse.statusCode;

          if (status == 200 || status == 206) {
            final contentLength = streamedResponse.contentLength ?? 0;
            final builder = BytesBuilder(copy: false);
            var received = 0;

            await for (final chunk in streamedResponse.stream) {
              builder.add(chunk);
              received += chunk.length;
              if (contentLength > 0) {
                final prog = (received / contentLength).clamp(0.0, 1.0);
                downloadProgressMap[video.id] = prog;
                onProgress?.call(prog);
              }
            }
            if (received >= 512) {
              fileBytes = builder.toBytes();
              break;
            }
          } else if (status == 401 || status == 403) {
            if (attempt == 0 &&
                (activeUrl.contains('firebasestorage.googleapis.com') ||
                    activeUrl.contains('storage.googleapis.com'))) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(activeUrl);
                activeUrl = await ref.getDownloadURL();
                continue;
              } catch (_) {}
            }
          }
        } catch (_) {} finally {
          client?.close();
        }
      }
    }

    // Web Fallback: Firebase Storage SDK getData with 500 MB maximum size cap
    if (fileBytes == null || fileBytes.length < 512) {
      try {
        Reference? storageRef;
        if (targetUrl.startsWith('gs://') ||
            targetUrl.startsWith('https://firebasestorage.googleapis.com') ||
            targetUrl.startsWith('https://storage.googleapis.com')) {
          try {
            storageRef = FirebaseStorage.instance.refFromURL(targetUrl);
          } catch (_) {}
        }
        if (storageRef == null) {
          final probePaths = [
            'videos/${video.id}/1080p.mp4',
            'videos/${video.id}/720p.mp4',
            'videos/${video.id}/480p.mp4',
            'videos/${video.id}/360p.mp4',
            'videos/${video.id}/original.mp4',
            'videos/${video.id}/video.mp4',
            'videos/${video.id}.mp4',
          ];
          for (final path in probePaths) {
            try {
              final testRef = FirebaseStorage.instance.ref(path);
              await testRef.getMetadata();
              storageRef = testRef;
              break;
            } catch (_) {}
          }
        }

        if (storageRef != null) {
          fileBytes = await storageRef.getData(500 * 1024 * 1024);
        }
      } catch (_) {}
    }

    if (fileBytes == null || fileBytes.length < 512) {
      throw Exception('Media stream download failed or is too small.');
    }

    if (fileBytes.length >= 7 &&
        fileBytes[0] == 0x23 &&
        fileBytes[1] == 0x45 &&
        fileBytes[2] == 0x58 &&
        fileBytes[3] == 0x54 &&
        fileBytes[4] == 0x4D &&
        fileBytes[5] == 0x33 &&
        fileBytes[6] == 0x55) {
      throw Exception('Stream URL is an HLS playlist rather than raw media.');
    }

    await saveOfflineVideoBytes(video.id, fileBytes, offlineVideo);
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
  /// Shows all available video resolutions and audio only mode.
  void showDownloadQualityDialog(
    BuildContext? context,
    Video video, {
    Function(VideoResolutionV2 resolution)? onResolutionSelected,
    VoidCallback? onAudioSelected,
  }) {
    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) return;
    showModalBottomSheet(
      context: targetContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: FutureBuilder<List<VideoResolutionV2>>(
            future: getAvailableResolutionsForVideo(video),
            builder: (context, snapshot) {
              final resolutions = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.download_for_offline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Download Quality',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else ...[
                      // Resolutions List
                      ...resolutions.map((res) {
                        final badgeText = _getResolutionBadge(res.label, res.height);
                        return ListTile(
                          leading: const Icon(
                            Icons.video_file_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          title: Row(
                            children: [
                              Text(
                                res.label,
                                style: GoogleFonts.roboto(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (badgeText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Save video for offline viewing',
                            style: GoogleFonts.roboto(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            if (onResolutionSelected != null) {
                              onResolutionSelected(res);
                            } else {
                              downloadVideoOffline(
                                video: video,
                                resolution: res,
                              );
                            }
                          },
                        );
                      }),

                      // Audio Only Tile
                      ListTile(
                        leading: const Icon(
                          Icons.headphones_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'Audio only',
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Save audio for offline listening (saves storage & data)',
                          style: GoogleFonts.roboto(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Audio only',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          if (onAudioSelected != null) {
                            onAudioSelected();
                          } else {
                            downloadAudioOffline(
                              video: video,
                            );
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getResolutionBadge(String label, int height) {
    if (label.contains('1080') || height >= 1080) return 'Full HD';
    if (label.contains('720') || height >= 720) return 'HD';
    if (label.contains('480') || height >= 480) return 'SD';
    if (label.contains('360') || height >= 360) return 'Medium';
    if (label.contains('240') || height >= 240) return 'Low';
    if (label.contains('144') || height >= 144) return 'Data Saver';
    return '';
  }
}

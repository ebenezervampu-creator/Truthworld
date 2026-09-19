import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Manager for discovering and resolving available video playback and download resolutions.
class DownloadResolutionManager {
  /// Discovers all available resolutions for a given video.
  /// Checks resolution_jobs variants, video.adaptiveResolutions, and provides standard tiers.
  static Future<List<VideoResolutionV2>> getAvailableResolutionsForVideo(
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
                      inferHeightFromLabel(label),
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
                  } catch (e, s) {
                    ErrorHandler.log(
                      e,
                      stackTrace: s,
                      tag: 'DownloadResolutionManager.getAvailableResolutions.getDownloadURL',
                    );
                    downloadUrl = StorageUtils.getFastDownloadUrl(outputPath);
                  }
                  return VideoResolutionV2(
                    label: label,
                    url: downloadUrl,
                    width: (variantData['width'] as num?)?.toInt() ?? 0,
                    height: (variantData['height'] as num?)?.toInt() ??
                        inferHeightFromLabel(label),
                    bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                  );
                } catch (e, s) {
                  ErrorHandler.log(
                    e,
                    stackTrace: s,
                    tag: 'DownloadResolutionManager.getAvailableResolutions.fetchTask',
                  );
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadResolutionManager.getAvailableResolutions.transcoding',
      );
    }

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
                height: inferHeightFromLabel(label),
                bitrate: 0,
              ),
            );
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadResolutionManager.getAvailableResolutions.probePaths',
          );
        }
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

  /// Parses numeric height from resolution labels (e.g. "1080p" -> 1080).
  static int inferHeightFromLabel(String label) {
    final clean = label.replaceAll(RegExp('[^0-9]'), '');
    return int.tryParse(clean) ?? 720;
  }

  /// Returns user-friendly badge text for resolution chips.
  static String getResolutionBadge(String label, int height) {
    if (label.contains('1080') || height >= 1080) return 'Full HD';
    if (label.contains('720') || height >= 720) return 'HD';
    if (label.contains('480') || height >= 480) return 'SD';
    if (label.contains('360') || height >= 360) return 'Medium';
    if (label.contains('240') || height >= 240) return 'Low';
    if (label.contains('144') || height >= 144) return 'Data Saver';
    return '';
  }
}

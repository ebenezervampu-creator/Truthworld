import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Service for resolving direct download URLs and Firebase Storage references for media streams.
class DownloadUrlResolver {
  /// Extracts a reliable Firebase Storage Reference from any path or URL format.
  static Reference? getStorageRef(String urlOrPath) {
    return StorageUtils.getStorageRef(urlOrPath);
  }

  /// Resolves the fastest direct downloadable stream URL for a given video / quality.
  static Future<String> resolveDownloadUrl(
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
          final ref = getStorageRef(track);
          if (ref != null) {
            try {
              final signed = await ref.getDownloadURL();
              if (signed.isNotEmpty) return signed;
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DownloadUrlResolver.resolveDownloadUrl.audioTrackSigned',
              );
            }
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
          final ref = getStorageRef(url);
          if (ref != null) {
            try {
              final signed = await ref.getDownloadURL();
              if (signed.isNotEmpty) return signed;
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'DownloadUrlResolver.resolveDownloadUrl.adaptiveSigned',
              );
            }
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
      final ref = getStorageRef(resolution.url);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadUrlResolver.resolveDownloadUrl.resolutionSigned',
          );
        }
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
              final ref = getStorageRef(outputPath);
              if (ref != null) {
                try {
                  final signedUrl = await ref.getDownloadURL();
                  if (signedUrl.isNotEmpty) return signedUrl;
                } catch (e, s) {
                  ErrorHandler.log(
                    e,
                    stackTrace: s,
                    tag: 'DownloadUrlResolver.resolveDownloadUrl.outputPathSigned',
                  );
                }
              }
              return StorageUtils.getFastDownloadUrl(outputPath);
            }
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadUrlResolver.resolveDownloadUrl.resolutionJobs',
      );
    }

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
        final ref = getStorageRef(url);
        if (ref != null) {
          try {
            final signed = await ref.getDownloadURL();
            if (signed.isNotEmpty) return signed;
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DownloadUrlResolver.resolveDownloadUrl.mp4ResSigned',
            );
          }
        }
        return StorageUtils.getFastDownloadUrl(url);
      }
    }

    // 5. Check video.originalUrl
    if (video.originalUrl.isNotEmpty &&
        !video.originalUrl.contains('.m3u8') &&
        !video.originalUrl.contains('.mpd')) {
      final ref = getStorageRef(video.originalUrl);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadUrlResolver.resolveDownloadUrl.originalUrlSigned',
          );
        }
      }
      return StorageUtils.getFastDownloadUrl(video.originalUrl);
    }

    // 6. Check video.videoUrl
    if (video.videoUrl.isNotEmpty &&
        !video.videoUrl.contains('.m3u8') &&
        !video.videoUrl.contains('.mpd')) {
      final ref = getStorageRef(video.videoUrl);
      if (ref != null) {
        try {
          final signed = await ref.getDownloadURL();
          if (signed.isNotEmpty) return signed;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'DownloadUrlResolver.resolveDownloadUrl.videoUrlSigned',
          );
        }
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
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DownloadUrlResolver.resolveDownloadUrl.probePaths',
        );
      }
    }

    return '';
  }
}

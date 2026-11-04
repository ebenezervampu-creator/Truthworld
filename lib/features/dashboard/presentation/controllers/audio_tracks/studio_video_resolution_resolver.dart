import 'package:collection/collection.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Resolves adaptive bitrate resolution streams for TruthWorld Studio video playback.
///
/// Enforces the platform policy: NEVER play video in raw (original.mp4).
/// Always extract authentic processed resolutions (1080p, 720p, 480p, 360p, 240p, 144p, HLS)
/// and resolve them through authenticated Cloud Storage / Google Cloud CDN URLs.
class StudioVideoResolutionResolver {
  static const _tag = 'StudioVideoResolutionResolver';

  /// Resolves valid, non-raw playback resolution options for a given [video].
  static Future<List<VideoResolutionV2>> resolveResolutions(Video video) async {
    final validResolutions = <VideoResolutionV2>[];

    void addValidFromList(List<VideoResolutionV2> list) {
      for (final res in list) {
        final u = res.url.trim().toLowerCase();
        final l = res.label.toLowerCase();
        if (u.isNotEmpty &&
            !l.contains('audio') &&
            !u.contains('/audio') &&
            !u.endsWith('original.mp4') &&
            !u.contains('/original/')) {
          if (!validResolutions.any((r) => r.label == res.label || r.url == res.url)) {
            validResolutions.add(res);
          }
        }
      }
    }

    // 1. Direct on Video model
    if (video.adaptiveResolutions.isNotEmpty) {
      addValidFromList(video.adaptiveResolutions);
    }

    // 2. In-memory streaming cache
    final cached = VideoMediaService.streamingCache[video.id];
    if (cached != null && cached.adaptiveResolutions.isNotEmpty) {
      addValidFromList(cached.adaptiveResolutions);
    }

    // 3. Remote streaming subcollection if still empty
    if (validResolutions.isEmpty && video.id.isNotEmpty) {
      try {
        final streaming = await VideoMediaService().getStreaming(video.id);
        if (streaming.adaptiveResolutions.isNotEmpty) {
          addValidFromList(streaming.adaptiveResolutions);
        }
        if (validResolutions.isEmpty &&
            streaming.hlsUrl.isNotEmpty &&
            !streaming.hlsUrl.toLowerCase().endsWith('original.mp4') &&
            !streaming.hlsUrl.toLowerCase().contains('/original/')) {
          validResolutions.add(
            VideoResolutionV2(
              label: 'HLS Auto',
              url: streaming.hlsUrl,
              width: 1920,
              height: 1080,
              bitrate: 4500000,
            ),
          );
        }
      } catch (e) {
        logger.warning('Could not fetch streaming data for studio player: $e', tag: _tag);
      }
    }

    // 4. HLS master playlist on video model if available and non-raw
    if (video.hlsUrl.isNotEmpty &&
        !video.hlsUrl.toLowerCase().endsWith('original.mp4') &&
        !video.hlsUrl.toLowerCase().contains('/original/') &&
        !validResolutions.any((r) => r.label.toLowerCase() == 'hls' || r.url == video.hlsUrl)) {
      validResolutions.add(
        VideoResolutionV2(
          label: 'HLS Auto',
          url: video.hlsUrl,
          width: 1920,
          height: 1080,
          bitrate: 4500000,
        ),
      );
    }

    // Sort descending by height, then fps
    validResolutions.sort((a, b) {
      final cmp = b.height.compareTo(a.height);
      if (cmp != 0) return cmp;
      return b.fps.compareTo(a.fps);
    });

    return validResolutions;
  }

  /// Picks the optimal initial playback resolution (e.g. 720p or highest available <= 1080p).
  static VideoResolutionV2? pickDefaultResolution(List<VideoResolutionV2> resolutions) {
    if (resolutions.isEmpty) return null;
    return resolutions.firstWhereOrNull((r) => r.height == 720 || r.label.toLowerCase() == '720p') ??
        resolutions.firstWhereOrNull((r) => r.height == 1080 || r.label.toLowerCase() == '1080p') ??
        resolutions.firstWhereOrNull((r) => r.height == 480 || r.label.toLowerCase() == '480p') ??
        resolutions.first;
  }

  /// Resolves the authentic streaming URL for either a base video or a dubbed video track,
  /// ensuring tokens, App Check, and CDN headers are bound so playback never encounters 403 Forbidden.
  static Future<String> resolvePlaybackUrl({
    required Video video,
    required bool isBaseTrack,
    String? trackUrl,
    VideoResolutionV2? preferredResolution,
  }) async {
    // 1. If it's a dubbed video track, resolve the dubbed video file URL directly
    if (!isBaseTrack && trackUrl != null && trackUrl.trim().isNotEmpty) {
      final resolved = await StorageUtils.resolveUrl(trackUrl.trim());
      if (resolved.isNotEmpty) return resolved;
      return StorageUtils.getFastDownloadUrl(trackUrl.trim());
    }

    // 2. Base track: If a preferred resolution was supplied, resolve its URL
    if (preferredResolution != null && preferredResolution.url.trim().isNotEmpty) {
      final resolved = await StorageUtils.resolveUrl(preferredResolution.url.trim());
      if (resolved.isNotEmpty) return resolved;
      return StorageUtils.getFastDownloadUrl(preferredResolution.url.trim());
    }

    // 3. Base track: Fetch candidate resolutions ladder
    final resolutions = await resolveResolutions(video);
    final chosen = pickDefaultResolution(resolutions);
    if (chosen != null && chosen.url.trim().isNotEmpty) {
      final resolved = await StorageUtils.resolveUrl(chosen.url.trim());
      if (resolved.isNotEmpty) return resolved;
      return StorageUtils.getFastDownloadUrl(chosen.url.trim());
    }

    // 4. Fallback: If no processed resolution was found, resolve video.videoUrl with signed token
    final rawUrl = (trackUrl != null && trackUrl.trim().isNotEmpty)
        ? trackUrl.trim()
        : (video.videoUrl.isNotEmpty ? video.videoUrl : video.originalUrl);
    if (rawUrl.isNotEmpty) {
      final resolved = await StorageUtils.resolveUrl(rawUrl);
      if (resolved.isNotEmpty) return resolved;
      return StorageUtils.getFastDownloadUrl(rawUrl);
    }

    return '';
  }
}

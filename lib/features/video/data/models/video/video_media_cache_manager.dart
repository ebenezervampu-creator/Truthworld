import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video/video_resolutions.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Helper for populating [VideoMediaService] static caches during video model hydration.
class VideoMediaCacheManager {
  const VideoMediaCacheManager._();

  /// Populates localization, credibility, and streaming static caches for a video ID.
  static void populateCaches({
    required String id,
    required String originalUrl,
    required String hlsUrl,
    required String dashUrl,
    required List<VideoResolutionV2> adaptiveResolutions,
    required List<String> thumbnailVariants,
    required String animatedPreviewUrl,
    required double trustScore,
    required String? trustLabel,
    Map<String, String>? mediaSubtitles,
    Map<String, String>? dubbedVideos,
    Map<String, String>? audioTracks,
    List<VideoChapter>? chapters,
    String? factCheckUrl,
    String? transcriptionUrl,
    ScoringFactors? scoringFactors,
    List<TrustDeduction>? deductions,
    List<ContextualFlag>? contextualFlags,
    HonestyBreakdown? honestyBreakdown,
    bool? harmCapApplied,
    String? harmCapReason,
    Map<String, double>? categoryWeightProfile,
    List<String>? confidenceNotes,
    List<String>? diagnostics,
    FactCheckStats? factCheckStats,
    String? videoCategory,
    HardeningMetadata? hardeningMetadata,
    double? intentToMisleadScore,
    UIReport? uiReport,
  }) {
    if (id.isEmpty) return;

    // 1. Localization cache
    if ((mediaSubtitles != null && mediaSubtitles.isNotEmpty) ||
        (dubbedVideos != null && dubbedVideos.isNotEmpty) ||
        (audioTracks != null && audioTracks.isNotEmpty)) {
      VideoMediaService.localizationCache[id] = VideoMediaLocalization(
        subtitles: mediaSubtitles ?? const {},
        dubbedVideos: dubbedVideos ?? const {},
        audioTracks: audioTracks ?? const {},
      );
    }

    // 2. Credibility cache
    if (scoringFactors != null ||
        deductions != null ||
        contextualFlags != null ||
        (factCheckUrl != null && factCheckUrl.isNotEmpty) ||
        (transcriptionUrl != null && transcriptionUrl.isNotEmpty)) {
      VideoMediaService.credibilityCache[id] = VideoMediaCredibility(
        trustScore: trustScore,
        trustLabel: trustLabel,
        scoringFactors: scoringFactors,
        deductions: deductions ?? const [],
        contextualFlags: contextualFlags ?? const [],
        honestyBreakdown: honestyBreakdown,
        harmCapApplied: harmCapApplied ?? false,
        harmCapReason: harmCapReason,
        categoryWeightProfile: categoryWeightProfile,
        confidenceNotes: confidenceNotes ?? const [],
        diagnostics: diagnostics ?? const [],
        factCheckStats: factCheckStats,
        videoCategory: videoCategory,
        hardeningMetadata: hardeningMetadata,
        intentToMisleadScore: intentToMisleadScore,
        uiReport: uiReport,
        factCheckUrl: factCheckUrl ?? '',
        transcriptionUrl: transcriptionUrl ?? '',
      );
    }

    // 3. Streaming cache
    if (chapters != null) {
      VideoMediaService.streamingCache[id] = VideoMediaStreaming(
        originalUrl: originalUrl,
        hlsUrl: hlsUrl,
        dashUrl: dashUrl,
        adaptiveResolutions: adaptiveResolutions,
        thumbnailVariants: thumbnailVariants,
        animatedPreviewUrl: animatedPreviewUrl,
        chapters: chapters,
      );
    }
  }
}

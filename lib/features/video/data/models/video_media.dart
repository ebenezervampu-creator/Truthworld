// ==========================================================================
// VIDEO MEDIA SUBCOLLECTION MODELS — YouTube-Style Document Splitting
// ==========================================================================
//
// These models represent data stored in subcollections under each video:
//   videos/{videoId}/media/localization  — subtitles, dubbing, audio tracks
//   videos/{videoId}/media/credibility   — full credibility report data
//   videos/{videoId}/media/streaming     — streaming URLs, resolutions
//
// This prevents the main video document from exceeding Firestore's 1 MiB limit
// by offloading heavy, rarely-needed metadata to separate documents.
// ==========================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';

/// Localization data stored at: videos/{videoId}/media/localization
/// Contains subtitle URLs, dubbed video URLs, audio track URLs, and multi-video commentary tracks.
/// Kept separate because this grows with every supported language (130+).
class VideoMediaLocalization {
  const VideoMediaLocalization({
    this.subtitles = const {},
    this.dubbedVideos = const {},
    this.audioTracks = const {},
    this.commentaryVideos = const {},
    this.updatedAt,
  });

  factory VideoMediaLocalization.fromMap(Map<String, dynamic> data) {
    return VideoMediaLocalization(
      subtitles: _castStringMap(data['subtitles']),
      dubbedVideos: _castStringMap(data['dubbedVideos']),
      audioTracks: _castStringMap(data['audioTracks']),
      commentaryVideos: _castCommentaryMap(data['commentaryVideos']),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
  final Map<String, String> subtitles; // { langCode: downloadUrl }
  final Map<String, String> dubbedVideos; // { langCode: downloadUrl }
  final Map<String, String> audioTracks; // { langCode: downloadUrl }
  final Map<String, Map<String, String>>
  commentaryVideos; // { trackId: {title, role, videoUrl, audioUrl, langCode} }
  final Timestamp? updatedAt;

  Map<String, dynamic> toMap() => {
    'subtitles': subtitles,
    'dubbedVideos': dubbedVideos,
    'audioTracks': audioTracks,
    'commentaryVideos': commentaryVideos,
    'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
  };

  static Map<String, String> _castStringMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return Map<String, String>.from(
        value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      );
    }
    return {};
  }

  static Map<String, Map<String, String>> _castCommentaryMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      final res = <String, Map<String, String>>{};
      value.forEach((k, v) {
        if (v is Map) {
          res[k.toString()] = Map<String, String>.from(
            v.map(
              (innerK, innerV) =>
                  MapEntry(innerK.toString(), innerV?.toString() ?? ''),
            ),
          );
        }
      });
      return res;
    }
    return {};
  }

  bool get isEmpty =>
      subtitles.isEmpty &&
      dubbedVideos.isEmpty &&
      audioTracks.isEmpty &&
      commentaryVideos.isEmpty;
}

/// Credibility data stored at: videos/{videoId}/media/credibility
/// Contains full epistemic scoring, claims, deductions, hardening metadata.
/// This is the largest payload — can be 50-100KB for detailed reports.
class VideoMediaCredibility {
  const VideoMediaCredibility({
    this.trustScore = 0.0,
    this.trustLabel,
    this.summary = '',
    this.scoringFactors,
    this.deductions = const [],
    this.contextualFlags = const [],
    this.honestyBreakdown,
    this.harmCapApplied = false,
    this.harmCapReason,
    this.categoryWeightProfile,
    this.confidenceNotes = const [],
    this.diagnostics = const [],
    this.factCheckStats,
    this.videoCategory,
    this.effectiveCategory,
    this.hardeningMetadata,
    this.intentToMisleadScore,
    this.uiReport,
    this.factCheckUrl = '',
    this.transcriptionUrl = '',
    this.updatedAt,
  });

  factory VideoMediaCredibility.fromMap(Map<String, dynamic> data) {
    final rawTrustScore = data['trustScore'] ??
        data['trustIndex'] ??
        data['score'] ??
        data['videoRating'] ??
        0;
    final trustScore = (rawTrustScore is num) ? rawTrustScore.toDouble() : 0.0;
    final trustLabel =
        (data['trustLabel'] ?? data['label'] ?? data['state'])?.toString();
    final summary = (data['summary'] ??
            data['viewerNote'] ??
            data['narrative'] ??
            data['uiReport']?['narrative'] ??
            '')
        .toString();

    final rawFactors = data['scoringFactors'] ?? data['factors'];
    final scoringFactors = rawFactors != null && rawFactors is Map
        ? ScoringFactors.fromMap(Map<String, dynamic>.from(rawFactors))
        : null;

    final rawUiReport = data['uiReport'] != null
        ? UIReport.fromMap(Map<String, dynamic>.from(data['uiReport']))
        : (data.containsKey('claims') ||
                data.containsKey('viewerNote') ||
                data.containsKey('narrative') ||
                data.containsKey('keyClaims'))
            ? UIReport.fromMap(data)
            : null;

    return VideoMediaCredibility(
      trustScore: trustScore,
      trustLabel: trustLabel,
      summary: summary,
      scoringFactors: scoringFactors,
      deductions: (data['deductions'] as List? ?? [])
          .map((e) => TrustDeduction.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      contextualFlags: (data['contextualFlags'] as List? ?? [])
          .map((e) => ContextualFlag.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      honestyBreakdown: data['honestyBreakdown'] != null
          ? HonestyBreakdown.fromMap(
              Map<String, dynamic>.from(data['honestyBreakdown']),
            )
          : null,
      harmCapApplied: data['harmCapApplied'] ?? false,
      harmCapReason: data['harmCapReason'],
      categoryWeightProfile: data['categoryWeightProfile'] != null
          ? Map<String, double>.from(
              data['categoryWeightProfile'].map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            )
          : null,
      confidenceNotes: List<String>.from(data['confidenceNotes'] ?? []),
      diagnostics: List<String>.from(data['diagnostics'] ?? []),
      factCheckStats: data['factCheckStats'] != null
          ? FactCheckStats.fromMap(
              Map<String, dynamic>.from(data['factCheckStats']),
            )
          : null,
      videoCategory: data['videoCategory'],
      effectiveCategory: data['effectiveCategory'],
      hardeningMetadata: data['hardeningMetadata'] != null
          ? HardeningMetadata.fromMap(
              Map<String, dynamic>.from(data['hardeningMetadata']),
            )
          : null,
      intentToMisleadScore: (data['intentToMisleadScore'] ?? 0).toDouble(),
      uiReport: rawUiReport,
      factCheckUrl: (data['media'] is Map &&
              data['media']['factCheckUrl'] != null &&
              (data['media']['factCheckUrl'] as String).isNotEmpty)
          ? (data['media']['factCheckUrl'] as String)
          : (data['factCheckUrl'] ?? ''),
      transcriptionUrl: (data['media'] is Map &&
              data['media']['transcriptionUrl'] != null &&
              (data['media']['transcriptionUrl'] as String).isNotEmpty)
          ? (data['media']['transcriptionUrl'] as String)
          : (data['transcriptionUrl'] ?? ''),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
  // Core scores (also duplicated as summary on main doc for card display)
  final double trustScore;
  final String? trustLabel;
  final String summary;

  // v8.0 Epistemic Scoring
  final ScoringFactors? scoringFactors;
  final List<TrustDeduction> deductions;
  final List<ContextualFlag> contextualFlags;
  final HonestyBreakdown? honestyBreakdown;
  final bool harmCapApplied;
  final String? harmCapReason;
  final Map<String, double>? categoryWeightProfile;
  final List<String> confidenceNotes;
  final List<String> diagnostics;
  final FactCheckStats? factCheckStats;
  final String? videoCategory;
  final String? effectiveCategory;

  // v8.1 Hardened Trust
  final HardeningMetadata? hardeningMetadata;
  final double? intentToMisleadScore;

  // Full UI Report (biggest nested object)
  final UIReport? uiReport;

  // References to Cloud Storage for raw reports
  final String factCheckUrl;
  final String transcriptionUrl;

  final Timestamp? updatedAt;

  Map<String, dynamic> toMap() => {
    'trustScore': trustScore,
    'trustLabel': trustLabel,
    'scoringFactors': scoringFactors?.toMap(),
    'deductions': deductions.map((e) => e.toMap()).toList(),
    'contextualFlags': contextualFlags.map((e) => e.toMap()).toList(),
    'honestyBreakdown': honestyBreakdown?.toMap(),
    'harmCapApplied': harmCapApplied,
    'harmCapReason': harmCapReason,
    'categoryWeightProfile': categoryWeightProfile,
    'confidenceNotes': confidenceNotes,
    'diagnostics': diagnostics,
    'factCheckStats': factCheckStats?.toMap(),
    'videoCategory': videoCategory,
    'effectiveCategory': effectiveCategory,
    'hardeningMetadata': hardeningMetadata?.toMap(),
    'intentToMisleadScore': intentToMisleadScore,
    'uiReport': uiReport?.toMap(),
    'factCheckUrl': factCheckUrl,
    'transcriptionUrl': transcriptionUrl,
    'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
  };
}

/// Streaming data stored at: videos/{videoId}/media/streaming
/// Contains resolution URLs, preview assets, and full description.
class VideoMediaStreaming {
  const VideoMediaStreaming({
    this.originalUrl = '',
    this.hlsUrl = '',
    this.dashUrl = '',
    this.adaptiveResolutions = const [],
    this.thumbnailVariants = const [],
    this.animatedPreviewUrl = '',
    this.fullDescription = '',
    this.chapters = const [],
    this.updatedAt,
  });

  factory VideoMediaStreaming.fromMap(Map<String, dynamic> data) {
    return VideoMediaStreaming(
      originalUrl: data['originalUrl'] ?? '',
      hlsUrl: data['hlsUrl'] ?? '',
      dashUrl: data['dashUrl'] ?? '',
      adaptiveResolutions: (data['adaptiveResolutions'] as List? ?? [])
          .map((e) => VideoResolutionV2.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      thumbnailVariants: List<String>.from(data['thumbnailVariants'] ?? []),
      animatedPreviewUrl: data['animatedPreviewUrl'] ?? '',
      fullDescription: data['fullDescription'] ?? '',
      chapters: (data['chapters'] as List? ?? [])
          .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
  final String originalUrl;
  final String hlsUrl;
  final String dashUrl;
  final List<VideoResolutionV2> adaptiveResolutions;
  final List<String> thumbnailVariants;
  final String animatedPreviewUrl;
  final String fullDescription; // Full description (main doc truncated to 500)
  final List<VideoChapter> chapters;
  final Timestamp? updatedAt;

  Map<String, dynamic> toMap() => {
    'originalUrl': originalUrl,
    'hlsUrl': hlsUrl,
    'dashUrl': dashUrl,
    'adaptiveResolutions': adaptiveResolutions.map((e) => e.toMap()).toList(),
    'thumbnailVariants': thumbnailVariants,
    'animatedPreviewUrl': animatedPreviewUrl,
    'fullDescription': fullDescription,
    'chapters': chapters.map((e) => e.toMap()).toList(),
    'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
  };
}

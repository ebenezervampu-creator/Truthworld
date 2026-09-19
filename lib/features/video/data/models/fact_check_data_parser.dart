import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Strongly typed and normalized representation of fact-check data.
///
/// Consolidates fallback resolution for fields such as trust scores,
/// labels, confidence values, claims, and sources across all presentation surfaces.
class ParsedFactCheckData {
  const ParsedFactCheckData({
    required this.trustScore,
    required this.normalizedScore,
    required this.trustLabel,
    required this.confidenceVal,
    required this.confidenceTier,
    required this.analysisState,
    required this.viewerNote,
    required this.claims,
    required this.claimResults,
    required this.sources,
    required this.parsedSources,
    required this.factors,
    required this.chapters,
    required this.verifiedCount,
    required this.cautionCount,
    required this.falseCount,
    required this.isDisputed,
    required this.isCaution,
    required this.isLowTrust,
    required this.needsUrgency,
    required this.scoreColor,
    required this.urgencyColor,
    required this.scoreAvailable,
    this.isProvisional = false,
  });

  /// An empty state instance when no fact check data is present.
  static const empty = ParsedFactCheckData(
    trustScore: null,
    normalizedScore: null,
    trustLabel: 'ANALYZED',
    confidenceVal: 0.0,
    confidenceTier: '',
    analysisState: 'ANALYZED',
    viewerNote: '',
    claims: [],
    claimResults: [],
    sources: [],
    parsedSources: [],
    factors: {},
    chapters: [],
    verifiedCount: 0,
    cautionCount: 0,
    falseCount: 0,
    isDisputed: false,
    isCaution: false,
    isLowTrust: false,
    needsUrgency: false,
    scoreColor: AppColors.success,
    urgencyColor: AppColors.success,
    scoreAvailable: false,
  );

  final double? trustScore;
  final double? normalizedScore;
  final String trustLabel;
  final double confidenceVal;
  final String confidenceTier;
  final String analysisState;
  final String viewerNote;
  final List<Map<String, dynamic>> claims;
  final List<ClaimResult> claimResults;
  final List<dynamic> sources;
  final List<UISource> parsedSources;
  final Map<String, dynamic> factors;
  final List<dynamic> chapters;
  final int verifiedCount;
  final int cautionCount;
  final int falseCount;
  final bool isDisputed;
  final bool isCaution;
  final bool isLowTrust;
  final bool needsUrgency;
  final Color scoreColor;
  final Color urgencyColor;
  final bool scoreAvailable;
  final bool isProvisional;

  bool get isEmpty =>
      trustScore == null &&
      claims.isEmpty &&
      sources.isEmpty &&
      viewerNote.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

/// Canonical parser for raw fact-check and credibility JSON maps.
class FactCheckDataParser {
  FactCheckDataParser._();

  /// Parses raw map data (and optional fallback models) into a unified [ParsedFactCheckData].
  static ParsedFactCheckData parse(
    Map<String, dynamic>? rawData, {
    UIReport? fallbackReport,
    double? fallbackTrustScore,
    bool isVideoFactChecked = false,
  }) {
    if ((rawData == null || rawData.isEmpty) && fallbackReport == null) {
      if (fallbackTrustScore != null && fallbackTrustScore > 0) {
        final norm = fallbackTrustScore > 5
            ? fallbackTrustScore
            : fallbackTrustScore * 20;
        final color = VideoAnalysisHelpers.getScoreColor(norm);
        return ParsedFactCheckData(
          trustScore: fallbackTrustScore,
          normalizedScore: norm,
          trustLabel: VideoAnalysisHelpers.getRatingLabel(fallbackTrustScore),
          confidenceVal: 0.5,
          confidenceTier: 'Medium',
          analysisState: isVideoFactChecked ? 'VERIFIED' : 'ANALYZED',
          viewerNote: '',
          claims: const [],
          claimResults: const [],
          sources: const [],
          parsedSources: const [],
          factors: const {},
          chapters: const [],
          verifiedCount: 0,
          cautionCount: 0,
          falseCount: 0,
          isDisputed: false,
          isCaution: false,
          isLowTrust: norm < 50,
          needsUrgency: norm < 50,
          scoreColor: color,
          urgencyColor: norm < 50 ? AppColors.error : color,
          scoreAvailable: true,
        );
      }
      return ParsedFactCheckData.empty;
    }

    final data = rawData ?? <String, dynamic>{};

    // 1. Analysis State
    final analysisState = (data['analysisState'] ??
            data['state'] ??
            fallbackReport?.summary.analysisState ??
            (isVideoFactChecked ? 'VERIFIED' : 'ANALYZED'))
        .toString();

    final isProvisional = data['isProvisional'] == true ||
        data['credibilityStatus'] == 'provisional_ready';

    // 2. Trust Score
    final rawScore = data['trustScore'] ??
        data['trustIndex'] ??
        data['score'] ??
        data['videoRating'] ??
        data['provisionalScore'] ??
        fallbackReport?.summary.rating ??
        (fallbackTrustScore != null && fallbackTrustScore > 0
            ? fallbackTrustScore
            : null);

    final trustScore = (rawScore is num) ? rawScore.toDouble() : null;
    final normalizedScore = trustScore != null
        ? (trustScore > 5 ? trustScore : trustScore * 20)
        : null;

    // 3. Trust Label
    final trustLabel = (data['trustLabel'] ??
            data['label'] ??
            (fallbackReport?.summary.label.isNotEmpty == true
                ? fallbackReport!.summary.label
                : (trustScore != null
                    ? VideoAnalysisHelpers.getRatingLabel(trustScore)
                    : analysisState)))
        .toString();

    // 4. Confidence
    final confidenceRaw =
        data['confidence'] ?? fallbackReport?.summary.confidence;
    final confidenceTier = (data['confidenceTier'] ??
            (confidenceRaw is String ? confidenceRaw : ''))
        .toString();
    final confidenceVal = (confidenceRaw is num)
        ? (confidenceRaw > 1.0
            ? (confidenceRaw / 100.0)
            : confidenceRaw.toDouble())
        : (confidenceTier.toLowerCase() == 'high'
            ? 0.9
            : (confidenceTier.toLowerCase() == 'medium' ? 0.6 : 0.4));

    // 5. Viewer Note / Narrative
    final viewerNote = (data['viewerNote'] ??
            data['narrative'] ??
            data['summary'] ??
            data['explanation'] ??
            data['provisionalViewerNote'] ??
            data['uiReport']?['narrative'] ??
            fallbackReport?.narrative ??
            '')
        .toString()
        .trim();

    // 6. Chapters
    final chapters = (data['chapters'] as List?) ?? [];

    // 7. Claims
    final rawClaims = (data['claims'] as List?) ??
        (data['uiReport']?['keyClaims'] as List?) ??
        (data['provisionalClaims'] as List?) ??
        [];

    final claimsList = <Map<String, dynamic>>[];
    final claimResultsList = <ClaimResult>[];

    var verifiedCount = 0;
    var cautionCount = 0;
    var falseCount = 0;

    if (rawClaims.isNotEmpty) {
      for (final c in rawClaims) {
        if (c is Map) {
          final claimMap = Map<String, dynamic>.from(c);
          claimsList.add(claimMap);
          claimResultsList.add(ClaimResult.fromMap(claimMap));

          final verdict = ClaimVerdictHelper.resolveVerdict(claimMap);
          if (verdict.isVerified) {
            verifiedCount++;
          } else if (verdict.isFalse) {
            falseCount++;
          } else {
            cautionCount++;
          }
        }
      }
    } else if (fallbackReport != null && fallbackReport.keyClaims.isNotEmpty) {
      for (final cr in fallbackReport.keyClaims) {
        claimResultsList.add(cr);
        claimsList.add(cr.toMap());
        final verdict = ClaimVerdictHelper.resolveVerdict(cr);
        if (verdict.isVerified) {
          verifiedCount++;
        } else if (verdict.isFalse) {
          falseCount++;
        } else {
          cautionCount++;
        }
      }
    }

    // 8. Sources
    final rawSources = (data['sources'] ??
            data['richSources'] ??
            data['uiReport']?['sources'] ??
            fallbackReport?.sources) as List? ??
        [];

    final sourcesList = <dynamic>[];
    final parsedSourcesList = <UISource>[];

    for (final s in rawSources) {
      sourcesList.add(s);
      if (s is UISource) {
        parsedSourcesList.add(s);
      } else if (s is Map) {
        parsedSourcesList.add(UISource.fromMap(Map<String, dynamic>.from(s)));
      } else if (s is String && s.isNotEmpty) {
        parsedSourcesList.add(UISource(
          title: s,
          trustLevel: 'Medium',
          type: 'Supporting',
          url: s.startsWith('http') ? s : null,
        ));
      }
    }

    // 9. Scoring Factors
    final factors = (data['scoringFactors'] ?? data['factors']) as Map? ?? {};
    final factorsMap = Map<String, dynamic>.from(factors);

    // 10. Metrics & urgency computation
    final scoreColor = normalizedScore != null
        ? VideoAnalysisHelpers.getScoreColor(normalizedScore)
        : AppColors.success;

    final isDisputed = falseCount > 0 && falseCount >= verifiedCount;
    final isCaution = !isDisputed && cautionCount > verifiedCount;
    final isLowTrust = normalizedScore != null && normalizedScore < 50;
    final needsUrgency = isDisputed || isLowTrust;

    final urgencyColor = isDisputed
        ? AppColors.error
        : (isCaution ? AppColors.warning : scoreColor);

    final scoreAvailable = data['scoreAvailable'] == true ||
        trustScore != null ||
        claimsList.isNotEmpty;

    return ParsedFactCheckData(
      trustScore: trustScore,
      normalizedScore: normalizedScore,
      trustLabel: trustLabel,
      confidenceVal: confidenceVal,
      confidenceTier: confidenceTier,
      analysisState: analysisState,
      viewerNote: viewerNote,
      claims: claimsList,
      claimResults: claimResultsList,
      sources: sourcesList,
      parsedSources: parsedSourcesList,
      factors: factorsMap,
      chapters: chapters,
      verifiedCount: verifiedCount,
      cautionCount: cautionCount,
      falseCount: falseCount,
      isDisputed: isDisputed,
      isCaution: isCaution,
      isLowTrust: isLowTrust,
      needsUrgency: needsUrgency,
      scoreColor: scoreColor,
      urgencyColor: urgencyColor,
      scoreAvailable: scoreAvailable,
      isProvisional: isProvisional,
    );
  }
}

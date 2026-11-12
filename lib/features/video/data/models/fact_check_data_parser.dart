import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
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
    this.summary = '',
    this.conclusion = '',
    this.conclusionSources = const [],
    this.isProvisional = false,
    this.factCheckTier = 'standard',
    this.isVideoFactChecked = false,
  });

  /// An empty state instance when no fact check data is present.
  static const empty = ParsedFactCheckData(
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
  );
  final String trustLabel;
  final double confidenceVal;
  final String confidenceTier;
  final String analysisState;
  final String viewerNote;
  final String summary;
  final String conclusion;
  final List<UISource> conclusionSources;
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
  final bool isProvisional;
  final String factCheckTier;
  final bool isVideoFactChecked;

  bool get isShortOverview => factCheckTier == 'short';
  bool get isFullGround =>
      factCheckTier == 'full_ground' ||
      factCheckTier == 'fullground' ||
      factCheckTier == 'ground';
  bool get isStandardTier => !isShortOverview && !isFullGround;

  String get tierBadgeLabel {
    if (isShortOverview) return 'SHORT FACT-CHECK • OVERVIEW';
    if (isFullGround) return 'FULL GROUND FACT-CHECK • ALL CLAIMS VERIFIED';
    return 'VERIFIED FACT-CHECK';
  }

  bool get isEmpty {
    if (claims.isNotEmpty ||
        sources.isNotEmpty ||
        viewerNote.isNotEmpty ||
        conclusion.isNotEmpty) {
      return false;
    }
    if (isVideoFactChecked) {
      return false;
    }
    return true;
  }

  bool get isNotEmpty => !isEmpty;
}

/// Canonical parser for raw fact-check and credibility JSON maps.
class FactCheckDataParser {
  FactCheckDataParser._();

  /// Detects whether a string is an interim or provisional pipeline placeholder
  /// (e.g. background synthesis in progress) rather than a final verified conclusion.
  static bool isPlaceholderStatus(String? text) {
    if (text == null || text.trim().isEmpty) return true;
    final lower = text.trim().toLowerCase();
    return lower.contains('overview is being generated') ||
        lower.contains('overview synthesis is finalizing') ||
        lower.contains('finalizing in the background') ||
        lower.contains('checking the facts in this video right now') ||
        lower.contains('individual claim verdicts are already ready') ||
        lower.contains('claim verdicts are complete and available now') ||
        lower.contains('synthesis is finalizing');
  }

  /// Parses raw map data (and optional fallback models) into a unified [ParsedFactCheckData].
  static ParsedFactCheckData parse(
    Map<String, dynamic>? rawData, {
    UIReport? fallbackReport,
    bool isVideoFactChecked = false,
  }) {
    if ((rawData == null || rawData.isEmpty) && fallbackReport == null) {
      if (isVideoFactChecked) {
        return ParsedFactCheckData(
          trustLabel: 'VERIFIED',
          confidenceVal: 0.85,
          confidenceTier: 'High',
          analysisState: 'VERIFIED',
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
          isLowTrust: false,
          needsUrgency: false,
          scoreColor: AppColors.success,
          urgencyColor: AppColors.success,
          isVideoFactChecked: true,
          conclusion: 'Truth verification complete. No verifiable empirical assertions evaluated.',
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

    // 2. Trust Label
    final trustLabel = (data['trustLabel'] ??
            data['label'] ??
            (fallbackReport?.summary.label.isNotEmpty == true
                ? fallbackReport!.summary.label
                : analysisState))
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

    // 5. Summary / Viewer Note / Narrative / Conclusion
    final rawSummary = (data['summary'] ??
            data['overview'] ??
            data['aiFeatures']?['factCheckSummary'] ??
            data['uiReport']?['summary']?['narrative'] ??
            '')
        .toString()
        .trim();
    final cleanSummary = UserFeedbackSanitizer.sanitizeViewerNote(rawSummary);

    final rawDataConclusion = data['conclusion'];
    final dataConclusionText = rawDataConclusion is Map
        ? (rawDataConclusion['text'] ?? rawDataConclusion['summary'] ?? '').toString()
        : (rawDataConclusion is String ? rawDataConclusion : '');

    final rawViewerNote = (data['viewerNote'] ??
            data['narrative'] ??
            data['explanation'] ??
            data['provisionalViewerNote'] ??
            data['uiReport']?['narrative'] ??
            (dataConclusionText.isNotEmpty ? dataConclusionText : null) ??
            fallbackReport?.narrative ??
            fallbackReport?.riskNote ??
            '')
        .toString()
        .trim();
    final viewerNote = UserFeedbackSanitizer.sanitizeViewerNote(rawViewerNote);

    final rawConclusion = data['conclusion'] ??
        data['uiReport']?['conclusion'] ??
        fallbackReport?.conclusion;
    final conclusionText = rawConclusion is Map
        ? (rawConclusion['text'] ?? rawConclusion['summary'] ?? '').toString()
        : (rawConclusion is String ? rawConclusion : (rawConclusion ?? '').toString());
    final cleanConclusion = ClaimVerdictHelper.humanizeConclusionText(
      UserFeedbackSanitizer.sanitizeViewerNote(conclusionText),
    ).trim();

    // 6. Chapters
    final chapters = (data['chapters'] as List?) ?? [];

    // 7. Claims
    final rawClaims = (data['claims'] as List?) ??
        (data['keyClaims'] as List?) ??
        (data['uiReport']?['keyClaims'] as List?) ??
        (data['uiReport']?['claims'] as List?) ??
        (data['evaluatedClaims'] as List?) ??
        (data['extractedClaims'] as List?) ??
        (data['provisionalClaims'] as List?) ??
        (data['analysis'] is Map ? (data['analysis']['claims'] as List?) : null) ??
        (data['result'] is Map ? (data['result']['claims'] as List?) : null) ??
        (fallbackReport?.keyClaims.isNotEmpty == true ? fallbackReport!.keyClaims : null) ??
        [];

    final claimsList = <Map<String, dynamic>>[];
    final claimResultsList = <ClaimResult>[];

    var verifiedCount = 0;
    var cautionCount = 0;
    var falseCount = 0;

    for (final c in rawClaims) {
      Map<String, dynamic>? claimMap;
      ClaimResult? claimResult;

      if (c is ClaimResult) {
        claimResult = c;
        claimMap = c.toMap();
      } else if (c is Map) {
        claimMap = Map<String, dynamic>.from(c);
        claimResult = ClaimResult.fromMap(claimMap);
      }

      if (claimMap != null && claimResult != null) {
        final text = claimResult.text.isNotEmpty
            ? claimResult.text
            : (claimMap['claim'] ?? claimMap['text'] ?? claimMap['statement'] ?? '').toString();
        claimMap['claim'] = text;
        claimMap['text'] = text;

        final verdict = ClaimVerdictHelper.resolveVerdict(claimMap);
        final rawVerdictStr = claimResult.verdict.isNotEmpty ? claimResult.verdict : verdict.label;
        claimMap['verdict'] = rawVerdictStr;
        claimMap['status'] = claimMap['status'] ?? rawVerdictStr;
        claimMap['verificationStatus'] = claimMap['verificationStatus'] ?? rawVerdictStr;
        claimMap['isVerified'] = verdict.isVerified;
        claimMap['isFalse'] = verdict.isFalse;
        claimMap['isCaution'] = verdict.isCaution;

        var aiExplanation = '';
        if (claimResult.verdictBasis != null && claimResult.verdictBasis!.isNotEmpty) {
          aiExplanation = claimResult.verdictBasis!.join('\n\n');
        } else {
          final rawExpl = (claimMap['response'] ??
                  claimMap['reasoning'] ??
                  claimMap['whyWrong'] ??
                  claimMap['explanation'] ??
                  claimMap['correction'] ??
                  claimMap['verificationSummary'] ??
                  claimMap['details'] ??
                  claimMap['analysis'] ??
                  claimMap['context'] ??
                  claimMap['note'] ??
                  '')
              .toString()
              .trim();
          if (rawExpl.isNotEmpty) {
            aiExplanation = rawExpl;
          } else {
            aiExplanation = verdict.summaryTakeaway;
          }
        }
        claimMap['response'] = aiExplanation;
        claimMap['reasoning'] = aiExplanation;
        claimMap['explanation'] = aiExplanation;
        claimMap['verdictBasis'] = [aiExplanation];

        final effectiveSources = <Map<dynamic, dynamic>>[];
        final rawEffSources = claimResult.effectiveSources.isNotEmpty
            ? claimResult.effectiveSources.map((s) => s.toMap()).toList()
            : (claimMap['sources'] ??
                claimMap['effectiveSources'] ??
                claimMap['richSources'] ??
                claimMap['evidence'] ??
                claimMap['citations'] ??
                []);
        if (rawEffSources is List) {
          for (final s in rawEffSources) {
            if (!SourceUrlSanitizer.isValidSource(s)) continue;
            if (s is UISource) {
              effectiveSources.add(SourceUrlSanitizer.sanitizeSourceMap(s.toMap()));
            } else if (s is Map) {
              effectiveSources.add(SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s)));
            } else if (s is String && s.trim().isNotEmpty) {
              final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
              effectiveSources.add({
                'title': s.trim(),
                'url': clean ?? '',
                'directUrl': clean ?? '',
                'domain': SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
                'trustLevel': 'Medium',
                'type': 'Supporting',
              });
            }
          }
        }
        claimMap['sources'] = effectiveSources;
        claimMap['effectiveSources'] = effectiveSources;

        claimsList.add(claimMap);
        claimResultsList.add(claimResult);

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
            data['citations'] ??
            data['uiReport']?['sources'] ??
            data['uiReport']?['richSources'] ??
            fallbackReport?.sources) as List? ??
        [];

    final sourcesList = <dynamic>[];
    final parsedSourcesList = <UISource>[];

    for (final s in rawSources) {
      if (!SourceUrlSanitizer.isValidSource(s)) continue;
      if (s is UISource) {
        final sanitizedMap = SourceUrlSanitizer.sanitizeSourceMap(s.toMap());
        sourcesList.add(sanitizedMap);
        parsedSourcesList.add(UISource.fromMap(Map<String, dynamic>.from(sanitizedMap)));
      } else if (s is Map) {
        final sanitizedMap = SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s));
        final strMap = Map<String, dynamic>.from(sanitizedMap);
        sourcesList.add(strMap);
        parsedSourcesList.add(UISource.fromMap(strMap));
      } else if (s is String && s.trim().isNotEmpty) {
        final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
        final uiSrc = UISource(
          title: s.trim(),
          trustLevel: 'Medium',
          type: 'Supporting',
          url: clean,
          domain: SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
        );
        sourcesList.add(uiSrc.toMap());
        parsedSourcesList.add(uiSrc);
      }
    }

    // 8.1 Fallback aggregation: If top-level sources are empty, aggregate distinct sources from claims!
    if (parsedSourcesList.isEmpty && claimsList.isNotEmpty) {
      final seenKeys = <String>{};

      for (final c in claimsList) {
        final cSources = c['sources'] ??
            c['effectiveSources'] ??
            c['richSources'] ??
            c['citations'] ??
            c['evidence'] ??
            c['references'];
        if (cSources is List) {
          for (final s in cSources) {
            if (!SourceUrlSanitizer.isValidSource(s)) continue;
            UISource? parsedSource;
            Map<String, dynamic>? sourceMap;

            if (s is UISource) {
              sourceMap = Map<String, dynamic>.from(SourceUrlSanitizer.sanitizeSourceMap(s.toMap()));
              parsedSource = UISource.fromMap(sourceMap);
            } else if (s is Map) {
              sourceMap = Map<String, dynamic>.from(SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s)));
              parsedSource = UISource.fromMap(sourceMap);
            } else if (s is String && s.trim().isNotEmpty) {
              final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
              parsedSource = UISource(
                title: s.trim(),
                trustLevel: 'Medium',
                type: 'Supporting',
                url: clean,
                domain: SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
              );
              sourceMap = parsedSource.toMap();
            }

            if (parsedSource != null && sourceMap != null) {
              final key = (parsedSource.url != null && parsedSource.url!.isNotEmpty)
                  ? parsedSource.url!.toLowerCase()
                  : parsedSource.title.toLowerCase();
              if (key.isNotEmpty && !seenKeys.contains(key)) {
                seenKeys.add(key);
                parsedSourcesList.add(parsedSource);
                sourcesList.add(sourceMap);
              }
            }
          }
        }
      }
    }

    // 8.2 Conclusion Sources: Extract specific conclusion sources from conclusion or conclusionSources
    final rawConclusionSources = (rawConclusion is Map && rawConclusion['sources'] is List
            ? rawConclusion['sources'] as List
            : null) ??
        (data['conclusionSources'] as List?) ??
        (data['uiReport']?['conclusionSources'] as List?) ??
        (fallbackReport?.conclusionSources.isNotEmpty == true ? fallbackReport!.conclusionSources : null);

    final parsedConclusionSources = <UISource>[];
    if (rawConclusionSources != null && rawConclusionSources.isNotEmpty) {
      for (final s in rawConclusionSources) {
        if (!SourceUrlSanitizer.isValidSource(s)) continue;
        if (s is UISource) {
          parsedConclusionSources.add(s);
        } else if (s is Map) {
          final sanitized = SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s));
          parsedConclusionSources.add(UISource.fromMap(Map<String, dynamic>.from(sanitized)));
        } else if (s is String && s.trim().isNotEmpty) {
          final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
          parsedConclusionSources.add(UISource(
            title: s.trim(),
            trustLevel: 'Medium',
            type: 'Supporting',
            url: clean,
            domain: SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
          ));
        }
      }
    }

    // 8.3 Include distinct conclusion sources in sources list if not already present
    if (parsedConclusionSources.isNotEmpty) {
      final existingKeys = <String>{};
      for (final s in parsedSourcesList) {
        final key = (s.url != null && s.url!.isNotEmpty)
            ? s.url!.toLowerCase()
            : s.title.toLowerCase();
        if (key.isNotEmpty) existingKeys.add(key);
      }
      for (final s in parsedConclusionSources) {
        final key = (s.url != null && s.url!.isNotEmpty)
            ? s.url!.toLowerCase()
            : s.title.toLowerCase();
        if (!existingKeys.contains(key)) {
          existingKeys.add(key);
          sourcesList.add(s.toMap());
          parsedSourcesList.add(s);
        }
      }
    }

    // 9. Scoring Factors
    final factors = (data['scoringFactors'] ?? data['factors']) as Map? ?? {};
    final factorsMap = Map<String, dynamic>.from(factors);

    // 10. Metrics & urgency computation
    final isDisputed = falseCount > 0 && falseCount >= verifiedCount;
    final isCaution = !isDisputed && cautionCount > verifiedCount;
    final isLowTrust = isDisputed;
    final needsUrgency = isDisputed || isCaution;

    final scoreColor = isDisputed
        ? AppColors.error
        : (isCaution ? AppColors.warning : AppColors.success);

    final urgencyColor = isDisputed
        ? AppColors.error
        : (isCaution ? AppColors.warning : scoreColor);

    // 10.1 Synthesize conclusion if raw conclusion was a placeholder, empty, or formulaic
    var finalConclusion = cleanConclusion;
    final isGenericFormula = finalConclusion.toLowerCase().startsWith('based on ') &&
        finalConclusion.toLowerCase().contains('empirical claims evaluated');
    if (isPlaceholderStatus(finalConclusion) || isGenericFormula || finalConclusion.isEmpty) {
      if (claimsList.isNotEmpty) {
        finalConclusion = ClaimVerdictHelper.buildCompleteVideoConclusion(
          rawConclusion: finalConclusion,
          summary: cleanSummary,
          videoTitle: (data['title'] ?? data['videoTitle'] ?? '').toString(),
          claims: claimsList,
          verifiedCount: verifiedCount,
          cautionCount: cautionCount,
          falseCount: falseCount,
        );
      } else {
        finalConclusion = '';
      }
    }

    return ParsedFactCheckData(
      trustLabel: trustLabel,
      confidenceVal: confidenceVal,
      confidenceTier: confidenceTier,
      analysisState: analysisState,
      viewerNote: viewerNote,
      summary: cleanSummary,
      conclusion: finalConclusion,
      conclusionSources: parsedConclusionSources,
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
      isProvisional: isProvisional,
      isVideoFactChecked: isVideoFactChecked,
      factCheckTier: (data['factCheckTier'] ??
              (data['aiFeatures'] is Map ? data['aiFeatures']['factCheckTier'] : null) ??
              (data['media'] is Map ? data['media']['factCheckTier'] : null) ??
              data['tier'] ??
              data['synthesisTier'] ??
              'standard')
          .toString(),
    );
  }
}

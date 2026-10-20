/// 🎯 CREDIBILITY REPORT MODELS (v8.0 — Epistemic Trust Engine)
///
/// Maps the multidimensional credibility data from the backend to Flutter.
/// Used for the "Credibility Nutrition Label" UI.
library;

import 'package:truthworld/core/utils/source_url_sanitizer.dart';

class ScoringFactors {
  ScoringFactors({
    required this.accuracy,
    required this.evidence,
    required this.consensus,
    required this.consistency,
    required this.integrity,
    required this.expertise,
    required this.freshness,
    required this.safety,
    required this.honesty,
  });

  factory ScoringFactors.fromMap(Map<String, dynamic> map) {
    return ScoringFactors(
      accuracy: (map['accuracy'] ?? 0).toDouble(),
      evidence: (map['evidence'] ?? 0).toDouble(),
      consensus: (map['consensus'] ?? 0).toDouble(),
      consistency: (map['consistency'] ?? 0).toDouble(),
      integrity: (map['integrity'] ?? 0).toDouble(),
      expertise: (map['expertise'] ?? 0).toDouble(),
      freshness: (map['freshness'] ?? 0).toDouble(),
      safety: (map['safety'] ?? 0).toDouble(),
      honesty: (map['honesty'] ?? 0).toDouble(),
    );
  }
  final double accuracy;
  final double evidence;
  final double consensus;
  final double consistency;
  final double integrity;
  final double expertise;
  final double freshness;
  final double safety;
  final double honesty;

  Map<String, dynamic> toMap() => {
    'accuracy': accuracy,
    'evidence': evidence,
    'consensus': consensus,
    'consistency': consistency,
    'integrity': integrity,
    'expertise': expertise,
    'freshness': freshness,
    'safety': safety,
    'honesty': honesty,
  };
}

class HonestyBreakdown {
  HonestyBreakdown({
    required this.score,
    required this.opinionLabeledOpinion,
    required this.beliefLabeledBelief,
    required this.beliefPresentedAsFact,
    required this.opinionPresentedAsFact,
    required this.speculationLabeledSpeculation,
    required this.assertivenessMismatchPenalty,
  });

  factory HonestyBreakdown.fromMap(Map<String, dynamic> map) {
    return HonestyBreakdown(
      score: (map['score'] ?? 0).toDouble(),
      opinionLabeledOpinion: map['opinionLabeledOpinion'] ?? 0,
      beliefLabeledBelief: map['beliefLabeledBelief'] ?? 0,
      beliefPresentedAsFact: map['beliefPresentedAsFact'] ?? 0,
      opinionPresentedAsFact: map['opinionPresentedAsFact'] ?? 0,
      speculationLabeledSpeculation: map['speculationLabeledSpeculation'] ?? 0,
      assertivenessMismatchPenalty: (map['assertivenessMismatchPenalty'] ?? 0)
          .toDouble(),
    );
  }
  final double score;
  final int opinionLabeledOpinion;
  final int beliefLabeledBelief;
  final int beliefPresentedAsFact;
  final int opinionPresentedAsFact;
  final int speculationLabeledSpeculation;
  final double assertivenessMismatchPenalty;

  Map<String, dynamic> toMap() => {
    'score': score,
    'opinionLabeledOpinion': opinionLabeledOpinion,
    'beliefLabeledBelief': beliefLabeledBelief,
    'beliefPresentedAsFact': beliefPresentedAsFact,
    'opinionPresentedAsFact': opinionPresentedAsFact,
    'speculationLabeledSpeculation': speculationLabeledSpeculation,
    'assertivenessMismatchPenalty': assertivenessMismatchPenalty,
  };
}

class ContextualFlag {
  ContextualFlag({
    required this.topic,
    required this.claimText,
    required this.perspectives,
    required this.aiNote,
  });

  factory ContextualFlag.fromMap(Map<String, dynamic> map) {
    return ContextualFlag(
      topic: map['topic'] ?? '',
      claimText: map['claimText'] ?? '',
      perspectives: (map['perspectives'] as List? ?? [])
          .map((p) => Perspective.fromMap(p))
          .toList(),
      aiNote: map['aiNote'] ?? '',
    );
  }
  final String topic;
  final String claimText;
  final List<Perspective> perspectives;
  final String aiNote;

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'claimText': claimText,
    'perspectives': perspectives.map((p) => p.toMap()).toList(),
    'aiNote': aiNote,
  };
}

class Perspective {
  Perspective({
    required this.label,
    required this.explanation,
    required this.sources,
  });

  factory Perspective.fromMap(Map<String, dynamic> map) {
    return Perspective(
      label: map['label'] ?? '',
      explanation: map['explanation'] ?? '',
      sources: List<String>.from(map['sources'] ?? []),
    );
  }
  final String label;
  final String explanation;
  final List<String> sources;

  Map<String, dynamic> toMap() => {
    'label': label,
    'explanation': explanation,
    'sources': sources,
  };
}

class TrustDeduction {
  TrustDeduction({
    required this.factor,
    required this.points,
    required this.reason,
  });

  factory TrustDeduction.fromMap(Map<String, dynamic> map) {
    return TrustDeduction(
      factor: map['factor'] ?? '',
      points: (map['points'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
    );
  }
  final String factor;
  final double points;
  final String reason;

  Map<String, dynamic> toMap() => {
    'factor': factor,
    'points': points,
    'reason': reason,
  };
}

class FactCheckStats {
  FactCheckStats({
    required this.totalClaims,
    required this.correct,
    required this.incorrect,
    required this.unverifiable,
  });

  factory FactCheckStats.fromMap(Map<String, dynamic> map) {
    return FactCheckStats(
      totalClaims: map['totalClaims'] ?? 0,
      correct: map['correct'] ?? 0,
      incorrect: map['incorrect'] ?? 0,
      unverifiable: map['unverifiable'] ?? 0,
    );
  }
  final int totalClaims;
  final int correct;
  final int incorrect;
  final int unverifiable;

  Map<String, dynamic> toMap() => {
    'totalClaims': totalClaims,
    'correct': correct,
    'incorrect': incorrect,
    'unverifiable': unverifiable,
  };
}

/// 🏛 VERIFIABLE CLAIM LEDGER (Industry Standard)
///
/// Replaces arbitrary, deceptive scalar scores with an objective claim-by-claim ledger.
class ClaimLedgerSummary {
  const ClaimLedgerSummary({
    required this.totalClaimsChecked,
    required this.confirmedCount,
    required this.disputedCount,
    required this.unprovenCount,
    required this.falseCount,
    required this.contextualCount,
    required this.highestSeverityVerdict,
    required this.verdictHeadline,
    this.priorityNotice,
    this.verifiableRatio = 0.0,
  });

  factory ClaimLedgerSummary.fromMap(Map<String, dynamic> map) {
    return ClaimLedgerSummary(
      totalClaimsChecked: (map['totalClaimsChecked'] ?? 0) as int,
      confirmedCount: (map['confirmedCount'] ?? 0) as int,
      disputedCount: (map['disputedCount'] ?? 0) as int,
      unprovenCount: (map['unprovenCount'] ?? 0) as int,
      falseCount: (map['falseCount'] ?? 0) as int,
      contextualCount: (map['contextualCount'] ?? 0) as int,
      highestSeverityVerdict: (map['highestSeverityVerdict'] ?? 'none').toString(),
      verdictHeadline: (map['verdictHeadline'] ?? '').toString(),
      priorityNotice: map['priorityNotice']?.toString(),
      verifiableRatio: (map['verifiableRatio'] is num)
          ? (map['verifiableRatio'] as num).toDouble()
          : 0.0,
    );
  }

  final int totalClaimsChecked;
  final int confirmedCount;
  final int disputedCount;
  final int unprovenCount;
  final int falseCount;
  final int contextualCount;
  final String highestSeverityVerdict;
  final String verdictHeadline;
  final String? priorityNotice;
  final double verifiableRatio;

  bool get hasHighSeverityIssues => falseCount > 0 || disputedCount > 0;

  Map<String, dynamic> toMap() => {
    'totalClaimsChecked': totalClaimsChecked,
    'confirmedCount': confirmedCount,
    'disputedCount': disputedCount,
    'unprovenCount': unprovenCount,
    'falseCount': falseCount,
    'contextualCount': contextualCount,
    'highestSeverityVerdict': highestSeverityVerdict,
    'verdictHeadline': verdictHeadline,
    'priorityNotice': priorityNotice,
    'verifiableRatio': verifiableRatio,
  };
}

class HardeningMetadata {
  HardeningMetadata({
    required this.truthFloorApplied,
    required this.consensusGateTriggered,
    required this.intentToMisleadScore,
    required this.penalties,
    required this.auditTimestamp,
    this.truthFloorReason,
    this.domainOverride,
  });

  factory HardeningMetadata.fromMap(Map<String, dynamic> map) {
    return HardeningMetadata(
      truthFloorApplied: map['truthFloorApplied'] ?? false,
      truthFloorReason: map['truthFloorReason'],
      domainOverride: map['domainOverride'] != null
          ? DomainOverride.fromMap(map['domainOverride'])
          : null,
      consensusGateTriggered: map['consensusGateTriggered'] ?? false,
      intentToMisleadScore: (map['intentToMisleadScore'] ?? 0).toDouble(),
      penalties: List<Map<String, dynamic>>.from(map['penalties'] ?? []),
      auditTimestamp: map['auditTimestamp'] ?? '',
    );
  }
  final bool truthFloorApplied;
  final String? truthFloorReason;
  final DomainOverride? domainOverride;
  final bool consensusGateTriggered;
  final double intentToMisleadScore;
  final List<Map<String, dynamic>> penalties;
  final String auditTimestamp;

  Map<String, dynamic> toMap() => {
    'truthFloorApplied': truthFloorApplied,
    'truthFloorReason': truthFloorReason,
    'domainOverride': domainOverride?.toMap(),
    'consensusGateTriggered': consensusGateTriggered,
    'intentToMisleadScore': intentToMisleadScore,
    'penalties': penalties,
    'auditTimestamp': auditTimestamp,
  };
}

class DomainOverride {
  DomainOverride({
    required this.triggered,
    required this.penalty,
    required this.riskDelta,
    this.from,
    this.to,
  });

  factory DomainOverride.fromMap(Map<String, dynamic> map) {
    return DomainOverride(
      triggered: map['triggered'] ?? false,
      from: map['from'],
      to: map['to'],
      penalty: (map['penalty'] ?? 0).toDouble(),
      riskDelta: (map['riskDelta'] ?? 0).toDouble(),
    );
  }
  final bool triggered;
  final String? from;
  final String? to;
  final double penalty;
  final double riskDelta;

  Map<String, dynamic> toMap() => {
    'triggered': triggered,
    'from': from,
    'to': to,
    'penalty': penalty,
    'riskDelta': riskDelta,
  };
}

class UIDriver {
  // 'high' | 'medium'

  UIDriver({required this.text, required this.impact});

  factory UIDriver.fromMap(Map<String, dynamic> map) {
    return UIDriver(
      text: map['text'] ?? '',
      impact: map['impact'] ?? 'medium',
    );
  }
  final String text;
  final String impact;

  Map<String, dynamic> toMap() => {
    'text': text,
    'impact': impact,
  };
}

class UISource {
  UISource({
    required this.title,
    required this.trustLevel,
    required this.type,
    this.url,
    this.domain,
    this.citationCount = 0,
    this.snippet,
    this.retrievalProvider,
    this.publisher,
    this.publishedAt,
    this.avatarUrl,
  });

  factory UISource.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] ??
            map['author'] ??
            map['domain'] ??
            map['bookTitle'] ??
            map['journalName'] ??
            'Source Citation')
        .toString();
    final rawUrl =
        (map['url'] ?? map['directUrl'] ?? map['link'])?.toString();
    final rawDomain = map['domain']?.toString();
    final publisher = (map['publisher'] ?? map['author'] ?? map['organization'])?.toString();
    final publishedAt = (map['publishedAt'] ??
            map['publishDate'] ??
            map['date'] ??
            map['lastPublished'] ??
            map['timestamp'])
        ?.toString();
    final avatarUrl = (map['avatarUrl'] ?? map['logoUrl'] ?? map['iconUrl'])?.toString();

    final sanitizedUrl = rawUrl != null
        ? SourceUrlSanitizer.sanitizeUrl(
            rawUrl,
            title: title,
            publisher: publisher,
            domain: rawDomain,
          )
        : null;
    final url = sanitizedUrl ??
        SourceUrlSanitizer.resolveFallbackUrl(
          domain: rawDomain,
          publisher: publisher,
          title: title,
        );

    final candidateHost = (rawUrl != null && !SourceUrlSanitizer.isGroundingRedirect(rawUrl))
        ? Uri.tryParse(rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl')
            ?.host
            .replaceFirst(RegExp(r'^www\.'), '')
        : null;
    final domain = (SourceUrlSanitizer.isValidDomain(rawDomain) ? rawDomain : null) ??
        (SourceUrlSanitizer.isValidDomain(candidateHost) ? candidateHost : null) ??
        SourceUrlSanitizer.resolveDisplayDomain(
          url ?? rawUrl,
          title: title,
          explicitDomain: rawDomain,
          publisher: publisher,
        );
    final trustLevel =
        (map['trustLevel'] ?? map['trust'] ?? 'Medium').toString();
    final type =
        (map['sourceType'] ?? map['type'] ?? 'Secondary').toString();

    return UISource(
      title: title,
      url: url,
      domain: domain,
      trustLevel: trustLevel,
      type: type,
      citationCount: (map['citationCount'] as num?)?.toInt() ?? 0,
      snippet:
          (map['snippet'] ?? map['quote'] ?? map['provenance'])?.toString(),
      retrievalProvider: map['retrievalProvider']?.toString(),
      publisher: publisher,
      publishedAt: publishedAt,
      avatarUrl: avatarUrl,
    );
  }
  final String title;
  final String? url;
  final String? domain;
  final String trustLevel; // 'High' | 'Medium' | 'Low'
  final String type; // 'Primary' | 'Secondary' | 'Supporting'
  final int citationCount;
  final String? snippet;
  final String? retrievalProvider;
  final String? publisher;
  final String? publishedAt;
  final String? avatarUrl;

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'domain': domain,
    'trustLevel': trustLevel,
    'type': type,
    'citationCount': citationCount,
    'snippet': snippet,
    'retrievalProvider': retrievalProvider,
    'publisher': publisher,
    'publishedAt': publishedAt,
    'avatarUrl': avatarUrl,
  };
}

class UIEvidence {
  UIEvidence({required this.type, required this.strength});

  factory UIEvidence.fromMap(Map<String, dynamic> map) => UIEvidence(
    type: map['type'] ?? '',
    strength: map['strength'] ?? '',
  );
  final String type;
  final String strength;

  Map<String, dynamic> toMap() => {
    'type': type,
    'strength': strength,
  };
}

class UIConsensus {
  UIConsensus({required this.domain, required this.level});

  factory UIConsensus.fromMap(Map<String, dynamic> map) => UIConsensus(
    domain: map['domain'] ?? '',
    level: map['level'] ?? '',
  );
  final String domain;
  final String level;

  Map<String, dynamic> toMap() => {
    'domain': domain,
    'level': level,
  };
}

class ClaimResult {
  ClaimResult({
    required this.text,
    required this.verdict,
    this.start,
    this.end,
    this.isLowRiskTrivia,
    this.effectiveSources = const [],
    this.classificationConfidence,
    this.historicalEvidenceConfidence,
    this.evidenceDetails,
    this.consensusDetails,
    this.claimDomain,
    this.claimNature,
    this.verdictBasis,
    this.evidence,
    this.consensus,
    this.multiModelConsensus,
    this.isAppealed,
    this.appealStatus,
  });

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    final rawText = (map['text'] ??
            map['claim'] ??
            map['statement'] ??
            map['cleanText'] ??
            '')
        .toString();
    final rawVerdict = (map['verdict'] ??
            map['status'] ??
            map['verificationStatus'] ??
            'unverified')
        .toString();

    double? startVal;
    if (map['startMs'] is num) {
      startVal = (map['startMs'] as num).toDouble() / 1000.0;
    } else if (map['startTimeMs'] is num) {
      startVal = (map['startTimeMs'] as num).toDouble() / 1000.0;
    } else if (map['start'] is num) {
      final s = (map['start'] as num).toDouble();
      startVal = s > 100000 ? s / 1000.0 : s;
    } else if (map['timestampStart'] is num) {
      final s = (map['timestampStart'] as num).toDouble();
      startVal = s > 100000 ? s / 1000.0 : s;
    } else if (map['startTime'] is num) {
      final s = (map['startTime'] as num).toDouble();
      startVal = s > 100000 ? s / 1000.0 : s;
    }

    double? endVal;
    if (map['endMs'] is num) {
      endVal = (map['endMs'] as num).toDouble() / 1000.0;
    } else if (map['endTimeMs'] is num) {
      endVal = (map['endTimeMs'] as num).toDouble() / 1000.0;
    } else if (map['end'] is num) {
      final e = (map['end'] as num).toDouble();
      endVal = e > 100000 ? e / 1000.0 : e;
    } else if (map['timestampEnd'] is num) {
      final e = (map['timestampEnd'] as num).toDouble();
      endVal = e > 100000 ? e / 1000.0 : e;
    } else if (map['endTime'] is num) {
      final e = (map['endTime'] as num).toDouble();
      endVal = e > 100000 ? e / 1000.0 : e;
    }

    final rawSources = map['effectiveSources'] ??
        map['richSources'] ??
        map['sources'] ??
        map['citations'];
    final sourcesList = <UISource>[];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (!SourceUrlSanitizer.isValidSource(s)) continue;
        if (s is Map) {
          sourcesList.add(
            UISource.fromMap(Map<String, dynamic>.from(s)),
          );
        } else if (s is String && s.trim().isNotEmpty) {
          final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s) ??
              SourceUrlSanitizer.resolveFallbackUrl(domain: s, title: s);
          final domain = SourceUrlSanitizer.resolveDisplayDomain(clean ?? s, title: s);
          sourcesList.add(
            UISource(
              title: s.trim(),
              trustLevel: 'Medium',
              type: 'Supporting',
              url: clean,
              domain: domain,
            ),
          );
        }
      }
    }

    List<String>? basisList;
    if (map['verdictBasis'] != null) {
      basisList = List<String>.from(map['verdictBasis']);
    } else {
      final reason = (map['response'] ??
              map['reasoning'] ??
              map['whyWrong'] ??
              map['explanation'] ??
              map['verificationSummary'] ??
              '')
          .toString();
      if (reason.isNotEmpty) {
        basisList = [reason];
      }
    }

    return ClaimResult(
      text: rawText,
      verdict: rawVerdict,
      start: startVal,
      end: endVal,
      isLowRiskTrivia: map['isLowRiskTrivia'] as bool?,
      effectiveSources: sourcesList,
      classificationConfidence: (map['classificationConfidence'] as num?)
          ?.toDouble(),
      historicalEvidenceConfidence:
          (map['historicalEvidenceConfidence'] as num?)?.toDouble(),
      evidenceDetails: map['evidenceDetails'] != null
          ? Map<String, String>.from(map['evidenceDetails'])
          : null,
      consensusDetails: map['consensusDetails'] != null
          ? Map<String, String>.from(map['consensusDetails'])
          : null,
      claimDomain: map['claimDomain'],
      claimNature: map['claimNature'],
      verdictBasis: basisList,
      evidence: (map['evidence'] as List?)
          ?.map((e) => UIEvidence.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      consensus: (map['consensus'] as List?)
          ?.map((c) => UIConsensus.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      multiModelConsensus: map['multiModelConsensus'] is Map
          ? Map<String, dynamic>.from(map['multiModelConsensus'])
          : null,
      isAppealed: map['isAppealed'] as bool?,
      appealStatus: map['appealStatus']?.toString(),
    );
  }
  final String text;
  final String verdict;
  final double? start;
  final double? end;
  final bool? isLowRiskTrivia;
  final List<UISource> effectiveSources;

  /// Confidence in the categorization of the claim nature (e.g. 1.0 = 100% sure this is a RELIGIOUS_CLAIM).
  final double? classificationConfidence;

  /// Confidence in the historical/empirical evidence backing the claim (e.g. 0.9 = 90% sure Siddhartha Gautama existed historically).
  final double? historicalEvidenceConfidence;
  final Map<String, String>? evidenceDetails;
  final Map<String, String>? consensusDetails;
  final String? claimDomain;
  final String? claimNature;
  final List<String>? verdictBasis;
  final List<UIEvidence>? evidence;
  final List<UIConsensus>? consensus;
  final Map<String, dynamic>? multiModelConsensus;
  final bool? isAppealed;
  final String? appealStatus;

  Map<String, dynamic> toMap() => {
    'text': text,
    'verdict': verdict,
    'start': start,
    'end': end,
    'isLowRiskTrivia': isLowRiskTrivia,
    'effectiveSources': effectiveSources.map((s) => s.toMap()).toList(),
    'classificationConfidence': classificationConfidence,
    'historicalEvidenceConfidence': historicalEvidenceConfidence,
    'evidenceDetails': evidenceDetails,
    'consensusDetails': consensusDetails,
    'claimDomain': claimDomain,
    'claimNature': claimNature,
    'verdictBasis': verdictBasis,
    'evidence': evidence?.map((e) => e.toMap()).toList(),
    'consensus': consensus?.map((c) => c.toMap()).toList(),
    'multiModelConsensus': multiModelConsensus,
    'isAppealed': isAppealed,
    'appealStatus': appealStatus,
  };
}

class UISummary {
  UISummary({
    required this.label,
    required this.confidence,
    this.rating,
    this.honestyScore,
    this.rationalityScore,
    this.confidenceInterpretation,
    this.analysisState,
  });

  factory UISummary.fromMap(Map<String, dynamic> map) {
    return UISummary(
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      honestyScore: map['honestyScore'] != null
          ? (map['honestyScore'] as num).toDouble()
          : null,
      rationalityScore: map['rationalityScore'] != null
          ? (map['rationalityScore'] as num).toDouble()
          : null,
      label: map['label'] ?? '',
      confidence: map['confidence'] ?? 'low',
      confidenceInterpretation: map['confidenceInterpretation'],
      analysisState: map['analysisState'],
    );
  }
  final double? rating;
  final double? honestyScore;
  final double? rationalityScore;
  final String label;
  final String confidence;
  final String? confidenceInterpretation;
  final String? analysisState;

  Map<String, dynamic> toMap() => {
    'rating': rating,
    'honestyScore': honestyScore,
    'rationalityScore': rationalityScore,
    'label': label,
    'confidence': confidence,
    'confidenceInterpretation': confidenceInterpretation,
    'analysisState': analysisState,
  };
}

class UIReport {
  UIReport({
    required this.summary,
    required this.quickVerdict,
    required this.narrative,
    required this.riskNote,
    required this.positiveDrivers,
    required this.negativeDrivers,
    required this.sources,
    required this.conclusion,
    this.conclusionSources = const [],
    this.counterSignals = const [],
    this.reviewRequestEnabled = true,
    this.keyClaims = const [],
    this.claimLedger,
  });

  factory UIReport.fromMap(Map<String, dynamic> map) {
    final summaryMap = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'])
        : <String, dynamic>{};
    if (!summaryMap.containsKey('rating') && map.containsKey('trustScore')) {
      summaryMap['rating'] = map['trustScore'];
    }
    if (!summaryMap.containsKey('label') && map.containsKey('trustLabel')) {
      summaryMap['label'] = map['trustLabel'];
    }
    if (!summaryMap.containsKey('confidence') && map.containsKey('confidence')) {
      summaryMap['confidence'] = map['confidence'].toString();
    }
    if (!summaryMap.containsKey('analysisState') &&
        (map.containsKey('analysisState') || map.containsKey('state'))) {
      summaryMap['analysisState'] =
          (map['analysisState'] ?? map['state']).toString();
    }

    final rawClaims =
        map['keyClaims'] as List? ?? map['claims'] as List? ?? [];
    final rawSources =
        map['sources'] as List? ?? map['richSources'] as List? ?? [];
    final narrative = (map['narrative'] ??
            map['viewerNote'] ??
            map['summary'] ??
            map['explanation'] ??
            '')
        .toString();

    final parsedKeyClaims = rawClaims
        .map((c) => ClaimResult.fromMap(
              Map<String, dynamic>.from(
                c is Map ? c : {'text': c.toString()},
              ),
            ))
        .toList();

    int verdictPriority(ClaimResult c) {
      final v = c.verdict.toLowerCase();
      if (v.contains('false') || v.contains('incorrect') || v.contains('denial') || v.contains('misleading')) {
        return 0; // Contradicted / False: Top priority at top of player
      }
      if (v.contains('dispute') || v.contains('inconclusive') || v.contains('limited')) {
        return 1; // Caution / Disputed: High priority
      }
      if (v.contains('unproven') || v.contains('unsupported') || v.contains('unverified')) {
        return 2; // Unproven
      }
      if (v.contains('true') || v.contains('correct')) {
        return 3; // Confirmed True
      }
      return 4; // Opinion / Faith / Contextual
    }

    final prioritizedKeyClaims = List<ClaimResult>.from(parsedKeyClaims)
      ..sort((a, b) => verdictPriority(a).compareTo(verdictPriority(b)));

    ClaimLedgerSummary? parsedLedger;
    if (map['claimLedger'] is Map) {
      parsedLedger = ClaimLedgerSummary.fromMap(Map<String, dynamic>.from(map['claimLedger']));
    } else if (prioritizedKeyClaims.isNotEmpty) {
      final confirmed = prioritizedKeyClaims.where((c) => verdictPriority(c) == 3).length;
      final disputed = prioritizedKeyClaims.where((c) => verdictPriority(c) == 1).length;
      final falseCount = prioritizedKeyClaims.where((c) => verdictPriority(c) == 0).length;
      final unproven = prioritizedKeyClaims.where((c) => verdictPriority(c) == 2).length;
      final contextual = prioritizedKeyClaims.where((c) => verdictPriority(c) == 4).length;
      final total = prioritizedKeyClaims.length;

      parsedLedger = ClaimLedgerSummary(
        totalClaimsChecked: total,
        confirmedCount: confirmed,
        disputedCount: disputed,
        unprovenCount: unproven,
        falseCount: falseCount,
        contextualCount: contextual,
        highestSeverityVerdict: falseCount > 0 ? 'false_claim' : disputed > 0 ? 'disputed' : unproven > 0 ? 'unproven' : 'verified_true',
        verdictHeadline: '$confirmed Confirmed • $disputed Disputed • $falseCount False',
        priorityNotice: falseCount > 0 ? 'Notice: $falseCount claim(s) contradicted by documented evidence.' : null,
        verifiableRatio: total > 0 ? confirmed / total : 0.0,
      );
    }

    final parsedSources = rawSources
        .map((s) => UISource.fromMap(
              Map<String, dynamic>.from(
                s is Map ? s : {'title': s.toString()},
              ),
            ))
        .toList();

    final rawConclusion = map['conclusion'];
    final conclusionText = rawConclusion is Map
        ? (rawConclusion['text'] ?? rawConclusion['summary'] ?? '').toString()
        : (rawConclusion ?? '').toString();

    final rawConclusionSources = (rawConclusion is Map && rawConclusion['sources'] is List
            ? rawConclusion['sources'] as List
            : null) ??
        (map['conclusionSources'] as List?) ??
        (rawSources.isNotEmpty ? rawSources : null);

    final parsedConclusionSources = (rawConclusionSources != null)
        ? rawConclusionSources
            .map((s) => UISource.fromMap(
                  Map<String, dynamic>.from(
                    s is Map ? s : {'title': s.toString()},
                  ),
                ))
            .toList()
        : <UISource>[];

    return UIReport(
      summary: UISummary.fromMap(summaryMap),
      quickVerdict: (map['quickVerdict'] ?? '').toString(),
      narrative: narrative,
      riskNote: (map['riskNote'] ?? '').toString(),
      positiveDrivers: (map['positiveDrivers'] as List? ?? [])
          .map((d) => UIDriver.fromMap(d))
          .toList(),
      negativeDrivers: (map['negativeDrivers'] as List? ?? [])
          .map((d) => UIDriver.fromMap(d))
          .toList(),
      sources: parsedSources,
      conclusion: conclusionText,
      conclusionSources: parsedConclusionSources,
      counterSignals: List<String>.from(map['counterSignals'] ?? []),
      reviewRequestEnabled: map['reviewRequestEnabled'] ?? true,
      keyClaims: prioritizedKeyClaims,
      claimLedger: parsedLedger,
    );
  }
  final UISummary summary;
  final String quickVerdict;
  final String narrative;
  final String riskNote;
  final List<UIDriver> positiveDrivers;
  final List<UIDriver> negativeDrivers;
  final List<UISource> sources;
  final String conclusion;
  final List<UISource> conclusionSources;
  final List<String> counterSignals;
  final bool reviewRequestEnabled;
  final List<ClaimResult> keyClaims;
  final ClaimLedgerSummary? claimLedger;

  Map<String, dynamic> toMap() {
    return {
      'summary': summary.toMap(),
      'quickVerdict': quickVerdict,
      'narrative': narrative,
      'riskNote': riskNote,
      'positiveDrivers': positiveDrivers.map((d) => d.toMap()).toList(),
      'negativeDrivers': negativeDrivers.map((d) => d.toMap()).toList(),
      'sources': sources.map((s) => s.toMap()).toList(),
      'conclusion': conclusion,
      'conclusionSources': conclusionSources.map((s) => s.toMap()).toList(),
      'counterSignals': counterSignals,
      'reviewRequestEnabled': reviewRequestEnabled,
      'keyClaims': keyClaims.map((c) => c.toMap()).toList(),
      'claimLedger': claimLedger?.toMap(),
    };
  }

  double? get rating => summary.rating;
  double? get truthScore => summary.honestyScore;
  double? get honestyScore => summary.honestyScore;
  double? get rationalityScore => summary.rationalityScore;
  String get label => summary.label;
  String get confidence => summary.confidence;
  String? get analysisState => summary.analysisState;
}

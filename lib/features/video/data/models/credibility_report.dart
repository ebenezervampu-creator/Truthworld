/// 🎯 CREDIBILITY REPORT MODELS (v8.0 — Epistemic Trust Engine)
///
/// Maps the multidimensional credibility data from the backend to Flutter.
/// Used for the "Credibility Nutrition Label" UI.
library;

import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';

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

class EvidenceAssessment {
  EvidenceAssessment({
    this.scripturalSupport,
    this.independentHistoricalCorroboration,
    this.empiricalVerification,
  });

  factory EvidenceAssessment.fromMap(Map<String, dynamic> map) {
    return EvidenceAssessment(
      scripturalSupport: map['scripturalSupport']?.toString(),
      independentHistoricalCorroboration:
          map['independentHistoricalCorroboration']?.toString(),
      empiricalVerification: map['empiricalVerification']?.toString(),
    );
  }

  final String? scripturalSupport;
  final String? independentHistoricalCorroboration;
  final String? empiricalVerification;

  Map<String, dynamic> toMap() => {
    'scripturalSupport': scripturalSupport,
    'independentHistoricalCorroboration': independentHistoricalCorroboration,
    'empiricalVerification': empiricalVerification,
  };
}

class FramingViolationDetail {
  FramingViolationDetail({
    this.violationType,
    this.assertedEvidenceQuality,
    this.explanation,
  });

  factory FramingViolationDetail.fromMap(Map<String, dynamic> map) {
    return FramingViolationDetail(
      violationType: map['violationType']?.toString(),
      assertedEvidenceQuality: map['assertedEvidenceQuality']?.toString(),
      explanation: map['explanation']?.toString(),
    );
  }

  final String? violationType;
  final String? assertedEvidenceQuality;
  final String? explanation;

  Map<String, dynamic> toMap() => {
    'violationType': violationType,
    'assertedEvidenceQuality': assertedEvidenceQuality,
    'explanation': explanation,
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
    this.whatItSupports,
    this.whatItDoesNotEstablish,
    this.sourceRole,
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

    final whatItSupports = map['whatItSupports']?.toString();
    final whatItDoesNotEstablish = map['whatItDoesNotEstablish']?.toString();
    final sourceRole = map['sourceRole']?.toString();

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
      whatItSupports: whatItSupports,
      whatItDoesNotEstablish: whatItDoesNotEstablish,
      sourceRole: sourceRole,
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
  final String? whatItSupports;
  final String? whatItDoesNotEstablish;
  final String? sourceRole;

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
    'whatItSupports': whatItSupports,
    'whatItDoesNotEstablish': whatItDoesNotEstablish,
    'sourceRole': sourceRole,
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
    this.thumbnailUrl,
    this.evidenceAssessment,
    this.beliefAssessment,
    this.misinformationVerdict,
    this.framingViolationDetail,
    this.confidenceMeaning,
    this.framingAssessment,
    this.epistemicLimitations,
    this.evidenceTraceability,
    this.calibratedConfidence,
    this.assessmentV2,
    this.localizedTexts,
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

    final rawThumbnail = (map['thumbnailUrl'] ??
            map['thumbnail'] ??
            map['frameUrl'] ??
            map['imageUrl'])
        ?.toString();

    final rawLocalized =
        map['localizedTexts'] ?? map['translations'] ?? map['localizations'];
    Map<String, String>? localizedMap;
    if (rawLocalized is Map) {
      localizedMap = {};
      for (final entry in rawLocalized.entries) {
        if (entry.key != null && entry.value != null) {
          localizedMap[UserLanguagesService.normalizeCode(entry.key.toString())] =
              entry.value.toString();
        }
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
      thumbnailUrl: (rawThumbnail != null && rawThumbnail.trim().isNotEmpty)
          ? rawThumbnail.trim()
          : null,
      evidenceAssessment: map['evidenceAssessment'] is Map
          ? EvidenceAssessment.fromMap(
              Map<String, dynamic>.from(map['evidenceAssessment']),
            )
          : null,
      beliefAssessment: map['beliefAssessment']?.toString(),
      misinformationVerdict: map['misinformationVerdict']?.toString(),
      framingViolationDetail: map['framingViolationDetail'] is Map
          ? FramingViolationDetail.fromMap(
              Map<String, dynamic>.from(map['framingViolationDetail']),
            )
          : null,
      confidenceMeaning: map['confidenceMeaning']?.toString(),
      framingAssessment: map['framingAssessment']?.toString(),
      epistemicLimitations: (map['epistemicLimitations'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      evidenceTraceability: map['evidenceTraceability'] is Map
          ? EvidenceToClaimTraceability.fromMap(
              Map<String, dynamic>.from(map['evidenceTraceability']),
            )
          : null,
      calibratedConfidence: map['calibratedConfidence'] is Map
          ? CalibratedConfidenceBreakdown.fromMap(
              Map<String, dynamic>.from(map['calibratedConfidence']),
            )
          : null,
      assessmentV2: map['assessmentV2'] is Map
          ? CredibilityAssessmentV2.fromMap(
              Map<String, dynamic>.from(map['assessmentV2']),
            )
          : null,
      localizedTexts: localizedMap,
    );
  }
  final String text;
  final String verdict;
  final double? start;
  final double? end;
  final bool? isLowRiskTrivia;
  final List<UISource> effectiveSources;
  final String? thumbnailUrl;
  final EvidenceAssessment? evidenceAssessment;
  final String? beliefAssessment;
  final String? misinformationVerdict;
  final FramingViolationDetail? framingViolationDetail;
  final String? confidenceMeaning;
  final String? framingAssessment;
  final List<String>? epistemicLimitations;
  final EvidenceToClaimTraceability? evidenceTraceability;
  final CalibratedConfidenceBreakdown? calibratedConfidence;
  final CredibilityAssessmentV2? assessmentV2;
  final Map<String, String>? localizedTexts;

  /// Returns the claim text translated into the requested [langCode] or the user's
  /// active primary language. Seamlessly falls back to the default canonical [text].
  String localizedText([String? langCode]) {
    final code = (langCode != null && langCode.trim().isNotEmpty)
        ? UserLanguagesService.normalizeCode(langCode)
        : (UserLanguagesService.isRegistered
            ? UserLanguagesService.to.primaryLanguageCode
            : 'en');

    if (localizedTexts != null && localizedTexts!.containsKey(code)) {
      final loc = localizedTexts![code];
      if (loc != null && loc.trim().isNotEmpty) return loc;
    }
    return text;
  }

  /// Returns the verdict label localized in the user's primary language.
  String localizedVerdictLabel([String? langCode]) {
    return ClaimVerdictHelper.resolveVerdictString(
      verdict,
      confidence: classificationConfidence,
    ).localizedLabel(langCode);
  }

  Duration get startDuration =>
      Duration(milliseconds: ((start ?? 0) * 1000).round());

  String get formattedStartTime {
    if (start == null) return '00:00';
    final totalSec = start!.toInt();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
    'thumbnailUrl': thumbnailUrl,
    'evidenceAssessment': evidenceAssessment?.toMap(),
    'beliefAssessment': beliefAssessment,
    'misinformationVerdict': misinformationVerdict,
    'framingViolationDetail': framingViolationDetail?.toMap(),
    'confidenceMeaning': confidenceMeaning,
    'framingAssessment': framingAssessment,
    'epistemicLimitations': epistemicLimitations,
    'evidenceTraceability': evidenceTraceability?.toMap(),
    'calibratedConfidence': calibratedConfidence?.toMap(),
    'assessmentV2': assessmentV2?.toMap(),
    if (localizedTexts != null && localizedTexts!.isNotEmpty)
      'localizedTexts': localizedTexts,
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

/// 🔍 Evidence-to-Claim Traceability: Source Provenance
class EvidenceProvenance {
  const EvidenceProvenance({
    required this.originAgencyOrAuthor,
    required this.isIndependentOfSubject,
    required this.independenceValidation,
  });

  factory EvidenceProvenance.fromMap(Map<String, dynamic> map) {
    return EvidenceProvenance(
      originAgencyOrAuthor: (map['originAgencyOrAuthor'] ?? '').toString(),
      isIndependentOfSubject: (map['isIndependentOfSubject'] ?? false) as bool,
      independenceValidation: (map['independenceValidation'] ?? '').toString(),
    );
  }

  final String originAgencyOrAuthor;
  final bool isIndependentOfSubject;
  final String independenceValidation;

  Map<String, dynamic> toMap() => {
    'originAgencyOrAuthor': originAgencyOrAuthor,
    'isIndependentOfSubject': isIndependentOfSubject,
    'independenceValidation': independenceValidation,
  };
}

/// 🔍 Source Independence Matrix (Non-Binary Provenance)
class SourceIndependenceMatrix {
  const SourceIndependenceMatrix({
    required this.publisherIndependentOfSubject,
    required this.underlyingDataIndependentOfSubject,
    required this.analysisIndependentlyConducted,
    required this.corroborationType,
  });

  factory SourceIndependenceMatrix.fromMap(Map<String, dynamic> map) {
    return SourceIndependenceMatrix(
      publisherIndependentOfSubject: (map['publisherIndependentOfSubject'] ?? false) as bool,
      underlyingDataIndependentOfSubject: (map['underlyingDataIndependentOfSubject'] ?? false) as bool,
      analysisIndependentlyConducted: (map['analysisIndependentlyConducted'] ?? false) as bool,
      corroborationType: (map['corroborationType'] ?? 'subject_self_reporting').toString(),
    );
  }

  final bool publisherIndependentOfSubject;
  final bool underlyingDataIndependentOfSubject;
  final bool analysisIndependentlyConducted;
  final String corroborationType;

  Map<String, dynamic> toMap() => {
    'publisherIndependentOfSubject': publisherIndependentOfSubject,
    'underlyingDataIndependentOfSubject': underlyingDataIndependentOfSubject,
    'analysisIndependentlyConducted': analysisIndependentlyConducted,
    'corroborationType': corroborationType,
  };
}

/// 🔍 Automated Passage Verification (Machine-Audited Retrieval)
class AutomatedPassageVerification {
  const AutomatedPassageVerification({
    required this.urlResolved,
    required this.passageLocated,
    required this.passageMatchesSource,
    required this.supportsClaimComponent,
    required this.verificationMethod,
    required this.lastVerifiedAt,
    this.locatedContextSnippet,
    this.omittedContextDetected = false,
    this.omittedContextExplanation,
  });

  factory AutomatedPassageVerification.fromMap(Map<String, dynamic> map) {
    return AutomatedPassageVerification(
      urlResolved: (map['urlResolved'] ?? false) as bool,
      passageLocated: (map['passageLocated'] ?? false) as bool,
      passageMatchesSource: (map['passageMatchesSource'] ?? false) as bool,
      supportsClaimComponent: (map['supportsClaimComponent'] ?? false) as bool,
      verificationMethod: (map['verificationMethod'] ?? 'unverified_citation').toString(),
      lastVerifiedAt: (map['lastVerifiedAt'] ?? '').toString(),
      locatedContextSnippet: map['locatedContextSnippet']?.toString(),
      omittedContextDetected: (map['omittedContextDetected'] ?? false) as bool,
      omittedContextExplanation: map['omittedContextExplanation']?.toString(),
    );
  }

  final bool urlResolved;
  final bool passageLocated;
  final bool passageMatchesSource;
  final bool supportsClaimComponent;
  final String verificationMethod;
  final String lastVerifiedAt;
  final String? locatedContextSnippet;
  final bool omittedContextDetected;
  final String? omittedContextExplanation;

  Map<String, dynamic> toMap() => {
    'urlResolved': urlResolved,
    'passageLocated': passageLocated,
    'passageMatchesSource': passageMatchesSource,
    'supportsClaimComponent': supportsClaimComponent,
    'verificationMethod': verificationMethod,
    'lastVerifiedAt': lastVerifiedAt,
    'locatedContextSnippet': locatedContextSnippet,
    'omittedContextDetected': omittedContextDetected,
    'omittedContextExplanation': omittedContextExplanation,
  };
}

/// 🔍 Calibrated Confidence Breakdown
class CalibratedConfidenceBreakdown {
  const CalibratedConfidenceBreakdown({
    this.claimDecomposition,
    this.premiseAssessment,
    this.sourceVerification,
    this.inferenceAssessment,
    this.overallVerdict,
  });

  factory CalibratedConfidenceBreakdown.fromMap(Map<String, dynamic> map) {
    return CalibratedConfidenceBreakdown(
      claimDecomposition: (map['claimDecomposition'] is num) ? (map['claimDecomposition'] as num).toDouble() : null,
      premiseAssessment: (map['premiseAssessment'] is num) ? (map['premiseAssessment'] as num).toDouble() : null,
      sourceVerification: (map['sourceVerification'] is num) ? (map['sourceVerification'] as num).toDouble() : null,
      inferenceAssessment: (map['inferenceAssessment'] is num) ? (map['inferenceAssessment'] as num).toDouble() : null,
      overallVerdict: (map['overallVerdict'] is num) ? (map['overallVerdict'] as num).toDouble() : null,
    );
  }

  final double? claimDecomposition;
  final double? premiseAssessment;
  final double? sourceVerification;
  final double? inferenceAssessment;
  final double? overallVerdict;

  Map<String, dynamic> toMap() => {
    'claimDecomposition': claimDecomposition,
    'premiseAssessment': premiseAssessment,
    'sourceVerification': sourceVerification,
    'inferenceAssessment': inferenceAssessment,
    'overallVerdict': overallVerdict,
  };
}

/// 🔍 Evidence-to-Claim Traceability: Exact Evidence Item
class EvidenceTraceItem {
  const EvidenceTraceItem({
    required this.evidenceId,
    required this.componentId,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.retrievalTimestamp,
    required this.sourceType,
    required this.provenance,
    required this.exactPassage,
    required this.claimComponentAddressed,
    required this.relationship,
    required this.verificationStatus,
    this.sourceIndependence,
    this.automatedVerification,
    this.knownLimitations = const [],
  });

  factory EvidenceTraceItem.fromMap(Map<String, dynamic> map) {
    return EvidenceTraceItem(
      evidenceId: (map['evidenceId'] ?? '').toString(),
      componentId: (map['componentId'] ?? '').toString(),
      sourceTitle: (map['sourceTitle'] ?? '').toString(),
      sourceUrl: (map['sourceUrl'] ?? '').toString(),
      retrievalTimestamp: (map['retrievalTimestamp'] ?? 0) as int,
      sourceType: (map['sourceType'] ?? '').toString(),
      provenance: map['provenance'] is Map
          ? EvidenceProvenance.fromMap(Map<String, dynamic>.from(map['provenance']))
          : const EvidenceProvenance(
              originAgencyOrAuthor: '',
              isIndependentOfSubject: false,
              independenceValidation: '',
            ),
      exactPassage: (map['exactPassage'] ?? '').toString(),
      claimComponentAddressed: (map['claimComponentAddressed'] ?? '').toString(),
      relationship: (map['relationship'] ?? '').toString(),
      verificationStatus: (map['verificationStatus'] ?? '').toString(),
      sourceIndependence: map['sourceIndependence'] is Map
          ? SourceIndependenceMatrix.fromMap(Map<String, dynamic>.from(map['sourceIndependence']))
          : null,
      automatedVerification: map['automatedVerification'] is Map
          ? AutomatedPassageVerification.fromMap(Map<String, dynamic>.from(map['automatedVerification']))
          : null,
      knownLimitations: (map['knownLimitations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final String evidenceId;
  final String componentId;
  final String sourceTitle;
  final String sourceUrl;
  final int retrievalTimestamp;
  final String sourceType;
  final EvidenceProvenance provenance;
  final SourceIndependenceMatrix? sourceIndependence;
  final AutomatedPassageVerification? automatedVerification;
  final String exactPassage;
  final String claimComponentAddressed;
  final String relationship;
  final String verificationStatus;
  final List<String> knownLimitations;

  Map<String, dynamic> toMap() => {
    'evidenceId': evidenceId,
    'componentId': componentId,
    'sourceTitle': sourceTitle,
    'sourceUrl': sourceUrl,
    'retrievalTimestamp': retrievalTimestamp,
    'sourceType': sourceType,
    'provenance': provenance.toMap(),
    'sourceIndependence': sourceIndependence?.toMap(),
    'automatedVerification': automatedVerification?.toMap(),
    'exactPassage': exactPassage,
    'claimComponentAddressed': claimComponentAddressed,
    'relationship': relationship,
    'verificationStatus': verificationStatus,
    'knownLimitations': knownLimitations,
  };
}

/// 🔍 Evidence-to-Claim Traceability: Decomposed Claim Component
class ClaimComponent {
  const ClaimComponent({
    required this.componentId,
    required this.statement,
    required this.type,
    required this.factualAccuracy,
    required this.explanation,
    this.inferentialValidity,
    this.detectedFallacy,
    this.evidenceIds = const [],
  });

  factory ClaimComponent.fromMap(Map<String, dynamic> map) {
    return ClaimComponent(
      componentId: (map['componentId'] ?? '').toString(),
      statement: (map['statement'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      factualAccuracy: (map['factualAccuracy'] ?? '').toString(),
      inferentialValidity: map['inferentialValidity']?.toString(),
      explanation: (map['explanation'] ?? '').toString(),
      detectedFallacy: map['detectedFallacy']?.toString(),
      evidenceIds: (map['evidenceIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final String componentId;
  final String statement;
  final String type;
  final String factualAccuracy;
  final String? inferentialValidity;
  final String explanation;
  final String? detectedFallacy;
  final List<String> evidenceIds;

  Map<String, dynamic> toMap() => {
    'componentId': componentId,
    'statement': statement,
    'type': type,
    'factualAccuracy': factualAccuracy,
    'inferentialValidity': inferentialValidity,
    'explanation': explanation,
    'detectedFallacy': detectedFallacy,
    'evidenceIds': evidenceIds,
  };
}

/// 🔍 Evidence-to-Claim Traceability: Full Traceability Manifest
class EvidenceToClaimTraceability {
  const EvidenceToClaimTraceability({
    required this.isCompoundClaim,
    required this.components,
    required this.evidenceTraces,
    required this.inferentialBridgeSummary,
    this.premisesVerdict,
    this.conclusionVerdict,
    this.finalAdjudication,
  });

  factory EvidenceToClaimTraceability.fromMap(Map<String, dynamic> map) {
    final synthesis = map['overallSynthesis'] is Map
        ? Map<String, dynamic>.from(map['overallSynthesis'])
        : <String, dynamic>{};
    return EvidenceToClaimTraceability(
      isCompoundClaim: (map['isCompoundClaim'] ?? false) as bool,
      components: (map['components'] as List?)
              ?.map((c) => ClaimComponent.fromMap(Map<String, dynamic>.from(c)))
              .toList() ??
          const [],
      evidenceTraces: (map['evidenceTraces'] as List?)
              ?.map((e) => EvidenceTraceItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      inferentialBridgeSummary:
          (map['inferentialBridgeSummary'] ?? '').toString(),
      premisesVerdict: synthesis['premisesVerdict']?.toString(),
      conclusionVerdict: synthesis['conclusionVerdict']?.toString(),
      finalAdjudication: synthesis['finalAdjudication']?.toString(),
    );
  }

  final bool isCompoundClaim;
  final List<ClaimComponent> components;
  final List<EvidenceTraceItem> evidenceTraces;
  final String inferentialBridgeSummary;
  final String? premisesVerdict;
  final String? conclusionVerdict;
  final String? finalAdjudication;

  Map<String, dynamic> toMap() => {
    'isCompoundClaim': isCompoundClaim,
    'components': components.map((c) => c.toMap()).toList(),
    'evidenceTraces': evidenceTraces.map((e) => e.toMap()).toList(),
    'inferentialBridgeSummary': inferentialBridgeSummary,
    'overallSynthesis': {
      'premisesVerdict': premisesVerdict,
      'conclusionVerdict': conclusionVerdict,
      'finalAdjudication': finalAdjudication,
    },
  };
}

// ============================================================================
// 🏛 V2 CREDIBILITY ASSESSMENT & 3-AXIS ORTHOGONAL CLASSIFICATION
// ============================================================================

class OrthogonalClassification {
  const OrthogonalClassification({
    required this.propositionType,
    required this.evidenceStatus,
    required this.reasoningValidity,
    required this.displayBadge,
  });

  factory OrthogonalClassification.fromMap(Map<String, dynamic> map) {
    return OrthogonalClassification(
      propositionType: (map['propositionType'] ?? 'EMPIRICAL_OBSERVATION').toString(),
      evidenceStatus: (map['evidenceStatus'] ?? 'INSUFFICIENT_EVIDENCE').toString(),
      reasoningValidity: (map['reasoningValidity'] ?? 'NOT_APPLICABLE').toString(),
      displayBadge: (map['displayBadge'] ?? 'UNSUPPORTED_CONJECTURE').toString(),
    );
  }

  final String propositionType;
  final String evidenceStatus;
  final String reasoningValidity;
  final String displayBadge;

  Map<String, dynamic> toMap() => {
    'propositionType': propositionType,
    'evidenceStatus': evidenceStatus,
    'reasoningValidity': reasoningValidity,
    'displayBadge': displayBadge,
  };
}

class ClaimDecompositionProposition {
  const ClaimDecompositionProposition({
    required this.propositionId,
    required this.role,
    required this.text,
    required this.propositionType,
    required this.assessment,
    this.supportingEvidenceIds = const [],
    this.contradictingEvidenceIds = const [],
    this.independentPrimarySourceCount = 0,
  });

  factory ClaimDecompositionProposition.fromMap(Map<String, dynamic> map) {
    return ClaimDecompositionProposition(
      propositionId: (map['propositionId'] ?? '').toString(),
      role: (map['role'] ?? 'PREMISE').toString(),
      text: (map['text'] ?? '').toString(),
      propositionType: (map['propositionType'] ?? 'EMPIRICAL_OBSERVATION').toString(),
      assessment: (map['assessment'] ?? 'INSUFFICIENT_EVIDENCE').toString(),
      supportingEvidenceIds: (map['supportingEvidenceIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      contradictingEvidenceIds: (map['contradictingEvidenceIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      independentPrimarySourceCount: (map['independentPrimarySourceCount'] ?? 0) as int,
    );
  }

  final String propositionId;
  final String role;
  final String text;
  final String propositionType;
  final String assessment;
  final List<String> supportingEvidenceIds;
  final List<String> contradictingEvidenceIds;
  final int independentPrimarySourceCount;

  Map<String, dynamic> toMap() => {
    'propositionId': propositionId,
    'role': role,
    'text': text,
    'propositionType': propositionType,
    'assessment': assessment,
    'supportingEvidenceIds': supportingEvidenceIds,
    'contradictingEvidenceIds': contradictingEvidenceIds,
    'independentPrimarySourceCount': independentPrimarySourceCount,
  };
}

class DeterministicVerification {
  const DeterministicVerification({
    required this.fetchStatus,
    required this.snapshotSha256,
    required this.retrievedAtUtc,
    required this.verifiedPassage,
    required this.charStart,
    required this.charEnd,
    required this.exactMatchScore,
    this.contextDistortionDetected = false,
  });

  factory DeterministicVerification.fromMap(Map<String, dynamic> map) {
    return DeterministicVerification(
      fetchStatus: (map['fetchStatus'] ?? 'UNVERIFIED').toString(),
      snapshotSha256: (map['snapshotSha256'] ?? '').toString(),
      retrievedAtUtc: (map['retrievedAtUtc'] ?? '').toString(),
      verifiedPassage: (map['verifiedPassage'] ?? '').toString(),
      charStart: (map['charStart'] ?? 0) as int,
      charEnd: (map['charEnd'] ?? 0) as int,
      exactMatchScore: ((map['exactMatchScore'] ?? 0.0) as num).toDouble(),
      contextDistortionDetected: (map['contextDistortionDetected'] ?? false) as bool,
    );
  }

  final String fetchStatus;
  final String snapshotSha256;
  final String retrievedAtUtc;
  final String verifiedPassage;
  final int charStart;
  final int charEnd;
  final double exactMatchScore;
  final bool contextDistortionDetected;

  Map<String, dynamic> toMap() => {
    'fetchStatus': fetchStatus,
    'snapshotSha256': snapshotSha256,
    'retrievedAtUtc': retrievedAtUtc,
    'verifiedPassage': verifiedPassage,
    'charStart': charStart,
    'charEnd': charEnd,
    'exactMatchScore': exactMatchScore,
    'contextDistortionDetected': contextDistortionDetected,
  };
}

class SourceIndependenceProfile {
  const SourceIndependenceProfile({
    required this.lineageType,
    this.upstreamSourceId,
    required this.independenceWeight,
  });

  factory SourceIndependenceProfile.fromMap(Map<String, dynamic> map) {
    return SourceIndependenceProfile(
      lineageType: (map['lineageType'] ?? 'PRIMARY_TECHNICAL_RECORD').toString(),
      upstreamSourceId: map['upstreamSourceId']?.toString(),
      independenceWeight: ((map['independenceWeight'] ?? 1.0) as num).toDouble(),
    );
  }

  final String lineageType;
  final String? upstreamSourceId;
  final double independenceWeight;

  Map<String, dynamic> toMap() => {
    'lineageType': lineageType,
    'upstreamSourceId': upstreamSourceId,
    'independenceWeight': independenceWeight,
  };
}

class EpistemicScope {
  const EpistemicScope({
    required this.establishes,
    required this.doesNotEstablish,
    required this.limitations,
  });

  factory EpistemicScope.fromMap(Map<String, dynamic> map) {
    return EpistemicScope(
      establishes: (map['establishes'] ?? '').toString(),
      doesNotEstablish: (map['doesNotEstablish'] ?? '').toString(),
      limitations: (map['limitations'] ?? '').toString(),
    );
  }

  final String establishes;
  final String doesNotEstablish;
  final String limitations;

  Map<String, dynamic> toMap() => {
    'establishes': establishes,
    'doesNotEstablish': doesNotEstablish,
    'limitations': limitations,
  };
}

class EvidenceRegistryItem {
  const EvidenceRegistryItem({
    required this.publisher,
    required this.url,
    this.primaryArtifactId,
    required this.deterministicVerification,
    required this.independence,
    required this.epistemicScope,
  });

  factory EvidenceRegistryItem.fromMap(Map<String, dynamic> map) {
    final identity = map['sourceIdentity'] is Map
        ? Map<String, dynamic>.from(map['sourceIdentity'])
        : <String, dynamic>{};
    return EvidenceRegistryItem(
      publisher: (identity['publisher'] ?? '').toString(),
      url: (identity['url'] ?? '').toString(),
      primaryArtifactId: identity['primaryArtifactId']?.toString(),
      deterministicVerification: DeterministicVerification.fromMap(
        map['deterministicVerification'] is Map
            ? Map<String, dynamic>.from(map['deterministicVerification'])
            : <String, dynamic>{},
      ),
      independence: SourceIndependenceProfile.fromMap(
        map['independence'] is Map
            ? Map<String, dynamic>.from(map['independence'])
            : <String, dynamic>{},
      ),
      epistemicScope: EpistemicScope.fromMap(
        map['epistemicScope'] is Map
            ? Map<String, dynamic>.from(map['epistemicScope'])
            : <String, dynamic>{},
      ),
    );
  }

  final String publisher;
  final String url;
  final String? primaryArtifactId;
  final DeterministicVerification deterministicVerification;
  final SourceIndependenceProfile independence;
  final EpistemicScope epistemicScope;

  Map<String, dynamic> toMap() => {
    'sourceIdentity': {
      'publisher': publisher,
      'url': url,
      'primaryArtifactId': primaryArtifactId,
    },
    'deterministicVerification': deterministicVerification.toMap(),
    'independence': independence.toMap(),
    'epistemicScope': epistemicScope.toMap(),
  };
}

class BackendAuditFlags {
  const BackendAuditFlags({
    required this.allReferencedCitationsDeterministicallyVerified,
    required this.unverifiedEvidencePresent,
    required this.closedWorldCitationCheckPassed,
  });

  factory BackendAuditFlags.fromMap(Map<String, dynamic> map) {
    return BackendAuditFlags(
      allReferencedCitationsDeterministicallyVerified:
          (map['allReferencedCitationsDeterministicallyVerified'] ?? false) as bool,
      unverifiedEvidencePresent:
          (map['unverifiedEvidencePresent'] ?? false) as bool,
      closedWorldCitationCheckPassed:
          (map['closedWorldCitationCheckPassed'] ?? true) as bool,
    );
  }

  final bool allReferencedCitationsDeterministicallyVerified;
  final bool unverifiedEvidencePresent;
  final bool closedWorldCitationCheckPassed;

  Map<String, dynamic> toMap() => {
    'allReferencedCitationsDeterministicallyVerified':
        allReferencedCitationsDeterministicallyVerified,
    'unverifiedEvidencePresent': unverifiedEvidencePresent,
    'closedWorldCitationCheckPassed': closedWorldCitationCheckPassed,
  };
}

class EpistemicUncertainty {
  const EpistemicUncertainty({
    this.numericalConfidenceAvailable = false,
    this.calibrationModelVersion,
    required this.qualitativeTier,
    this.conformalPredictionSet = const [],
    this.disclosedGaps = const [],
  });

  factory EpistemicUncertainty.fromMap(Map<String, dynamic> map) {
    return EpistemicUncertainty(
      numericalConfidenceAvailable:
          (map['numericalConfidenceAvailable'] ?? false) as bool,
      calibrationModelVersion: map['calibrationModelVersion']?.toString(),
      qualitativeTier: (map['qualitativeTier'] ?? 'PRELIMINARY_EVIDENCE').toString(),
      conformalPredictionSet: (map['conformalPredictionSet'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      disclosedGaps: (map['disclosedGaps'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final bool numericalConfidenceAvailable;
  final String? calibrationModelVersion;
  final String qualitativeTier;
  final List<String> conformalPredictionSet;
  final List<String> disclosedGaps;

  Map<String, dynamic> toMap() => {
    'numericalConfidenceAvailable': numericalConfidenceAvailable,
    'calibrationModelVersion': calibrationModelVersion,
    'qualitativeTier': qualitativeTier,
    'conformalPredictionSet': conformalPredictionSet,
    'disclosedGaps': disclosedGaps,
  };
}

class CredibilityAssessmentV2 {
  const CredibilityAssessmentV2({
    required this.assessmentId,
    this.schemaVersion = '2.0.0',
    this.assessmentVersion = 1,
    this.supersededBy,
    this.correctionReason,
    this.speakerStance = 'SPEAKER_ASSERTS',
    required this.claimText,
    required this.classification,
    required this.claimDecomposition,
    required this.evidenceRegistry,
    required this.backendAuditFlags,
    required this.uncertainty,
    this.semanticValidation,
  });

  factory CredibilityAssessmentV2.fromMap(Map<String, dynamic> map) {
    final videoCtx = map['videoContext'] is Map
        ? Map<String, dynamic>.from(map['videoContext'])
        : <String, dynamic>{};

    final regMap = map['evidenceRegistry'] is Map
        ? Map<String, dynamic>.from(map['evidenceRegistry'])
        : <String, dynamic>{};

    final registry = <String, EvidenceRegistryItem>{};
    regMap.forEach((k, v) {
      if (v is Map) {
        registry[k] = EvidenceRegistryItem.fromMap(Map<String, dynamic>.from(v));
      }
    });

    return CredibilityAssessmentV2(
      assessmentId: (map['assessmentId'] ?? '').toString(),
      schemaVersion: (map['schemaVersion'] ?? '2.0.0').toString(),
      assessmentVersion: (map['assessmentVersion'] ?? 1) as int,
      supersededBy: map['supersededBy']?.toString(),
      correctionReason: map['correctionReason']?.toString(),
      speakerStance: (videoCtx['speakerStance'] ?? 'SPEAKER_ASSERTS').toString(),
      claimText: (map['claimText'] ?? '').toString(),
      classification: OrthogonalClassification.fromMap(
        map['classification'] is Map
            ? Map<String, dynamic>.from(map['classification'])
            : <String, dynamic>{},
      ),
      claimDecomposition: (map['claimDecomposition'] as List?)
              ?.map((p) => ClaimDecompositionProposition.fromMap(
                  Map<String, dynamic>.from(p)))
              .toList() ??
          const [],
      evidenceRegistry: registry,
      backendAuditFlags: BackendAuditFlags.fromMap(
        map['backendAuditFlags'] is Map
            ? Map<String, dynamic>.from(map['backendAuditFlags'])
            : <String, dynamic>{},
      ),
      uncertainty: EpistemicUncertainty.fromMap(
        map['uncertainty'] is Map
            ? Map<String, dynamic>.from(map['uncertainty'])
            : <String, dynamic>{},
      ),
      semanticValidation: map['semanticValidation'] is Map
          ? SemanticEvidenceValidationResult.fromMap(
              Map<String, dynamic>.from(map['semanticValidation']),
            )
          : null,
    );
  }

  final String assessmentId;
  final String schemaVersion;
  final int assessmentVersion;
  final String? supersededBy;
  final String? correctionReason;
  final String speakerStance;
  final String claimText;
  final OrthogonalClassification classification;
  final List<ClaimDecompositionProposition> claimDecomposition;
  final Map<String, EvidenceRegistryItem> evidenceRegistry;
  final BackendAuditFlags backendAuditFlags;
  final EpistemicUncertainty uncertainty;
  final SemanticEvidenceValidationResult? semanticValidation;

  Map<String, dynamic> toMap() => {
    'assessmentId': assessmentId,
    'schemaVersion': schemaVersion,
    'assessmentVersion': assessmentVersion,
    'supersededBy': supersededBy,
    'correctionReason': correctionReason,
    'videoContext': {
      'speakerStance': speakerStance,
    },
    'claimText': claimText,
    'classification': classification.toMap(),
    'claimDecomposition':
        claimDecomposition.map((p) => p.toMap()).toList(),
    'evidenceRegistry': evidenceRegistry.map((k, v) => MapEntry(k, v.toMap())),
    'backendAuditFlags': backendAuditFlags.toMap(),
    'uncertainty': uncertainty.toMap(),
    'semanticValidation': semanticValidation?.toMap(),
  };
}

class SemanticEvidenceLink {
  const SemanticEvidenceLink({
    required this.evidenceId,
    required this.targetPropositionId,
    required this.semanticRelationship,
    required this.rationale,
    this.disclosedCaveats = const [],
    this.hypothesisVsFindingDistinction,
    this.scopeOfSupport = 'FULL_PROPOSITION',
  });

  factory SemanticEvidenceLink.fromMap(Map<String, dynamic> map) {
    return SemanticEvidenceLink(
      evidenceId: (map['evidenceId'] ?? '').toString(),
      targetPropositionId: (map['targetPropositionId'] ?? '').toString(),
      semanticRelationship: (map['semanticRelationship'] ?? 'AMBIGUOUS').toString(),
      rationale: (map['rationale'] ?? '').toString(),
      disclosedCaveats: (map['disclosedCaveats'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      hypothesisVsFindingDistinction:
          map['hypothesisVsFindingDistinction']?.toString(),
      scopeOfSupport: (map['scopeOfSupport'] ?? 'FULL_PROPOSITION').toString(),
    );
  }

  final String evidenceId;
  final String targetPropositionId;
  final String semanticRelationship;
  final String rationale;
  final List<String> disclosedCaveats;
  final String? hypothesisVsFindingDistinction;
  final String scopeOfSupport;

  Map<String, dynamic> toMap() => {
    'evidenceId': evidenceId,
    'targetPropositionId': targetPropositionId,
    'semanticRelationship': semanticRelationship,
    'rationale': rationale,
    'disclosedCaveats': disclosedCaveats,
    'hypothesisVsFindingDistinction': hypothesisVsFindingDistinction,
    'scopeOfSupport': scopeOfSupport,
  };
}

class OverclaimingAudit {
  const OverclaimingAudit({
    required this.overclaimingDetected,
    this.violationTypes = const [],
    this.details = const [],
  });

  factory OverclaimingAudit.fromMap(Map<String, dynamic> map) {
    return OverclaimingAudit(
      overclaimingDetected: (map['overclaimingDetected'] ?? false) as bool,
      violationTypes: (map['violationTypes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      details: (map['details'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final bool overclaimingDetected;
  final List<String> violationTypes;
  final List<String> details;

  Map<String, dynamic> toMap() => {
    'overclaimingDetected': overclaimingDetected,
    'violationTypes': violationTypes,
    'details': details,
  };
}

class SemanticEvidenceValidationResult {
  const SemanticEvidenceValidationResult({
    this.links = const [],
    required this.overclaimingAudit,
    this.semanticEvidenceLevel = 'ROBUST_SUPPORT',
  });

  factory SemanticEvidenceValidationResult.fromMap(Map<String, dynamic> map) {
    return SemanticEvidenceValidationResult(
      links: (map['links'] as List?)
              ?.map((l) => SemanticEvidenceLink.fromMap(Map<String, dynamic>.from(l)))
              .toList() ??
          const [],
      overclaimingAudit: OverclaimingAudit.fromMap(
        map['overclaimingAudit'] is Map
            ? Map<String, dynamic>.from(map['overclaimingAudit'])
            : <String, dynamic>{},
      ),
      semanticEvidenceLevel:
          (map['semanticEvidenceLevel'] ?? 'ROBUST_SUPPORT').toString(),
    );
  }

  final List<SemanticEvidenceLink> links;
  final OverclaimingAudit overclaimingAudit;
  final String semanticEvidenceLevel;

  Map<String, dynamic> toMap() => {
    'links': links.map((l) => l.toMap()).toList(),
    'overclaimingAudit': overclaimingAudit.toMap(),
    'semanticEvidenceLevel': semanticEvidenceLevel,
  };
}

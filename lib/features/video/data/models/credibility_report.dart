/// 🎯 CREDIBILITY REPORT MODELS (v8.0 — Epistemic Trust Engine)
/// 
/// Maps the multidimensional credibility data from the backend to Flutter.
/// Used for the "Credibility Nutrition Label" UI.
library;

class ScoringFactors {
  final double accuracy;
  final double evidence;
  final double consensus;
  final double consistency;
  final double integrity;
  final double expertise;
  final double freshness;
  final double safety;
  final double honesty;

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
  final double score;
  final int opinionLabeledOpinion;
  final int beliefLabeledBelief;
  final int beliefPresentedAsFact;
  final int opinionPresentedAsFact;
  final int speculationLabeledSpeculation;
  final double assertivenessMismatchPenalty;

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
      assertivenessMismatchPenalty: (map['assertivenessMismatchPenalty'] ?? 0).toDouble(),
    );
  }

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
  final String topic;
  final String claimText;
  final List<Perspective> perspectives;
  final String aiNote;

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

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'claimText': claimText,
    'perspectives': perspectives.map((p) => p.toMap()).toList(),
    'aiNote': aiNote,
  };
}

class Perspective {
  final String label;
  final String explanation;
  final List<String> sources;

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

  Map<String, dynamic> toMap() => {
    'label': label,
    'explanation': explanation,
    'sources': sources,
  };
}

class TrustDeduction {
  final String factor;
  final double points;
  final String reason;

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

  Map<String, dynamic> toMap() => {
    'factor': factor,
    'points': points,
    'reason': reason,
  };
}

class FactCheckStats {
  final int totalClaims;
  final int extractedClaims;
  final int evaluatedClaims;
  final int correct;
  final int mostlyCorrect;
  final int incorrect;
  final int unsupported;
  final int unverifiable;
  final int verifiedTrue;
  final int mostlyTrue;
  final int disputed;
  final int unproven;
  final int misleading;
  final int falseClaim;
  final int religiousBelief;
  final int opinionClaim;
  final int satireClaim;
  final int verificationTimeout;
  final int inconclusive;
  final int limitedSupport;
  final double? checkedClaimsRatio;
  final bool? extractionPartial;
  final double? verificationCoverageRatio;

  FactCheckStats({
    required this.totalClaims,
    required this.extractedClaims,
    required this.evaluatedClaims,
    required this.correct,
    required this.mostlyCorrect,
    required this.incorrect,
    required this.unsupported,
    required this.unverifiable,
    required this.verifiedTrue,
    required this.mostlyTrue,
    required this.disputed,
    required this.unproven,
    required this.misleading,
    required this.falseClaim,
    required this.religiousBelief,
    required this.opinionClaim,
    required this.satireClaim,
    required this.verificationTimeout,
    required this.inconclusive,
    required this.limitedSupport,
    this.checkedClaimsRatio,
    this.extractionPartial,
    this.verificationCoverageRatio,
  });

  factory FactCheckStats.fromMap(Map<String, dynamic> map) {
    return FactCheckStats(
      totalClaims: map['totalClaims'] ?? 0,
      extractedClaims: map['extractedClaims'] ?? 0,
      evaluatedClaims: map['evaluatedClaims'] ?? 0,
      correct: map['correct'] ?? 0,
      mostlyCorrect: map['mostly_correct'] ?? 0,
      incorrect: map['incorrect'] ?? 0,
      unsupported: map['unsupported'] ?? 0,
      unverifiable: map['unverifiable'] ?? 0,
      verifiedTrue: map['verified_true'] ?? 0,
      mostlyTrue: map['mostly_true'] ?? 0,
      disputed: map['disputed'] ?? 0,
      unproven: map['unproven'] ?? 0,
      misleading: map['misleading'] ?? 0,
      falseClaim: map['false_claim'] ?? 0,
      religiousBelief: map['religious_belief'] ?? 0,
      opinionClaim: map['opinion_claim'] ?? 0,
      satireClaim: map['satire_claim'] ?? 0,
      verificationTimeout: map['verification_timeout'] ?? 0,
      inconclusive: map['inconclusive'] ?? 0,
      limitedSupport: map['limited_support'] ?? 0,
      checkedClaimsRatio: (map['checkedClaimsRatio'] as num?)?.toDouble(),
      extractionPartial: map['extractionPartial'],
      verificationCoverageRatio: (map['verificationCoverageRatio'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'totalClaims': totalClaims,
    'extractedClaims': extractedClaims,
    'evaluatedClaims': evaluatedClaims,
    'correct': correct,
    'mostly_correct': mostlyCorrect,
    'incorrect': incorrect,
    'unsupported': unsupported,
    'unverifiable': unverifiable,
    'verified_true': verifiedTrue,
    'mostly_true': mostlyTrue,
    'disputed': disputed,
    'unproven': unproven,
    'misleading': misleading,
    'false_claim': falseClaim,
    'religious_belief': religiousBelief,
    'opinion_claim': opinionClaim,
    'satire_claim': satireClaim,
    'verification_timeout': verificationTimeout,
    'inconclusive': inconclusive,
    'limited_support': limitedSupport,
    'checkedClaimsRatio': checkedClaimsRatio,
    'extractionPartial': extractionPartial,
    'verificationCoverageRatio': verificationCoverageRatio,
  };
}

class HardeningMetadata {
  final bool truthFloorApplied;
  final String? truthFloorReason;
  final DomainOverride? domainOverride;
  final bool consensusGateTriggered;
  final double intentToMisleadScore;
  final List<Map<String, dynamic>> penalties;
  final String auditTimestamp;

  HardeningMetadata({
    required this.truthFloorApplied,
    this.truthFloorReason,
    this.domainOverride,
    required this.consensusGateTriggered,
    required this.intentToMisleadScore,
    required this.penalties,
    required this.auditTimestamp,
  });

  factory HardeningMetadata.fromMap(Map<String, dynamic> map) {
    return HardeningMetadata(
      truthFloorApplied: map['truthFloorApplied'] ?? false,
      truthFloorReason: map['truthFloorReason'],
      domainOverride: map['domainOverride'] != null ? DomainOverride.fromMap(map['domainOverride']) : null,
      consensusGateTriggered: map['consensusGateTriggered'] ?? false,
      intentToMisleadScore: (map['intentToMisleadScore'] ?? 0).toDouble(),
      penalties: List<Map<String, dynamic>>.from(map['penalties'] ?? []),
      auditTimestamp: map['auditTimestamp'] ?? '',
    );
  }

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
  final bool triggered;
  final String? from;
  final String? to;
  final double penalty;
  final double riskDelta;

  DomainOverride({
    required this.triggered,
    this.from,
    this.to,
    required this.penalty,
    required this.riskDelta,
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

  Map<String, dynamic> toMap() => {
    'triggered': triggered,
    'from': from,
    'to': to,
    'penalty': penalty,
    'riskDelta': riskDelta,
  };
}


class UIDriver {
  final String text;
  final String impact; // 'high' | 'medium'

  UIDriver({required this.text, required this.impact});

  factory UIDriver.fromMap(Map<String, dynamic> map) {
    return UIDriver(
      text: map['text'] ?? '',
      impact: map['impact'] ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'impact': impact,
  };
}

class UISource {
  final String title;
  final String? url;
  final String? domain;
  final String trustLevel; // 'High' | 'Medium' | 'Low'
  final String type; // 'Primary' | 'Secondary' | 'Supporting'

  UISource({
    required this.title,
    this.url,
    this.domain,
    required this.trustLevel,
    required this.type,
  });

  factory UISource.fromMap(Map<String, dynamic> map) {
    return UISource(
      title: map['title'] ?? '',
      url: map['url'],
      domain: map['domain'],
      trustLevel: map['trustLevel'] ?? 'Medium',
      type: map['type'] ?? 'Secondary',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'domain': domain,
    'trustLevel': trustLevel,
    'type': type,
  };
}

class EvidenceCoverage {
  final int checked;
  final int total;
  final String label;

  EvidenceCoverage({
    required this.checked,
    required this.total,
    required this.label,
  });

  factory EvidenceCoverage.fromMap(Map<String, dynamic> map) {
    return EvidenceCoverage(
      checked: map['checked'] ?? 0,
      total: map['total'] ?? 0,
      label: map['label'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'checked': checked,
    'total': total,
    'label': label,
  };
}

class UISummary {
  final double? rating;
  final double? truthScore;
  final double? honestyScore;
  final double? rationalityScore;
  final String label;
  final String confidence;
  final String? confidenceInterpretation;
  final String? analysisState;
  final EvidenceCoverage? evidenceCoverage;
  final FactCheckStats? factCheckStats;

  UISummary({
    this.rating,
    this.truthScore,
    this.honestyScore,
    this.rationalityScore,
    required this.label,
    required this.confidence,
    this.confidenceInterpretation,
    this.analysisState,
    this.evidenceCoverage,
    this.factCheckStats,
  });

  factory UISummary.fromMap(Map<String, dynamic> map) {
    return UISummary(
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      truthScore: map['truthScore'] != null ? (map['truthScore'] as num).toDouble() : null,
      honestyScore: map['honestyScore'] != null ? (map['honestyScore'] as num).toDouble() : null,
      rationalityScore: map['rationalityScore'] != null ? (map['rationalityScore'] as num).toDouble() : null,
      label: map['label'] ?? '',
      confidence: map['confidence'] ?? 'low',
      confidenceInterpretation: map['confidenceInterpretation'],
      analysisState: map['analysisState'],
      evidenceCoverage: map['evidenceCoverage'] != null 
        ? EvidenceCoverage.fromMap(map['evidenceCoverage']) 
        : null,
      factCheckStats: map['evidenceCoverage'] != null // Note: backend often nests stats under coverage in uiReport
        ? null 
        : (map['factCheckStats'] != null ? FactCheckStats.fromMap(map['factCheckStats']) : null),
    );
  }

  Map<String, dynamic> toMap() => {
    'rating': rating,
    'truthScore': truthScore,
    'honestyScore': honestyScore,
    'rationalityScore': rationalityScore,
    'label': label,
    'confidence': confidence,
    'confidenceInterpretation': confidenceInterpretation,
    'analysisState': analysisState,
    'evidenceCoverage': evidenceCoverage?.toMap(),
    'factCheckStats': factCheckStats?.toMap(),
  };
}

class ClaimResult {
  final String claimId;
  final String text;
  final String verdict;
  final String bucket;
  final List<String> sources;
  final String? reasoning;
  final String? verificationMethod;
  final String? displayLabel;
  final bool? isLowRiskTrivia;

  ClaimResult({
    required this.claimId,
    required this.text,
    required this.verdict,
    required this.bucket,
    this.sources = const [],
    this.reasoning,
    this.verificationMethod,
    this.displayLabel,
    this.isLowRiskTrivia,
  });

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    return ClaimResult(
      claimId: map['claimId'] ?? '',
      text: map['text'] ?? '',
      verdict: map['verdict'] ?? map['status'] ?? 'unverified',
      bucket: map['bucket'] ?? 'FACTUAL',
      sources: List<String>.from(map['sources'] ?? []),
      reasoning: map['reasoning'],
      verificationMethod: map['verificationMethod'],
      displayLabel: map['displayLabel'],
      isLowRiskTrivia: map['isLowRiskTrivia'],
    );
  }

  Map<String, dynamic> toMap() => {
    'claimId': claimId,
    'text': text,
    'verdict': verdict,
    'bucket': bucket,
    'sources': sources,
    'reasoning': reasoning,
    'verificationMethod': verificationMethod,
    'displayLabel': displayLabel,
    'isLowRiskTrivia': isLowRiskTrivia,
  };
}

class UIReport {
  final UISummary summary;
  final String quickVerdict;
  final String narrative;
  final String riskNote;
  final List<UIDriver> positiveDrivers;
  final List<UIDriver> negativeDrivers;
  final List<UISource> sources;
  final String conclusion;
  final List<String> counterSignals;
  final List<ClaimResult> keyClaims;
  final bool reviewRequestEnabled;

  UIReport({
    required this.summary,
    required this.quickVerdict,
    required this.narrative,
    required this.riskNote,
    required this.positiveDrivers,
    required this.negativeDrivers,
    required this.sources,
    required this.conclusion,
    this.keyClaims = const [],
    this.counterSignals = const [],
    this.reviewRequestEnabled = true,
  });

  factory UIReport.fromMap(Map<String, dynamic> map) {
    return UIReport(
      summary: UISummary.fromMap(map['summary'] ?? {}),
      quickVerdict: map['quickVerdict'] ?? '',
      narrative: map['narrative'] ?? '',
      riskNote: map['riskNote'] ?? '',
      positiveDrivers: (map['positiveDrivers'] as List? ?? [])
          .map((d) => UIDriver.fromMap(d))
          .toList(),
      negativeDrivers: (map['negativeDrivers'] as List? ?? [])
          .map((d) => UIDriver.fromMap(d))
          .toList(),
      sources: (map['sources'] as List? ?? [])
          .map((s) => UISource.fromMap(s))
          .toList(),
      conclusion: map['conclusion'] ?? '',
      keyClaims: (map['keyClaims'] as List? ?? [])
          .map((c) => ClaimResult.fromMap(c))
          .toList(),
      counterSignals: List<String>.from(map['counterSignals'] ?? []),
      reviewRequestEnabled: map['reviewRequestEnabled'] ?? true,
    );
  }

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
      'keyClaims': keyClaims.map((c) => c.toMap()).toList(),
      'counterSignals': counterSignals,
      'reviewRequestEnabled': reviewRequestEnabled,
    };
  }

  double? get rating => summary.rating;
  double? get truthScore => summary.truthScore;
  double? get honestyScore => summary.honestyScore;
  double? get rationalityScore => summary.rationalityScore;
  String get label => summary.label;
  String get confidence => summary.confidence;
  String? get analysisState => summary.analysisState;
}





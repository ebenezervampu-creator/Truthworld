/// 🎯 CREDIBILITY REPORT MODELS (v8.0 — Epistemic Trust Engine)
/// 
/// Maps the multidimensional credibility data from the backend to Flutter.
/// Used for the "Credibility Nutrition Label" UI.
library;

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
      assertivenessMismatchPenalty: (map['assertivenessMismatchPenalty'] ?? 0).toDouble(),
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

class HardeningMetadata {

  HardeningMetadata({
    required this.truthFloorApplied,
    required this.consensusGateTriggered, required this.intentToMisleadScore, required this.penalties, required this.auditTimestamp, this.truthFloorReason,
    this.domainOverride,
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
    required this.penalty, required this.riskDelta, this.from,
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


class UIDriver { // 'high' | 'medium'

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
    required this.trustLevel, required this.type, this.url,
    this.domain,
    this.citationCount = 0,
    this.snippet,
    this.retrievalProvider,
  });

  factory UISource.fromMap(Map<String, dynamic> map) {
    return UISource(
      title: map['title'] ?? '',
      url: map['url'],
      domain: map['domain'],
      trustLevel: map['trustLevel'] ?? 'Medium',
      type: map['type'] ?? 'Secondary',
      citationCount: (map['citationCount'] as num?)?.toInt() ?? 0,
      snippet: map['snippet'],
      retrievalProvider: map['retrievalProvider'],
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

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'domain': domain,
    'trustLevel': trustLevel,
    'type': type,
    'citationCount': citationCount,
    'snippet': snippet,
    'retrievalProvider': retrievalProvider,
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
  });

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    return ClaimResult(
      text: map['text'] ?? '',
      verdict: map['verdict'] ?? '',
      start: (map['start'] as num?)?.toDouble(),
      end: (map['end'] as num?)?.toDouble(),
      isLowRiskTrivia: map['isLowRiskTrivia'] as bool?,
      effectiveSources: (map['effectiveSources'] as List? ?? [])
          .map((s) => UISource.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      classificationConfidence: (map['classificationConfidence'] as num?)?.toDouble(),
      historicalEvidenceConfidence: (map['historicalEvidenceConfidence'] as num?)?.toDouble(),
      evidenceDetails: map['evidenceDetails'] != null
          ? Map<String, String>.from(map['evidenceDetails'])
          : null,
      consensusDetails: map['consensusDetails'] != null
          ? Map<String, String>.from(map['consensusDetails'])
          : null,
      claimDomain: map['claimDomain'],
      claimNature: map['claimNature'],
      verdictBasis: map['verdictBasis'] != null
          ? List<String>.from(map['verdictBasis'])
          : null,
      evidence: (map['evidence'] as List?)
          ?.map((e) => UIEvidence.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      consensus: (map['consensus'] as List?)
          ?.map((c) => UIConsensus.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
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
  };
}

class UISummary {

  UISummary({
    required this.label, required this.confidence, this.rating,
    this.truthScore,
    this.honestyScore,
    this.rationalityScore,
    this.confidenceInterpretation,
    this.analysisState,
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
    );
  }
  final double? rating;
  final double? truthScore;
  final double? honestyScore;
  final double? rationalityScore;
  final String label;
  final String confidence;
  final String? confidenceInterpretation;
  final String? analysisState;

  Map<String, dynamic> toMap() => {
    'rating': rating,
    'truthScore': truthScore,
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
    this.counterSignals = const [],
    this.reviewRequestEnabled = true,
    this.keyClaims = const [],
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
      counterSignals: List<String>.from(map['counterSignals'] ?? []),
      reviewRequestEnabled: map['reviewRequestEnabled'] ?? true,
      keyClaims: (map['keyClaims'] as List? ?? [])
          .map((c) => ClaimResult.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
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
  final List<String> counterSignals;
  final bool reviewRequestEnabled;
  final List<ClaimResult> keyClaims;

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
      'counterSignals': counterSignals,
      'reviewRequestEnabled': reviewRequestEnabled,
      'keyClaims': keyClaims.map((c) => c.toMap()).toList(),
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





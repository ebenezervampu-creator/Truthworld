/**
 * 🎯 CATEGORY WEIGHTS SERVICE (v8.0 — Epistemic Trust Engine)
 * 
 * Drop-in replacement for getVerticalWeights() in scoringEngine.ts.
 * Adds the 9th dimension (honesty), category-specific weight profiles,
 * penalty multipliers, harm cap logic, and contextual flag detection.
 */

import {
  ClaimType, ClaimStatus, ClaimSeverity, ClaimAssertiveness, ClaimStrength,
  InstitutionalTrustFactors, VideoCategory, CategoryWeightProfile,
  ContextualFlag, HonestyBreakdown, HarmCapResult, TrustLabel, HardeningMetadata,
  ClaimNature, FramingStyle, EvidenceLevel
} from '../types';

// ─── Weight Profiles Per Category ────────────────────────────────────────────

const WEIGHT_PROFILES: Record<VideoCategory, CategoryWeightProfile> = {
  science: {
    category: 'science',
    weights: { accuracy: 30, evidence: 20, consensus: 10, consistency: 5, integrity: 5, expertise: 5, freshness: 5, safety: 10, honesty: 10 },
    falsehood_penalty: -3.0, misleading_penalty: -1.5,
    harm_cap: 3.0, harm_cap_severity: ['high', 'extreme'],
  },
  science_trivia: {
    category: 'science_trivia',
    weights: { accuracy: 15, evidence: 10, consensus: 5, consistency: 10, integrity: 10, expertise: 5, freshness: 10, safety: 5, honesty: 30 },
    falsehood_penalty: -1.5, misleading_penalty: -0.7,
    harm_cap: null, harm_cap_severity: [],
  },
  health: {
    category: 'health',
    weights: { accuracy: 30, evidence: 20, consensus: 10, consistency: 5, integrity: 5, expertise: 5, freshness: 5, safety: 10, honesty: 10 },
    falsehood_penalty: -3.0, misleading_penalty: -1.5,
    harm_cap: 3.0, harm_cap_severity: ['high', 'extreme'],
  },
  financial: {
    category: 'financial',
    weights: { accuracy: 25, evidence: 20, consensus: 10, consistency: 5, integrity: 10, expertise: 10, freshness: 10, safety: 5, honesty: 5 },
    falsehood_penalty: -3.5, misleading_penalty: -2.0,
    harm_cap: 3.0, harm_cap_severity: ['high', 'extreme'],
  },
  legal: {
    category: 'legal',
    weights: { accuracy: 25, evidence: 20, consensus: 10, consistency: 10, integrity: 5, expertise: 15, freshness: 5, safety: 5, honesty: 5 },
    falsehood_penalty: -3.0, misleading_penalty: -1.5,
    harm_cap: null, harm_cap_severity: [],
  },
  news: {
    category: 'news',
    weights: { accuracy: 25, evidence: 15, consensus: 10, consistency: 10, integrity: 10, expertise: 5, freshness: 10, safety: 5, honesty: 10 },
    falsehood_penalty: -3.0, misleading_penalty: -1.5,
    harm_cap: null, harm_cap_severity: [],
  },
  politics: {
    category: 'politics',
    weights: { accuracy: 25, evidence: 15, consensus: 10, consistency: 10, integrity: 10, expertise: 5, freshness: 10, safety: 5, honesty: 10 },
    falsehood_penalty: -3.0, misleading_penalty: -1.5,
    harm_cap: null, harm_cap_severity: [],
  },
  history: {
    category: 'history',
    weights: { accuracy: 25, evidence: 20, consensus: 15, consistency: 10, integrity: 5, expertise: 10, freshness: 5, safety: 0, honesty: 10 },
    falsehood_penalty: -2.5, misleading_penalty: -1.0,
    harm_cap: null, harm_cap_severity: [],
  },
  religion: {
    category: 'religion',
    weights: { accuracy: 10, evidence: 10, consensus: 5, consistency: 10, integrity: 5, expertise: 10, freshness: 5, safety: 5, honesty: 40 },
    falsehood_penalty: -2.0, misleading_penalty: -1.0,
    harm_cap: null, harm_cap_severity: [],
  },
  culture: {
    category: 'culture',
    weights: { accuracy: 15, evidence: 10, consensus: 5, consistency: 10, integrity: 5, expertise: 10, freshness: 5, safety: 5, honesty: 35 },
    falsehood_penalty: -2.0, misleading_penalty: -1.0,
    harm_cap: null, harm_cap_severity: [],
  },
  education: {
    category: 'education',
    weights: { accuracy: 30, evidence: 20, consensus: 10, consistency: 10, integrity: 5, expertise: 10, freshness: 5, safety: 5, honesty: 5 },
    falsehood_penalty: -2.5, misleading_penalty: -1.0,
    harm_cap: null, harm_cap_severity: [],
  },
  opinion: {
    category: 'opinion',
    weights: { accuracy: 10, evidence: 10, consensus: 5, consistency: 15, integrity: 10, expertise: 5, freshness: 5, safety: 5, honesty: 35 },
    falsehood_penalty: -1.5, misleading_penalty: -0.5,
    harm_cap: null, harm_cap_severity: [],
  },
  podcast: {
    category: 'podcast',
    weights: { accuracy: 10, evidence: 10, consensus: 5, consistency: 15, integrity: 10, expertise: 5, freshness: 5, safety: 5, honesty: 35 },
    falsehood_penalty: -1.5, misleading_penalty: -0.5,
    harm_cap: null, harm_cap_severity: [],
  },
  entertainment: {
    category: 'entertainment',
    weights: { accuracy: 10, evidence: 5, consensus: 5, consistency: 10, integrity: 10, expertise: 5, freshness: 10, safety: 10, honesty: 35 },
    falsehood_penalty: -1.0, misleading_penalty: -0.5,
    harm_cap: null, harm_cap_severity: [],
  },
  unknown: {
    category: 'unknown',
    weights: { accuracy: 20, evidence: 15, consensus: 10, consistency: 10, integrity: 10, expertise: 10, freshness: 10, safety: 5, honesty: 10 },
    falsehood_penalty: -2.0, misleading_penalty: -1.0,
    harm_cap: null, harm_cap_severity: [],
  },
};

// ─── Risk Hierarchy (v8.1 Stable) ───────────────────────────────────────────

const RISK_HIERARCHY: VideoCategory[] = [
  'health', 
  'financial',
  'science', 
  'legal',
  'news', 
  'politics', 
  'history', 
  'education', 
  'science_trivia',
  'opinion', 
  'podcast', 
  'culture', 
  'religion', 
  'entertainment', 
  'unknown'
];

function getRiskRank(cat: VideoCategory): number {
  const index = RISK_HIERARCHY.indexOf(cat);
  return index === -1 ? 99 : index;
}

// ─── Category Mapping (upload UI → internal key) ────────────────────────────

const CATEGORY_MAP: Record<string, VideoCategory> = {
  'science': 'science', 'technology': 'science', 'tech': 'science', 'nature & wildlife': 'science', 'automotive': 'science',
  'health': 'health', 'health & fitness': 'health', 'medicine': 'health', 'medical': 'health',
  'financial': 'financial', 'finance': 'financial', 'business & finance': 'financial', 'investing': 'financial', 'stocks': 'financial', 'crypto': 'financial', 'money': 'financial', 'economic': 'financial',
  'legal': 'legal', 'law': 'legal', 'court': 'legal', 'lawyer': 'legal', 'judiciary': 'legal', 'rights': 'legal',
  'news': 'news', 'breaking news': 'news',
  'politics': 'politics', 'political': 'politics',
  'history': 'history', 'historical': 'history', 'geography': 'history', 'documentary': 'history',
  'religion': 'religion', 'religious': 'religion', 'spirituality': 'religion',
  'culture': 'culture', 'cultural': 'culture', 'society': 'culture', 'art & design': 'culture',
  'education': 'education', 'educational': 'education', 'tutorial': 'education', 'how-to': 'education', 'diy & how-to': 'education',
  'opinion': 'opinion', 'editorial': 'opinion', 'commentary': 'opinion', 'motivation': 'opinion',
  'podcast': 'podcast', 'interview': 'podcast',
  'entertainment': 'entertainment', 'comedy': 'entertainment', 'lifestyle': 'entertainment', 'satire': 'entertainment', 'gaming': 'entertainment', 'sports': 'entertainment', 'movies': 'entertainment', 'tv shows': 'entertainment', 'tv_shows': 'entertainment', 'vlogs': 'entertainment', 'people & blogs': 'entertainment', 'people_blogs': 'entertainment', 'music': 'entertainment', 'animation': 'entertainment', 'short films': 'entertainment', 'kids & family': 'entertainment', 'kids_family': 'entertainment', 'fashion & beauty': 'entertainment', 'food & cooking': 'entertainment', 'animals & pets': 'entertainment', 'other': 'entertainment',
};

export function mapUploadCategory(raw: string | undefined | null): VideoCategory {
  if (!raw) return 'unknown';
  return CATEGORY_MAP[raw.trim().toLowerCase()] ?? 'unknown';
}

export function getCategoryWeights(
  uploadCategory: string | undefined | null,
  detectedVertical?: string | null,
  primaryIntent?: string | null
): CategoryWeightProfile {
  const upload = mapUploadCategory(uploadCategory);
  const detected = mapUploadCategory(detectedVertical);

  // v8.1 Stable: Always use the higher-risk profile (lower index in RISK_HIERARCHY)
  let effectiveCategory = getRiskRank(detected) < getRiskRank(upload) ? detected : upload;
  
  // v8.5 Calibration: Downgrade science to science_trivia if intent is entertainment
  if (effectiveCategory === 'science' && primaryIntent === 'entertainment') {
    effectiveCategory = 'science_trivia';
  }

  return WEIGHT_PROFILES[effectiveCategory] || WEIGHT_PROFILES['unknown'];
}

// ─── Honesty Dimension ──────────────────────────────────────────────────────

interface ClaimForHonesty {
  claimType: ClaimType;
  assertiveness: ClaimAssertiveness;
  status: ClaimStatus;
}

function getClaimHonestyContribution(c: ClaimForHonesty): number {
  const { claimType, assertiveness } = c;

  // Faith/belief claims — reward humble framing, penalise authority
  if (claimType === 'doctrinal_metaphysical' || (claimType as string) === 'faith_based') {
    if (assertiveness === 'casual' || assertiveness === 'moderate') return 1.0;
    if (assertiveness === 'confident') return 0.5;
    if (assertiveness === 'authoritative') return -0.5;
    if (assertiveness === 'absolute') return -2.0;
  }

  // Opinion/editorial claims
  if (claimType === 'opinion' || (claimType as string) === 'editorial') {
    if (assertiveness === 'casual') return 1.0;
    if (assertiveness === 'moderate') return 0.8;
    if (assertiveness === 'confident') return 0.3;
    if (assertiveness === 'authoritative') return -0.3;
    if (assertiveness === 'absolute') return -1.5;
  }

  // Speculation/projection
  if (claimType === 'speculation') {
    if (assertiveness === 'absolute') return -1.0;
    if (assertiveness === 'authoritative') return -0.5;
    return 0.8;
  }

  // Empirical claims — penalise confidently wrong
  if (claimType === 'empirical' || (claimType as string) === 'statistical') {
    if (c.status === 'false_claim' && (assertiveness === 'authoritative' || assertiveness === 'absolute')) return -1.0;
    return 0;
  }

  if (claimType === 'satirical') return 0.5;
  return 0;
}

export function computeHonestyScore(claims: ClaimForHonesty[]): HonestyBreakdown {
  if (claims.length === 0) {
    // v8.6: Default to neutral-high (85) when no verifiable claims are present.
    // 7.0 was a catastrophic typo that penalized harmless expressive content.
    return { score: 85.0, opinionLabeledOpinion: 0, beliefLabeledBelief: 0, beliefPresentedAsFact: 0, opinionPresentedAsFact: 0, speculationLabeledSpeculation: 0, assertivenessMismatchPenalty: 0 };
  }

  let total = 0;
  let opinionLabeledOpinion = 0, beliefLabeledBelief = 0;
  let beliefPresentedAsFact = 0, opinionPresentedAsFact = 0;
  let speculationLabeledSpeculation = 0, assertivenessMismatchPenalty = 0;

  for (const c of claims) {
    const contribution = getClaimHonestyContribution(c);
    total += contribution;
    if (contribution < 0) assertivenessMismatchPenalty += Math.abs(contribution);

    const isFaith = c.claimType === 'doctrinal_metaphysical' || (c.claimType as string) === 'faith_based';
    const isOpinion = c.claimType === 'opinion' || (c.claimType as string) === 'editorial';

    if (isFaith && (c.assertiveness === 'authoritative' || c.assertiveness === 'absolute')) beliefPresentedAsFact++;
    if (isFaith && (c.assertiveness === 'casual' || c.assertiveness === 'moderate')) beliefLabeledBelief++;
    if (isOpinion && (c.assertiveness === 'authoritative' || c.assertiveness === 'absolute')) opinionPresentedAsFact++;
    if (isOpinion && (c.assertiveness === 'casual' || c.assertiveness === 'moderate')) opinionLabeledOpinion++;
    if (c.claimType === 'speculation' && c.assertiveness === 'casual') speculationLabeledSpeculation++;
  }

  const avg = total / claims.length;
  const score = Math.max(0, Math.min(100, 70 + avg * 30));

  return {
    score: Math.round(score),
    opinionLabeledOpinion, beliefLabeledBelief,
    beliefPresentedAsFact, opinionPresentedAsFact,
    speculationLabeledSpeculation,
    assertivenessMismatchPenalty: Math.round(assertivenessMismatchPenalty * 100) / 100,
  };
}

// ─── Harm Cap Enforcement ───────────────────────────────────────────────────

interface ClaimForHarmCap {
  status: ClaimStatus;
  severity?: ClaimSeverity;
  claimType: ClaimType;
}

export function applyHarmCap(
  rawScore: number,
  claims: ClaimForHarmCap[],
  profile: CategoryWeightProfile,
): HarmCapResult {
  if (profile.harm_cap === null) return { applied: false };

  const dangerous = claims.filter(c =>
    c.status === 'false_claim' &&
    c.severity !== undefined &&
    profile.harm_cap_severity.includes(c.severity),
  );
  if (dangerous.length === 0 || rawScore <= profile.harm_cap!) return { applied: false };

  return {
    applied: true,
    reason: `${dangerous.length} dangerous ${profile.category} claim(s) with severity "${dangerous[0].severity}". Score capped at ${profile.harm_cap}/100 to protect viewers.`,
    originalScore: Math.round(rawScore),
    cappedScore: profile.harm_cap!,
  };
}

// ─── Contextual Flag Detection ──────────────────────────────────────────────

const MULTI_PERSPECTIVE_TOPICS = [
  {
    keywords: ['egg', 'vegetarian', 'veg', 'non-veg', 'non veg'],
    topic: 'Classification of eggs as vegetarian or non-vegetarian',
    perspectives: [
      { label: 'Biological', explanation: 'Unfertilised commercial eggs contain no embryo.' },
      { label: 'Indian vegetarian tradition (FSSAI)', explanation: 'India\'s FSSAI classifies eggs as non-vegetarian.' },
      { label: 'Western ovo-vegetarian', explanation: 'Most Western frameworks include eggs in vegetarian diets.' },
      { label: 'Vegan', explanation: 'All animal-derived products including eggs are excluded.' },
    ],
    aiNote: 'The classification of eggs varies by biological definition, cultural tradition, and dietary framework. No single answer is universally correct.',
  },
  {
    keywords: ['aryan invasion', 'aryan migration', 'indo-aryan'],
    topic: 'Origins of Indo-Aryan peoples',
    perspectives: [
      { label: 'Steppe migration hypothesis', explanation: 'Mainstream archaeogenetics consensus: migration from Pontic steppe ~2000 BCE.' },
      { label: 'Out of India hypothesis', explanation: 'Alternative view: Indo-European languages originated in South Asia.' },
    ],
    aiNote: 'This is an actively debated topic. Mainstream scientific consensus favours steppe migration but the picture is contested.',
  },
  {
    keywords: ['jerusalem', 'temple mount', 'al-aqsa'],
    topic: 'Religious significance of Jerusalem / Temple Mount',
    perspectives: [
      { label: 'Jewish tradition', explanation: 'Site of the First and Second Temples; holiest site in Judaism.' },
      { label: 'Islamic tradition', explanation: 'Al-Aqsa Mosque is the third holiest site in Islam.' },
      { label: 'Christian tradition', explanation: 'City of crucifixion and resurrection.' },
    ],
    aiNote: 'Jerusalem\'s status involves deeply held religious beliefs and unresolved political disputes.',
  },
];

export function detectContextualFlags(
  claims: ScoredClaim[],
  overallConsensusScore: number = 50,
): ContextualFlag[] {
  const flags: ContextualFlag[] = [];
  const corpus = claims.map(c => c.text).join(' ').toLowerCase();

  for (const topic of MULTI_PERSPECTIVE_TOPICS) {
    if (!topic.keywords.some(kw => corpus.includes(kw))) continue;

    // v8.1 Stable: Evidence-Aware Consensus Gating
    // Prevent false equivalence for fringe claims (<20% consensus) UNLESS evidence quality is high (Emerging Science)
    const matchingClaims = claims.filter(c => topic.keywords.some(kw => c.text.toLowerCase().includes(kw)));
    const maxEvidence = Math.max(...matchingClaims.map(c => (c as any).evidenceConfidence || 0.5));
    
    if (overallConsensusScore < 20 && maxEvidence < 0.75) {
      continue; // Fringe claim suppression
    }

    const trigger = matchingClaims[0]?.text ?? '';
    flags.push({ topic: topic.topic, claimText: trigger, perspectives: topic.perspectives, aiNote: topic.aiNote });
  }
  return flags;
}

// ─── Epistemic Hardening (v8.1 Stable) ───────────────────────────────────────

/**
 * 1. Severity-Aware Truth Floor
 * Tiered caps based on the harm severity of incorrect empirical claims.
 */
function applySeverityAwareTruthFloor(
  score: number,
  claims: ScoredClaim[],
): { cappedScore: number; applied: boolean; reason?: string } {
  const empiricalIncorrect = claims.filter(c => 
    (c.claimType === 'empirical' || c.claimType === 'pseudo_scientific') && 
    (c.status === 'false_claim' || (c.status as string) === 'false')
  );

  if (empiricalIncorrect.length === 0) return { cappedScore: score, applied: false };

  // Determine cap based on highest severity
  let cap = 55; // Default Low Harm floor
  let highestSeverity: ClaimSeverity = 'low';

  for (const c of empiricalIncorrect) {
    if (c.severity === 'extreme') { cap = 20; highestSeverity = 'extreme'; break; }
    if (c.severity === 'high') { cap = Math.min(cap, 30); highestSeverity = 'high'; }
    if (c.severity === 'medium') { cap = Math.min(cap, 45); highestSeverity = 'medium'; }
  }

  const applied = score > cap;
  return {
    cappedScore: applied ? cap : score,
    applied,
    reason: applied ? `TRUTH_FLOOR: Incorrect empirical claim (${highestSeverity} harm) caps score at ${cap/10}` : undefined
  };
}

/**
 * 2. Intent to Mislead Detection
 * Heuristic based on "honesty washing" signals (belief framing + empirical falsehood).
 */
function computeIntentToMislead(claims: ScoredClaim[]): number {
  let score = 0;
  
  // Signal 1: Honesty Washing Risk (Gemini flag)
  const washingRisk = claims.filter(c => (c as any).honestyWashingRisk === true).length;
  score += washingRisk * 25;

  // Signal 2: High assertiveness + High severity incorrectness
  const aggressiveMisinfo = claims.filter(c => 
    (c.assertiveness === 'authoritative' || c.assertiveness === 'absolute') && 
    c.status === 'false_claim' && 
    (c.severity === 'high' || c.severity === 'extreme')
  ).length;
  score += aggressiveMisinfo * 35;

  // Signal 3: Hedging pattern (Strategic ambiguity)
  const isHedged = (c: ScoredClaim) => (c as any).claimStrength === 'hedged' || c.assertiveness === 'casual';
  const hedgedFalsehoods = claims.filter(c => isHedged(c) && c.status === 'false_claim').length;
  score += hedgedFalsehoods * 15;

  return Math.min(100, score);
}

// ─── Composite Score Computation ────────────────────────────────────────────

interface ScoredClaim {
  status: ClaimStatus;
  severity?: ClaimSeverity;
  claimNature: ClaimNature;
  framingStyle: FramingStyle;
  evidenceLevel: EvidenceLevel;
  honestyWashingRisk?: boolean;
  text: string;
  claimType: ClaimType;
  assertiveness: ClaimAssertiveness;
  claimStrength?: ClaimStrength;
}

export interface ComputedScore {
  finalScore: number;
  rawWeightedScore: number;
  dimensions: InstitutionalTrustFactors;
  profile: CategoryWeightProfile;
  harmCap: HarmCapResult;
  honestyBreakdown: HonestyBreakdown;
  contextualFlags: ContextualFlag[];
  penaltyApplied: number;
  
  // v8.1 Stable Fields
  hardeningMetadata?: HardeningMetadata;
  intentToMisleadScore?: number;
  effectiveCategory?: string;
}

/**
 * Main entry point — replaces the old getVerticalWeights() scoring path.
 * 
 * @param baseDimensions The 8 existing dimension scores (0–100 each) from the current engine.
 * @param claims All verified claims for the video.
 * @param uploadCategory The category string from the video's upload metadata.
 * @param detectedVertical Fallback from vertical detector.
 */
export function computeCategoryAwareScore(
  baseDimensions: Omit<InstitutionalTrustFactors, 'honesty'>,
  claims: ScoredClaim[],
  uploadCategory: string | undefined | null,
  detectedVertical?: string | null,
  overallConsensus: number = 50,
  primaryIntent?: string | null
): ComputedScore {
  const profile = getCategoryWeights(uploadCategory, detectedVertical, primaryIntent);
  const upload = mapUploadCategory(uploadCategory);
  const detected = mapUploadCategory(detectedVertical);

  // 1. Domain Mismatch & Risk Hierarchy
  const hardeningMetadata: HardeningMetadata = {
    truthFloorApplied: false,
    domainOverride: {
      triggered: getRiskRank(detected) < getRiskRank(upload),
      from: upload,
      to: profile.category,
      penalty: 0,
      riskDelta: getRiskRank(upload) - getRiskRank(detected)
    },
    consensusGateTriggered: false,
    intentToMisleadScore: 0,
    penalties: [],
    auditTimestamp: new Date().toISOString()
  };

  if (hardeningMetadata.domainOverride?.triggered) {
    // Apply adaptive domain mismatch penalty (base 15% * risk delta)
    const penalty = Math.min(0.30, 0.15 * Math.max(1, hardeningMetadata.domainOverride.riskDelta));
    hardeningMetadata.domainOverride.penalty = penalty;
    hardeningMetadata.penalties.push({ type: 'DOMAIN_MISMATCH', value: penalty });
  }

  // 2. Compute honesty dimension
  const honestyBreakdown = computeHonestyScore(claims);

  // 3. Merge all 9 dimensions
  const dimensions: InstitutionalTrustFactors = {
    ...baseDimensions,
    honesty: honestyBreakdown.score,
  };

  // 4. Weighted sum
  const totalWeight = Object.values(profile.weights).reduce((s, w) => s + w, 0) || 100;
  let weightedSum = 0;
  for (const key of Object.keys(dimensions) as (keyof InstitutionalTrustFactors)[]) {
    const weight = profile.weights[key] || 0;
    weightedSum += ((dimensions[key] || 0) * weight) / totalWeight;
  }

  // 5. Apply per-claim penalties
  let penaltyApplied = 0;
  for (const claim of claims) {
    if (claim.status === 'false_claim' || (claim.status as string) === 'false') {
      penaltyApplied += Math.abs(profile.falsehood_penalty);
      weightedSum = Math.max(0, weightedSum + profile.falsehood_penalty);
    } else if (['needs_context', 'misleading', 'missing_context', 'mostly_true', 'disputed'].includes(claim.status as string)) {
      penaltyApplied += Math.abs(profile.misleading_penalty);
      weightedSum = Math.max(0, weightedSum + profile.misleading_penalty);
    }
  }

  // 6. Intent to Mislead Penalty (v8.1)
  const intentScore = computeIntentToMislead(claims);
  hardeningMetadata.intentToMisleadScore = intentScore;
  const intentPenaltyMultiplier = 1 - (intentScore / 100) * 0.3; // Up to 30% reduction
  weightedSum *= intentPenaltyMultiplier;
  if (intentScore > 0) {
    hardeningMetadata.penalties.push({ type: 'INTENT_TO_MISLEAD', value: 1 - intentPenaltyMultiplier });
  }

  // 7. Domain Override Penalty
  if (hardeningMetadata.domainOverride.triggered) {
    weightedSum *= (1 - hardeningMetadata.domainOverride.penalty);
  }

  const rawWeightedScore = Math.min(100, Math.max(0, weightedSum));

  // 8. Severity-Aware Truth Floor
  const truthFloor = applySeverityAwareTruthFloor(rawWeightedScore, claims);
  if (truthFloor.applied) {
    hardeningMetadata.truthFloorApplied = true;
    hardeningMetadata.truthFloorReason = truthFloor.reason;
  }

  // 9. Apply harm cap (Legacy safety veto)
  const harmCap = applyHarmCap(truthFloor.cappedScore, claims, profile);
  const finalScore = harmCap.applied ? harmCap.cappedScore! : truthFloor.cappedScore;

  // 10. Detect contextual flags (with consensus gating)
  const contextualFlags = detectContextualFlags(claims, overallConsensus);
  if (contextualFlags.length < detectContextualFlags(claims, 100).length) {
    hardeningMetadata.consensusGateTriggered = true;
  }

  return {
    finalScore: Math.round(finalScore),
    rawWeightedScore: Math.round(rawWeightedScore),
    dimensions,
    profile,
    harmCap,
    honestyBreakdown,
    contextualFlags,
    penaltyApplied: Math.round(penaltyApplied * 10) / 10,
    hardeningMetadata,
    intentToMisleadScore: intentScore,
    effectiveCategory: profile.category
  };
}

// ─── Trust Label Resolver ───────────────────────────────────────────────────

export function getTrustLabelFromScore(score: number | null, harmCapApplied: boolean, category?: VideoCategory): TrustLabel {
  if (score === null) return 'Confidence Evolving';
  if (harmCapApplied) return 'Safety Capped \u2013 Significant Concerns';
  
  const s = score * 10; // 0-100 scale for comparison
  
  if (s >= 90) return 'Highly Reliable';
  if (s >= 70) return 'Reliable';
  if (s >= 50) return 'Mixed';
  if (s >= 30) return 'Low';
  return 'Misleading';
}

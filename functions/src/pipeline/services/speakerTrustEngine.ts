/**
 * 👥 SPEAKER TRUST ENGINE (v5.0)
 *
 * Computes per-speaker trust breakdown from verified claims.
 * Fills the previously empty `speakers` array in CredibilityResult.
 *
 * Architecture:
 *   1. Group verified claims by speaker field
 *   2. Compute per-speaker accuracy, claim count, trust index
 *   3. Query historical speaker data (future: speaker_registry collection)
 *   4. Return SpeakerBreakdown[] for inclusion in results
 *
 * IMPORTANT: Speaker history should be used as a PRIOR (10-15% weight),
 * never as a dominant signal. Current claim truth always takes priority.
 */

import { VerifiedClaim, SpeakerBreakdown, ClaimStatus } from "../types";
import { logger } from "../utils/logger";

/** Status categories for speaker scoring */
const POSITIVE_STATUSES: ClaimStatus[] = [
  'verified_true', 'mostly_true', 'correct', 'mostly_correct',
];
const NEGATIVE_STATUSES: ClaimStatus[] = [
  'false_claim', 'incorrect', 'verified_false', 'historical_consensus_denial', 'incorrect_citation',
];
const NEUTRAL_STATUSES: ClaimStatus[] = [
  'inconclusive', 'limited_support', 'unverified', 'disputed', 'misleading', 'needs_context',
  'partially_true', 'rhetorical_exaggeration', 'unproven', 'unsupported', 'verification_timeout',
];
const OPINION_STATUSES: (ClaimStatus | string)[] = [
  'opinion_claim', 'religious_belief', 'satire_claim', 'opinion', 'faith_based_claim', 'faith_context',
  'value_judgment', 'preference_statement', 'tradition_linked', 'historical_tradition', 'anecdotal_experience',
];

export class SpeakerTrustEngine {

  /**
   * Compute per-speaker trust metrics from verified claims.
   *
   * @param verifiedClaims - All verified claims (including opinions)
   * @param roles - (Optional) Map of speakerId to detected roles (Host, Guest, etc.)
   * @returns SpeakerBreakdown[] sorted by claim count (descending)
   */
  computeSpeakerMetrics(verifiedClaims: VerifiedClaim[], roles: Record<string, string> = {}): SpeakerBreakdown[] {
    if (!verifiedClaims || verifiedClaims.length === 0) {
      return [];
    }

    // 1. Group claims by speaker
    const speakerMap = new Map<string, VerifiedClaim[]>();
    verifiedClaims.forEach(claim => {
      const speaker = claim.speaker || "Speaker A"; // Default if not diarized
      if (!speakerMap.has(speaker)) speakerMap.set(speaker, []);
      speakerMap.get(speaker)!.push(claim);
    });

    // 2. Compute metrics per speaker
    const breakdowns: SpeakerBreakdown[] = [];

    for (const [speakerId, claims] of speakerMap.entries()) {
      // Separate factual claims from opinions for scoring
      const factualClaims = claims.filter(c => !OPINION_STATUSES.includes(c.status));
      const opinionClaims = claims.filter(c => OPINION_STATUSES.includes(c.status));

      let trustIndex = 50; // Default neutral score

      const hasDecisiveVerdicts = factualClaims.some(c => POSITIVE_STATUSES.includes(c.status) || NEGATIVE_STATUSES.includes(c.status));
      if (factualClaims.length > 0 && hasDecisiveVerdicts) {
        // Weight: correct claims add, incorrect subtract, neutral are partial
        let weightedSum = 0;
        let totalWeight = 0;

        factualClaims.forEach(c => {
          const importance = c.importance || 0.5;
          totalWeight += importance;

          if (POSITIVE_STATUSES.includes(c.status)) {
            weightedSum += 1.0 * importance;
          } else if (NEGATIVE_STATUSES.includes(c.status)) {
            weightedSum += 0.0 * importance;
          } else if (NEUTRAL_STATUSES.includes(c.status)) {
            weightedSum += 0.4 * importance;
          }
        });

        // Trust index: 0-100 scale
        trustIndex = Math.round((weightedSum / (totalWeight || 1)) * 100);
      } else if (opinionClaims.length > 0 || factualClaims.length > 0) {
        // Speaker only made opinion or unproven/neutral claims — neutral score
        trustIndex = 50;
      }

      // Word count estimation from claim text
      const wordCount = claims.reduce((sum, c) => sum + c.text.split(/\s+/).length, 0);

      breakdowns.push({
        speakerId,
        label: speakerId, // Can be enhanced with name extraction later
        role: roles[speakerId] || "Other", // v5.3: Detected role
        trustIndex,
        wordCount,
        claimCount: claims.length,
      });
    }

    // Sort by claim count (most active speaker first)
    breakdowns.sort((a, b) => b.claimCount - a.claimCount);

    logger.info("[SpeakerTrust] Computed metrics", {
      speakers: breakdowns.length,
      breakdown: breakdowns.map(s => `${s.label}: ${s.trustIndex}/100 (${s.claimCount} claims)`),
    });

    return breakdowns;
  }
}

export const speakerTrustEngine = new SpeakerTrustEngine();

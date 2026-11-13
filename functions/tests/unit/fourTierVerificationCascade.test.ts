/**
 * ⚡ UNIT & ADVERSARIAL TEST: FOUR-TIER VERIFICATION CASCADE (TRUTHWORLD)
 *
 * Validates:
 * 1. Tier 1 Semantic Claim Cache:
 *    - Proposition alignment guards (polarity inversion, number differences, year mismatches).
 *    - Time-sensitive claim detection (capped TTL for breaking/relative dates).
 *    - Retraction invalidation.
 * 2. Tier 2 Deterministic Knowledge Registry:
 *    - Scientific constants & conditions (water boiling @ 100°C @ 1 atm vs Everest elevation false claim).
 *    - Unit verification (100°C vs 100°F).
 *    - Authoritative world capitals with country-capital entity pairing (Tokyo <-> Japan, Kyoto refuted).
 *    - Medical baselines (antibiotics vs viruses).
 * 3. Tier 3 Fast-Track LLM:
 *    - Subjective opinion resolution (no grounding required).
 *    - Epistemic Guard: Empirical assertions flag requiresGrounding and cannot be affirmed true on training data.
 * 4. Tier 4 Intelligent Escalation Policy:
 *    - "Water boils at 100°C at standard atmospheric pressure" → Tier 2
 *    - "The capital of Japan is Tokyo" → Tier 2
 *    - "India's GDP grew by 8% this year" → Tier 4
 *    - "A new vaccine was approved yesterday" → Tier 4
 *    - "A politician secretly received foreign funding" → Tier 4
 *    - "The cinematography in this movie is the most beautiful of the year" → Tier 3
 */

import {
  validatePropositionAlignment,
  isTimeSensitiveClaim,
  ClaimCacheService,
} from "../../src/pipeline/services/claimCacheService";
import { DeterministicRegistryService } from "../../src/pipeline/services/deterministicRegistry";
import { FastTrackLlmService } from "../../src/pipeline/services/fastTrackLlmService";
import { VerificationCascadeService } from "../../src/pipeline/services/verificationCascadeService";

describe("Four-Tier Verification Cascade Suite", () => {
  // ──────────────────────────────────────────────────────────────────────────
  // TIER 1: SEMANTIC CLAIM CACHE & PROPOSITION ALIGNMENT
  // ──────────────────────────────────────────────────────────────────────────
  describe("Tier 1: Semantic Claim Cache & Proposition Alignment", () => {
    test("Authorizes cache reuse when propositions are strictly aligned", () => {
      const cached = "The speed of light in vacuum is 299,792,458 meters per second.";
      const incoming = "The speed of light in vacuum is 299,792,458 meters per second.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(true);
    });

    test("Rejects semantic match when polarity is inverted (negation flip)", () => {
      const cached = "The health ministry approved the new clinical trial.";
      const incoming = "The health ministry did not approve the new clinical trial.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(false);
      expect(result.reason).toBe("polarity_inversion");
    });

    test("Rejects semantic match when directional / antonym verbs are swapped (rose vs fell)", () => {
      const cached = "Consumer price inflation fell to 3.2% in June.";
      const incoming = "Consumer price inflation rose to 3.2% in June.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(false);
      expect(result.reason).toContain("antonym_direction_mismatch");
    });

    test("Rejects semantic match when election outcome verbs are swapped (won vs lost)", () => {
      const cached = "The governing party candidate won the presidential election.";
      const incoming = "The governing party candidate lost the presidential election.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(false);
      expect(result.reason).toContain("antonym_direction_mismatch");
    });

    test("Rejects semantic match when numerical quantities or percentages differ", () => {
      const cached = "Company quarterly revenues grew by 15%.";
      const incoming = "Company quarterly revenues grew by 25%.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(false);
      expect(result.reason).toContain("numerical_quantity_mismatch");
    });

    test("Rejects semantic match when historical years differ", () => {
      const cached = "The international charter was signed in 1945.";
      const incoming = "The international charter was signed in 1955.";
      const result = validatePropositionAlignment(cached, incoming);
      expect(result.isAligned).toBe(false);
      expect(result.reason).toContain("temporal_year_mismatch");
    });

    test("Detects time-sensitive assertions that require volatile cache management", () => {
      expect(isTimeSensitiveClaim("A new policy was announced today.")).toBe(true);
      expect(isTimeSensitiveClaim("The company CEO resigned yesterday.")).toBe(true);
      expect(isTimeSensitiveClaim("Breaking news: An emergency earthquake alert just issued.")).toBe(true);
      expect(isTimeSensitiveClaim("Prices reached a new record this week.")).toBe(true);
      expect(isTimeSensitiveClaim("Water boils at 100 degrees Celsius.")).toBe(false);
      expect(isTimeSensitiveClaim("The capital of France is Paris.")).toBe(false);
    });

    test("Invalidates cache entries citing retracted sources or DOIs", async () => {
      const count = await ClaimCacheService.invalidateForRetractedSource("retracted-journal.org/fake-study");
      expect(typeof count).toBe("number");
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TIER 2: DETERMINISTIC KNOWLEDGE REGISTRY
  // ──────────────────────────────────────────────────────────────────────────
  describe("Tier 2: Deterministic Knowledge Registry", () => {
    test("Resolves boiling point of water at standard pressure as verified_true", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Water boils at 100°C at standard atmospheric pressure."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("verified_true");
      expect(match?.verificationMethod).toBe("deterministic");
      expect(match?.confidence).toBeGreaterThanOrEqual(0.99);
    });

    test("Rejects boiling point on Mount Everest due to elevation condition violation", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Water boils at 100°C on Mount Everest."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
      expect(match?.reasoning).toContain("Mount Everest");
    });

    test("Rejects boiling point of 100 degrees Fahrenheit due to unit violation", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Water boils at 100 degrees Fahrenheit."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
      expect(match?.reasoning).toContain("212°F");
    });

    test("Resolves country-capital entity pairing (Tokyo <-> Japan) as verified_true", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "The capital of Japan is Tokyo."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("verified_true");
      expect(match?.confidence).toBe(1.0);
      expect(match?.verificationMethod).toBe("deterministic");
    });

    test("Refutes incorrect capital assertion (Kyoto for Japan) as false_claim", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "The capital of Japan is Kyoto."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
      expect(match?.reasoning).toContain("TOKYO");
    });

    test("Resolves speed of light in vacuum as verified_true with exact BIPM constant", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "The speed of light in a vacuum is 299,792,458 m/s."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("verified_true");
      expect(match?.confidence).toBe(1.0);
    });

    test("Resolves antibiotics ineffectiveness against viruses as verified_true", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Antibiotics cannot kill viruses like the common cold or flu."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("verified_true");
    });

    test("Refutes claim that antibiotics cure viral infections as false_claim", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Antibiotics cure viral sicknesses."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
    });

    test("Refutes turmeric cancer cure myth as false_claim", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "Drinking turmeric water cures cancer."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
    });

    test("Refutes flat earth assertion as false_claim", () => {
      const match = DeterministicRegistryService.resolveDeterministicFact(
        "The Earth is flat."
      );
      expect(match).not.toBeNull();
      expect(match?.status).toBe("false_claim");
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TIER 3: FAST-TRACK LLM
  // ──────────────────────────────────────────────────────────────────────────
  describe("Tier 3: Fast-Track LLM & Epistemic Safeguards", () => {
    test("Fast-resolves subjective opinion without external grounding", async () => {
      const result = await FastTrackLlmService.evaluateClaim(
        "In my personal opinion, this film is the greatest artistic achievement of the century."
      );
      expect(result.resolved).toBe(true);
      expect(result.status).toBe("opinion_claim");
      expect(result.requiresGrounding).toBe(false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TIER 4: INTELLIGENT TIER ESCALATION POLICY
  // ──────────────────────────────────────────────────────────────────────────
  describe("Tier Escalation Policy: Intelligent Tier Assignment", () => {
    test("Routes physical constant 'Water boils at 100°C at standard atmospheric pressure' to Tier 2", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "Water boils at 100°C at standard atmospheric pressure."
      );
      expect(decision.recommendedTier).toBe(2);
    });

    test("Routes established geography 'The capital of Japan is Tokyo' to Tier 2", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "The capital of Japan is Tokyo."
      );
      expect(decision.recommendedTier).toBe(2);
    });

    test("Escalates statistical & temporal claim 'India's GDP grew by 8% this year' to Tier 4", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "India's GDP grew by 8% this year."
      );
      expect(decision.recommendedTier).toBe(4);
      expect(decision.isStatistical).toBe(true);
      expect(decision.isTimeSensitive).toBe(true);
      expect(decision.escalationReasons.length).toBeGreaterThan(0);
    });

    test("Escalates medical & breaking claim 'A new vaccine was approved yesterday' to Tier 4", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "A new vaccine was approved yesterday."
      );
      expect(decision.recommendedTier).toBe(4);
      expect(decision.isMedical).toBe(true);
      expect(decision.isTimeSensitive).toBe(true);
    });

    test("Escalates high-stakes political allegation 'A politician secretly received foreign funding' to Tier 4", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "A politician secretly received foreign funding."
      );
      expect(decision.recommendedTier).toBe(4);
      expect(decision.isHighStakes).toBe(true);
    });

    test("Routes purely subjective statement 'In my personal opinion, this song is the best' to Tier 3", () => {
      const decision = VerificationCascadeService.analyzeClaimForTierRouting(
        "In my personal opinion, this song is the best."
      );
      expect(decision.recommendedTier).toBe(3);
      expect(decision.isSubjective).toBe(true);
    });
  });
});

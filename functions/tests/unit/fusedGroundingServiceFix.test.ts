import {
  FusedClaimVerdictSchema,
  FusedBatchResponseSchema,
  FusedGroundingService,
} from "../../src/pipeline/services/fusedGroundingService";
import { FilteredClaim } from "../../src/pipeline/types";

describe("FusedGroundingService & Resilient Schema Validation", () => {
  describe("FusedClaimVerdictSchema Resilience", () => {
    it("parses and normalizes exact standard schema verdicts", () => {
      const input = {
        claimId: "claim_1",
        verdict: "verified_true",
        evidenceLevel: "STRONG",
        summary: "This fact is backed by official government data.",
        keyFacts: ["Fact 1"],
        missingEvidence: "",
        supportingChunkIndices: [0],
        contradictingChunkIndices: [],
      };

      const parsed = FusedClaimVerdictSchema.parse(input);
      expect(parsed.claimId).toBe("claim_1");
      expect(parsed.verdict).toBe("verified_true");
      expect(parsed.evidenceLevel).toBe("STRONG");
      expect(parsed.summary).toBe("This fact is backed by official government data.");
    });

    it("resiliently normalizes loose verdicts, uppercase levels, and long summaries", () => {
      const input = {
        claimId: "  claim_2  ",
        verdict: "VERIFIED_TRUE",
        evidenceLevel: "moderate",
        summary: "A".repeat(450), // exceeds original 400 char limit
        keyFacts: ["Fact A", "Fact B"],
        missingEvidence: null,
        supportingChunkIndices: ["0", 1],
      };

      const parsed = FusedClaimVerdictSchema.parse(input);
      expect(parsed.claimId).toBe("claim_2");
      expect(parsed.verdict).toBe("verified_true");
      expect(parsed.evidenceLevel).toBe("MODERATE");
      expect(parsed.summary.length).toBeLessThanOrEqual(500);
      expect(parsed.supportingChunkIndices).toEqual([0, 1]);
    });

    it("handles colloquial or synonym verdicts gracefully without throwing", () => {
      expect(FusedClaimVerdictSchema.parse({ claimId: "c1", verdict: "true", summary: "Valid claim" }).verdict).toBe("verified_true");
      expect(FusedClaimVerdictSchema.parse({ claimId: "c2", verdict: "false", summary: "False claim" }).verdict).toBe("false_claim");
      expect(FusedClaimVerdictSchema.parse({ claimId: "c3", verdict: "partially true", summary: "Partially true claim" }).verdict).toBe("mostly_true");
      expect(FusedClaimVerdictSchema.parse({ claimId: "c4", verdict: "debunked", summary: "Debunked claim" }).verdict).toBe("false_claim");
      expect(FusedClaimVerdictSchema.parse({ claimId: "c5", verdict: "unverified", summary: "Unverified claim" }).verdict).toBe("unproven");
    });
  });

  describe("FusedBatchResponseSchema Validation", () => {
    it("parses complete batch response structure", () => {
      const batchJson = {
        verifications: [
          {
            claimId: "c1",
            verdict: "verified_true",
            summary: "Supported by official records.",
            supportingChunkIndices: [0],
          },
          {
            claimId: "c2",
            verdict: "false_claim",
            summary: "Contradicted by data.",
            contradictingChunkIndices: [1],
          },
        ],
      };

      const parsed = FusedBatchResponseSchema.parse(batchJson);
      expect(parsed.verifications.length).toBe(2);
      expect(parsed.verifications[0].verdict).toBe("verified_true");
      expect(parsed.verifications[1].verdict).toBe("false_claim");
    });
  });

  describe("FusedGroundingService.verifyBatchFused Fallback Behavior", () => {
    it("returns empty array for empty claims", async () => {
      const res = await FusedGroundingService.verifyBatchFused([]);
      expect(res).toEqual([]);
    });

    it("gracefully falls back to unproven when Gemini call fails or times out", async () => {
      const claims: FilteredClaim[] = [
        {
          claimId: "c_fail_1",
          text: "Sample claim",
          timestampMs: 1000,
          salience: 0.8,
        } as any,
      ];

      jest.spyOn((FusedGroundingService as any).vertexAI, "getGenerativeModel").mockReturnValue({
        generateContent: jest.fn().mockRejectedValue(new Error("Network timeout")),
      });

      const res = await FusedGroundingService.verifyBatchFused(claims);
      expect(res.length).toBe(1);
      expect(res[0].status).toBe("unproven");
      expect(res[0].reasoning).toBe("Verification could not reach authoritative records at this time.");
    });
  });
});

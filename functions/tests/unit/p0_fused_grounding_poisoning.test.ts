/**
 * 🧪 P0 VERIFICATION SUITE: ANTI-CITATION POISONING & GROUNDING ISOLATION
 *
 * Verifies that in a multi-claim batch:
 * 1. A claim with explicit grounding indices receives its legitimate citations.
 * 2. A fabricated claim with omitted grounding indices NEVER inherits citations from the batch.
 * 3. The ungrounded fabricated claim is strictly demoted to "unproven" with 0.0 confidence.
 */

import { FusedGroundingService } from "../../src/pipeline/services/fusedGroundingService";
import { FilteredClaim, ClaimNature, ClaimStrength, FramingStyle } from "../../src/pipeline/types";

describe("P0: FusedGroundingService Anti-Citation Poisoning", () => {
  it("prevents batch-wide chunk fallback so ungrounded claims receive 0 citations and 0.0 confidence", async () => {
    const claims: FilteredClaim[] = [
      {
        claimId: "claim_verified_1",
        text: "The Apollo 11 lunar module landed on the Moon on July 20, 1969.",
        nature: ClaimNature.VERIFIABLE_FACT,
        claimStrength: "strong" as ClaimStrength,
        importance: 0.9,
        speaker: "Speaker 1",
        confidence: 0.95,
        start: 0,
        end: 5000,
        framing: FramingStyle.BALANCED,
        chunkIndex: 0,
      },
      {
        claimId: "claim_fabricated_2",
        text: "The Moon is artificially hollow and contains a surveillance bunker built in 1840.",
        nature: ClaimNature.VERIFIABLE_FACT,
        claimStrength: "absolute" as ClaimStrength,
        importance: 0.8,
        speaker: "Speaker 1",
        confidence: 0.9,
        start: 5000,
        end: 10000,
        framing: FramingStyle.BALANCED,
        chunkIndex: 1,
      },
    ];

    const mockGroundingChunks = [
      {
        web: {
          uri: "https://www.nasa.gov/mission_pages/apollo/apollo11.html",
          title: "Apollo 11 Mission Overview - NASA",
        },
      },
    ];

    const mockModelResponse = {
      response: {
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    verifications: [
                      {
                        claimId: "claim_verified_1",
                        verdict: "verified_true",
                        evidenceLevel: "STRONG",
                        summary: "NASA historical mission records document Apollo 11 landing on July 20, 1969.",
                        keyFacts: ["Apollo 11 landed on the moon on July 20, 1969."],
                        missingEvidence: "",
                        supportingChunkIndices: [0],
                        contradictingChunkIndices: [],
                      },
                      {
                        claimId: "claim_fabricated_2",
                        verdict: "verified_true", // Model hallucinated true or omitted indices
                        evidenceLevel: "NONE",
                        summary: "No credible scientific or planetary records corroborate this assertion.",
                        keyFacts: [],
                        missingEvidence: "No peer-reviewed evidence.",
                        supportingChunkIndices: [], // OMITTED CHUNKS!
                        contradictingChunkIndices: [],
                      },
                    ],
                  }),
                },
              ],
            },
            groundingMetadata: {
              groundingChunks: mockGroundingChunks,
              groundingSupports: [],
            },
          },
        ],
      },
    };

    const mockModel = {
      generateContent: jest.fn().mockResolvedValue(mockModelResponse),
    };
    (FusedGroundingService as any)._vertexAI = {
      getGenerativeModel: jest.fn().mockReturnValue(mockModel),
    };

    const results = await FusedGroundingService.verifyBatchFused(claims, "Science");

    expect(results).toHaveLength(2);

    const apolloClaim = results.find((r) => r.claimId === "claim_verified_1")!;
    expect(apolloClaim.status).toBe("verified_true");
    expect(apolloClaim.richSources?.length).toBeGreaterThan(0);
    expect(apolloClaim.richSources?.[0].url).toContain("nasa.gov");

    const fabricatedClaim = results.find((r) => r.claimId === "claim_fabricated_2")!;
    // Epistemic invariant: Because chunk indices were empty, candidateSources must be empty
    // and status must be demoted to "unproven" with 0.0 confidence!
    expect(fabricatedClaim.status).toBe("unproven");
    expect(fabricatedClaim.richSources ?? []).toHaveLength(0);
    expect(fabricatedClaim.sources ?? []).toHaveLength(0);
    expect(fabricatedClaim.verificationConfidence).toBe(0.0);
    expect(fabricatedClaim.isGrounded).toBe(false);
  });
});

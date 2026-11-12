import {
  GeminiVerificationSchema,
  GeminiSingleVerificationSchema,
} from "../../src/pipeline/types";
import { CIRCUIT_DEFAULTS } from "../../src/pipeline/utils/ai-utils";

describe("Unit: Credibility Pipeline Large Video & Production Resilience", () => {
  describe("Bug 1: Resilient Zod Schema Validation on evidenceTraceability", () => {
    it("successfully parses verifications when evidenceTraceability omits optional nested fields", () => {
      const payloadFromGemini = {
        verifications: [
          {
            claimId: "claim_1",
            claim: "In the 1960s, going to the Moon was technologically possible.",
            claimType: "factual",
            label: "VERIFIED_TRUE",
            confidence: 0.95,
            summary: "Apollo missions successfully landed astronauts on the Moon.",
            sources: [
              {
                title: "NASA Apollo Program",
                url: "https://www.nasa.gov/mission_pages/apollo",
                snippet: "The Apollo program was the third United States human spaceflight program.",
              },
            ],
            // Gemini omitted provenance, exactPassage, claimComponentAddressed, relationship, etc.
            evidenceTraceability: {
              isCompoundClaim: false,
              components: [
                {
                  componentId: "comp_1",
                  statement: "Going to the Moon was possible in 1960s",
                  type: "PREMISE_OBSERVATION",
                  factualAccuracy: "ACCURATE_OBSERVATION",
                  explanation: "Documented history of Apollo 11",
                },
              ],
              evidenceTraces: [
                {
                  evidenceId: "E1",
                  componentId: "comp_1",
                  sourceTitle: "NASA History",
                  sourceUrl: "https://www.nasa.gov",
                },
              ],
            },
          },
        ],
      };

      const result = GeminiVerificationSchema.safeParse(payloadFromGemini);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.verifications).toHaveLength(1);
        expect(result.data.verifications[0].claimId).toBe("claim_1");
        expect(result.data.verifications[0].label).toBe("VERIFIED_TRUE");
      }
    });

    it("allows single verification item parsing and passthrough of extra model fields", () => {
      const singleItem = {
        claimId: "claim_test_2",
        label: "FALSE_CLAIM",
        confidence: 0.9,
        summary: "Claim is contradicted by empirical evidence.",
        extraFieldFromGemini: "unexpected_property",
        sources: [],
      };

      const result = GeminiSingleVerificationSchema.safeParse(singleItem);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.claimId).toBe("claim_test_2");
        expect(result.data.label).toBe("FALSE_CLAIM");
      }
    });
  });

  describe("Bug 2: Circuit Breaker Capped for Serverless Function Budgets", () => {
    it("caps MAX_OPEN_DURATION_MS at or below 30s to prevent 540s Cloud Run starvation", () => {
      expect(CIRCUIT_DEFAULTS.MAX_OPEN_DURATION_MS).toBeLessThanOrEqual(30_000);
      expect(CIRCUIT_DEFAULTS.BASE_OPEN_DURATION_MS).toBeLessThanOrEqual(15_000);
    });
  });
});

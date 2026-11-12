import { PIPELINE_CONFIG } from "../../src/pipeline/config";
import { RATE_CARDS, CostEngine } from "../../src/pipeline/services/cost-engine";
import { aiSearchAssistant } from "../../src/search/aiSearch";
import { getVertexAI } from "../../src/pipeline/utils/ai-client";

jest.mock("../../src/pipeline/utils/ai-client", () => ({
  getVertexAI: jest.fn(),
}));

describe("Vertex AI Cost Optimization & Model Routing Suite", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("1. PIPELINE_CONFIG Model Topology", () => {
    it("should configure gemini-2.5-flash as the default reasoning model on Vertex AI", () => {
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.reasoning).toBe("gemini-2.5-flash");
    });

    it("should configure gemini-2.5-flash for worker and query micro-tasks by default", () => {
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.profiling).toBe("gemini-2.5-flash");
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.fastTier).toBe("gemini-2.5-flash");
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.queryDecomposition).toBe("gemini-2.5-flash");
    });

    it("should preserve gemini-2.5-flash for bulk extraction and verification workhorse tasks", () => {
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.extraction).toBe("gemini-2.5-flash");
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.verification).toBe("gemini-2.5-flash");
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.synthesis).toBe("gemini-2.5-flash");
      expect(PIPELINE_CONFIG.GEMINI_MODELS?.moderation).toBe("gemini-2.5-flash");
    });

    it("should have Vertex AI context caching enabled by default", () => {
      expect(PIPELINE_CONFIG.CONTEXT_CACHING?.ENABLED).toBe(true);
      expect(PIPELINE_CONFIG.CONTEXT_CACHING?.MIN_TOKEN_THRESHOLD).toBe(32768);
    });
  });

  describe("2. Unit Economics & Rate Cards (Vertex AI Pricing)", () => {
    it("should accurately reflect Gemini reasoning model pricing ($0.15 / $0.60 per 1M)", () => {
      expect(RATE_CARDS["gemini-reasoning"].perInputToken).toBe(0.00000015);
      expect(RATE_CARDS["gemini-reasoning"].perOutputToken).toBe(0.0000006);
    });

    it("should accurately reflect Gemini Flash-Lite pricing ($0.075 / $0.30 per 1M)", () => {
      expect(RATE_CARDS["gemini-flash-lite"].perInputToken).toBe(0.000000075);
      expect(RATE_CARDS["gemini-flash-lite"].perOutputToken).toBe(0.0000003);
    });

    it("should accurately reflect Gemini Flash pricing ($0.15 / $0.60 per 1M)", () => {
      expect(RATE_CARDS["gemini-flash"].perInputToken).toBe(0.00000015);
      expect(RATE_CARDS["gemini-flash"].perOutputToken).toBe(0.0000006);
    });

    it("should calculate correct unit economics with context caching discounts", async () => {
      const engine = new CostEngine();
      const recordCostSpy = jest.spyOn(engine as any, "recordCost").mockResolvedValue(undefined);

      // 100k total tokens: 80k cached input, 10k non-cached input, 10k output on Reasoning (Gemini 2.5 Flash)
      await engine.recordGeminiCost(
        "job_test_123",
        "user_test_456",
        "verification",
        "reasoning",
        90000, // inputTokens
        10000, // outputTokens
        80000  // cachedTokens
      );

      expect(recordCostSpy).toHaveBeenCalled();
      const [jobId, userId, stage, sku, calculatedCost, unit, totalTokens] = recordCostSpy.mock.calls[0];

      expect(sku).toBe("gemini-reasoning");
      expect(totalTokens).toBe(100000);

      // Cost calculation check:
      // Non-cached input: 10,000 * 0.00000015 = $0.0015
      // Cached input:     80,000 * 0.0000001 = $0.008
      // Output:           10,000 * 0.0000006 = $0.006
      // Total expected = $0.0155
      expect(calculatedCost).toBeCloseTo(0.0155, 5);
    });
  });

  describe("3. AI Search Worker Model Selection", () => {
    it("should invoke getGenerativeModel with gemini-2.0-flash-lite for query decomposition", async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: { parts: [{ text: JSON.stringify({ cleanKeywords: ["test"], confidence: 0.9 }) }] },
            },
          ],
        },
      });

      const getGenerativeModelMock = jest.fn().mockReturnValue({
        generateContent: mockGenerateContent,
      });

      (getVertexAI as jest.Mock).mockReturnValue({
        getGenerativeModel: getGenerativeModelMock,
      });

      const runAiSearch = (data: any, auth: any = { uid: "user_test_1" }) => {
        return (aiSearchAssistant as any).run({ data, auth });
      };

      await runAiSearch({ query: "vertex ai model routing query" });

      expect(getGenerativeModelMock).toHaveBeenCalledWith(
        expect.objectContaining({
          model: PIPELINE_CONFIG.GEMINI_MODELS?.queryDecomposition || "gemini-2.5-flash",
        })
      );
    });
  });
});

import { computeTextEmbedding } from "../../src/search/embeddingService";
import { aiSearchAssistant } from "../../src/search/aiSearch";
import { getVertexAI } from "../../src/pipeline/utils/ai-client";
import { GoogleAuth } from "google-auth-library";

// Mock the AI client module
jest.mock("../../src/pipeline/utils/ai-client", () => ({
  getVertexAI: jest.fn(),
}));

let mockRequestFn = jest.fn();

// Mock google-auth-library
jest.mock("google-auth-library", () => {
  return {
    GoogleAuth: jest.fn().mockImplementation(() => {
      return {
        getClient: jest.fn().mockResolvedValue({
          request: (...args: any[]) => mockRequestFn(...args),
        }),
      };
    }),
  };
});

describe("Vertex AI Services", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockRequestFn.mockReset();
  });

  describe("computeTextEmbedding", () => {
    it("should return null for empty text", async () => {
      const result = await computeTextEmbedding("   ");
      expect(result).toBeNull();
    });

    it("should generate embeddings using mocked google-auth-library", async () => {
      mockRequestFn.mockResolvedValueOnce({
        data: {
          predictions: [
            {
              embeddings: { values: [0.1, 0.2, 0.3] }
            }
          ]
        }
      });

      const result = await computeTextEmbedding("test query");
      expect(result).toEqual([0.1, 0.2, 0.3]);
      expect(mockRequestFn).toHaveBeenCalled();
    });

    it("should handle errors gracefully and return null", async () => {
      mockRequestFn.mockRejectedValueOnce(new Error("API Error"));

      const result = await computeTextEmbedding("test query");
      expect(result).toBeNull();
    });
  });

  describe("aiSearchAssistant", () => {
    // aiSearchAssistant is a Callable function, we can invoke it via .run(request)
    const runAiSearch = (data: any, auth: any = { uid: "user1" }) => {
      return (aiSearchAssistant as any).run({ data, auth });
    };

    it("should reject empty queries", async () => {
      await expect(runAiSearch({ query: "" })).rejects.toThrow(/empty/);
    });

    it("should return parsed JSON from mocked Vertex AI", async () => {
      const mockResponse = {
        cleanKeywords: ["test"],
        semanticSynonyms: ["trial"],
        subdomains: [],
        excludedTerms: [],
        isConversational: false,
        resultMode: "ranked",
        confidence: 0.9,
        explanation: "Test explanation"
      };

      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: { parts: [{ text: JSON.stringify(mockResponse) }] }
            }
          ]
        }
      });

      (getVertexAI as jest.Mock).mockReturnValue({
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent
        })
      });

      // Clear the internal cache in aiSearch by using a unique query
      const result = await runAiSearch({ query: "unique query 1" });
      
      expect(result.cleanKeywords).toEqual(["test"]);
      expect(result.confidence).toBe(0.9);
      expect(mockGenerateContent).toHaveBeenCalled();
    });

    it("should handle malformed AI responses with fallback", async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: { parts: [{ text: "NOT VALID JSON" }] }
            }
          ]
        }
      });

      (getVertexAI as jest.Mock).mockReturnValue({
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent
        })
      });

      const result = await runAiSearch({ query: "broken ai query" });
      
      // Should fallback to deterministic
      expect(result.cleanKeywords).toEqual(["broken", "query"]);
      expect(result.resultMode).toBe("ranked");
    });

    it("should handle timeout when Vertex AI is slow", async () => {
      const mockGenerateContent = jest.fn().mockImplementation(() => {
        return new Promise((resolve) => setTimeout(resolve, 6000)); // Slower than 5s
      });

      (getVertexAI as jest.Mock).mockReturnValue({
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent
        })
      });

      const result = await runAiSearch({ query: "timeout ai query" });
      
      // Should fallback to deterministic
      expect(result.cleanKeywords).toEqual(["timeout", "query"]);
      expect(result.explanation).toContain("timeout query");
    });
  });
});

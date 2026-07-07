/**
 * 🏦 TOKEN ACCOUNTING SERVICE
 *
 * Centralized cost estimation for LLM calls.
 * Uses token-based pricing (not character-based) for accurate cost tracking.
 *
 * Design notes:
 * - Token estimation uses chars/4 as a reasonable English approximation.
 *   Actual billing uses provider token counts — this is for budgeting/alerting.
 * - Pricing is centralized here so rate changes only need one update.
 * - Supports multiple providers for future multi-model expansion.
 */

export type LLMProvider = 'gemini-flash' | 'gemini-pro' | 'openai' | 'claude';

interface PricingTier {
  inputPerMToken: number;   // USD per 1M input tokens
  outputPerMToken: number;  // USD per 1M output tokens
  searchQueryCost: number;  // USD per grounding/search query
}

/** Pricing as of June 2026. Update when provider rates change. */
const PRICING: Record<LLMProvider, PricingTier> = {
  'gemini-flash': {
    inputPerMToken: 0.075,
    outputPerMToken: 0.30,
    searchQueryCost: 0.005,
  },
  'gemini-pro': {
    inputPerMToken: 1.25,
    outputPerMToken: 5.00,
    searchQueryCost: 0.005,
  },
  'openai': {
    inputPerMToken: 2.50,
    outputPerMToken: 10.00,
    searchQueryCost: 0,
  },
  'claude': {
    inputPerMToken: 3.00,
    outputPerMToken: 15.00,
    searchQueryCost: 0,
  },
};

export interface CostEstimate {
  inputTokens: number;
  outputTokens: number;
  provider: LLMProvider;
  groundingUsed: boolean;
  estimatedCostUsd: number;
}

class TokenAccountingService {
  /**
   * Estimate token count from raw text.
   * Uses chars/4 as a practical English approximation.
   * Non-Latin scripts (e.g. CJK) average closer to chars/2.
   */
  estimateTokens(text: string): number {
    if (!text) return 0;
    // Heuristic: 1 token ≈ 4 characters for English
    // For non-Latin scripts, this underestimates — but better than chars/1
    return Math.ceil(text.length / 4);
  }

  /**
   * Resolve which pricing tier a model ID maps to.
   */
  resolveProvider(modelId: string): LLMProvider {
    if (modelId.includes('pro')) return 'gemini-pro';
    if (modelId.includes('flash')) return 'gemini-flash';
    if (modelId.includes('gpt') || modelId.includes('openai')) return 'openai';
    if (modelId.includes('claude')) return 'claude';
    return 'gemini-flash'; // Default fallback
  }

  /**
   * Calculate estimated cost for an LLM call.
   */
  estimateCost(
    inputText: string,
    outputText: string,
    modelId: string,
    groundingUsed: boolean = false
  ): CostEstimate {
    const provider = this.resolveProvider(modelId);
    const pricing = PRICING[provider];

    const inputTokens = this.estimateTokens(inputText);
    const outputTokens = this.estimateTokens(outputText);

    let cost = 0;
    cost += (inputTokens / 1_000_000) * pricing.inputPerMToken;
    cost += (outputTokens / 1_000_000) * pricing.outputPerMToken;
    if (groundingUsed) {
      cost += pricing.searchQueryCost;
    }

    return {
      inputTokens,
      outputTokens,
      provider,
      groundingUsed,
      estimatedCostUsd: Math.round(cost * 1_000_000) / 1_000_000, // 6 decimal places
    };
  }

  /**
   * Estimate cost for a batch of claims (pre-verification budgeting).
   */
  estimateBatchCost(
    claimCount: number,
    avgClaimChars: number,
    batchSize: number,
    modelId: string,
    groundingUsed: boolean = false
  ): { estimatedCostUsd: number; batchCount: number; warning?: string } {
    const batchCount = Math.ceil(claimCount / batchSize);
    const provider = this.resolveProvider(modelId);
    const pricing = PRICING[provider];

    // Estimate: ~600 tokens prompt overhead + avgClaimChars/4 per claim
    const promptOverhead = 600;
    const tokensPerClaim = Math.ceil(avgClaimChars / 4);
    const inputTokensPerBatch = promptOverhead + (tokensPerClaim * batchSize);
    const outputTokensPerBatch = Math.ceil(batchSize * 120); // ~120 tokens per claim response

    let costPerBatch = 0;
    costPerBatch += (inputTokensPerBatch / 1_000_000) * pricing.inputPerMToken;
    costPerBatch += (outputTokensPerBatch / 1_000_000) * pricing.outputPerMToken;
    if (groundingUsed) costPerBatch += pricing.searchQueryCost;

    const totalCost = costPerBatch * batchCount;

    return {
      estimatedCostUsd: Math.round(totalCost * 1_000_000) / 1_000_000,
      batchCount,
      warning: totalCost > 0.50 ? `High estimated cost: $${totalCost.toFixed(4)} for ${claimCount} claims` : undefined,
    };
  }
}

/** Singleton instance */
export const tokenAccounting = new TokenAccountingService();

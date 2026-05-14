/**
 * ⚡ FAST VERIFICATION SERVICE (v11.0)
 * 
 * Lightweight credibility signal for real-time use cases:
 * - Browser extensions
 * - Mobile app quick-check
 * - API embeds
 * - Live content triage
 * 
 * Design: Flash model only, no grounding, registry lookup,
 * max 5 claims. Returns traffic-light signal in < 5 seconds.
 * 
 * Cost: ~$0.001 per call vs ~$0.05 for deep tier
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { logger } from "../utils/logger";
import { z } from "zod";

/** Fast tier configuration */
export const FAST_TIER_CONFIG = {
  MAX_CLAIMS: 5,
  TIMEOUT_MS: 10_000,
  MODEL: "gemini-2.5-flash",
  ENABLE_GROUNDING: false,
  SIGNAL_THRESHOLDS: { green: 0.7, yellow: 0.4 }, // below 0.4 = red
  MAX_TEXT_LENGTH: 5000, // character limit for input text
} as const;

/** Signal output from fast verification */
export interface FastVerificationResult {
  signal: 'green' | 'yellow' | 'red';
  confidence: number;            // 0-1
  score: number;                 // 0-10 quick score
  claimCount: number;            // number of claims analyzed
  bullets: string[];             // 3-5 key findings
  processingTimeMs: number;
  tier: 'fast';
}

/** Zod schema for Gemini fast response */
const FastResponseSchema = z.object({
  claims: z.array(z.object({
    text: z.string(),
    isFactual: z.boolean(),
    accuracy: z.number().min(0).max(10),
    note: z.string(),
  })).max(FAST_TIER_CONFIG.MAX_CLAIMS),
  overallScore: z.number().min(0).max(10),
  keyFindings: z.array(z.string()).max(5),
});

export class FastVerificationService {
  private readonly genAI: GoogleGenerativeAI;

  constructor(geminiApiKey: string) {
    this.genAI = new GoogleGenerativeAI(geminiApiKey);
  }

  /**
   * Perform fast verification on raw text content.
   * Returns a traffic-light signal with key findings in < 5 seconds.
   */
  async verify(
    text: string,
    domain: string = 'General',
    category: string = 'unknown'
  ): Promise<FastVerificationResult> {
    const t0 = Date.now();

    // Truncate input to avoid token overflow
    const truncatedText = text.length > FAST_TIER_CONFIG.MAX_TEXT_LENGTH
      ? text.substring(0, FAST_TIER_CONFIG.MAX_TEXT_LENGTH) + '... [truncated]'
      : text;

    const prompt = `You are a fact-check triage system. Analyze this content and extract up to ${FAST_TIER_CONFIG.MAX_CLAIMS} key factual claims.
For each claim, rate its likely accuracy (0-10) based on your training knowledge ONLY (no web search).
Provide an overall credibility score (0-10) and up to 5 key findings.

CONTENT DOMAIN: ${domain}
CONTENT CATEGORY: ${category}

CONTENT:
${truncatedText}

CRITICAL RULES:
- Do NOT verify opinions, beliefs, or subjective statements — skip them.
- Focus ONLY on verifiable factual claims.
- If the content is entertainment, satire, or opinion, set overallScore to 7.0 and note that in keyFindings.
- If you cannot determine accuracy, rate the claim 5.0 (neutral).
- NEVER invent facts. Rate based on confidence only.

Return ONLY valid JSON matching this schema:
{
  "claims": [{ "text": "...", "isFactual": true, "accuracy": 0-10, "note": "..." }],
  "overallScore": 0-10,
  "keyFindings": ["...", "..."]
}`;

    try {
      const model = this.genAI.getGenerativeModel({
        model: FAST_TIER_CONFIG.MODEL,
      });

      // Race against timeout
      const result = await Promise.race([
        model.generateContent(prompt),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error('FAST_TIER_TIMEOUT')), FAST_TIER_CONFIG.TIMEOUT_MS)
        ),
      ]);

      const responseText = result.response.text();
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);

      if (!jsonMatch) {
        logger.warn('[FastVerification] No valid JSON in response');
        return this.fallbackResult(t0);
      }

      const parsed = FastResponseSchema.safeParse(JSON.parse(jsonMatch[0]));
      if (!parsed.success) {
        logger.warn('[FastVerification] Schema validation failed', { errors: parsed.error.format() });
        return this.fallbackResult(t0);
      }

      const { claims, overallScore, keyFindings } = parsed.data;
      const normalizedScore = Math.min(10, Math.max(0, overallScore));

      // Determine traffic-light signal
      const signal: 'green' | 'yellow' | 'red' =
        normalizedScore >= FAST_TIER_CONFIG.SIGNAL_THRESHOLDS.green * 10 ? 'green'
        : normalizedScore >= FAST_TIER_CONFIG.SIGNAL_THRESHOLDS.yellow * 10 ? 'yellow'
        : 'red';

      const processingTimeMs = Date.now() - t0;
      logger.info(`[FastVerification] Complete in ${processingTimeMs}ms: signal=${signal}, score=${normalizedScore}`, {
        claimCount: claims.length,
        domain,
        category,
      });

      return {
        signal,
        confidence: claims.length > 0 ? 0.6 : 0.3, // Fast tier is inherently lower confidence
        score: Number(normalizedScore.toFixed(1)),
        claimCount: claims.length,
        bullets: keyFindings.slice(0, 5),
        processingTimeMs,
        tier: 'fast',
      };

    } catch (error: any) {
      if (error?.message === 'FAST_TIER_TIMEOUT') {
        logger.warn('[FastVerification] Timed out after 10s');
      } else {
        logger.error('[FastVerification] Error', { error: String(error) });
      }
      return this.fallbackResult(t0);
    }
  }

  /** Fallback when verification fails — return neutral signal */
  private fallbackResult(t0: number): FastVerificationResult {
    return {
      signal: 'yellow',
      confidence: 0.1,
      score: 5.0,
      claimCount: 0,
      bullets: ['Unable to verify — try the full analysis for detailed results.'],
      processingTimeMs: Date.now() - t0,
      tier: 'fast',
    };
  }
}

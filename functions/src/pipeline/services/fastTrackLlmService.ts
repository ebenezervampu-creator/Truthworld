/**
 * ⚡ TIER 3: FAST-TRACK LLM SERVICE (TRUTHWORLD)
 *
 * Provides ultra-fast (< 1.2s) assessment for:
 * 1. Subjective statements, personal opinions, and moral/philosophical judgments.
 * 2. Rhetorical hyperbole, humor, and satire.
 * 3. Pre-triage routing of empirical claims.
 *
 * MANDATORY EPISTEMIC INVARIANT:
 * Parametric training weights CANNOT independently confirm an empirical claim as
 * 'verified_true' without authoritative grounding. Any empirical claim requiring
 * factual verification MUST return `requiresGrounding: true` and escalate to Tier 4.
 */

import { z } from "zod";
import { getVertexAI } from "../utils/ai-client";
import { PIPELINE_CONFIG } from "../config";
import { extractCandidateText } from "../utils/ai-utils";
import { logger } from "../utils/logger";
import { ClaimStatus, RichSource } from "../types";

export interface FastTrackEvaluationResult {
  tier: 3;
  resolved: boolean;
  status?: ClaimStatus;
  confidence: number;
  reasoning: string;
  requiresGrounding: boolean;
  escalationReason?: string;
  richSources?: RichSource[];
  isProvisional?: boolean;
}

const FastTrackSchema = z.object({
  claimType: z.enum([
    "OPINION_OR_SUBJECTIVE",
    "FAITH_OR_BELIEF",
    "SATIRE_OR_HYPERBOLE",
    "EMPIRICAL_FACTUAL_ASSERTION",
  ]),
  requiresGrounding: z.boolean(),
  status: z.enum([
    "opinion_claim",
    "satire_claim",
    "needs_grounding",
    "unproven",
    "disputed",
  ]),
  confidence: z.number().min(0).max(1),
  reasoning: z.string(),
  escalationReason: z.string().optional(),
});

export class FastTrackLlmService {
  /**
   * Fast evaluation of an individual claim using Flash-Lite / Flash.
   */
  public static async evaluateClaim(
    claimText: string,
    domainContext: string = "General"
  ): Promise<FastTrackEvaluationResult> {
    const t0 = Date.now();

    // Fast heuristic pre-check for obvious subjective indicators before LLM call
    const lower = claimText.toLowerCase();
    const isObviousOpinion = /\b(i feel|in my opinion|i believe|personally|i think|my favorite|best movie|worst movie|greatest|most beautiful|should be|ought to)\b/i.test(lower);
    if (isObviousOpinion && !/\b(\d+(?:\.\d+)?%|killed|bribed|stole|fraud|gdp|billion|trillion)\b/i.test(lower)) {
      return {
        tier: 3,
        resolved: true,
        status: "opinion_claim",
        confidence: 0.95,
        reasoning: "This statement reflects personal viewpoints, taste, or subjective value judgments rather than a testable empirical fact.",
        requiresGrounding: false,
        richSources: [],
      };
    }

    try {
      const genAI = getVertexAI();
      const model = genAI.getGenerativeModel({
        model: PIPELINE_CONFIG.GEMINI_MODELS?.fastTier || "gemini-2.5-flash",
        generationConfig: {
          temperature: 0.0,
          responseMimeType: "application/json",
          maxOutputTokens: 500,
        },
      });

      const prompt = `You are TruthWorld's Tier-3 Fast-Track Epistemic Router.
Evaluate the following statement:

STATEMENT: "${claimText}"
DOMAIN: ${domainContext}

CRITICAL RULES:
1. If the statement is a personal opinion, preference, subjective feeling, or value judgment:
   - claimType: "OPINION_OR_SUBJECTIVE"
   - requiresGrounding: false
   - status: "opinion_claim"
   - confidence: 0.95

2. If the statement is satirical, humorous, or obvious rhetorical hyperbole:
   - claimType: "SATIRE_OR_HYPERBOLE"
   - requiresGrounding: false
   - status: "satire_claim"
   - confidence: 0.90

3. If the statement is an EMPIRICAL FACTUAL ASSERTION (e.g. statistics, breaking news, politics, scientific discoveries, historical claims, actions of individuals):
   - MANDATORY EPISTEMIC GUARD: You CANNOT confirm empirical facts based solely on internal model weights.
   - claimType: "EMPIRICAL_FACTUAL_ASSERTION"
   - requiresGrounding: true
   - status: "needs_grounding"
   - escalationReason: "Empirical assertion requires multi-source verification & citation firewall."

Return ONLY valid JSON matching this schema:
{
  "claimType": "OPINION_OR_SUBJECTIVE" | "FAITH_OR_BELIEF" | "SATIRE_OR_HYPERBOLE" | "EMPIRICAL_FACTUAL_ASSERTION",
  "requiresGrounding": boolean,
  "status": "labeled_opinion" | "contextual" | "needs_grounding" | "unproven" | "disputed",
  "confidence": number,
  "reasoning": string,
  "escalationReason": string
}`;

      // Race against 1.2s SLA timeout
      const result = await Promise.race([
        model.generateContent(prompt),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("FAST_TRACK_TIMEOUT")), 1200)
        ),
      ]);

      const candidateText = extractCandidateText(result.response.candidates?.[0]) ||
        result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

      const parsed = FastTrackSchema.safeParse(JSON.parse(candidateText));
      if (!parsed.success) {
        logger.warn("[FastTrack] Schema parse failed; escalating to Tier 4", { errors: parsed.error.format() });
        return {
          tier: 3,
          resolved: false,
          requiresGrounding: true,
          escalationReason: "Schema parse fallback",
          confidence: 0.0,
          reasoning: "Fast triage inconclusive; escalating to deep grounded verification.",
        };
      }

      const data = parsed.data;

      // Epistemic Guard Enforced: Never allow empirical facts to be confirmed at Tier 3
      if (data.claimType === "EMPIRICAL_FACTUAL_ASSERTION" || data.requiresGrounding) {
        return {
          tier: 3,
          resolved: false,
          requiresGrounding: true,
          escalationReason: data.escalationReason || "Empirical assertion requires multi-source grounding",
          confidence: data.confidence,
          reasoning: data.reasoning,
        };
      }

      // Resolved at Tier 3 (Opinions / Satire / Hyperbole)
      return {
        tier: 3,
        resolved: true,
        status: (data.status === "needs_grounding" ? "unproven" : data.status) as ClaimStatus,
        confidence: data.confidence,
        reasoning: data.reasoning,
        requiresGrounding: false,
        richSources: [],
      };
    } catch (err: any) {
      logger.info(`[FastTrack] Fast track timed out or failed (${Date.now() - t0}ms); escalating claim to Tier 4`, {
        err: err?.message,
      });

      return {
        tier: 3,
        resolved: false,
        requiresGrounding: true,
        escalationReason: "Fast track timeout/fallback (>1.2s)",
        confidence: 0.0,
        reasoning: "Escalated to deep grounded verification.",
      };
    }
  }
}

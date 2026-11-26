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

    // Fast heuristic pre-check ONLY for unambiguous pure aesthetic/artistic taste with zero empirical entities.
    // Conversational hedges ("I think", "I believe", "In my opinion", "Personally") MUST NEVER bypass fact-checking!
    const lower = claimText.trim().toLowerCase();
    const isPureAestheticTaste = /^(my favorite (movie|song|film|color|food|flavor|band|artist|book|actor)|i prefer (chocolate|vanilla|tea|coffee)|(this|that) is (a masterpiece|my favorite movie|a boring movie))\b/i.test(lower);
    const hasEmpiricalIndicators = /\b(\d|cancer|vaccin|cure|prevent|cause|speed|capital|founded|invented|landed|planet|earth|gdp|billion|trillion|percent|%|kill|bribe|stole|fraud|law|court|president|minister|election|war|treaty|doctor|study|research|faked|conspiracy|moon|mars|sun|water|boil|freeze|virus|bacteria|drug|medicine)\b/i.test(lower);
    if (isPureAestheticTaste && !hasEmpiricalIndicators) {
      return {
        tier: 3,
        resolved: true,
        status: "opinion_claim",
        confidence: 0.95,
        reasoning: "This statement reflects personal aesthetic preference or subjective taste rather than a testable empirical fact.",
        requiresGrounding: false,
        richSources: [],
      };
    }

    try {
      const genAI = getVertexAI();
      const model = genAI.getGenerativeModel({
        model: PIPELINE_CONFIG.GEMINI_MODELS?.fastTier || "gemini-3.5-flash-lite",
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
1. CONVERSATIONAL HEDGES ARE NOT OPINIONS:
   Conversational hedges or epistemic qualifiers such as "I think", "I believe", "In my opinion", "Personally", "I feel", "I guess", "Should be", "Ought to" do NOT transform an empirical, scientific, medical, historical, geographic, financial, legal, or political claim into a personal opinion or taste.
   If the underlying proposition asserts an empirical fact, statistic, historical event, medical/scientific claim, or actions of people/institutions (e.g. "I think smoking prevents cancer", "In my opinion the capital of India is Kolkata", "I believe Apollo 11 was faked", "I think vaccines cause autism", "I believe the earth is flat"):
   - You MUST classify it as claimType: "EMPIRICAL_FACTUAL_ASSERTION"
   - requiresGrounding: true
   - status: "needs_grounding"
   - escalationReason: "Empirical assertion requires multi-source verification & citation firewall."

2. EMPIRICAL FACTUAL ASSERTION:
   If the statement asserts a testable fact, statistic, historical event, medical/scientific claim, news event, geographic fact, or actions of individuals (regardless of whether the speaker hedges):
   - MANDATORY EPISTEMIC GUARD: You CANNOT confirm empirical facts based solely on internal model weights.
   - claimType: "EMPIRICAL_FACTUAL_ASSERTION"
   - requiresGrounding: true
   - status: "needs_grounding"
   - escalationReason: "Empirical assertion requires multi-source verification & citation firewall."

3. PURE OPINION OR SUBJECTIVE TASTE:
   ONLY classify as OPINION_OR_SUBJECTIVE if the statement is purely a subjective aesthetic preference, personal taste, artistic critique, or emotional sentiment with NO empirical, factual, medical, historical, or scientific claims (e.g. "Vanilla is tastier than chocolate", "That painting is gorgeous", "Blue is my favorite color"):
   - claimType: "OPINION_OR_SUBJECTIVE"
   - requiresGrounding: false
   - status: "opinion_claim"
   - confidence: 0.95

4. SATIRE OR HYPERBOLE:
   If the statement is satirical, humorous, or obvious rhetorical hyperbole (e.g. "I'm so hungry I could eat a horse"):
   - claimType: "SATIRE_OR_HYPERBOLE"
   - requiresGrounding: false
   - status: "satire_claim"
   - confidence: 0.90

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

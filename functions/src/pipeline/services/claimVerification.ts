import { VertexAI, HarmCategory, HarmBlockThreshold } from "@google-cloud/vertexai";
import { PIPELINE_CONFIG } from "../config";
import { telemetryService } from "./telemetry";
import { normalizeClaimText, hashClaimText } from "../utils/claim-normalization";
import {
  ClaimStatus,
  ClaimNature,
  FramingStyle,
  EvidenceLevel,
  ExtractedClaim,
  FilteredClaim,
  GeminiVerificationSchema,
  RichSource,
  SourceTier,
  VerifiedClaim,
  VerificationMethod,
} from "../types";
import { containsVerifiablePredicate } from "./contentIntentDetector";
import { withAiRetry } from "../utils/ai-utils";
import { logger } from "../utils/logger";
import { sourceTrustService } from "./sourceTrustService";
import { tier0KnowledgeService } from "./tier0Knowledge";

/**
 * v10.6: Dynamic batch timeout calculation.
 * Accounts for model type, grounding mode, batch size, and retry pass.
 * For long-form videos (50+ claims), this ensures no single batch
 * blocks the pipeline beyond 2 minutes.
 */
function calculateBatchTimeout(
  batchSize: number,
  groundingMode: 'always' | 'sensitive_only' | 'never',
  forcePro: boolean,
  isRetryPass: boolean
): number {
  const isGrounded = groundingMode === 'always';
  const isProModel = forcePro;

  // Base timeouts by mode (v11.1 Hardened)
  const baseTimeout = isProModel && isGrounded ? 30_000   // Pro + grounding (Reduced from 45s)
    : isGrounded ? 10_000   // Flash + grounding (Reduced from 15s)
      : 8_000;  // Flash, no grounding (Reduced from 10s)

  // Per-claim addition (User requested 8s per claim)
  const perClaimMs = isProModel && isGrounded ? 10_000   // Pro + grounding: 10s/claim
    : isGrounded ? 8_000    // Flash + grounding: 8s/claim (Verified)
      : 4_000;   // Standard: 4s/claim

  // Retry pass gets a flat 30s regardless of model (v11.2 Hardened)
  if (isRetryPass) return 30_000;

  return Math.min(
    baseTimeout + (batchSize * perClaimMs),
    180_000  // raised ceiling to 3 minutes to accommodate larger batches in long-form videos
  );
}

// v14.0 + v18.0: Sanitize LLM JSON output (trailing commas, comments, control chars)
function sanitizeJSON(raw: string): string {
  let sanitized = raw
    .replace(/(?<!https?:|ftp:|file:)\/\/[^\r\n]*/g, '') // Remove single-line comments safely (ignoring protocols)
    .replace(/\/\*[\s\S]*?\*\//g, '')   // Remove multi-line comments
    .replace(/,\s*([\]\}])/g, '$1')     // Remove trailing commas
    .replace(/[\uFEFF\u200B]/g, '');    // Remove BOM/zero-width chars

  // v18.0: Strip control characters inside JSON string values.
  // Gemini sometimes embeds raw tabs, newlines, carriage returns inside string literals.
  // This replaces them with safe equivalents while preserving structural whitespace.
  sanitized = sanitized.replace(/"(?:[^"\\]|\\.)*"/g, (match) => {
    return match
      .replace(/(?<!\\)\t/g, '\\t')    // raw tab → escaped tab
      .replace(/(?<!\\)\n/g, '\\n')    // raw newline → escaped newline
      .replace(/(?<!\\)\r/g, '\\r')    // raw CR → escaped CR
      .replace(/[\x00-\x1f]/g, (c) => { // any other control char
        if (c === '\t' || c === '\n' || c === '\r') return c; // already handled
        return '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0');
      });
  });

  return sanitized;
}

/**
 * 🔹 C. Claim Verification Service
 *
 * Verifies claims using Gemini
 * Input: batch of claims (10-20)
 * Output: status (correct/incorrect/unverifiable) + confidence + reasoning
 */
export class ClaimVerificationService {
  private genAI: VertexAI;
  private confidenceThreshold: number;

  constructor(apiKey: string, confidenceThreshold: number = 0.6) {
    this.genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
    this.confidenceThreshold = confidenceThreshold;
  }

  /**
   * 🎯 Risk-Based Dynamic Router
   * Routes sensitive claims to Pro, standard claims to Flash.
   * This saves ~85% cost while ensuring high-stakes claims get Pro-level judgment.
   */
  private isSensitiveClaim(claim: { text: string; nature: string }, isDiscoverySensitive: boolean = false): boolean {
    if (isDiscoverySensitive) return true; // v5.2 LLM Discovery override

    const text = claim.text.toLowerCase();
    const sensitivePatterns = [
      /\b(?:died|killed|assassinated|dead|death|executed)\b/i,
      /\b(?:war|invasion|bombed|strike|missile|military|troops)\b/i,
      /\b(?:election|voted|president|prime minister|leader|supreme)\b/i,
      /\b(?:sanction|embargo|blockade|tariff)\b/i,
      /\b(?:pandemic|outbreak|vaccine|mortality|cancer cure)\b/i,
      /\b(?:bankrupt|crash|recession|inflation|gdp|trillion)\b/i,
      /\b(?:genocide|ethnic cleansing|war crime|human rights)\b/i,
      /\b(?:nuclear|chemical weapon|biological weapon)\b/i,
      /\b(?:coup|overthrow|martial law|emergency)\b/i,
      /\b(?:scientific discovery|breakthrough|study shows|researchers found)\b/i, // v12.5: Science markers
      /\b(?:ancient|archaeological|excavated|dynasty|civilization|historical record)\b/i, // v12.5: History markers
    ];

    // Pattern match
    if (sensitivePatterns.some(p => p.test(text))) return true;

    // Domain match
    const sensitiveDomains = PIPELINE_CONFIG.SENSITIVE_DOMAINS || [];
    if (sensitiveDomains.some((d: string) => text.includes(d))) return true;


    return false;
  }

  /**
   * Helper to determine if a claim mentions a recent event or launch
   */
  private shouldGroundClaim(text: string, isLaunchNews: boolean = false): boolean {
    if (isLaunchNews) return true; // v5.2: Force grounding for launches
    
    const textLower = text.toLowerCase();

    // v11.3 & v11.5: "Knowledge-Only" Skip List (Historical/Scientific/Trivia Constants)
    // These are known by Gemini training data and do NOT need 15s search latency.
    const historicalMarkers = [
      /\bancient\b/i, /\bhistorical\b/i, /\bcentury\b/i, /\bgupta\b/i, /\bindus valley\b/i,
      /\bdynasty\b/i, /\bmythology\b/i, /\bscripture\b/i, /\bbce\b/i, /\barchaeology\b/i,
      /\bhistory of\b/i, /\borigin of\b/i, /\binvented by\b/i, /\bdiscovered by\b/i
    ];

    const geographyMarkers = [
      /\bborder\b/i, /\bcapital of\b/i, /\bhemisphere\b/i, /\bmeridian\b/i, /\bequator\b/i,
      /\bstate of\b/i, /\bcountry\b/i, /\bocean\b/i, /\bcontinent\b/i, /\blatitude\b/i, /\blongitude\b/i,
      /\bsouthernmost\b/i, /\bnorthernmost\b/i, /\beasternmost\b/i, /\bwesternmost\b/i,
      /\bhottest temperature\b/i, /\bcoldest temperature\b/i, /\bhighest peak\b/i, /\bdeepest\b/i
    ];

    const scienceMarkers = [
      /\bboiling point\b/i, /\bfreezing point\b/i, /\belements\b/i, /\bperiodic table\b/i,
      /\bspeed of light\b/i, /\bgravity\b/i, /\bmolecule\b/i, /\batom\b/i, /\bdna\b/i,
      /\bplanet\b/i, /\bsolar system\b/i, /\bgalaxy\b/i, /\bmathematics\b/i, /\bformula\b/i,
      /\banatomy\b/i, /\bheart\b/i, /\bspecies\b/i, /\bmammal\b/i, /\banimal\b/i, /\binvertebrate\b/i,
      /\bblood\b/i, /\bskeleton\b/i, /\bgrowth\b/i, /\bsleep\b/i, /\bgestation\b/i, /\bhabitat\b/i
    ];

    const freshMarkers = [
      /\blaunched\b/i, /\bannounced\b/i, /\breleased\b/i, /\bjust in\b/i,
      /\brecently\b/i, /\bnew product\b/i, /\bupcoming\b/i, /\bfeature\b/i,
      /\btoday\b/i, /\byesterday\b/i, /\bthis week\b/i, /\bbreaking\b/i,
      /\bdeployment\b/i, /\brollout\b/i, /\bupdate\b/i
    ];

    if (freshMarkers.some(regex => regex.test(textLower))) {
      return true;
    }

    if (
      historicalMarkers.some(regex => regex.test(textLower)) ||
      geographyMarkers.some(regex => regex.test(textLower)) ||
      scienceMarkers.some(regex => regex.test(textLower))
    ) {
      logger.info(`[ClaimVerification] Grounding skipped: Deterministic context detected in "${text.substring(0, 50)}..."`);
      return false;
    }

    return false;
  }

  /**
   * Assigns a tier to a source based on its domain using the SourceTrustService.
   */
  private getSourceTier(url: string, domainContext: string = "General"): SourceTier {
    // v18.0: Extract real domain from Vertex AI grounding redirect URLs
    const resolvedUrl = this.resolveGroundingRedirectUrl(url);
    const trust = sourceTrustService.resolveSourceTrust(resolvedUrl, domainContext);
    return trust.tier;
  }

  /**
   * v18.0: Vertex AI grounding returns redirect URLs like:
   *   https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQF00...
   * These hide the real domain (e.g. wikipedia.org) behind a redirect.
   * This method extracts the real domain from the title when possible,
   * or returns the original URL if it's not a redirect.
   */
  private resolveGroundingRedirectUrl(url: string): string {
    if (!url.includes('vertexaisearch.cloud.google.com/grounding-api-redirect')) {
      return url;
    }
    // Can't resolve redirect URLs statically — return as-is for now.
    // The real domain will be extracted from the grounding chunk title instead.
    return url;
  }

  /**
   * v18.0: Extract domain from grounding chunk title (e.g. "wikipedia.org" from title).
   * Used when the URL is a Vertex AI redirect that hides the real domain.
   */
  private getSourceTierFromGroundingChunk(chunk: any, domainContext: string = "General"): SourceTier {
    const url = chunk?.web?.uri || '';
    const title = (chunk?.web?.title || '').toLowerCase();

    // If it's a redirect URL, try to infer domain from title
    if (url.includes('vertexaisearch.cloud.google.com/grounding-api-redirect')) {
      // Extract domain pattern from title (e.g. "wikipedia.org", "nih.gov", "reuters.com")
      const domainMatch = title.match(/([a-z0-9-]+\.(gov|edu|org|com|int|mil|co\.uk|ac\.uk|net))/i);
      if (domainMatch) {
        const trust = sourceTrustService.resolveSourceTrust(`https://${domainMatch[1]}`, domainContext);
        return trust.tier;
      }
      // Fallback: check title for known source names
      const knownSources: Record<string, string> = {
        'wikipedia': 'wikipedia.org', 'reuters': 'reuters.com', 'ap news': 'apnews.com',
        'bbc': 'bbc.com', 'nature': 'nature.com', 'science': 'science.org',
        'bloomberg': 'bloomberg.com', 'nyt': 'nytimes.com', 'new york times': 'nytimes.com',
        'cdc': 'cdc.gov', 'who': 'who.int', 'nih': 'nih.gov', 'nasa': 'nasa.gov',
        'fda': 'fda.gov', 'britannica': 'britannica.com', 'healthline': 'healthline.com',
        'investopedia': 'investopedia.com', 'techcrunch': 'techcrunch.com',
        'the verge': 'theverge.com', 'wired': 'wired.com', 'forbes': 'forbes.com',
        'hhs': 'hhs.gov', 'openai': 'openai.com', 'google': 'google.com',
      };
      for (const [keyword, domain] of Object.entries(knownSources)) {
        if (title.includes(keyword)) {
          const trust = sourceTrustService.resolveSourceTrust(`https://${domain}`, domainContext);
          return trust.tier;
        }
      }
    }
    return this.getSourceTier(url, domainContext);
  }

  /**
   * 🎯 Claim Routing Matrix (v5.0 — replaces filterNonFacts)
   *
   * Instead of a binary filter, this routes claims into three buckets:
   *   - verify:    factual assertions → send to verification engine
   *   - label:     genuine opinions  → label as opinion, skip verification
   *   - decompose: mixed claims      → attempt to extract verifiable core
   *
   * KEY FIX: Claims are routed based on BOTH their type classification AND
   * verifiable predicate detection. A claim typed as "opinion" but containing
   * a verifiable predicate (e.g., "Anthropic launched Claude Design") is
   * rerouted to verification.
   */
  classifyClaims(
    claims: ExtractedClaim[],
    isLaunchNews: boolean = false,
    isDiscoverySensitive: boolean = false
  ): {
    toVerify: FilteredClaim[];
    opinions: FilteredClaim[];
    filteringReasons: string[];
  } {
    const toVerify: FilteredClaim[] = [];
    const opinions: FilteredClaim[] = [];
    const filteringReasons: string[] = [];

    claims.forEach((claim, idx) => {
      const claimId = (claim as any).claimId || `claim_${Date.now()}_${idx}`;
      
      // Honesty Flag Detection: If Opinion/Belief is presented as Fact
      const isOpinionOrBelief = claim.nature === ClaimNature.OPINION || claim.nature === ClaimNature.BELIEF;
      const isAuthoritative = claim.framing === FramingStyle.ABSOLUTE || claim.framing === FramingStyle.MANIPULATIVE || (claim as any).assertiveness === 'authoritative' || (claim as any).assertiveness === 'absolute';
      
      const tagged: FilteredClaim = { 
        ...claim, 
        claimId,
        isFramingViolation: isOpinionOrBelief && isAuthoritative
      };

      // Gate 1: Minimum confidence threshold
      const effectiveThreshold = this.confidenceThreshold * (isLaunchNews ? 0.66 : 1.0);
      if (claim.confidence < effectiveThreshold) {
        filteringReasons.push(`Claim "${claim.text.substring(0, 40)}..." filtered: confidence ${claim.confidence} below ${effectiveThreshold.toFixed(2)}`);
        return;
      }

      // Gate 2: Satirical content
      if (claim.nature === ClaimNature.SATIRE) {
        opinions.push(tagged);
        return;
      }

      // === ROUTING MATRIX (TRUTHWORLD PATH 1) ===

      // Bucket 1 (Fact) & Bucket 4 (Estimation) -> Verification
      if (claim.nature === ClaimNature.VERIFIABLE_FACT || claim.nature === ClaimNature.ESTIMATION) {
        toVerify.push(tagged);
        return;
      }

      // Bucket 2 (Opinion) & Bucket 3 (Belief) -> Opinions (Labeling only)
      if (isOpinionOrBelief) {
        // RESCUE: If it contains a verifiable predicate, it might be Bucket 1 in disguise
        if (claim.isVerifiableEvent || containsVerifiablePredicate(claim.text)) {
          toVerify.push(tagged);
          return;
        }
        opinions.push(tagged);
        return;
      }

      // Safety net
      toVerify.push(tagged);
    });

    console.log(
      `[ClaimRouter] Routing: ${claims.length} total → ${toVerify.length} verify, ${opinions.length} opinions`
    );

    return { toVerify, opinions, filteringReasons };
  }

  /**
   * @deprecated Use classifyClaims() instead. Kept for backward compatibility.
   * Legacy filter that drops non-factual claims entirely.
   */
  filterNonFacts(claims: ExtractedClaim[]): FilteredClaim[] {
    const { toVerify } = this.classifyClaims(claims);
    return toVerify;
  }

  /**
   * Batch verify claims
   * Process 10-20 claims per Gemini request
   */
  async verifyClaimBatch(
    claims: FilteredClaim[],
    domainContext: string = "General",
    options: {
      groundingMode: 'always' | 'sensitive_only' | 'never';
      forcePro: boolean;
      minSourcesRequired: number;
      sourceDiversityRequired: boolean;
      isDiscoverySensitive?: boolean;
    } = {
        groundingMode: 'sensitive_only',
        forcePro: false,
        minSourcesRequired: 1,
        sourceDiversityRequired: false
      },
    signal?: AbortSignal,
    maxAttemptsOverride?: number
  ): Promise<VerifiedClaim[]> {
    if (claims.length === 0) {
      return [];
    }

    // Format claims for batch processing



    try {
      const remainingToVerify = claims;
      const preVerified: VerifiedClaim[] = [];

      // Fetch Tier-0 Wikipedia Context for all claims in this batch
      const tier0Contexts = await tier0KnowledgeService.getBatchContext(
        remainingToVerify.map(c => ({ claimId: c.claimId, text: c.text }))
      );

      let tier0Injection = "";
      const validContexts = tier0Contexts.filter(c => c.context !== null);
      if (validContexts.length > 0) {
        tier0Injection = `\n### TIER-0 KNOWLEDGE RECOVERY (WIKIPEDIA):\n${validContexts.map(c => `[ID: ${c.claimId}] ${c.context}`).join('\n')}\n`;
      }

      const prompt = `ROLE: TruthWorld Institutional Verification Engine.

OBJECTIVE: Verify the following batch of claims with world-class source attribution.

PROTOCOL:
1. EVIDENCE: If Google Search tools are enabled, prioritize them. If disabled or search fails, use your internal high-precision training data.
2. LABELS: VERIFIED TRUE | MOSTLY TRUE | DISPUTED | INCONCLUSIVE | LIMITED SUPPORT | MISLEADING | FALSE | RELIGIOUS BELIEF | OPINION | SATIRE.
3. BAN ON UNSUPPORTED: You are STRICTLY FORBIDDEN from outputting "UNPROVEN" or "UNSUPPORTED". This applies to ALL categories and ALL videos.
4. KNOWLEDGE FALLBACK: If search yields no results, evaluate the claim using your internal knowledge. If it is widely accepted as true (e.g. animal trivia, science facts), label it MOSTLY TRUE or LIMITED SUPPORT.
5. EVIDENCE LEVELS: STRONG | MODERATE | WEAK | NONE | CONTRADICTED. Use NONE for INCONCLUSIVE.
6. ANTI-HALLUCINATION: Never invent sources. If evidence is truly missing and your internal knowledge is low-confidence, use INCONCLUSIVE.
7. SOURCE ATTRIBUTION (CRITICAL): For EVERY claim, you MUST provide at least 2-3 real, authoritative sources in the "sources" array. Each source must have a real title, a real URL (not placeholder), and a snippet of evidence. Prioritize:
   - Tier A: Government (.gov), international bodies (.int), peer-reviewed journals (nature.com, science.org, nih.gov)
   - Tier B: Gold standard news (reuters.com, apnews.com, bbc.com, bloomberg.com)
   - Tier C: Encyclopedic (wikipedia.org, britannica.com)
   DO NOT use only one source. Aim for source diversity across different domains.
${tier0Injection}
### BATCH TO VERIFY:
${remainingToVerify.map(c => {
  // v11.6: Sanity-strip emoji hallucinations from extraction layer
  const cleanText = c.text.replace(/^[🔍\s]+/, '').trim();
  return `[ID: ${c.claimId}] Claim: "${cleanText}"`;
}).join('\n')}

RETURN JSON:
{
  "verifications": [
    {
      "claimId": "string",
      "claim": "string",
      "claimType": "string",
      "label": "string",
      "evidenceLevel": "STRONG|MODERATE|WEAK|NONE|CONTRADICTED",
      "rating": number (0-10),
      "confidence": number (0-1),
      "freshness": "string",
      "summary": "string",
      "verifiedFacts": ["string"],
      "missingEvidence": ["string"],
      "sourceConsensus": "string",
      "riskLevel": "string",
      "publicNote": "string",
      "recommendedAction": "string",
      "sources": [
        {
          "title": "Source Name",
          "url": "https://real-source-url.com/path",
          "snippet": "Key evidence excerpt from this source"
        }
      ]
    }
  ]
}`;

      // Step A: Determine if grounding is needed for remaining
      const needsGrounding = remainingToVerify.some(c =>
        (c.nature === ClaimNature.VERIFIABLE_FACT) &&
        this.shouldGroundClaim(c.text)
      );

      // v11.4 + v18.0: "Knowledge-Only" Override — but respect groundingMode: 'always'
      const allHistorical = remainingToVerify.every(c => !this.shouldGroundClaim(c.text));
      // v18.0: When groundingMode is explicitly 'always', ALWAYS ground — source attribution requires it
      const forceGrounding = options.groundingMode === 'always' || PIPELINE_CONFIG.GROUNDING_MODE === 'always';
      const enableGrounding = forceGrounding || (!allHistorical && needsGrounding);

      const hasSensitiveClaims = options.isDiscoverySensitive || options.forcePro || remainingToVerify.some(c => this.isSensitiveClaim(c, options.isDiscoverySensitive));

      const standardChain = {
        primary: PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-pro",
        fallback: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
        forcePrimary: false,
      };

      // v14.0: Changed fallback from null to Flash. Previously Pro had no fallback,
      // meaning if Pro failed (rate limit, safety filter), ALL retries hit Pro again.
      // Now Pro falls back to Flash, ensuring verification always has a path forward.
      const sensitiveChain = {
        primary: PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-pro",
        fallback: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash",
        forcePrimary: false,
      };

      const chain = (hasSensitiveClaims && enableGrounding) ? sensitiveChain : standardChain;
      const instanceId = `verification_batch_${Date.now()}`;

      const verifiedFromLLM: VerifiedClaim[] = await withAiRetry(async (modelId: string) => {
        logger.info(`[ClaimVerification] Constructing Gemini Call`, {
          modelId,
          enableGrounding,
          batchSize: remainingToVerify.length,
          claims: remainingToVerify.map(c => c.text.substring(0, 50) + "...")
        });

        // v14.0: Safety settings for fact-checking engine.
        // TruthWorld MUST be able to process content about violence, politics, 
        // assassination, military strikes, etc. — that's what it fact-checks.
        // Default Gemini safety filters block this content, causing 100% timeouts.
        const safetySettings = [
          { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
        ];

        const activeModel = this.genAI.getGenerativeModel({
          model: modelId,
          tools: enableGrounding ? [{ googleSearch: {} } as any] : undefined,
          safetySettings,
        });

        // Step B: Call Gemini with timeout support
        const tReqStart = Date.now();
        const response = await activeModel.generateContent(prompt);
        const tReqEnd = Date.now();

        const resp = response.response;
        const text = resp.candidates?.[0]?.content?.parts?.[0]?.text || "";
        const groundingMetadata = (resp.candidates?.[0] as any)?.groundingMetadata;

        logger.info(`[ClaimVerification] Gemini Call Completed`, {
          latencyMs: tReqEnd - tReqStart,
          modelId,
          groundingUsed: !!groundingMetadata
        });

        const groundingChunks = groundingMetadata?.groundingChunks || [];

        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          console.warn("No valid JSON found in verification response. Raw response was:", text);
          return [];
        }

        // Hardened Schema Validation
        let rawParsed: any;
        const sanitizedText = sanitizeJSON(jsonMatch[0]);
        try {
          rawParsed = JSON.parse(sanitizedText);
        } catch (e: any) {
          console.error("[ClaimVerification] JSON parsing failed. Error:", e.message);
          console.error("--- RAW TEXT MATCHED ---");
          console.error(jsonMatch[0]);
          console.error("--- SANITIZED TEXT ---");
          console.error(sanitizedText);
          throw e;
        }
        const validation = GeminiVerificationSchema.safeParse(rawParsed);

        if (!validation.success) {
          console.error("[ClaimVerification] Schema validation failed:", validation.error.format());
          return [];
        }

        const parsed = validation.data;

        // v11.0: Extract claim-level grounding attribution
        const groundingSupports = groundingMetadata?.groundingSupports || [];

        // Step C: Map verifications back — STRICT claimId matching only (v11.0)
        return remainingToVerify.map((claim) => {
          // v11.0: Strict claimId matching — no fuzzy substring fallback
          const verification = parsed.verifications.find(
            (v: any) => v.claimId === claim.claimId
          );

          if (!verification) {
            logger.warn(`[ClaimVerification] claimId mismatch — no Gemini result matched ${claim.claimId}`, {
              expectedId: claim.claimId,
              returnedIds: parsed.verifications.map((v: any) => v.claimId),
            });
            return {
              ...claim,
              status: "verification_timeout",
              verificationConfidence: 0.3,
              reasoning: "Claim ID mismatch during verification — marked for re-analysis.",
              sources: [],
              richSources: [],
              isGrounded: false,
              verificationMethod: 'not_verified'
            };
          }

          // v11.5: Determine verification method and evidence level
          const hasRichSources = !!groundingSupports.length;
          const skippedGrounding = !enableGrounding;
          
          let verificationMethod: VerificationMethod = 'llm_training';
          if (hasRichSources) {
            verificationMethod = 'grounded';
          } else if (skippedGrounding) {
            verificationMethod = 'deterministic'; // Verified via internal training data as a "known constant"
          }

          // v11.0: Claim-level source attribution via groundingSupports
          // Each grounding support has a text segment + indices into groundingChunks.
          // We match supports to this specific claim by checking text overlap.
          const claimRichSources: RichSource[] = [];
          const claimTextLower = claim.text.toLowerCase();

          // v18.0: First, collect Gemini's inline per-claim sources (highest quality)
          if (verification.sources && Array.isArray(verification.sources)) {
            verification.sources.forEach((src: any) => {
              if (src.url && src.url.length > 5 && !src.url.startsWith('http://example')) {
                claimRichSources.push({
                  title: src.title || 'Reference Source',
                  url: src.url,
                  tier: this.getSourceTier(src.url, domainContext),
                  snippet: src.snippet || '',
                });
              }
            });
          }

          // v18.0: Then, supplement with grounding metadata sources
          if (groundingSupports.length > 0) {
            groundingSupports.forEach((support: any) => {
              const supportText = (support.segment?.text || '').toLowerCase();
              // Check if this grounding support is relevant to this claim
              const isRelevant = supportText.length > 10 && (
                claimTextLower.includes(supportText.substring(0, Math.min(40, supportText.length))) ||
                supportText.includes(claimTextLower.substring(0, Math.min(40, claimTextLower.length)))
              );
              if (isRelevant && support.groundingChunkIndices) {
                support.groundingChunkIndices.forEach((idx: number) => {
                  const chunk = groundingChunks[idx];
                  if (chunk?.web?.uri) {
                    claimRichSources.push({
                      title: chunk.web.title || "Reference Source",
                      url: chunk.web.uri,
                      tier: this.getSourceTierFromGroundingChunk(chunk, domainContext),
                      snippet: support.segment?.text || '',
                    });
                  }
                });
              }
            });
          }

          // Fallback: if no claim-specific attribution found, use all grounding chunks
          const richSources: RichSource[] = claimRichSources.length > 0
            ? claimRichSources
            : groundingChunks
              .filter((chunk: any) => chunk.web?.uri)
              .map((chunk: any) => ({
                title: chunk.web.title || "Reference Source",
                url: chunk.web.uri,
                tier: this.getSourceTierFromGroundingChunk(chunk, domainContext),
                snippet: "",
              }));

          const status = this.mapLabelToStatus(verification.label);

          // Apply source diversity enforcement (v10.5)
          const rawSources = richSources.map(rs => ({ ...rs, tier: this.getSourceTier(rs.url, domainContext) }));
          const diverseSources = this.enforceSourceDiversity(rawSources);

          let evidenceLevel = verification.evidenceLevel as any;
          let finalStatus = status;
          let publicNote = verification.publicNote;

          if (options.sourceDiversityRequired && diverseSources.length < options.minSourcesRequired) {
            evidenceLevel = "INSUFFICIENT";
            finalStatus = 'inconclusive';
            publicNote = `Only ${diverseSources.length} unique source(s) found. Minimum ${options.minSourcesRequired} required for verification.`;
          }

          return {
            ...claim,
            status: finalStatus,
            verificationConfidence: verification.confidence,
            reasoning: verification.summary,
            sources: verification.verifiedFacts,
            richSources: diverseSources,
            isGrounded: options.groundingMode === 'always' &&
              diverseSources.some(s => s.tier === 'A' || s.tier === 'B' || s.tier === 'C') &&
              diverseSources.length >= options.minSourcesRequired,
            trueAsOf: verification.freshness,
            verificationMethod, // v11.5: deterministic | grounded | llm_training

            // v5.2: Live Grounding Engine Fields
            claimType: verification.claimType,
            rating: verification.rating,
            freshness: verification.freshness,
            verificationSummary: verification.summary,
            verifiedFacts: verification.verifiedFacts,
            missingEvidence: verification.missingEvidence,
            sourceConsensus: verification.sourceConsensus,
            riskLevel: verification.riskLevel,
            publicNote: publicNote,
            recommendedAction: verification.recommendedAction,
            evidenceLevel: evidenceLevel,
            ontology: (verification.claimType as any) || claim.nature, // Use nature if claimType missing
            freshnessScore: verification.rating / 10 // Map 0-10 rating to 0-1 score
          };
        });
      }, chain, { maxAttempts: maxAttemptsOverride ?? 1, instanceId, signal });

      return [...preVerified, ...verifiedFromLLM];
    } catch (error) {
      console.error("Error verifying claims batch:", error);
      throw error;
    }
  }

  /**
   * Verify all filtered claims (v5.0: PARALLEL execution)
   * Splits claims by risk tier and verifies in parallel batches using Promise.allSettled.
   * Target latency: under 12s for short-form, under 20s for long-form.
   */
  async verifyClaims(
    filteredClaims: FilteredClaim[],
    claimsPerBatch: number = 10, // v10.6: batch size now driven by caller
    maxConcurrent: number = 3,
    domainContext: string = "General",
    options: {
      groundingMode: 'always' | 'sensitive_only' | 'never';
      forcePro: boolean;
      minSourcesRequired: number;
      sourceDiversityRequired: boolean;
      isDiscoverySensitive?: boolean;
      isRetryPass?: boolean; // v10.6: flag for retry pass routing
      jobId?: string; // v11.5: for circuit breaker logging
    } = {
        groundingMode: 'auto' as any,
        forcePro: false,
        minSourcesRequired: 1,
        sourceDiversityRequired: false
      }
  ): Promise<{ claims: VerifiedClaim[], batchStats: { completed: number, timedOut: number } }> {
    if (filteredClaims.length === 0) {
      console.log("No claims to verify");
      return { claims: [], batchStats: { completed: 0, timedOut: 0 } };
    }

    const isRetryPass = options.isRetryPass ?? false;

    // Deduplication logic (only if not a retry pass)
    let claimsToVerify = filteredClaims;
    const duplicateMap = new Map<string, FilteredClaim[]>();
    const primaryClaimMap = new Map<string, FilteredClaim>();

    if (!isRetryPass) {
      const uniqueClaims: FilteredClaim[] = [];
      filteredClaims.forEach(claim => {
        const normalized = normalizeClaimText(claim.text);
        if (!primaryClaimMap.has(normalized)) {
          primaryClaimMap.set(normalized, claim);
          uniqueClaims.push(claim);
          duplicateMap.set(normalized, []);
        } else {
          duplicateMap.get(normalized)!.push(claim);
        }
      });
      claimsToVerify = uniqueClaims;
      console.log(`[ClaimVerification] Deduplication: ${filteredClaims.length} input claims -> ${uniqueClaims.length} unique claims`);
    }

    console.log(
      `[ClaimVerification] Starting ${isRetryPass ? 'RETRY' : 'PARALLEL'} verification of ${claimsToVerify.length} claims (batch size: ${claimsPerBatch})`
    );

    // Step 1: Split claims into risk-based groups for model routing
    const sensitiveClaims = claimsToVerify.filter(c => this.isSensitiveClaim(c, options.isDiscoverySensitive));
    const standardClaims = claimsToVerify.filter(c => !this.isSensitiveClaim(c, options.isDiscoverySensitive));

    console.log(`[ClaimVerification] Risk split: ${sensitiveClaims.length} sensitive (Pro), ${standardClaims.length} standard (Flash)`);

    // Step 2: Create batches for each group
    const createBatches = (claims: FilteredClaim[], batchSize: number): FilteredClaim[][] => {
      const batches: FilteredClaim[][] = [];
      for (let i = 0; i < claims.length; i += batchSize) {
        batches.push(claims.slice(i, i + batchSize));
      }
      return batches;
    };

    const sensitiveBatches = createBatches(sensitiveClaims, Math.min(claimsPerBatch, 5)); // Smaller batches for Pro
    const standardBatches = createBatches(standardClaims, claimsPerBatch);

    // Step 3: Define batch factories
    // Factory pattern ensures promises only start when we reach their wave in the loop
    const allBatchFactories = [
      ...sensitiveBatches.map((batch, idx) => ({
        factory: (signal?: AbortSignal, maxAttempts?: number) => this.verifyClaimBatch(batch, domainContext, { ...options, isDiscoverySensitive: true }, signal, maxAttempts),
        label: `sensitive_${idx}`,
        claims: batch,
      })),
      ...standardBatches.map((batch, idx) => ({
        factory: (signal?: AbortSignal, maxAttempts?: number) => this.verifyClaimBatch(batch, domainContext, options, signal, maxAttempts),
        label: `standard_${idx}`,
        claims: batch,
      })),
    ];

    // Process with concurrency control
    const allVerified: VerifiedClaim[] = [];
    let completed = 0;
    let timedOut = 0;

    // Concurrency state for Adaptive Concurrency
    let concurrency = {
      current: maxConcurrent,
      min: 1,
      max: maxConcurrent,
      consecutiveSuccesses: 0,
      consecutiveFailures: 0,
    };

    let batchIndex = 0;
    while (batchIndex < allBatchFactories.length) {
      const wave = allBatchFactories.slice(batchIndex, batchIndex + concurrency.current);
      batchIndex += wave.length;

      // v10.6: Dynamic timeout per batch — accounts for model, grounding, and batch size
      // BUG FIX: Check if wave contains sensitive batches (routed to Pro internally)
      const waveBatchSize = wave.length > 0 ? wave[0].claims.length : claimsPerBatch;
      const waveHasSensitiveClaims = wave.some(w => w.label.startsWith('sensitive_'));
      const batchTimeoutMs = calculateBatchTimeout(
        waveBatchSize,
        options.groundingMode,
        waveHasSensitiveClaims || (options.forcePro ?? false), // use Pro timeout if any batch is sensitive
        isRetryPass
      );

      logger.info(`[ClaimVerification] Wave timeout: ${batchTimeoutMs}ms for ${waveBatchSize} claims (retry=${isRetryPass})`);

      const waveController = new AbortController();
      const results = await Promise.allSettled(
        wave.map(async (w) => {
          const waveSignal = waveController.signal;

          // v13.2: Correct timeout-then-recover architecture.
          // Race the factory against a simple timer. Recovery runs AFTER the race is decided,
          // not inside a competing promise (which caused the abort-rejection to win every time).
          type RaceResult = { type: 'success'; claims: VerifiedClaim[] } | { type: 'timeout' };

          const raceResult = await Promise.race([
            w.factory(waveSignal, isRetryPass ? 2 : 1)
              .then((claims): RaceResult => ({ type: 'success', claims }))
              .catch((): RaceResult => ({ type: 'timeout' })), // Abort/error → treat as timeout
            new Promise<RaceResult>(resolve =>
              setTimeout(() => resolve({ type: 'timeout' }), batchTimeoutMs)
            )
          ]);

          // Case 1: Factory resolved successfully with real results
          if (raceResult.type === 'success') {
            const allTimedOut = raceResult.claims.length > 0 &&
              raceResult.claims.every(c => c.status === 'verification_timeout' || (c as any).failureReason === 'timeout');

            if (!allTimedOut) {
              return raceResult.claims; // Real results — use them
            }
            // Factory "succeeded" but returned all-timeout claims (e.g. claimId mismatch) — fall through to recovery
          }

          // Case 2: Timeout or all-timeout factory results — run Fast Knowledge Recovery
          console.warn(`[ClaimVerification] Wave batch timeout for ${w.claims.length} claims. Running Fast Knowledge Recovery.`);
          waveController.abort(); // Kill any lingering grounded calls

          try {
            const recovered = await this.verifyBatchWithFastKnowledge(w.claims, options.jobId || "unknown");
            logger.info(`[ClaimVerification] Recovery Pass succeeded for ${recovered.length} claims`);
            return recovered;
          } catch (err) {
            logger.error(`[ClaimVerification] Recovery Pass failed: ${(err as any).message}`, { jobId: options.jobId });
            return w.claims.map(c => ({
              ...c,
              status: "verification_timeout" as ClaimStatus,
              verificationConfidence: 0.1,
              reasoning: "Critical infrastructure failure — both grounding and recovery pass failed.",
              sources: [],
              richSources: [],
              evidenceLevel: EvidenceLevel.NONE,
              importance: c.importance || 0.5,
              timedOutAt: Date.now(),
              failureReason: 'timeout'
            }));
          }
        })
      );

      const failures = results.filter(r => r.status === 'rejected').length;
      const outcome = failures === 0 ? 'success' : failures === wave.length ? 'failure' : 'partial';

      for (let idx = 0; idx < results.length; idx++) {
        const result = results[idx];
        if (result.status === 'fulfilled') {
          allVerified.push(...result.value);
          const isActuallyTimeout = result.value.some(c => c.timedOutAt !== undefined);
          if (isActuallyTimeout) timedOut++;
          else completed++;
        } else {
          console.warn(`[ClaimVerification] Wave batch REJECTED: ${result.reason}`);
          allVerified.push(...wave[idx].claims.map(c => ({
            ...c,
            status: "verification_timeout" as ClaimStatus,
            verificationConfidence: 0,
            reasoning: 'Wave batch failed during execution (AI or Network error).',
            sources: [],
            richSources: [],
            evidenceLevel: EvidenceLevel.NONE,
            importance: c.importance || 0.5,
            timedOutAt: Date.now(), // v10.6: mark as timed out for retry
            failureReason: 'timeout'
          })));
        }
      }

      // Adjust concurrency for next wave
      const isWaveActuallyTimeout = results.some(r => r.status === 'fulfilled' && r.value.some((c: any) => c.failureReason === 'timeout'));
      
      if (outcome === 'failure' || isWaveActuallyTimeout) {
        concurrency.current = Math.max(concurrency.min, concurrency.current - 1);
        concurrency.consecutiveSuccesses = 0;
        concurrency.consecutiveFailures++;
      } else if (outcome === 'partial') {
        concurrency.current = Math.max(concurrency.min, Math.floor(concurrency.current * 0.5));
        concurrency.consecutiveSuccesses = 0;
        concurrency.consecutiveFailures++;
      } else {
        concurrency.consecutiveSuccesses++;
        if (concurrency.consecutiveSuccesses >= 2 && concurrency.current < concurrency.max) {
          concurrency.current++;
        }
        concurrency.consecutiveFailures = 0;
      }

      if (concurrency.consecutiveFailures >= 3) {
        logger.error(`[ClaimVerification] CIRCUIT BREAKER: 3 consecutive waves timed out or failed. Aborting remaining batches.`, {
          remaining: allBatchFactories.length - batchIndex,
          jobId: options.jobId
        });
        
        // Mark remaining batches — attempt Fast Knowledge Recovery instead of hard-kill
        const remaining = allBatchFactories.slice(batchIndex);
        for (const batch of remaining) {
          try {
            const recovered = await this.verifyBatchWithFastKnowledge(batch.claims, options.jobId || "unknown");
            allVerified.push(...recovered);
          } catch (e) {
            allVerified.push(...batch.claims.map(c => ({
              ...c,
              status: "verification_timeout" as ClaimStatus,
              verificationConfidence: 0,
              reasoning: 'Verification aborted due to persistent pipeline latency (Circuit Breaker). Recovery also failed.',
              sources: [],
              richSources: [],
              evidenceLevel: EvidenceLevel.NONE,
              importance: c.importance || 0.5,
              timedOutAt: Date.now(),
              failureReason: 'timeout'
            })));
          }
          timedOut++;
        }
        break; 
      }

      if (outcome !== 'success') {
        logger.info(`[AdaptiveConcurrency] Adjusted concurrency to ${concurrency.current} after ${outcome} wave.`);
      }
    }

    // ── v10.6: RETRY PASS — Re-verify timed-out claims with smaller batches ──
    // Only retry claims with importance >= 0.5 to avoid wasting API cost.
    // Routes through the same wave system (recursive call) with sequential concurrency.
    if (!isRetryPass) {
      const timedOutClaims = allVerified.filter(
        c => (c.status === 'inconclusive' || c.status === 'verification_timeout') &&
          c.timedOutAt !== undefined &&
          (c.importance ?? 0.5) >= 0.5
      );

      if (timedOutClaims.length > 0 && timedOutClaims.length <= 10) {
        logger.info(`[ClaimVerification] Retry pass: ${timedOutClaims.length} claims (importance >= 0.5)`);

        const retryResult = await this.verifyClaims(
          timedOutClaims as FilteredClaim[],
          2,                    // batch size of 2 for retry
          1,                    // sequential — no parallel pressure during retry
          domainContext,
          {
            ...options,
            isRetryPass: true,  // flag so wave system knows this is a retry (60s flat timeout)
          }
        );

        // Replace original results with retry results
        for (const retried of retryResult.claims) {
          const idx = allVerified.findIndex(c => c.claimId === retried.claimId);
          if (idx !== -1) allVerified[idx] = retried;
        }

        const recoveredCount = retryResult.claims.filter(c => c.status !== 'inconclusive').length;
        logger.info(`[ClaimVerification] Retry pass complete. ${recoveredCount} claims recovered.`);
      } else if (timedOutClaims.length > 10) {
        logger.warn(`[ClaimVerification] Too many timed-out claims (${timedOutClaims.length}) — skipping retry pass to avoid cost.`);
      }

      // ── v10.6: Final conversion — remaining unverifiable+timedOutAt → inconclusive ──
      for (const claim of allVerified) {
        if ((claim.status === 'unproven' || claim.status === 'inconclusive') && claim.timedOutAt) {
          claim.status = 'inconclusive';
          claim.verificationConfidence = 0.1;
          claim.reasoning = 'Verification timed out during deep research. The claim has been marked inconclusive as evidence could not be retrieved in the allotted time.';
          claim.publicNote = 'Evidence Inconclusive';
        }
      }
    }

    let finalClaims = allVerified;
    if (!isRetryPass) {
      finalClaims = [];
      const verifiedByNormalized = new Map<string, VerifiedClaim>();

      for (const verifiedClaim of allVerified) {
        const normalized = normalizeClaimText(verifiedClaim.text);
        verifiedByNormalized.set(normalized, verifiedClaim);
        
        // Log telemetry for primary claim (cacheHit: false)
        await telemetryService.record({
          claimId: verifiedClaim.claimId,
          claimHash: hashClaimText(verifiedClaim.text),
          videoId: options.jobId || "unknown",
          category: (verifiedClaim as any).claimType || "empirical",
          riskLevel: (verifiedClaim as any).riskLevel || "low",
          verificationOutcome: verifiedClaim.status,
          verificationPath: verifiedClaim.verificationMethod || "not_verified",
          latencyMs: 0,
          providerUsed: "vertexai",
          fallbackUsed: false,
          cacheHit: false,
          retryCount: 0,
          confidenceDelta: 0,
          costUsd: 0
        });
      }

      // Re-map in original input order
      for (const inputClaim of filteredClaims) {
        const normalized = normalizeClaimText(inputClaim.text);
        const primaryClaim = primaryClaimMap.get(normalized);
        const primaryVerified = verifiedByNormalized.get(normalized);

        if (inputClaim.claimId === primaryClaim?.claimId) {
          if (primaryVerified) {
            finalClaims.push(primaryVerified);
          } else {
            finalClaims.push({
              ...inputClaim,
              status: "verification_timeout",
              verificationConfidence: 0.1,
              reasoning: "Primary claim was not verified.",
              sources: [],
              richSources: [],
              isGrounded: false,
              verificationMethod: 'not_verified'
            });
          }
        } else {
          if (primaryVerified) {
            const dupClaim: VerifiedClaim = {
              ...primaryVerified,
              claimId: inputClaim.claimId,
              verificationMethod: 'cache_hit' as any
            };
            finalClaims.push(dupClaim);

            // Log telemetry for duplicate (cacheHit: true)
            await telemetryService.record({
              claimId: inputClaim.claimId,
              claimHash: hashClaimText(inputClaim.text),
              videoId: options.jobId || "unknown",
              category: (primaryVerified as any).claimType || "empirical",
              riskLevel: (primaryVerified as any).riskLevel || "low",
              verificationOutcome: primaryVerified.status,
              verificationPath: 'cache_hit',
              latencyMs: 0,
              providerUsed: "vertexai",
              fallbackUsed: false,
              cacheHit: true,
              retryCount: 0,
              confidenceDelta: 0,
              costUsd: 0
            });
          } else {
            finalClaims.push({
              ...inputClaim,
              status: "verification_timeout",
              verificationConfidence: 0.1,
              reasoning: "Primary claim verification failed — duplicate marked as timeout.",
              sources: [],
              richSources: [],
              isGrounded: false,
              verificationMethod: 'not_verified'
            });
          }
        }
      }
    }

    console.log(`\u2705 Verified ${finalClaims.length} claims (${isRetryPass ? 'retry' : 'parallel'} mode)`);
    return { claims: finalClaims, batchStats: { completed, timedOut } };
  }

  /**
   * Double-check high-impact claims (optional)
   * Re-verify claims with controversial status
   */
  async doubleCheckHighImpactClaims(
    verifiedClaims: VerifiedClaim[]
  ): Promise<VerifiedClaim[]> {
    // Select claims for double-checking:
    // - Incorrect claims with confidence < 0.8
    // - Unverifiable claims with confidence < 0.6
    const needsDoubleCheck = verifiedClaims.filter(
      (claim) =>
        (claim.status === "false_claim" && claim.verificationConfidence < 0.8) ||
        ((claim.status === "unproven" || claim.status === "inconclusive") && claim.verificationConfidence < 0.6)
    );

    if (needsDoubleCheck.length === 0) {
      return verifiedClaims;
    }

    console.log(
      `Double-checking ${needsDoubleCheck.length} high-impact claims`
    );

    // Re-verify high-impact claims with Pro + grounding for accuracy
    const reVerified = await this.verifyClaimBatch(needsDoubleCheck, 'General', {
      groundingMode: 'always',
      forcePro: true,      // double-check always uses Pro
      minSourcesRequired: 2,
      sourceDiversityRequired: true,
    });

    // Replace original verifications with reVerifications
    const result = verifiedClaims.map((claim) => {
      const reVerified2 = reVerified.find((rv) => rv.claimId === claim.claimId);
      return reVerified2 || claim;
    });

    return result;
  }

  /**
   * v10.5: Enforce domain diversity in sources.
   * Rejects results where multiple sources come from the same domain.
   */
  private enforceSourceDiversity(sources: RichSource[]): RichSource[] {
    const seenDomains = new Set<string>();
    return sources.filter(s => {
      if (!s.url || s.url === "#" || s.url.startsWith("#")) return true; // Keep registry/mock sources
      try {
        const domain = sourceTrustService.resolveSourceTrust(s.url).domain;
        if (seenDomains.has(domain)) return false;
        seenDomains.add(domain);
        return true;
      } catch (e) {
        return true;
      }
    });
  }

  private mapLabelToStatus(label: string): ClaimStatus {
    const l = label.toUpperCase();
    if (l.includes("VERIFIED TRUE")) return "verified_true";
    if (l.includes("MOSTLY TRUE")) return "mostly_true";
    if (l.includes("DISPUTED")) return "disputed";
    if (l.includes("UNPROVEN") || l.includes("UNSUPPORTED")) return "inconclusive";
    if (l.includes("FALSE CLAIM")) return "false_claim";
    if (l.includes("MISLEADING")) return "misleading";
    return "inconclusive";
  }

  /**
   * 🏷 v13.0: Zero-Timeout Fast Recovery Pass
   * Verifies claims using Gemini's internal training data (No Grounding).
   * Used as a fallback when search/grounding takes too long.
   */
  public async verifyBatchWithFastKnowledge(claims: FilteredClaim[], jobId: string): Promise<VerifiedClaim[]> {
    logger.info(`[ClaimVerification] Initiating Fast Knowledge Recovery Pass for ${claims.length} claims`, { jobId });
    
    const prompt = `ROLE: TruthWorld Epistemic Recovery Engine.
OBJECTIVE: Verify this batch of claims using your INTERNAL TRAINING DATA only.
CONTEXT: Grounding infrastructure timed out. Provide the best possible verdict based on general consensus knowledge.

Claims to Verify:
${claims.map(c => `[ID: ${c.claimId}] ${c.text}`).join('\n')}

Output JSON:
{
  "verifications": [
    {
      "claimId": "ID",
      "status": "VERIFIED TRUE | MOSTLY TRUE | DISPUTED | UNSUPPORTED | FALSE CLAIM | MISLEADING",
      "reasoning": "Explain based on consensus knowledge.",
      "confidence": 0.8
    }
  ]
}
Return ONLY JSON.`;

    const recoveryChain = { primary: "gemini-2.5-flash", fallback: null, forcePrimary: true };
    
    return withAiRetry(async (modelId: string) => {
      const activeModel = this.genAI.getGenerativeModel({ 
        model: modelId,
        safetySettings: [
          { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
          { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
        ],
      });
      const res = await activeModel.generateContent(prompt);
      const text = res.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const match = text.match(/\{[\s\S]*\}/);
      if (!match) throw new Error("No JSON in recovery response");
      
      const parsed = JSON.parse(sanitizeJSON(match[0]));
      return claims.map(c => {
        const v = parsed.verifications.find((v: any) => v.claimId === c.claimId);
        return {
          ...c,
          status: v ? this.mapLabelToStatus(v.status) : ("inconclusive" as ClaimStatus),
          verificationConfidence: v ? v.confidence : 0.4,
          reasoning: v ? `[RECOVERY PASS] ${v.reasoning}` : "Recovery pass failed to provide verdict.",
          sources: ["Internal Knowledge Recovery"],
          richSources: [],
          evidenceLevel: EvidenceLevel.WEAK,
          importance: c.importance || 0.5,
          verificationMethod: 'llm_training'
        };
      });
    }, recoveryChain, { maxAttempts: 2, instanceId: "FastKnowledgeRecovery" });
  }
}

import { GoogleGenerativeAI } from "@google/generative-ai";
import { PIPELINE_CONFIG } from "../config";
import {
  ClaimStatus,
  EvidenceLevel,
  ExtractedClaim,
  FilteredClaim,
  GeminiVerificationSchema,
  RichSource,
  SourceTier,
  VerifiedClaim,
} from "../types";
import { registryService } from "../registry/RegistryService";
import { containsVerifiablePredicate } from "./contentIntentDetector";
import { withAiRetry } from "../utils/ai-utils";
import { logger } from "../utils/logger";

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

  // Base timeouts by mode
  const baseTimeout = isProModel && isGrounded ? 45_000   // Pro + grounding
    : isGrounded ? 30_000   // Flash + grounding
      : 20_000;  // Flash, no grounding

  // Per-claim addition
  const perClaimMs = isProModel && isGrounded ? 12_000   // Pro + grounding: 12s/claim
    : isGrounded ? 8_000    // Flash + grounding: 8s/claim
      : 5_000;   // Standard: 5s/claim

  // Retry pass gets a flat 60s regardless of model
  if (isRetryPass) return 60_000;

  return Math.min(
    baseTimeout + (batchSize * perClaimMs),
    120_000  // hard ceiling — never wait more than 2 minutes per batch
  );
}

/**
 * 🔹 C. Claim Verification Service
 *
 * Verifies claims using Gemini
 * Input: batch of claims (10-20)
 * Output: status (correct/incorrect/unverifiable) + confidence + reasoning
 */
export class ClaimVerificationService {
  private genAI: GoogleGenerativeAI;
  private confidenceThreshold: number;

  constructor(apiKey: string, confidenceThreshold: number = 0.6) {
    this.genAI = new GoogleGenerativeAI(apiKey);
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
    ];

    // Pattern match
    if (sensitivePatterns.some(p => p.test(text))) return true;

    // Domain match
    const sensitiveDomains = PIPELINE_CONFIG.SENSITIVE_DOMAINS || [];
    if (sensitiveDomains.some((d: string) => text.includes(d))) return true;

    // High-importance factual claims
    if ((claim.nature === 'FACTUAL') && text.length > 80) return true;

    return false;
  }

  /**
   * Helper to determine if a claim mentions a recent event or launch
   */
  private shouldGroundClaim(text: string, isLaunchNews: boolean = false): boolean {
    if (isLaunchNews) return true; // v5.2: Force grounding for launches
    const freshMarkers = [
      /\blaunched\b/i, /\bannounced\b/i, /\breleased\b/i, /\bjust in\b/i,
      /\brecently\b/i, /\bnew product\b/i, /\bupcoming\b/i, /\bfeature\b/i,
      /\btoday\b/i, /\byesterday\b/i, /\bthis week\b/i, /\bbreaking\b/i,
      /\bdeployment\b/i, /\brollout\b/i, /\bupdate\b/i
    ];
    return freshMarkers.some(regex => regex.test(text));
  }

  /**
   * Assigns a tier to a source based on its domain
   */
  private getSourceTier(url: string, domainContext: string = "General"): SourceTier {
    const lowUrl = url.toLowerCase();

    // Tier A: Official sources / Gold standard
    const officialTech = ["anthropic.com", "openai.com", "google.com", "apple.com", "microsoft.com", "nvidia.com", "meta.com"];
    const officialGov = [".gov", ".edu", "who.int", "nih.gov", "fda.gov", "sec.gov", "ecb.europa.eu"];

    if (officialGov.some(d => lowUrl.includes(d)) || officialTech.some(d => lowUrl.includes(d))) return 'A';

    // Tier B: Institutional Press / Primary Agencies
    const tier1Press = ["reuters.com", "apnews.com", "bloomberg.com", "wsj.com", "nytimes.com", "ft.com"];
    if (tier1Press.some(d => lowUrl.includes(d))) return 'B';

    // Tier C: Specialized Press / Enthusiast
    const techPress = ["techcrunch.com", "theverge.com", "wired.com", "engadget.com", "zdnet.com"];
    if (techPress.some(d => lowUrl.includes(d))) return 'C';

    return 'D';
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
      const claimId = `claim_${Date.now()}_${idx}`;
      const tagged: FilteredClaim = { ...claim, claimId };

      // Gate 1: Minimum confidence threshold
      // v5.1: Lower threshold for launch news to ensure critical product claims aren't missed
      const effectiveThreshold = this.confidenceThreshold * (isLaunchNews ? 0.66 : 1.0); // 0.4 instead of 0.6 for launches
      if (claim.confidence < effectiveThreshold) {
        filteringReasons.push(`Claim "${claim.text.substring(0, 40)}..." filtered: confidence ${claim.confidence} below ${effectiveThreshold.toFixed(2)}`);
        return; // Drop entirely
      }

      // Gate 2: Satirical content is never verified
      if (claim.nature === 'SATIRE') {
        opinions.push(tagged);
        filteringReasons.push(`Claim "${claim.text.substring(0, 40)}..." labeled satirical — skipping verification`);
        return;
      }

      // Gate 3: Unclear claims (dropped if nature is unknown or low confidence)
      // v8.5: We strictly use nature now

      // === ROUTING MATRIX ===

      // v11.0 Safety Net: Route claims with missing or unrecognized nature to verification
      // This prevents claims from being dropped when Gemini's extraction classifier is uncertain
      const recognizedNatures = ['FACTUAL', 'OPINION', 'PREDICTION', 'THEORY', 'BELIEF', 'SATIRE'];
      if (!claim.nature || !recognizedNatures.includes(claim.nature as string)) {
        toVerify.push(tagged);
        filteringReasons.push(`Claim "${claim.text.substring(0, 40)}..." had nature=${claim.nature || 'undefined'} — routed to verify (safety net)`);
        return;
      }

      // Route A: Explicitly factual natures → always verify
      const factualNatures = ['FACTUAL', 'THEORY', 'PREDICTION'];
      if (factualNatures.includes(claim.nature)) {
        toVerify.push(tagged);
        return;
      }

      // Route B: Opinion/belief types — but check for hidden verifiable predicates
      const opinionNatures = ['OPINION', 'BELIEF'];
      if (opinionNatures.includes(claim.nature)) {
        // CRITICAL FIX: If the claim LOOKS like an opinion but contains a
        // verifiable predicate, it should be verified, not filtered.
        if (claim.isVerifiableEvent || containsVerifiablePredicate(claim.text)) {
          console.log(`[ClaimRouter] Rescued verifiable claim from opinion bucket: "${claim.text.substring(0, 50)}..."`);
          toVerify.push(tagged);
          return;
        }
        opinions.push(tagged);
        return;
      }

      // Route C: Everything else (unclear with high confidence, etc.) → verify
      // Safety net: when classifier confidence is low, route to verify anyway
      // (better false positives than missed truth checks)
      toVerify.push(tagged);
    });

    console.log(
      `[ClaimRouter] Routing: ${claims.length} total → ${toVerify.length} verify, ${opinions.length} opinions, ${claims.length - toVerify.length - opinions.length} dropped`
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
        groundingMode: 'auto' as any,
        forcePro: false,
        minSourcesRequired: 1,
        sourceDiversityRequired: false
      }
  ): Promise<VerifiedClaim[]> {
    if (claims.length === 0) {
      return [];
    }

    // Format claims for batch processing



    try {
      // 🛡 NEW: LAYER 4 Deterministic Registry Bypass
      const preVerified: VerifiedClaim[] = [];
      const remainingToVerify: FilteredClaim[] = [];

      for (const claim of claims) {
        const registryCheck = registryService.resolveTruthCheck(claim.text);
        if (registryCheck) {
          preVerified.push({
            ...claim,
            status: registryCheck.status as any,
            nature: claim.nature,
            ontology: claim.nature as any,
            verificationConfidence: 1.0,
            evidenceConfidence: 1.0,
            reasoning: registryCheck.reasoning,
            sources: [registryCheck.source],
            richSources: [{ title: registryCheck.source, url: "#", tier: "A", snippet: registryCheck.reasoning }],
            isGrounded: true
          });
        } else {
          remainingToVerify.push(claim);
        }
      }

      if (remainingToVerify.length === 0) return preVerified;

      const useDeepResearchPrompt = options.groundingMode === 'always';

      const prompt = useDeepResearchPrompt
        ? `SYSTEM PROMPT - TRUTHWORLD DEEP RESEARCH MASTER PROMPT v10.5
You are an institutional fact-checker performing exhaustive deep research.

For each claim provided, you must:

1. SEARCH GLOBALLY: Use Google Search to find sources from multiple regions, institutions, and perspectives. Do not limit yourself to English-language or Western sources.

2. CROSS-SOURCE VALIDATION: Verify each claim against a minimum of ${options.minSourcesRequired} independent sources. Sources must come from different domains — do not accept two results from the same website.

3. CLASSIFY EVIDENCE: For each source found, assign:
   - tier: "A" (peer-reviewed / government / WHO / official institution)
   - tier: "B" (established news organization / university press)
   - tier: "C" (credible secondary source / expert blog)
   - tier: "D" (forum / unverified / social media)

4. RETURN STRUCTURED RESULTS: For each claim return:
   - status: correct | mostly_correct | incorrect | needs_context | outdated | unsupported | unverifiable
   - evidenceLevel: STRONG | MODERATE | WEAK | NONE | CONTRADICTED
   - verifiedFacts: string[] — direct findings from sources (quote the relevant fact)
   - missingEvidence: string[] — what you could not find or confirm
   - sourceConsensus: "consensus" | "disputed" | "no_data"
   - richSources: [{title, url, domain, publishedAt, tier, snippet}]
   - publicNote: plain-language summary for viewers
   - recommendedAction: what a viewer should do with this information

CONSTRAINT: You may only use information found via the Google Search tool. You are strictly prohibited from using your internal training knowledge to confirm or deny any factual claim. If search returns no results, return evidenceLevel: "NONE".

Claims to research:
${remainingToVerify.map((c, i) => `[${i + 1}] "${c.text}" (ID: ${c.claimId})`).join('\n')}

Return ONLY valid JSON object with "verifications" array.
`
        : `SYSTEM PROMPT - TRUTHWORLD LIVE GROUNDING MASTER PROMPT v10.0
STRICT CONSTRAINT: You must only verify claims using the provided source documents and registry data. 
You are PROHIBITED from using your internal training knowledge to confirm or deny any factual claim.
If no registry source supports a claim, return evidenceLevel: "NONE" — do not infer from training data.

ROLE:
You are TruthWorld’s Institutional Verification Engine.
Your duty is to determine what is TRUE, FALSE, UNVERIFIED, MISLEADING, OUTDATED, PARTLY TRUE, OPINION, THEORY, BELIEF, SATIRE, PROPAGANDA, or QUESTIONABLE using the most current information available.

DEEP RESEARCH PROTOCOL (v10.5):
1. Use Google Search tools for EVERY claim.
2. Cross-reference multiple high-tier sources (Tier 1-2).
3. Look for contradictions, retractions, or recent updates.
4. If a claim is "partially true", pinpoint exactly which part is verified and which is not.
5. Identify the "latest known state" of any event or metric.

You are NOT a chatbot.
You are a live truth investigator.

--------------------------------------------------
PRIMARY OBJECTIVE
--------------------------------------------------

Given any claim, transcript, article, speech, creator statement, breaking news alert, historical statement, conspiracy claim, religious claim, economic claim, war claim, political claim, or viral rumor:

You must determine:
1. What exactly is being claimed?
2. Is it factual, opinion, prediction, theory, belief, satire, or propaganda?
3. Is it true right now?
4. Was it true before but outdated now?
5. Is there enough evidence?
6. Are trusted sources confirming it?
7. Is it manipulated framing?
8. What is the confidence level?
9. What should public users know?

--------------------------------------------------
LIVE GROUNDING REQUIREMENT (MANDATORY)
--------------------------------------------------

For any time-sensitive claim, you MUST use freshest available sources.
If evidence unavailable, say so clearly.

--------------------------------------------------
SOURCE HIERARCHY
--------------------------------------------------

Tier 1 (Highest Trust): Official Gov, Courts, UN/WHO/IMF, Stock Exchanges, Official Press Releases.
Tier 2: Reuters, AP, AFP, Bloomberg, BBC, FT, WSJ.
Tier 3: Reputable specialist media.
Tier 4: Wikipedia (background only).
Tier 5 (Low Trust): Social media, Influence posts, Anonymous blogs.

--------------------------------------------------
CLAIM TYPES
--------------------------------------------------
A. FACT CLAIM, B. BREAKING NEWS, C. HISTORICAL CLAIM, D. OPINION, E. PREDICTION, F. THEORY, G. BELIEF, H. SATIRE, I. QUESTION, J. PROPAGANDA.

--------------------------------------------------
TRUTH LABELS
--------------------------------------------------
1. VERIFIED TRUE, 2. MOSTLY TRUE, 3. PARTLY TRUE, 4. NEEDS CONTEXT, 5. OUTDATED, 6. UNVERIFIED, 7. FALSE, 8. MISLEADING, 9. DISPUTED, 10. DEVELOPING STORY, 11. OPINION, 12. BELIEF / FAITH CLAIM, 13. PREDICTION, 14. SATIRE, 15. QUESTION / INQUIRY

--------------------------------------------------
EVIDENCE LEVELS
--------------------------------------------------
- "STRONG": Multiple independent high-tier sources.
- "MODERATE": Some reliable sources, but not definitive.
- "WEAK": Single source or anecdotal evidence only.
- "NONE": No evidence found.
- "CONTRADICTED": Credible sources explicitly disprove the claim.

--------------------------------------------------
ANTI-HALLUCINATION LAW
--------------------------------------------------
Never invent evidence. Never guess. If insufficient evidence, say UNVERIFIED.

--------------------------------------------------
OUTPUT FORMAT (MANDATORY JSON ARRAY)
--------------------------------------------------
Return a JSON object with a "verifications" array. Each object in the array MUST follow:
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
  "recommendedAction": "string"
}

### BATCH TO VERIFY:
${remainingToVerify.map(c => `[ID: ${c.claimId}, Context: ${domainContext}] Claim: "${c.text}"`).join('\n')}

Return ONLY valid JSON.`;

      // Step A: Determine if grounding is needed for remaining
      const needsGrounding = remainingToVerify.some(c =>
        (c.nature === 'FACTUAL') &&
        this.shouldGroundClaim(c.text)
      ) || PIPELINE_CONFIG.GROUNDING_MODE === 'always';

      const hasSensitiveClaims = options.isDiscoverySensitive || options.forcePro || remainingToVerify.some(c => this.isSensitiveClaim(c, options.isDiscoverySensitive));
      const enableGrounding = options.groundingMode === 'always' || needsGrounding;

      const standardChain = {
        primary: PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-pro",
        fallback: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
        forcePrimary: false,
      };

      const sensitiveChain = {
        primary: PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-pro",
        fallback: null,
        forcePrimary: true,
      };

      const chain = hasSensitiveClaims ? sensitiveChain : standardChain;
      const instanceId = `verification_batch_${Date.now()}`;

      const verifiedFromLLM: VerifiedClaim[] = await withAiRetry(async (modelId: string) => {
        const activeModel = this.genAI.getGenerativeModel({
          model: modelId,
          tools: enableGrounding ? [{ googleSearch: {} }] as any : undefined
        });

        const response = await activeModel.generateContent(prompt);
        const text = response.response.text();

        const groundingMetadata = (response.response.candidates?.[0] as any)?.groundingMetadata;
        const groundingChunks = groundingMetadata?.groundingChunks || [];

        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          console.warn("No valid JSON found in verification response");
          return [];
        }

        // Hardened Schema Validation
        const rawParsed = JSON.parse(jsonMatch[0]);
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
              status: "unverifiable",
              verificationConfidence: 0.3,
              reasoning: "Claim ID mismatch during verification — marked for re-analysis.",
              sources: [],
              richSources: [],
              isGrounded: false
            };
          }

          // v11.0: Claim-level source attribution via groundingSupports
          // Each grounding support has a text segment + indices into groundingChunks.
          // We match supports to this specific claim by checking text overlap.
          const claimRichSources: RichSource[] = [];
          const claimTextLower = claim.text.toLowerCase();

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
                      tier: this.getSourceTier(chunk.web.uri),
                      snippet: support.segment?.text || '',
                    });
                  }
                });
              }
            });
          }

          // Fallback: if no claim-specific attribution found, use all grounding chunks (legacy)
          const richSources: RichSource[] = claimRichSources.length > 0
            ? claimRichSources
            : groundingChunks
              .filter((chunk: any) => chunk.web?.uri)
              .map((chunk: any) => ({
                title: chunk.web.title || "Reference Source",
                url: chunk.web.uri,
                tier: this.getSourceTier(chunk.web.uri),
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
            finalStatus = 'unverifiable';
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
      }, chain, { maxAttempts: 4, instanceId });

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
    console.log(
      `[ClaimVerification] Starting ${isRetryPass ? 'RETRY' : 'PARALLEL'} verification of ${filteredClaims.length} claims (batch size: ${claimsPerBatch})`
    );

    // Step 1: Split claims into risk-based groups for model routing
    const sensitiveClaims = filteredClaims.filter(c => this.isSensitiveClaim(c, options.isDiscoverySensitive));
    const standardClaims = filteredClaims.filter(c => !this.isSensitiveClaim(c, options.isDiscoverySensitive));

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
        factory: () => this.verifyClaimBatch(batch, domainContext, { ...options, isDiscoverySensitive: true }),
        label: `sensitive_${idx}`,
        claims: batch,
      })),
      ...standardBatches.map((batch, idx) => ({
        factory: () => this.verifyClaimBatch(batch, domainContext, options),
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

      const results = await Promise.allSettled(
        wave.map(w => Promise.race([
          w.factory(),
          new Promise<VerifiedClaim[]>((resolve) =>
            setTimeout(() => resolve(w.claims.map(c => ({
              ...c,
              status: "unverifiable" as ClaimStatus, // Keep as unverifiable — retry pass detects this
              verificationConfidence: 0,
              reasoning: "Verification timed out. Will retry if claim importance qualifies.",
              sources: [],
              richSources: [],
              evidenceLevel: EvidenceLevel.NONE,
              importance: c.importance || 0.5,
              timedOutAt: Date.now(), // v10.6: marker for retry detection
            }))), batchTimeoutMs)
          )
        ]))
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
          logger.warn(`[AdaptiveConcurrency] Wave batch failed: ${result.reason}`);
          allVerified.push(...wave[idx].claims.map(c => ({
            ...c,
            status: "unverifiable" as ClaimStatus,
            verificationConfidence: 0,
            reasoning: 'Wave batch failed during execution.',
            sources: [],
            richSources: [],
            evidenceLevel: EvidenceLevel.NONE,
            importance: c.importance || 0.5,
            timedOutAt: Date.now(), // v10.6: mark as timed out for retry
          })));
        }
      }

      // Adjust concurrency for next wave
      if (outcome === 'failure') {
        concurrency.current = concurrency.min;
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

      if (outcome !== 'success') {
        logger.info(`[AdaptiveConcurrency] Adjusted concurrency to ${concurrency.current} after ${outcome} wave.`);
      }
    }

    // ── v10.6: RETRY PASS — Re-verify timed-out claims with smaller batches ──
    // Only retry claims with importance >= 0.5 to avoid wasting API cost.
    // Routes through the same wave system (recursive call) with sequential concurrency.
    if (!isRetryPass) {
      const timedOutClaims = allVerified.filter(
        c => c.status === 'unverifiable' &&
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

        const recoveredCount = retryResult.claims.filter(c => c.status !== 'unverifiable').length;
        logger.info(`[ClaimVerification] Retry pass complete. ${recoveredCount} claims recovered.`);
      } else if (timedOutClaims.length > 10) {
        logger.warn(`[ClaimVerification] Too many timed-out claims (${timedOutClaims.length}) — skipping retry pass to avoid cost.`);
      }

      // ── v10.6: Final conversion — remaining unverifiable+timedOutAt → unsupported ──
      for (const claim of allVerified) {
        if (claim.status === 'unverifiable' && claim.timedOutAt) {
          claim.status = 'unsupported';
          claim.verificationConfidence = 0.1;
          claim.reasoning = 'Evidence not found — verification timed out. Try re-analyzing for complete results.';
          claim.publicNote = 'Evidence not found for this claim.';
        }
      }
    }

    console.log(`\u2705 Verified ${allVerified.length} claims (${isRetryPass ? 'retry' : 'parallel'} mode)`);
    return { claims: allVerified, batchStats: { completed, timedOut } };
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
        (claim.status === "incorrect" && claim.verificationConfidence < 0.8) ||
        (claim.status === "unverifiable" && claim.verificationConfidence < 0.6)
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
      if (!s.url || s.url === "#") return true; // Keep registry sources
      try {
        const domain = new URL(s.url).hostname.replace('www.', '');
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
    if (l.includes("VERIFIED TRUE")) return "correct";
    if (l.includes("MOSTLY TRUE")) return "mostly_correct";
    if (l.includes("PARTLY TRUE")) return "needs_context";
    if (l.includes("NEEDS CONTEXT")) return "needs_context";
    if (l.includes("OUTDATED")) return "outdated";
    if (l.includes("FALSE")) return "incorrect";
    if (l.includes("MISLEADING")) return "incorrect";
    if (l.includes("UNVERIFIED")) return "unverified";
    if (l.includes("DISPUTED")) return "unsupported";
    if (l.includes("DEVELOPING STORY")) return "developing_story";
    if (l.includes("OPINION")) return "opinion";
    if (l.includes("BELIEF")) return "faith_context";
    if (l.includes("PREDICTION")) return "speculation";
    if (l.includes("SATIRE")) return "satire";
    if (l.includes("QUESTION")) return "opinion";
    return "unverifiable";
  }
}

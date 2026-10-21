import type { VertexAI } from "@google-cloud/vertexai";
import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";
import { 
  ExtractedClaim, 
  GeminiExtractionSchema, 
  Utterance, 
  VerifiedClaim,
  ClaimNature,
  SynthesisResult,
} from "../types";
import { registryService } from "../registry/RegistryService";
import { isSubjectiveClaim, containsVerifiablePredicate } from "./contentIntentDetector";
import { SourceAvatarService } from "./sourceAvatarService";
import { logger } from "../utils/logger";
import { withAiRetry, extractCandidateText } from "../utils/ai-utils";

const HarmCategory = {
  HARM_CATEGORY_HARASSMENT: "HARM_CATEGORY_HARASSMENT",
  HARM_CATEGORY_HATE_SPEECH: "HARM_CATEGORY_HATE_SPEECH",
  HARM_CATEGORY_SEXUALLY_EXPLICIT: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
  HARM_CATEGORY_DANGEROUS_CONTENT: "HARM_CATEGORY_DANGEROUS_CONTENT",
} as const;

const HarmBlockThreshold = {
  BLOCK_NONE: "BLOCK_NONE",
} as const;

// v14.0: Safety settings for fact-checking engine.
// TruthWorld must process content about violence, politics, assassination, etc.
const FACT_CHECK_SAFETY_SETTINGS = [
  { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
  { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
  { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
  { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
] as any;

/**
 * 🔹 A. Fact Extraction Service
 * 
 * Extracts atomic factual claims from transcript chunks
 * Input: transcript chunks (30-60 sec)
 * Output: classified claims (fact/opinion/speculation/unclear)
 */
export class FactExtractionService {
  private genAI: VertexAI;

  constructor(apiKey: string) {
    this.genAI = getVertexAI();
  }

  private static readonly LONGFORM_THRESHOLD_MINUTES = 30;
  private static readonly LONGFORM_THRESHOLD_MS = FactExtractionService.LONGFORM_THRESHOLD_MINUTES * 60 * 1000;

  /**
   * Split transcript into chunks (30-60 seconds)
   * 🛠 v5.1 FIX: Handles oversized utterances by splitting them semantically.
   */
  private chunkTranscript(
    utterances: Utterance[],
    chunkDurationMs: number = 45000 // 45 seconds default
  ): { utterances: Utterance[]; chunkIndex: number }[] {
    const chunks: { utterances: Utterance[]; chunkIndex: number }[] = [];
    let currentChunk: Utterance[] = [];
    let chunkStart = utterances[0]?.start || 0;
    let chunkIndex = 0;

    for (const utterance of utterances) {
      // 1. Handle oversized utterances (v5.1 Fix)
      // If a single utterance is significantly longer than our chunk target, split it.
      if (utterance.end - utterance.start > chunkDurationMs * 1.5) {
        // Flush any pending utterances first
        if (currentChunk.length > 0) {
          chunks.push({ utterances: currentChunk, chunkIndex });
          chunkIndex++;
          currentChunk = [];
        }

        // Split the giant utterance into virtual sub-utterances
        const subChunks = this.splitLargeUtterance(utterance, chunkDurationMs);
        for (const sub of subChunks) {
          chunks.push({ utterances: [sub], chunkIndex });
          chunkIndex++;
        }

        // Reset for next
        chunkStart = utterance.end;
        continue;
      }

      // 2. Standard chunking logic
      currentChunk.push(utterance);

      // Check if chunk is large enough
      if (utterance.end - chunkStart >= chunkDurationMs) {
        chunks.push({ utterances: currentChunk, chunkIndex });
        currentChunk = [];
        chunkStart = utterance.end;
        chunkIndex++;
      }
    }

    // Add remaining utterances
    if (currentChunk.length > 0) {
      chunks.push({ utterances: currentChunk, chunkIndex });
    }

    return chunks;
  }

  /**
   * 🛠 v5.1: Semantic splitting for giant utterances (monologues).
   * Splits on punctuation if possible, otherwise falls back to word count.
   */
  private splitLargeUtterance(utterance: Utterance, targetDurationMs: number): Utterance[] {
    const words = utterance.text.split(/\s+/);
    const subUtterances: Utterance[] = [];
    
    // Estimate words per chunk: standard speaking rate ~150 wpm = 2.5 words/sec.
    // 45 seconds ~ 110-130 words. We use 180 for safety with fast speakers.
    const targetWords = 180; 
    const overlapWords = 25;
    const duration = utterance.end - utterance.start;

    for (let i = 0; i < words.length; i += (targetWords - overlapWords)) {
      let endIdx = i + targetWords;
      
      // Attempt to find a punctuation boundary within the last 30% of the chunk
      const searchWindow = Math.floor(targetWords * 0.3);
      const windowEnd = Math.min(words.length, i + targetWords);
      const windowStart = Math.max(i, windowEnd - searchWindow);
      
      for (let j = windowEnd - 1; j >= windowStart; j--) {
        if (words[j].endsWith('.') || words[j].endsWith('?') || words[j].endsWith('!')) {
          endIdx = j + 1;
          break;
        }
      }

      const chunkWords = words.slice(i, Math.min(words.length, endIdx));
      if (chunkWords.length < 30 && subUtterances.length > 0) break; // Avoid tiny orphans

      const ratioStart = i / words.length;
      const ratioEnd = Math.min(1, endIdx / words.length);

      subUtterances.push({
        speaker: utterance.speaker,
        text: chunkWords.join(" "),
        start: Math.floor(utterance.start + (duration * ratioStart)),
        end: Math.floor(utterance.start + (duration * ratioEnd))
      });

      if (endIdx >= words.length) break;
      i = endIdx - overlapWords; // Move i to endIdx but keep overlap
    }

    return subUtterances;
  }

  /**
   * Format utterances into readable transcript
   */
  private formatChunk(utterances: Utterance[]): string {
    return utterances
      .map(
        (u) =>
          `[${this.formatTime(u.start)}-${this.formatTime(u.end)}] ${u.speaker || "Unnamed"}: ${u.text}`
      )
      .join("\n");
  }

  private formatTime(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${String(secs).padStart(2, "0")}`;
  }

  /**
   * Extract claims from a single chunk using Gemini
   */
  async extractClaimsFromChunk(
    jobId: string,
    utterances: Utterance[],
    chunkIndex: number
  ): Promise<ExtractedClaim[]> {
    const transcript = this.formatChunk(utterances);

    const prompt = `You are a fact-checking expert and claim ontologist for TruthWorld's Credibility System. Extract all distinct, atomic claims (statements of fact, statistics, events, historical dates, scientific facts, or notable opinions) from the following transcript chunk. Be thorough and comprehensive — extract all factual assertions made by the speaker(s); do not omit valid claims.

### ARCHITECTURAL SEPARATION:
You are part of the CREDIBILITY SYSTEM (epistemic verification). You are NOT Content Moderation.
Content Moderation handles family-friendly delivery (profanity, gore, explicit content) in a separate pre-pipeline stage.
Your job is purely epistemic: extract all empirical claims without filtering out controversial, sensitive, political, or radical topics. Do not censor.

### CORE PRINCIPLE:
A claim is FACTUAL if an external source (news archive, official record, scientific data) could confirm or refute it, even if presented dramatically, emotionally, sarcastically, or persuasively. Tone ≠ Falsity. 

### CRITICAL RULES:
1.1. **HISTORICAL & SCIENTIFIC TRIVIA**: Always extract claims about inventions, discoveries, geographical facts, animal trivia, and scientific constants. These are BUCKET 1 (VERIFIABLE_FACT).
1.2. **NO EMOJIS**: Do NOT include emojis (like 🔍, ✅, ❌) in the "text" field of the JSON. Extract the raw text only.
### THE FOUR BUCKETS:
Each claim MUST be classified into one of these buckets:
    - "VERIFIABLE_FACT" (Bucket 1): Empirically testable claims, current events, statistics, historical records, inventions, scientific constants.
    - "OPINION" (Bucket 2): Subjective preferences, values, or moral judgments ("This is good", "I prefer X").
    - "BELIEF" (Bucket 3): Faith-based, scriptural, or miraculous claims ("God created the world").
    - "ESTIMATION" (Bucket 4): Projections, future-oriented claims, or theoretical guesses.
    - "SATIRE": Non-literal or parody content.

4. Detect **FramingStyle** (How the speaker presents the claim):
    - "HEDGED": Use of "may", "might", "possibly", "could", "evidence suggests". (Honesty bonus)
    - "BALANCED": Acknowledges multiple perspectives or uncertainty. (Honesty bonus)
    - "ASSERTIVE": Standard confident presentation. (Neutral)
    - "ABSOLUTE": Use of "proven", "guaranteed", "obvious fact", "without question". (Penalty if evidence weak)
    - "MANIPULATIVE": Use of rage-bait, fear-mongering, or emotional coercion. (Severe penalty)

3. **🚨 ANTI-SUPPRESSION RULE (v12.0) — HISTORICAL & SCIENTIFIC**:
    - Identify [Innovation/Event] + [Actor] + [Date/Place] as factual.
    - Examples (Factual): "Johannes Gutenberg developed the movable type printing press around 1440", "Alexander Fleming discovered penicillin in 1928", "The magnetic compass was invented in China during the Han dynasty".
    - Examples (Opinion): "This was the greatest technological breakthrough", "I love this era of history", "It was a wonderful golden age".

4. **Subjective Language Filtering**:
    - Do NOT extract purely subjective adjectives as claims.
    - If a sentence contains BOTH a subjective adjective AND a verifiable fact, STRIP the adjective and extract the fact.

5. **🚨 SPEAKER ATTRIBUTION (v5.3)**:
    - If there are multiple speakers, ALWAYS include the speaker name/label in the claim if they are making a personal claim or rebuttal.
    - Format: "[Speaker Name] stated that..." or "[Speaker Name] argued that..."
    - This is critical for differentiating Host questions from Guest claims.

6. Detect **assertiveness** and **strength** — how the speaker frames the claim:
   - "assertiveness": casual (hedged) | moderate | confident | authoritative | absolute
   - "claimStrength": "hedged" | "moderate" | "strong" | "absolute"

8. **HONESTY_WASHING detection**: 
   - A claim is "honesty washed" if a false empirical claim is disguised as an opinion (e.g., "In my opinion, smoking cures cancer"). 
   - Tag such claims with "honestyWashingRisk": true.


Transcript:
\`\`\`
${transcript}
\`\`\`

Return a JSON response with this structure:
{
  "claims": [
    {
      "text": "Exact claim from transcript",
      "nature": "VERIFIABLE_FACT|OPINION|BELIEF|ESTIMATION|SATIRE",
      "framing": "HEDGED|BALANCED|ASSERTIVE|ABSOLUTE|MANIPULATIVE",
      "confidence": 0.95,
      "importance": 0.8,
      "isVerifiableEvent": true|false,
      "honestyWashingRisk": true|false,
      "assertiveness": "casual|moderate|confident|authoritative|absolute",
      "claimStrength": "hedged|moderate|strong|absolute"
    }
  ],
  "summary": "Summary of extracted claims"
}

Return ONLY valid JSON, no explanations.`;

    const extractChain = {
      primary: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
      fallback: null,
      forcePrimary: true
    };
    return withAiRetry(async (modelId: string, recordUsage) => {
      const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
      const response = await activeModel.generateContent(prompt);
      recordUsage?.(response);
      const text = extractCandidateText(response.response.candidates?.[0]) || response.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

      // Parse JSON response with robust cleanup
      const jsonMatch = this.extractJSON(text);
      if (!jsonMatch) {
        console.warn(`No valid JSON found in response for chunk ${chunkIndex}.`);
        return [];
      }

      const rawParsed = JSON.parse(jsonMatch);
      const validation = GeminiExtractionSchema.safeParse(rawParsed);
      
      if (!validation.success) {
        console.error(`[FactExtraction] Schema validation failed for chunk ${chunkIndex}:`, validation.error.format());
        return [];
      }

      const parsed = validation.data;

      const extractedClaims: ExtractedClaim[] = parsed.claims
        .filter((c) => c.confidence >= 0.5) 
        .map((claim, idx) => {
          let nature: ClaimNature = claim.nature as any;
          const deterministicNature = registryService.getDeterministicDomain(claim.text);
          
          if (deterministicNature) {
            nature = deterministicNature as any;
          }

          return {
            text: claim.text.replace(/^[🔍\s]+/, '').trim(),
            nature,
            framing: claim.framing as any,
            confidence: claim.confidence,
            importance: claim.importance,
            chunkIndex,
            isVerifiableEvent: claim.isVerifiableEvent,
            honestyWashingRisk: claim.honestyWashingRisk,
            assertiveness: claim.assertiveness as any,
            claimStrength: claim.claimStrength as any,
            start: utterances[0]?.start,
            end: utterances[utterances.length - 1]?.end,
          };
        });

      const calibratedClaims = extractedClaims.map(claim => {
        // v5.2: LLM-flagged verifiable events bypass the English-only regex filter
        if (claim.isVerifiableEvent || containsVerifiablePredicate(claim.text)) {
          return claim;
        }
        if (isSubjectiveClaim(claim.text, claim.isVerifiableEvent)) {
          return { ...claim, nature: 'OPINION' as any };
        }
        return claim;
      });

      return calibratedClaims;
    }, extractChain, { maxAttempts: 4, instanceId: jobId, jobId, stage: "extraction" });
  }

  /**
   * Detect the overall domain and speaker's primary stance.
   * Useful for domain-sensitivity modes (Refinement 2).
   */
  async detectDomainAndStance(
    utterances: Utterance[]
  ): Promise<{ 
    domain: string; 
    stance: string; 
    cautionLevel: "low" | "medium" | "high"; 
    isLaunchNews: boolean;
    primaryIntent?: string;
    isSensitive?: boolean;
    detectedLanguage?: string;
  }> {
    const sample = utterances.slice(0, 50).map((u) => u.text).join(" ");
    
    const prompt = `Analyze the following transcript sample and categorize it.
Sample: "${sample.substring(0, 4000)}"

Return ONLY a JSON object:
{
  "domain": "e.g., Technology, Health, Finance, Entertainment, Politics, Science, Geopolitical",
  "stance": "e.g., Explanatory, Persuasive, Debunking, Satirical",
  "cautionLevel": "low|medium|high",
  "isLaunchNews": true|false,
  "primaryIntent": "factual|promotional|editorial|educational|entertainment|testimonial|commentary",
  "isSensitive": true|false,
  "detectedLanguage": "ISO code (e.g., en, hi, es, fr)"
}

RULES:
1. If domain is Health, Finance, or Breaking News/War, cautionLevel MUST be "high" and isSensitive: true.
2. If text mentions "launched", "announced", "new product", "released today", set isLaunchNews: true and primaryIntent: "promotional".
3. If text is hard news or geopolitical reporting, set primaryIntent: "factual".
4. Detect the language accurately.`;

    const stanceChain = {
      primary: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash",
      fallback: null,
      forcePrimary: true
    };

    return withAiRetry(async (modelId: string, recordUsage) => {
      const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
      const response = await activeModel.generateContent(prompt);
      recordUsage?.(response);
      const text = extractCandidateText(response.response.candidates?.[0]) || response.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const jsonMatch = this.extractJSON(text);
      const res = jsonMatch ? JSON.parse(jsonMatch) : { domain: "General", stance: "Mixed", cautionLevel: "medium", isLaunchNews: false };
      
      if (!res.isLaunchNews) {
        const freshKeywords = ["launch", "announce", "released", "today", "new product"];
        const hasKeywords = freshKeywords.some(kw => sample.toLowerCase().includes(kw));
        if (hasKeywords) res.isLaunchNews = true;
      }

      return res;
    }, stanceChain, { maxAttempts: 4, instanceId: "stance_detection" }).catch(() => ({ 
      domain: "General", 
      stance: "Mixed", 
      cautionLevel: "medium", 
      isLaunchNews: false, 
      primaryIntent: "factual", 
      isSensitive: false 
    }));
  }

  async extractClaimsStandard(
    jobId: string,
    utterances: Utterance[],
    chunkDurationMs: number = 45000,
    maxConcurrent: number = 5
  ): Promise<ExtractedClaim[]> {
    if (!utterances || utterances.length === 0) {
      console.warn("[FactExtraction] Empty transcript — skipping extraction");
      return [];
    }

    // Split into chunks
    const chunks = this.chunkTranscript(utterances, chunkDurationMs);
    const totalChunks = chunks.length;
    const allClaims: ExtractedClaim[] = [];

    // Process chunks with concurrency control
    for (let i = 0; i < chunks.length; i += maxConcurrent) {
      const batch = chunks.slice(i, i + maxConcurrent);
      
      // Granular progress update for long extractions (30% -> 50% range in 06-credibility)
      const progressPercent = 30 + Math.floor((i / totalChunks) * 20);
      try {
         const db = admin.firestore();
         await db.collection("video_jobs").doc(jobId).update({
           "stages.credibility.progress": Math.min(48, progressPercent),
           "stages.credibility.lastUpdate": admin.firestore.FieldValue.serverTimestamp()
         });
      } catch (e) { /* ignore progress update errors */ }

      try {
        const batchResults = await Promise.all(
          batch.map((chunk) =>
            this.extractClaimsFromChunk(jobId, chunk.utterances, chunk.chunkIndex)
          )
        );

        batchResults.forEach((claims) => allClaims.push(...claims));
      } catch (error: any) {
        // ... (existing error handling)
        const status = error?.status || (error?.message?.includes("429") ? 429 : 500);
        const isCapacity = status === 429 || status === 503 || error?.message?.toLowerCase().includes("capacity");
        
        if (isCapacity) {
          logger.warn(`[FactExtraction] High-level capacity limit hit. Falling back to sequential mode for batch at ${i}`);
          for (const chunk of batch) {
            const claims = await this.extractClaimsFromChunk(jobId, chunk.utterances, chunk.chunkIndex);
            allClaims.push(...claims);
          }
        } else {
          throw error;
        }
      }
    }

    return allClaims;
  }


  /**
   * 🎥 Multimodal Fact Extraction directly from Video/Audio Media via Google Cloud Vertex AI
   * Extracts atomic factual claims from audio/speech and visual OCR without requiring AssemblyAI.
   * Works across all languages (English, Telugu, Hindi, Spanish, French, etc.).
   */
  async extractClaimsFromMedia(
    jobId: string,
    gcsUri: string,
    mimeType: string = "video/mp4",
    videoTitle?: string
  ): Promise<{
    claims: ExtractedClaim[];
    domainInfo: {
      domain: string;
      stance: string;
      cautionLevel: "low" | "medium" | "high";
      isLaunchNews: boolean;
      primaryIntent?: string;
      isSensitive?: boolean;
      detectedLanguage?: string;
    };
    summary: string;
  }> {
    const cleanTitle = (videoTitle || "Untitled").replace(/["\r\n]/g, " ").trim();

    const prompt = `You are a fact-checking expert and claim ontologist for TruthWorld's Credibility System.
Analyze this video directly using both the AUDIO TRACK (speech across ANY language, e.g. English, Telugu, Hindi, Spanish, French, German, Tamil, etc.) and VISUAL FRAMES (on-screen text, tickers, slides).

### ARCHITECTURAL SEPARATION:
You are part of the CREDIBILITY SYSTEM (epistemic verification). You are NOT Content Moderation.
Content Moderation handles family-friendly delivery (profanity, gore, explicit content) in a separate pre-pipeline stage.
Your job is purely epistemic: extract all empirical claims without filtering out controversial, sensitive, political, or radical topics. Do not censor.

### CORE PRINCIPLE:
A claim is FACTUAL if an external source (news archive, official record, scientific data) could confirm or refute it, even if presented dramatically, emotionally, sarcastically, or persuasively. Tone != Falsity.

### VIDEO METADATA:
Title: "${cleanTitle}"

### CRITICAL RULES:
1.1. HISTORICAL, SCIENTIFIC, & REGIONAL TRIVIA: Always extract claims about inventions, discoveries, geographical facts, historical events, statistics, or public figures. These are BUCKET 1 (VERIFIABLE_FACT).
1.2. NO EMOJIS: Do NOT include emojis (like 🔍, ✅, ❌) in the "text" field of the JSON. Extract the raw text only.
1.3. LANGUAGE SUPPORT: Extract claims made in ANY language. If speech is in Telugu, Hindi, Spanish, French, etc., transcribe and represent each empirical assertion clearly.

### THE FOUR BUCKETS:
Each claim MUST be classified into one of these buckets:
- "VERIFIABLE_FACT" (Bucket 1): Empirically testable claims, current events, statistics, historical records, inventions, scientific constants.
- "OPINION" (Bucket 2): Subjective preferences, values, or moral judgments ("This is good", "I prefer X").
- "BELIEF" (Bucket 3): Faith-based, scriptural, or miraculous claims ("God created the world").
- "ESTIMATION" (Bucket 4): Projections, future-oriented claims, or theoretical guesses.
- "SATIRE": Non-literal or parody content.

FramingStyle:
- "HEDGED", "BALANCED", "ASSERTIVE", "ABSOLUTE", "MANIPULATIVE"

Assertiveness and Strength:
- "assertiveness": "casual" | "moderate" | "confident" | "authoritative" | "absolute"
- "claimStrength": "hedged" | "moderate" | "strong" | "absolute"

Return ONLY a valid JSON object matching this structure:
{
  "detectedLanguage": "ISO 639-1 language code (e.g. en, te, hi, es, fr)",
  "domain": "Technology | Health | Finance | Entertainment | Politics | Science | Geopolitical | General",
  "stance": "Explanatory | Persuasive | Debunking | Satirical | Mixed",
  "cautionLevel": "low | medium | high",
  "isLaunchNews": true | false,
  "primaryIntent": "factual | promotional | editorial | educational | entertainment | testimonial | commentary",
  "isSensitive": true | false,
  "summary": "Comprehensive overview of the claims made in the video",
  "claims": [
    {
      "text": "Exact factual assertion",
      "nature": "VERIFIABLE_FACT",
      "framing": "ASSERTIVE",
      "confidence": 0.95,
      "importance": 0.8,
      "isVerifiableEvent": true,
      "honestyWashingRisk": false,
      "assertiveness": "confident",
      "claimStrength": "strong",
      "start": 12000,
      "end": 18000,
      "speaker": "Speaker 1"
    }
  ]
}`;

    const extractChain = {
      primary: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
      fallback: null,
      forcePrimary: true,
    };

    return withAiRetry(async (modelId: string, recordUsage) => {
      const activeModel = this.genAI.getGenerativeModel({
        model: modelId,
        safetySettings: FACT_CHECK_SAFETY_SETTINGS,
      });

      const response = await activeModel.generateContent({
        contents: [
          {
            role: "user",
            parts: [
              {
                fileData: {
                  mimeType,
                  fileUri: gcsUri,
                },
              },
              {
                text: prompt,
              },
            ],
          },
        ],
      });

      recordUsage?.(response);
      const text = extractCandidateText(response.response.candidates?.[0]) || response.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

      const jsonMatch = this.extractJSON(text);
      if (!jsonMatch) {
        logger.warn(`[FactExtraction] No valid JSON found in media extraction response for ${jobId}.`);
        return {
          claims: [],
          domainInfo: { domain: "General", stance: "Mixed", cautionLevel: "medium", isLaunchNews: false, primaryIntent: "educational", isSensitive: false, detectedLanguage: "en" },
          summary: "No claims detected.",
        };
      }

      let parsed: any;
      try {
        parsed = JSON.parse(jsonMatch);
      } catch (parseErr) {
        logger.error(`[FactExtraction] JSON parse error in media extraction for ${jobId}:`, parseErr);
        return {
          claims: [],
          domainInfo: { domain: "General", stance: "Mixed", cautionLevel: "medium", isLaunchNews: false, primaryIntent: "educational", isSensitive: false, detectedLanguage: "en" },
          summary: "Parsing failed.",
        };
      }

      const validation = GeminiExtractionSchema.safeParse(parsed);
      const validatedData = validation.success ? validation.data : parsed;

      const rawClaimsList = Array.isArray(validatedData.claims) ? validatedData.claims : [];

      const extractedClaims: ExtractedClaim[] = rawClaimsList
        .filter((c: any) => (c.confidence ?? 0.5) >= 0.5)
        .map((claim: any, idx: number) => {
          let nature: ClaimNature = (claim.nature as any) || "VERIFIABLE_FACT";
          const deterministicNature = registryService.getDeterministicDomain(claim.text || "");
          if (deterministicNature) {
            nature = deterministicNature as any;
          }

          return {
            text: (claim.text || "").replace(/^[🔍\s]+/, "").trim(),
            nature,
            framing: (claim.framing as any) || "ASSERTIVE",
            confidence: typeof claim.confidence === "number" ? claim.confidence : 0.9,
            importance: typeof claim.importance === "number" ? claim.importance : 0.8,
            chunkIndex: 0,
            isVerifiableEvent: claim.isVerifiableEvent ?? true,
            honestyWashingRisk: claim.honestyWashingRisk ?? false,
            assertiveness: (claim.assertiveness as any) || "confident",
            claimStrength: (claim.claimStrength as any) || "strong",
            start: typeof claim.start === "number" ? claim.start : idx * 5000,
            end: typeof claim.end === "number" ? claim.end : (idx + 1) * 5000,
            speaker: claim.speaker || "Speaker",
          };
        });

      const calibratedClaims = extractedClaims.map((claim) => {
        if (claim.isVerifiableEvent || containsVerifiablePredicate(claim.text)) {
          return claim;
        }
        if (isSubjectiveClaim(claim.text, claim.isVerifiableEvent)) {
          return { ...claim, nature: "OPINION" as any };
        }
        return claim;
      });

      const detectedLang = validatedData.detectedLanguage || "en";
      const domainInfo = {
        domain: validatedData.domain || "General",
        stance: validatedData.stance || "Mixed",
        cautionLevel: (validatedData.cautionLevel as any) || "medium",
        isLaunchNews: !!validatedData.isLaunchNews,
        primaryIntent: validatedData.primaryIntent || "factual",
        isSensitive: !!validatedData.isSensitive,
        detectedLanguage: detectedLang,
      };

      return {
        claims: calibratedClaims,
        domainInfo,
        summary: validatedData.summary || "",
      };
    }, extractChain, { maxAttempts: 4, instanceId: jobId, jobId, stage: "media_extraction" });
  }

  async extractClaims(
    jobId: string,
    transcript: any, // TranscriptData
    chunkDurationMs: number = 45000,
    maxConcurrent: number = 5
  ): Promise<ExtractedClaim[]> {
    const durationMs = transcript.duration * 1000;
    
    if (durationMs > FactExtractionService.LONGFORM_THRESHOLD_MS) {
      logger.info(`[FactExtraction] Long-form detected (${Math.round(durationMs/60000)} mins). Using Map-Reduce path.`);
      return this.extractClaimsMapReduce(jobId, transcript, chunkDurationMs, maxConcurrent);
    } else {
      return this.extractClaimsStandard(jobId, transcript.utterances ?? [], chunkDurationMs, maxConcurrent);
    }
  }

  private async extractClaimsMapReduce(
    jobId: string,
    transcript: any, // TranscriptData
    chunkDurationMs: number,
    maxConcurrent: number
  ): Promise<ExtractedClaim[]> {
    const segmentDurationMs = 10 * 60 * 1000; // 10 minute segments
    const segments = this.segmentTranscript(transcript, segmentDurationMs);
    
    logger.info(`[FactExtraction] Map Phase: Segmented transcript into ${segments.length} blocks for parallel processing.`);

    const segmentResults: ExtractedClaim[][] = [];
    const segmentBatchSize = 2; // Process 2 segments (~20 mins of video) at a time

    for (let i = 0; i < segments.length; i += segmentBatchSize) {
      const batch = segments.slice(i, i + segmentBatchSize);
      logger.info(`[FactExtraction] Processing segment batch ${Math.floor(i/segmentBatchSize) + 1}/${Math.ceil(segments.length/segmentBatchSize)}`);
      
      const batchResults = await Promise.all(
        batch.map((segment) => this.extractClaimsStandard(jobId, segment.utterances, chunkDurationMs, maxConcurrent))
      );
      
      batchResults.forEach(res => segmentResults.push(res));
    }
    
    // Reduce: deduplicate and merge
    return this.deduplicateAndMerge(segmentResults.flat());
  }

  /**
   * Segments a transcript into larger blocks (e.g. 10 mins) for Map-Reduce
   */
  private segmentTranscript(transcript: any, segmentDurationMs: number): any[] {
    const segments: { utterances: Utterance[]; duration: number }[] = [];
    let currentUtterances: Utterance[] = [];
    let currentStart = transcript.utterances[0]?.start || 0;

    for (const utterance of transcript.utterances) {
      currentUtterances.push(utterance);
      if (utterance.end - currentStart >= segmentDurationMs) {
        segments.push({ utterances: currentUtterances, duration: (utterance.end - currentStart) / 1000 });
        currentUtterances = [];
        currentStart = utterance.end;
      }
    }

    if (currentUtterances.length > 0) {
      segments.push({ utterances: currentUtterances, duration: (currentUtterances[currentUtterances.length - 1].end - currentStart) / 1000 });
    }

    return segments;
  }

  /**
   * Basic semantic deduplication for merged claims
   */
  private deduplicateAndMerge(claims: ExtractedClaim[]): ExtractedClaim[] {
    const seen = new Set<string>();
    return claims.filter(c => {
      const key = c.text.toLowerCase().trim();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  /**
   * 🏛 NEW: Multi-Tier Intelligence Layer (Standard | Deep | Podcast)
   */
  async generateTieredIntelligence(
    utterances: Utterance[],
    verifiedClaims: VerifiedClaim[],
    tier: "standard" | "deep" | "podcast",
    consistencyWarnings: string[] = [],
    context: { 
      pipelineMode: string; 
      speakerCount: number;
      speakerIdentities?: Record<string, any>;
      speakerPriors?: Record<string, any>;
      evaluationHealth?: any; // v11.5: Pass health for honest synthesis
    } = { pipelineMode: "solo", speakerCount: 1 }
  ): Promise<SynthesisResult> {
    if (!utterances || utterances.length === 0) {
      return {
        summary: "No content detected.",
        conclusion: { label: "Empty", text: "Transcript is empty.", confidence: 1.0, sources: [] },
        knowledgeDensity: 0,
        keyThemes: [],
        viewerNote: "No content available.",
        manipulationScore: 0,
        manipulationSignals: [],
        chapters: [],
        speakerRoles: {},
        hallucinationIsolation: { verifiedFacts: [], modelInterpretations: [], uncertainInferences: [] },
        traceabilityMap: {}
      };
    }

    const fullTranscript = utterances.map((u) => `${u.speaker || "Speaker"}: ${u.text}`).join("\n");
    const verificationSummary = verifiedClaims.map(c => {
      const claimSources = (c.sources || (c as any).richSources || (c as any).effectiveSources || [])
        .map((s: any) => `${s.title || s.domain || s.url} (${s.url || s.domain || "citation"})`)
        .slice(0, 3)
        .join("; ");
      return `- [${c.speaker || "Speaker"}] [ID: ${c.claimId}] Claim: "${c.text}" | Status: ${c.status}${claimSources ? ` | Sources: ${claimSources}` : ""}`;
    }).join("\n");
    const consistencyBlob = consistencyWarnings.length > 0 ? `### INTERNAL CONTRADICTIONS DETECTED:\n${consistencyWarnings.join("\n")}` : "None detected.";

    // v5.1 & v8.4: Long-form Transcript Handling (Map-Reduce Summarization)
    const MAX_TRANSCRIPT_CHARS = 18000;
    let transcriptSnippet = fullTranscript;
    
    if (fullTranscript.length > MAX_TRANSCRIPT_CHARS) {
      logger.info("[FactExtraction] Large transcript detected — using Map-Reduce synthesis", { 
        length: fullTranscript.length, 
        limit: MAX_TRANSCRIPT_CHARS 
      });
      
      // Step 1: Map (Summarize segments in parallel)
      const segmentSize = Math.floor(utterances.length / 4); // 4 major segments
      const segments: { segmentUtterances: Utterance[]; index: number }[] = [];
      for (let i = 0; i < utterances.length; i += segmentSize) {
        segments.push({ segmentUtterances: utterances.slice(i, i + segmentSize), index: i });
      }

      const segmentSummariesResults = await Promise.all(
        segments.map(async (segment) => {
          const segmentText = segment.segmentUtterances.map(u => `${u.speaker || 'Speaker'}: ${u.text}`).join("\n");
          const segmentChain = { primary: PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash", fallback: null, forcePrimary: true };
          return withAiRetry(async (modelId: string) => {
            const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
            const res = await activeModel.generateContent(`Summarize this transcript segment briefly (focus on core arguments and key facts):\n\n${segmentText.substring(0, 10000)}`);
            const text = extractCandidateText(res.response.candidates?.[0]) || res.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
            return `SEGMENT ${Math.floor(segment.index/segmentSize) + 1} SUMMARY:\n${text}`;
          }, segmentChain, { maxAttempts: 4, instanceId: `SegmentSummary-${segment.index}` }).catch(() => "Segment summary unavailable.");
        })
      );
      
      const segmentSummaries = segmentSummariesResults;
      
      // Step 2: Combine for final reduce prompt
      transcriptSnippet = "AGGREGATED SEGMENT SUMMARIES (Longform Content):\n" + segmentSummaries.join("\n\n") + 
                         "\n\nFINAL TRANSCRIPT TAIL (Direct Context):\n" + fullTranscript.slice(-5000);
    }

    const personas = {
      standard: "Neutral Intelligence Analyst. Follow 'Rational Neutrality' rules: respect miracle narratives as faith-based contexts and never penalize theological beliefs. Focus on factual accuracy of empirical claims.",
      deep:     "Deep-Context Intelligence Analyst. Specialize in source integrity and ontology. Strictly distinguish between 'Faith Truth' (scriptural) and 'Empirical Truth' (scientific). Apply the 'Faith Context' label for traditions.",
      podcast:  "Podcast & Debate Expert. Analyze speaker stance, host/guest dynamics, and 'Manipulation Signals'. Detect emotional coercion, rage-bait, and fake urgency."
    };

    // v5.3: Adaptive Mode Instructions
    let modeInstruction = "";
    if (context.pipelineMode === "multi" || context.pipelineMode === "debate") {
      modeInstruction = `
### MULTI-SPEAKER MODE: ${context.pipelineMode.toUpperCase()}
1. Identify the ROLE of each speaker (Host, Guest, Interviewer, Expert, Caller).
2. Analyze "Claim Ownership": Who is introducing the facts? Who is verifying them?
3. Detect "Corrective Dynamics": If one speaker corrects another, note it in the summary.
4. Flag "Crosstalk/Chaos": If there are 4+ speakers or heavy overlap, adjust confidence accordingly.`;

      if (context.speakerPriors && Object.keys(context.speakerPriors).length > 0) {
        const priorsInfo = Object.entries(context.speakerPriors).map(([id, p]: any) => {
          const name = Object.values(context.speakerIdentities || {}).find((i: any) => i.id === id)?.name || id;
          return `- ${name}: Prior Trust Label "${p.trustLevel || 'Developing'}" (Historical Accuracy: ${(p.factualAccuracy * 100).toFixed(0)}%)`;
        }).join("\n");

        modeInstruction += `\n\n### SPEAKER REPUTATION (FOR CONTEXT ONLY):
Use these priors to guide your confidence in their expertise, but NEVER let them override current evidence:
${priorsInfo}`;
      }
    }

    const chapterInstruction = tier === "standard" 
      ? "Divide transcript into fixed 10-minute trust windows." 
      : "Perform SEMANTIC chaptering: detect topic shifts and assign a trustIndex to each chapter.";

    const health = context.evaluationHealth;
    const healthBlob = health ? `
### EVALUATION HEALTH: ${health.healthStatus.toUpperCase()}
- Extracted Claims: ${health.extractedClaims}
- Factual Claims Routed: ${health.factualRouted}
- Successfully Evaluated: ${health.evaluatedClaims}
${health.healthStatus === 'critical' ? 'CRITICAL OPERATIONAL FAILURE: Most factual claims failed verification due to system timeouts. DO NOT use the term "Unsupported" (which implies a successful search with no results). Instead, use "Inconclusive due to Operational Timeout". State clearly that verification coverage was insufficient to form a reliable verdict.' : ''}
` : "";

    const prompt = `You are a ${personas[tier]}. Produce an institutional-grade Trust Report.
    
### CORE PRINCIPLE: EVIDENCE-BOUNDED SYNTHESIS (v10.0)
Your summary and conclusion MUST be strictly derived from the provided transcript and verified claims. 
1. DO NOT use your own external training data to verify facts.
2. DO NOT make definitive statements that are not supported by the "Verified Claims" list.
3. If no claims were verified, explicitly state that the analysis is structural only.
4. If EVALUATION HEALTH is CRITICAL, explicitly state that the truth index is inconclusive.

### INPUT DATA
1. TRANSCRIPT (Sanitized):
"""
${transcriptSnippet} 
"""

2. VERIFIED CLAIMS:
${verificationSummary.substring(0, 5000)}

3. ${consistencyBlob}

${healthBlob}

${modeInstruction}

Produce a JSON response with:
1. summary: A faithful, friendly representation of what the speaker talked about in simple, clear everyday language that a 10-year-old can easily understand.
2. conclusion: Kid-friendly, human-accessible synthesis (label: Supported|Mixed|Contested|Unsupported). Explain clearly what the video said, what the real-world facts show, and whether the viewer can trust it.
   CRITICAL STYLE RULE: Write like an encouraging, knowledgeable teacher speaking to a 10-year-old child. ABSOLUTELY NEVER use dense academic, robotic, or bureaucratic AI jargon (e.g. NEVER use: "empirical concordance", "epistemological consensus", "substantiates the thesis", "hermeneutical alignment", "macroeconomic quantification", "institutional corroboration", "thematic synthesis").
   Must include an array of authoritative "sources" (with title, url, domain, trustLevel, type) that substantiate or contest the conclusion.
3. hallucinationIsolation: (v10.0) Separate the following:
   - "verifiedFacts": Statements directly supported by the "Verified Claims" list.
   - "modelInterpretations": Analytical interpretations of the speaker's intent or structure.
   - "uncertainInferences": Statements where the evidence is insufficient or logic is speculative.
4. traceabilityMap: (v10.0) Map each distinct sentence/point in the "conclusion" to the relevant "claimId"s from the verified claims (if any). Format: {"sentence text": ["claim_id_1", "claim_id_2"]}.
5. knowledgeDensity: 0.0-1.0.
6. keyThemes: 3-5 major topics.
7. viewerNote: Strategic pro-tip/warning.
8. manipulationScore: 0.0-1.0. 
   - **NUANCE RULE (v12.0)**: Distinguish between "Expressive Narration" (Patriotic pride, educational enthusiasm, storytelling tone) and "Deceptive Manipulation" (Rage-bait, fear-mongering, emotional coercion). 
   - Enthusiastic history/science narration should be scored LOW (0.1-0.2). 
   - Only score HIGH (>0.5) if there is clear evidence of misleading framing or harmful emotional triggers.
9. manipulationSignals: Explicitly label as "Hype/Promotion", "Rage-bait", "Fear-mongering", or "Political Spin".
10. chapters: ${chapterInstruction}
11. speakerRoles: Map each speaker to a detected role (Host|Guest|Expert|Caller|Other).

Return ONLY valid JSON according to:
{
  "summary": "...",
  "conclusion": {
    "label": "...",
    "text": "...",
    "confidence": 0.9,
    "sources": [
      { "title": "...", "url": "https://...", "domain": "...", "trustLevel": "High|Medium", "type": "Supporting" }
    ]
  },
  "hallucinationIsolation": {
    "verifiedFacts": ["..."],
    "modelInterpretations": ["..."],
    "uncertainInferences": ["..."]
  },
  "traceabilityMap": { "point 1": ["claim_1"], "point 2": ["claim_2"] },
  "knowledgeDensity": 0.85,
  "keyThemes": ["..."],
  "viewerNote": "...",
  "manipulationScore": 0.15,
  "manipulationSignals": ["..."],
  "chapters": [
    { "index": 0, "title": "...", "start": 0, "end": 600000, "trustIndex": 8.5, "primaryTopics": ["..."] }
  ],
  "speakerRoles": { "Speaker A": "Host" }
}

#### RATIONAL NEUTRALITY RULES (TRUTHWORLD PATH 1):
1. THE CORE RULE: A Fact is a Fact. A Belief is a Belief.
2. BUCKET 1 (Verifiable Fact): Treat as empirical. Distinguish between "Unproven" (no evidence found) and "False" (contradicted by evidence). "Unproven" should NOT be penalized as heavily as "False".
3. BUCKET 2/3 (Opinion/Belief): Respect fully. DO NOT attempt to verify for truth.
4. HONESTY FLAG: The ONLY violation for Bucket 2/3 is framing. If a speaker says "Scientists have proven [Belief]" or "It is a verified fact that [Opinion]", flag as a FRAMING VIOLATION.
5. SCRIPTURAL CONTEXT: For scriptural narratives, spiritual doctrines, or miraculous traditions across world faiths, classify them respectfully as religious/faith belief without applying physical falsification to personal theological beliefs.
6. MANIPULATION: Distinguish between "Marketing Hype" (scored low) and "Rage-bait" (scored high).
7. INTELLIGENT NEUTRALITY: If the transcript is primarily legal or political inquiries, suggest specific types of sources (e.g., "consult court rulings") rather than making definitive conclusions.`;

    const narrativeChain = { primary: PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash", fallback: null, forcePrimary: true };
    return withAiRetry(async (modelId: string) => {
      const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
      const response = await activeModel.generateContent(prompt);
      const text = extractCandidateText(response.response.candidates?.[0]) || response.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const jsonMatch = this.extractJSON(text);
      if (!jsonMatch) throw new Error("No JSON found");

      const parsed = JSON.parse(jsonMatch);

      // Build authentic sources lookup from verified claims
      const authenticSourcesMap = new Map<string, any>();
      verifiedClaims.forEach(c => {
        const sList = c.sources || (c as any).richSources || (c as any).effectiveSources || [];
        sList.forEach((s: any) => {
          const key = (s.url || s.domain || s.title || "").toLowerCase();
          if (key && !authenticSourcesMap.has(key)) {
            const dom = s.domain || SourceAvatarService.cleanDomain(s.url);
            const avatar = s.avatarUrl || SourceAvatarService.resolveAvatar(dom, s.publisher || s.author || s.title);
            authenticSourcesMap.set(key, {
              title: s.title || s.domain || "Authoritative Source",
              url: s.url || "",
              domain: dom,
              avatarUrl: avatar,
              publisher: s.publisher || s.author,
              trustLevel: s.tier === 'A' || s.tier === 'B' ? 'High' : (s.tier === 'C' ? 'Medium' : 'Low'),
              type: s.type || 'Supporting',
              snippet: s.snippet || "",
            });
          }
        });
      });

      let conclusionSources: any[] = Array.isArray(parsed.conclusion?.sources) ? parsed.conclusion.sources : [];
      if (conclusionSources.length === 0 && authenticSourcesMap.size > 0) {
        conclusionSources = Array.from(authenticSourcesMap.values());
      } else if (conclusionSources.length > 0) {
        conclusionSources = conclusionSources.map((cs: any) => {
          const csKey = (cs.url || cs.domain || cs.title || "").toLowerCase();
          const match = authenticSourcesMap.get(csKey) || Array.from(authenticSourcesMap.values()).find(as =>
            (cs.url && as.url && cs.url.toLowerCase() === as.url.toLowerCase()) ||
            (cs.domain && as.domain && cs.domain.toLowerCase() === as.domain.toLowerCase()) ||
            (cs.title && as.title && (cs.title.toLowerCase().includes(as.title.toLowerCase()) || as.title.toLowerCase().includes(cs.title.toLowerCase())))
          );
          const merged = match ? { ...cs, ...match } : cs;
          if (!merged.avatarUrl) {
            const dom = merged.domain || SourceAvatarService.cleanDomain(merged.url);
            merged.avatarUrl = SourceAvatarService.resolveAvatar(dom, merged.publisher || merged.author || merged.title);
          }
          return merged;
        });
      }

      const conclusionObj = {
        label: parsed.conclusion?.label || (verifiedClaims.length > 0 ? "Supported" : "Unverified"),
        text: parsed.conclusion?.text || (typeof parsed.conclusion === 'string' ? parsed.conclusion : "Conclusion unavailable."),
        confidence: parsed.conclusion?.confidence ?? (verifiedClaims.length > 0 ? 0.85 : 0.5),
        sources: conclusionSources,
      };

      return {
        summary:          parsed.summary || "Summary unavailable.",
        conclusion:       conclusionObj,
        hallucinationIsolation: parsed.hallucinationIsolation || { verifiedFacts: [], modelInterpretations: [], uncertainInferences: [] },
        traceabilityMap:  parsed.traceabilityMap || {},
        knowledgeDensity: parsed.knowledgeDensity || 0.5,
        keyThemes:        parsed.keyThemes || [],
        viewerNote:       parsed.viewerNote || "No viewer notes.",
        manipulationScore: parsed.manipulationScore || 0.0,
        manipulationSignals: parsed.manipulationSignals || [],
        chapters:         parsed.chapters || [],
        speakerRoles:     parsed.speakerRoles || {}
      };
    }, narrativeChain, { maxAttempts: 4, instanceId: `TieredIntelligence-${tier}` });
  }

  /**
   * 🛡 NEW: Global Consistency Engine
   * Cross-references claims across chunk boundaries to find stance shifts.
   */
  public async detectInternalContradictions(claims: VerifiedClaim[]): Promise<{ hasContradiction: boolean; details: string; claimNature: ClaimNature }> {
    if (claims.length < 3) return { hasContradiction: false, details: "", claimNature: ClaimNature.VERIFIABLE_FACT };

    // Filter for factual claims only to reduce token noise
    const factualClaims = claims.filter(c => 
      c.nature === ClaimNature.VERIFIABLE_FACT || 
      c.status === 'verified_true' || 
      c.status === 'false_claim'
    ).slice(0, 20); // Cap at top 20 for consistency check performance

    if (factualClaims.length < 2) return { hasContradiction: false, details: "", claimNature: ClaimNature.VERIFIABLE_FACT };

    const claimSummary = factualClaims
      .map(c => `[Speaker: ${c.speaker}] Claim: "${c.text}" | Timestamp: ${c.start}ms`)
      .join("\n");

    const prompt = `You are a Logical Consistency Auditor. Compare the following claims from the same transcript.
Identify any "Internal Contradictions" where a speaker reverses their stance or contradicts a previously stated fact.

Claims:
${claimSummary}

Return a JSON object:
{
  "hasContradiction": boolean,
  "details": "Summary of contradiction or empty string",
  "claimNature": "VERIFIABLE_FACT"
}
Return ONLY valid JSON.`;

    const contradictionChain = { primary: PIPELINE_CONFIG.GEMINI_MODELS?.consistency || PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash", fallback: null, forcePrimary: true };
    return withAiRetry(async (modelId: string) => {
      const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
      const response = await activeModel.generateContent(prompt);
      const text = extractCandidateText(response.response.candidates?.[0]) || response.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const jsonMatch = this.extractJSON(text);
      if (!jsonMatch) return { hasContradiction: false, details: "", claimNature: ClaimNature.VERIFIABLE_FACT };
      
      const parsed = JSON.parse(jsonMatch);
      return {
        hasContradiction: !!parsed.hasContradiction,
        details: parsed.details || "",
        claimNature: ClaimNature.VERIFIABLE_FACT
      };
    }, contradictionChain, { maxAttempts: 2, instanceId: "InternalContradictions" }).catch(() => ({
      hasContradiction: false,
      details: "",
      claimNature: ClaimNature.VERIFIABLE_FACT
    }));
  }

  /**
   * Helper to extract JSON from marked up text
   */
  private extractJSON(text: string): string | null {
    // 1. Try to find JSON within code blocks first
    const codeBlockMatch = text.match(/```json\s*(\{[\s\S]*?\})\s*```/);
    let raw = codeBlockMatch ? codeBlockMatch[1] : null;

    // 2. Fallback to finding first { and last }
    if (!raw) {
      const match = text.match(/\{[\s\S]*\}/);
      raw = match ? match[0] : null;
    }

    if (!raw) return null;

    // v14.0: Sanitize common LLM JSON output issues before parsing.
    // LLMs frequently produce:
    //   - Trailing commas: {"a": 1,}
    //   - Single-line comments: // comment
    //   - Multi-line comments: /* comment */
    //   - Unquoted keys (rare but possible)
    let sanitized = raw
      // Remove single-line comments (// ...)
      .replace(/\/\/[^\n]*/g, '')
      // Remove multi-line comments (/* ... */)
      .replace(/\/\*[\s\S]*?\*\//g, '')
      // Remove trailing commas before } or ]
      .replace(/,\s*([\]}])/g, '$1')
      // Remove any BOM or zero-width chars
      .replace(/[\uFEFF\u200B]/g, '');

    return sanitized;
  }
  /**
   * 🏷 v7: Identity Extraction (Quick Pass)
   */
  async extractSpeakerNames(sampleText: string): Promise<Record<string, string>> {
    const prompt = `Identify the real names of the speakers in this transcript if they are mentioned or can be inferred (e.g. from introductions).
Transcript Sample:
"""
${sampleText}
"""

Return a JSON map: {"Speaker Label": "Real Name or Unknown"}. 
Example: {"Speaker A": "John Smith", "Speaker B": "Unknown"}.
Return ONLY JSON.`;

    const speakerChain = { primary: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || PIPELINE_CONFIG.GEMINI_MODELS?.extraction || "gemini-2.5-flash", fallback: null, forcePrimary: true };
    return withAiRetry(async (modelId: string) => {
      const activeModel = this.genAI.getGenerativeModel({ model: modelId, safetySettings: FACT_CHECK_SAFETY_SETTINGS });
      const res = await activeModel.generateContent(prompt);
      const text = extractCandidateText(res.response.candidates?.[0]) || res.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const match = text.match(/\{[\s\S]*\}/);
      return match ? JSON.parse(match[0]) : {};
    }, speakerChain, { maxAttempts: 3, instanceId: "SpeakerNameExtraction" }).catch(() => ({}));
  }
}

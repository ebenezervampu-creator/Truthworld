import type { VertexAI } from "@google-cloud/vertexai";
import { logger } from "../utils/logger";
import { withAiRetry, extractCandidateText } from "../utils/ai-utils";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import {
  VideoGatewayDecision,
  GatewayDecisionStatus,
  ExecutionPlan,
  TimedSegment
} from "../types";

const HarmCategory = {
  HARM_CATEGORY_HARASSMENT: "HARM_CATEGORY_HARASSMENT",
  HARM_CATEGORY_HATE_SPEECH: "HARM_CATEGORY_HATE_SPEECH",
  HARM_CATEGORY_SEXUALLY_EXPLICIT: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
  HARM_CATEGORY_DANGEROUS_CONTENT: "HARM_CATEGORY_DANGEROUS_CONTENT",
} as const;

const HarmBlockThreshold = {
  BLOCK_NONE: "BLOCK_NONE",
} as const;

/** Minimum required percentage of English spoken content for a video to be accepted */
export const MIN_ENGLISH_CONTENT_PERCENTAGE = 90;

const COMMON_ENGLISH_WORDS = new Set([
  "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
  "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
  "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
  "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
  "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
  "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
  "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
  "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
  "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
  "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
  "is", "are", "was", "were", "been", "has", "had", "did", "does", "doing",
  "hello", "welcome", "today", "here", "where", "why", "very", "much", "more", "many",
  "said", "says", "told", "talking", "speaking", "report", "reporting", "news", "ground",
  "video", "channel", "watch", "world", "india", "local", "street", "interview", "let"
]);

const NON_LATIN_SCRIPT_REGEX = /[\u0600-\u06FF\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F\u0E00-\u0E7F\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF\u0400-\u04FF]/u;

/**
 * Estimates the percentage (0-100) of English spoken content in a transcript.
 * Supports the 90/10 rule: videos must be >= 90% English, allowing up to 10% in other languages
 * (e.g., ground news interviews in Hindi/Telugu, quotes, or regional phrases).
 */
export function estimateEnglishPercentage(
  transcriptText: string,
  detectedLanguage?: string
): number {
  const normLang = detectedLanguage ? normalizeLanguageCode(detectedLanguage) : "en";
  if (!transcriptText || transcriptText.trim().length === 0) {
    return normLang === "en" ? 100 : 0;
  }

  const words = transcriptText
    .trim()
    .split(/\s+/)
    .map(w => w.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, ""))
    .filter(w => w.length > 0);

  if (words.length === 0) {
    return normLang === "en" ? 100 : 0;
  }

  const latinWordList: string[] = [];
  let englishCoreCount = 0;

  for (const w of words) {
    if (!NON_LATIN_SCRIPT_REGEX.test(w)) {
      latinWordList.push(w);
      if (COMMON_ENGLISH_WORDS.has(w.toLowerCase())) {
        englishCoreCount++;
      }
    }
  }

  if (latinWordList.length === 0) {
    return 0;
  }

  const scriptRatio = latinWordList.length / words.length;
  const coreWordRatio = englishCoreCount / latinWordList.length;

  // Evaluate 10-word windows across the Latin words to detect any Latin-transliterated foreign stretches
  const windowSize = 10;
  let totalLatinWindows = 0;
  let englishLatinWindows = 0;

  for (let i = 0; i < latinWordList.length; i += windowSize) {
    // If the remaining tail is < 5 words and we already have a window, merge it with the preceding context
    if (i > 0 && latinWordList.length - i < 5) {
      break;
    }
    const slice = latinWordList.slice(i, i + windowSize);
    totalLatinWindows++;
    const hasEnglishCore = slice.some(w => COMMON_ENGLISH_WORDS.has(w.toLowerCase()));
    if (hasEnglishCore) {
      englishLatinWindows++;
    }
  }

  const latinWindowRatio = totalLatinWindows > 0 ? englishLatinWindows / totalLatinWindows : 0;

  if (normLang !== "en") {
    // If the speech detector flagged a non-English language, only override if there is a
    // substantial transcript (>= 15 words) that is >= 90% English in script, window coverage, and grammar.
    if (words.length >= 15 && scriptRatio >= 0.9 && latinWindowRatio >= 0.9 && coreWordRatio >= 0.25) {
      return Math.round(scriptRatio * latinWindowRatio * 100);
    }
    return Math.min(Math.round(scriptRatio * coreWordRatio * 100), 40);
  }

  return Math.round(scriptRatio * latinWindowRatio * 100);
}

export class VideoGatewayService {
  private _genAI?: VertexAI;

  private get genAI(): VertexAI {
    if (!this._genAI) {
      this._genAI = getVertexAI();
    }
    return this._genAI;
  }

  constructor() {}

  /**
   * Evaluates a video transcript after AssemblyAI transcription completes.
   * Determines if the video is APPROVED, REJECTED, or requires MANUAL_REVIEW.
   *
   * Enforces TruthWorld's 90/10 Primary English Policy:
   * - Primary language must be English (>= 90% of video in English).
   * - Up to 10% can be other languages (e.g., Hindi/Telugu ground reporting interviews, quotes, phrases).
   */
  async evaluateVideo(
    jobId: string,
    transcriptText: string,
    utterances: TimedSegment[],
    executionPlan: ExecutionPlan,
    detectedLanguage?: string
  ): Promise<VideoGatewayDecision> {
    logger.info(`[VideoGateway] Starting video evaluation gateway for job: ${jobId}`, { detectedLanguage });

    const resolvedLang = detectedLanguage
      ? normalizeLanguageCode(detectedLanguage)
      : (executionPlan.primaryLanguage ? normalizeLanguageCode(executionPlan.primaryLanguage) : "en");

    const localEnglishPct = estimateEnglishPercentage(transcriptText, resolvedLang || undefined);

    // 🔒 PLATFORM LANGUAGE POLICY ENFORCEMENT (90% PRIMARY ENGLISH RULE)
    // Reject immediately if the video is < 90% English (e.g. a full Telugu/Hindi video or majority non-English).
    // If the video is >= 90% English (such as an English Ground News report with a brief <= 10% Hindi/Telugu clip), allow it!
    if (localEnglishPct < MIN_ENGLISH_CONTENT_PERCENTAGE && (resolvedLang !== "en" || localEnglishPct < 80)) {
      const langUpper = (resolvedLang && resolvedLang !== "en" ? resolvedLang : "NON-EN").toUpperCase();
      logger.warn(
        `[VideoGateway] Video below 90% English threshold (${localEnglishPct}% English, primary detected: ${langUpper}) for job: ${jobId} — REJECTING per platform policy.`
      );
      return {
        status: "REJECTED",
        confidence: 0.99,
        evaluatedAt: Date.now(),
        rejectionReason: `Truthworld currently only supports English channels and content (at least 90% of the video must be in English; up to 10% in other languages is allowed for quotes or ground reporting). This video was detected in a non-English language (${langUpper}, ${localEnglishPct}% English) and cannot be accepted at this stage.`,
        violatingPolicies: ["UNSUPPORTED_LANGUAGE"],
        violatingClaims: [],
        sensitiveTopics: [],
        flaggedTimestamps: []
      };
    }

    if (!transcriptText || transcriptText.trim().length === 0) {
      logger.warn(`[VideoGateway] Empty transcript for job: ${jobId} — sending to MANUAL_REVIEW`);
      return {
        status: "MANUAL_REVIEW",
        confidence: 0.5,
        evaluatedAt: Date.now(),
        reviewReason: "Empty or silent audio transcript detected. Requires human inspection.",
        sensitiveTopics: ["EMPTY_AUDIO"],
        flaggedTimestamps: []
      };
    }

    const channelRequestedAutoChapters = !!(
      executionPlan.autoChapters ||
      (executionPlan as any).generateChapters ||
      (executionPlan as any).enableChapters
    );

    const prompt = `ROLE: TruthWorld Video Moderation & Metadata Gateway.
OBJECTIVE: Evaluate the provided video transcript to determine if the video should be APPROVED, REJECTED, or sent for MANUAL_REVIEW.

LANGUAGE POLICY (90% PRIMARY ENGLISH / 10% SECONDARY ALLOWANCE):
- TruthWorld requires the primary language of every video to be English: at least 90% of the spoken video content must be in English.
- Up to 10% of the video MAY contain words, phrases, quotes, or brief interviews in other languages (for example: Ground News reporting where an English presenter speaks or interviews locals in Hindi, Telugu, Spanish, etc. for a few moments). Do NOT reject a video if it is >= 90% English!
- If MORE than 10% of the video is in a non-English language (i.e. less than 90% English, or primarily in Telugu, Hindi, Tamil, Spanish, etc.), you MUST output status "REJECTED" with violatingPolicies ["UNSUPPORTED_LANGUAGE"].

DECISION CRITERIA:
1. REJECTED:
   - Violates the 90% Primary English Policy (less than 90% of the video is in English). Output status "REJECTED", rejectionReason "Truthworld currently only supports English channels and content (at least 90% of the video must be in English). This video exceeded the 10% non-English allowance and cannot be accepted at this stage.", and violatingPolicies ["UNSUPPORTED_LANGUAGE"].
   - Contains severe illegal content, dangerous violence, hate speech, severe harassment, or explicit dangerous medical misinformation.
   - You MUST output status "REJECTED".
   - You MUST provide a clear "rejectionReason" explaining why the video was rejected.
   - You MUST list "violatingPolicies" (e.g., ["UNSUPPORTED_LANGUAGE", "HATE_SPEECH", "SEVERE_MEDICAL_MISINFO"]).
   - You MUST list specific "violatingClaims" with exact quote text and timestamps if available.

2. MANUAL_REVIEW:
   - Contains high-stakes, unverified electoral claims, active conflict escalation, or ambiguous sensitive topics that require human judgment.
   - You MUST output status "MANUAL_REVIEW".
   - You MUST provide a clear "reviewReason" explaining why human review is required.
   - You MUST list "sensitiveTopics" (e.g., ["ELECTION_INTEGRITY", "UNVERIFIED_HEALTH_CLAIM"]).
   - You MUST list "flaggedTimestamps" with time ranges and reasons.

3. APPROVED:
   - Safe, educational, informational, news, ground reporting, political commentary, entertainment, or historical content where at least 90% of the video is in English (up to 10% secondary language quotes/interviews permitted).
   - You MUST output status "APPROVED".
   - You MUST provide a concise, engaging "summary" of the video content (2-3 sentences).
   - You MUST assign a primary "category" (e.g., "Education", "Science", "Politics", "History", "News", "Technology", "Entertainment").
   - You MUST provide 5-8 relevant "tags".
   ${channelRequestedAutoChapters 
     ? '- Channel explicitly requested AI Auto-Chapters: Provide 3-8 logical "autoChapters" with startMs, endMs, title, and summary.' 
     : '- Channel DID NOT request auto-chapters: Set autoChapters to an empty array []. DO NOT generate auto-chapters.'}

TRANSCRIPT TO EVALUATE:
${transcriptText.substring(0, 15000)}

UTTERANCES WITH TIMESTAMPS:
${utterances.slice(0, 50).map(u => `[${u.start}ms - ${u.end}ms] (${u.speaker || 'Speaker'}): "${u.text}"`).join('\n')}

RETURN STRICT JSON FORMAT ONLY:
{
  "status": "APPROVED" | "REJECTED" | "MANUAL_REVIEW",
  "detectedLanguage": "string (primary ISO 639-1 code e.g. en, te, hi)",
  "englishPercentage": number (0 to 100, percentage of video content in English),
  "confidence": number (0.0 to 1.0),
  "summary": "string (for APPROVED)",
  "category": "string (for APPROVED)",
  "tags": ["string"] (for APPROVED),
  "autoChapters": [
    { "startMs": number, "endMs": number, "title": "string", "summary": "string" }
  ],
  "rejectionReason": "string (for REJECTED)",
  "violatingPolicies": ["string"] (for REJECTED),
  "violatingClaims": [
    { "text": "string", "timestampMs": number, "reason": "string" }
  ],
  "reviewReason": "string (for MANUAL_REVIEW)",
  "sensitiveTopics": ["string"] (for MANUAL_REVIEW),
  "flaggedTimestamps": [
    { "startMs": number, "endMs": number, "reason": "string" }
  ]
}`;

    const chain = {
      primary: PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || "gemini-3.1-flash-lite",
      fallback: "gemini-3.1-flash-lite",
      forcePrimary: false
    };

    try {
      const decision = await withAiRetry(async (modelId: string) => {
        const model = this.genAI.getGenerativeModel({
          model: modelId,
          safetySettings: [
            { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
          ] as any
        });

        const res = await model.generateContent(prompt);
        const text = extractCandidateText(res.response.candidates?.[0]) || res.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No JSON in Video Gateway response");

        const parsed = JSON.parse(jsonMatch[0]);

        const geminiLang = parsed.detectedLanguage ? normalizeLanguageCode(parsed.detectedLanguage) : "en";
        const geminiEnglishPct = typeof parsed.englishPercentage === "number"
          ? parsed.englishPercentage
          : localEnglishPct;

        // Enforce the 90% Primary English Policy
        if (geminiEnglishPct < MIN_ENGLISH_CONTENT_PERCENTAGE) {
          const langLabel = (geminiLang !== "en" ? geminiLang : resolvedLang || "NON-EN").toUpperCase();
          logger.warn(`[VideoGateway] Gemini detected ${geminiEnglishPct}% English (< 90% required, language: ${langLabel}) for job: ${jobId} — REJECTING.`);
          return {
            status: "REJECTED" as GatewayDecisionStatus,
            confidence: 0.95,
            evaluatedAt: Date.now(),
            rejectionReason: `Truthworld currently only supports English channels and content (at least 90% of the video must be in English; up to 10% in other languages is allowed for quotes or ground reporting). This video was detected with ${geminiEnglishPct}% English (${langLabel}) and cannot be accepted at this stage.`,
            violatingPolicies: ["UNSUPPORTED_LANGUAGE"],
            violatingClaims: [],
            sensitiveTopics: [],
            flaggedTimestamps: []
          };
        }

        // Protect videos that meet the >= 90% English requirement from false-positive language rejections
        if (
          parsed.status === "REJECTED" &&
          geminiEnglishPct >= MIN_ENGLISH_CONTENT_PERCENTAGE &&
          Array.isArray(parsed.violatingPolicies) &&
          parsed.violatingPolicies.length === 1 &&
          parsed.violatingPolicies[0] === "UNSUPPORTED_LANGUAGE"
        ) {
          logger.info(`[VideoGateway] Approving video with ${geminiEnglishPct}% English (>= 90% rule satisfied) for job: ${jobId}`);
          parsed.status = "APPROVED";
          parsed.violatingPolicies = [];
          delete parsed.rejectionReason;
        }

        const status: GatewayDecisionStatus = 
          parsed.status === "REJECTED" ? "REJECTED" :
          parsed.status === "MANUAL_REVIEW" ? "MANUAL_REVIEW" : "APPROVED";

        const result: VideoGatewayDecision = {
          status,
          confidence: typeof parsed.confidence === 'number' ? parsed.confidence : 0.9,
          evaluatedAt: Date.now(),
          summary: parsed.summary || undefined,
          category: parsed.category || "General",
          tags: Array.isArray(parsed.tags) ? parsed.tags : [],
          autoChapters: channelRequestedAutoChapters && Array.isArray(parsed.autoChapters) ? parsed.autoChapters : [],
          rejectionReason: parsed.rejectionReason || undefined,
          violatingPolicies: Array.isArray(parsed.violatingPolicies) ? parsed.violatingPolicies : [],
          violatingClaims: Array.isArray(parsed.violatingClaims) ? parsed.violatingClaims : [],
          reviewReason: parsed.reviewReason || undefined,
          sensitiveTopics: Array.isArray(parsed.sensitiveTopics) ? parsed.sensitiveTopics : [],
          flaggedTimestamps: Array.isArray(parsed.flaggedTimestamps) ? parsed.flaggedTimestamps : []
        };

        return result;
      }, chain, { maxAttempts: 2, instanceId: "VideoGatewayService" });

      logger.info(`[VideoGateway] Gateway Decision for job ${jobId}: ${decision.status}`, { decision });
      return decision;
    } catch (error) {
      logger.warn(`[VideoGateway] Evaluation failed for job ${jobId} — evaluating language fallback`, { error });

      if (localEnglishPct < MIN_ENGLISH_CONTENT_PERCENTAGE) {
        const langUpper = (resolvedLang && resolvedLang !== "en" ? resolvedLang : "NON-EN").toUpperCase();
        return {
          status: "REJECTED",
          confidence: 0.95,
          evaluatedAt: Date.now(),
          rejectionReason: `Truthworld currently only supports English channels and content (at least 90% of the video must be in English; up to 10% in other languages is allowed for quotes or ground reporting). This video was detected in a non-English language (${langUpper}, ${localEnglishPct}% English) and cannot be accepted at this stage.`,
          violatingPolicies: ["UNSUPPORTED_LANGUAGE"],
          violatingClaims: [],
          sensitiveTopics: [],
          flaggedTimestamps: []
        };
      }

      const fallbackSummary = transcriptText.length > 20
        ? (transcriptText.length > 200 ? `${transcriptText.substring(0, 197)}...` : transcriptText)
        : "Video content processed successfully.";
      return {
        status: "APPROVED",
        confidence: 0.8,
        evaluatedAt: Date.now(),
        category: executionPlan.videoCategory || executionPlan.category || "General",
        summary: fallbackSummary,
        tags: executionPlan.tags && executionPlan.tags.length > 0 ? executionPlan.tags : ["truthworld", "video"],
        autoChapters: [],
        violatingPolicies: [],
        violatingClaims: [],
        sensitiveTopics: [],
        flaggedTimestamps: []
      };
    }
  }
}

export const videoGatewayService = new VideoGatewayService();

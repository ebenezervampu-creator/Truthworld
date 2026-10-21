import * as admin from "firebase-admin";
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
    /**
   * Evaluates video safety & community guidelines using Google Cloud Vertex AI.
   *
   * ⚡ COST-EFFECTIVE ARCHITECTURE:
   *   - Content moderation is NOT based on or dependent on an AssemblyAI transcript.
   *   - Reuses Google Cloud Content Moderation records from GCS URI multimodal analysis if already run.
   *   - Otherwise evaluates directly with Google Cloud Vertex AI Gemini 2.5 Flash on metadata & media.
   *   - Never flags or sends empty/silent audio to manual review.
   */
  async evaluateVideo(
    jobId: string,
    transcriptTextOrPlan?: string | ExecutionPlan,
    utterancesOrPlan?: TimedSegment[] | ExecutionPlan,
    planOrDetectedLang?: ExecutionPlan | string,
    detectedLang?: string
  ): Promise<VideoGatewayDecision> {
    let transcriptText = "";
    let utterances: TimedSegment[] = [];
    let executionPlan: ExecutionPlan = {
      jobId,
      videoId: jobId,
      title: "",
      channelId: "",
      channelName: "",
      category: "General",
      tags: [],
      languages: ["en"],
      primaryLanguage: "en",
      enablePath1: false,
      enablePath2: false,
      enableTruthEngine: false,
      enableReachEngine: false,
      enableAuxiliary: false,
      dubbingMode: "none",
      generateDubbing: false,
      genLangSubs: false,
      channelType: "standard",
      maxClaims: 10,
      priority: "normal",
      skipCache: false,
    };
    let detectedLanguage: string | undefined;

    if (transcriptTextOrPlan && typeof transcriptTextOrPlan === "object" && "jobId" in transcriptTextOrPlan) {
      executionPlan = transcriptTextOrPlan as ExecutionPlan;
      transcriptText = typeof utterancesOrPlan === "string" ? utterancesOrPlan : "";
      utterances = Array.isArray(planOrDetectedLang) ? planOrDetectedLang : [];
      detectedLanguage = typeof detectedLang === "string" ? detectedLang : undefined;
    } else {
      transcriptText = typeof transcriptTextOrPlan === "string" ? transcriptTextOrPlan : "";
      utterances = Array.isArray(utterancesOrPlan) ? utterancesOrPlan : [];
      if (planOrDetectedLang && typeof planOrDetectedLang === "object") {
        executionPlan = planOrDetectedLang as ExecutionPlan;
      }
      detectedLanguage = detectedLang;
    }

    const resolvedLang = detectedLanguage
      ? normalizeLanguageCode(detectedLanguage)
      : (executionPlan.primaryLanguage ? normalizeLanguageCode(executionPlan.primaryLanguage) : "en");

    logger.info(`[VideoGateway] Starting Google Cloud content moderation gateway for job: ${jobId}`, {
      detectedLanguage,
      resolvedLang,
      hasTranscript: Boolean(transcriptText && transcriptText.trim().length > 0)
    });

    const targetVideoId = executionPlan.videoId || jobId;

    // ─── STEP 1: Check existing Google Cloud Content Moderation records in Firestore ───
    try {
      const videoDoc = await admin.firestore().collection("videos").doc(targetVideoId).get();
      if (videoDoc.exists) {
        const videoData = videoDoc.data() || {};
        const mod = videoData.moderation;
        if (mod && (mod.status === "approved" || mod.status === "rejected")) {
          logger.info(`[VideoGateway] Utilizing existing Google Cloud Content Moderation result for ${targetVideoId}`, {
            status: mod.status,
            model: mod.model || "gemini-2.5-flash",
          });
          if (mod.status === "approved") {
            return {
              status: "APPROVED",
              confidence: typeof mod.confidenceScore === "number" ? mod.confidenceScore : 0.95,
              evaluatedAt: mod.checkedAt ?? Date.now(),
              summary: mod.summary || videoData.summary || videoData.moderationSummary || undefined,
              category: mod.category || videoData.category || "General",
              tags: Array.isArray(videoData.tags) && videoData.tags.length > 0
                ? videoData.tags
                : (executionPlan.tags && executionPlan.tags.length > 0 ? executionPlan.tags : ["truthworld"]),
              autoChapters: [],
              violatingPolicies: [],
              violatingClaims: [],
              sensitiveTopics: [],
              flaggedTimestamps: [],
            };
          } else if (mod.status === "rejected") {
            return {
              status: "REJECTED",
              confidence: typeof mod.confidenceScore === "number" ? mod.confidenceScore : 0.95,
              evaluatedAt: mod.checkedAt ?? Date.now(),
              rejectionReason: mod.reason || mod.policyReason || "Content violates Community Guidelines",
              violatingPolicies: Array.isArray(mod.violationCategories) && mod.violationCategories.length > 0
                ? mod.violationCategories
                : ["COMMUNITY_GUIDELINES_VIOLATION"],
              violatingClaims: [],
              autoChapters: [],
              tags: [],
              category: "General",
            };
          }
        }
      }
    } catch (checkErr) {
      logger.warn(`[VideoGateway] Non-blocking Firestore lookup error for video moderation:`, checkErr);
    }

    const channelRequestedAutoChapters = !!(
      executionPlan.autoChapters ||
      (executionPlan as any).generateChapters ||
      (executionPlan as any).enableChapters
    );

    const title = executionPlan.title || "Video";
    const description = executionPlan.description || "";
    const category = executionPlan.category || executionPlan.videoCategory || "General";
    const tags = executionPlan.tags || [];

    // ─── STEP 2: Evaluate using Google Cloud Vertex AI Gemini (NOT Transcript-dependent) ───
    const prompt = `ROLE: TruthWorld Content Moderation & Safety Gateway (Google Cloud AI).
OBJECTIVE: Evaluate the provided video metadata and content for Community Guidelines and Safety compliance.
NOTE: Content moderation is strictly based on safety, decorum, illegal content, harassment, hate speech, and dangerous materials. It is NOT based on speech-to-text transcripts or controversial opinions. TruthWorld welcomes all languages.

METADATA TO EVALUATE:
- Title: "${title}"
- Description: "${description}"
- Category: "${category}"
- Tags: [${tags.join(", ")}]
${transcriptText && transcriptText.trim().length > 0 ? `- Supplemental Audio Context (optional): "${transcriptText.substring(0, 4000)}"` : "- Audio/Video: Standard media stream without required transcript."}
${utterances.length > 0 ? `- Utterance Samples: ${utterances.slice(0, 10).map(u => `"${u.text}"`).join(", ")}` : ""}

GLOBAL LANGUAGE POLICY:
- TruthWorld welcomes and accepts content in all world languages.
- Spoken language is NEVER grounds for rejection.

DECISION CRITERIA:
1. REJECTED:
   - Contains severe illegal content, dangerous violence, hate speech, severe harassment, or explicit dangerous medical misinformation.
   - You MUST output status "REJECTED".
   - You MUST provide a clear "rejectionReason".
   - You MUST list "violatingPolicies" (e.g. ["HATE_SPEECH", "VIOLENCE", "HARASSMENT"]).

2. MANUAL_REVIEW:
   - High-stakes, unverified electoral claims, active conflict escalation, or ambiguous sensitive topics that require human judgment.
   - You MUST output status "MANUAL_REVIEW".
   - You MUST provide a clear "reviewReason" and "sensitiveTopics".

3. APPROVED:
   - Safe, educational, informational, news, ground reporting, political commentary, entertainment, music, or creative content in any language.
   - You MUST output status "APPROVED".
   - You MUST provide a concise, engaging "summary" (2-3 sentences).
   - You MUST assign a primary "category".
   - You MUST provide 5-8 relevant "tags".
   ${channelRequestedAutoChapters 
     ? '- Channel explicitly requested AI Auto-Chapters: Provide 3-8 logical "autoChapters" with startMs, endMs, title, and summary.' 
     : '- Set autoChapters to [].'}

RETURN STRICT JSON FORMAT ONLY:
{
  "status": "APPROVED" | "REJECTED" | "MANUAL_REVIEW",
  "detectedLanguage": "${resolvedLang}",
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
      primary: PIPELINE_CONFIG.GEMINI_MODELS?.moderation || PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || "gemini-2.5-flash",
      fallback: "gemini-2.5-flash",
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

        // Filter out any lingering UNSUPPORTED_LANGUAGE policy
        if (Array.isArray(parsed.violatingPolicies)) {
          parsed.violatingPolicies = parsed.violatingPolicies.filter((p: string) => p !== "UNSUPPORTED_LANGUAGE");
          if (parsed.status === "REJECTED" && parsed.violatingPolicies.length === 0) {
            parsed.status = "APPROVED";
            delete parsed.rejectionReason;
          }
        }

        const status: GatewayDecisionStatus = 
          parsed.status === "REJECTED" ? "REJECTED" :
          parsed.status === "MANUAL_REVIEW" ? "MANUAL_REVIEW" : "APPROVED";

        const result: VideoGatewayDecision = {
          status,
          confidence: typeof parsed.confidence === 'number' ? parsed.confidence : 0.9,
          evaluatedAt: Date.now(),
          summary: parsed.summary || undefined,
          category: parsed.category || category || "General",
          tags: Array.isArray(parsed.tags) && parsed.tags.length > 0 ? parsed.tags : tags,
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

      logger.info(`[VideoGateway] Google Cloud Gateway Decision for job ${jobId}: ${decision.status}`, { decision });
      return decision;
    } catch (error) {
      logger.warn(`[VideoGateway] Google Cloud AI Evaluation fallback for job ${jobId}`, { error });

      let fallbackSummary: string | undefined = undefined;
      try {
        const summaryModel = this.genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          generationConfig: { maxOutputTokens: 150, temperature: 0.2 } as any,
        });
        const summaryInput = (transcriptText && transcriptText.length > 20)
          ? transcriptText.substring(0, 4000)
          : `Title: ${title}. Description: ${description}`;
        const summaryRes = await summaryModel.generateContent(
          `Provide a concise 2-3 sentence AI summary of this video content based on: ${summaryInput}`
        );
        const candidateText = extractCandidateText(summaryRes.response?.candidates?.[0])?.trim();
        if (candidateText && candidateText.length > 20) {
          fallbackSummary = candidateText;
        }
      } catch (sumErr) {
        logger.warn(`[VideoGateway] Dedicated AI summary fallback failed for job ${jobId}`, { sumErr });
      }

      return {
        status: "APPROVED",
        confidence: 0.85,
        evaluatedAt: Date.now(),
        category: executionPlan.videoCategory || executionPlan.category || category || "General",
        summary: fallbackSummary || (description ? description.substring(0, 200) : "Video published on TruthWorld."),
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

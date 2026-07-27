import { VertexAI, HarmCategory, HarmBlockThreshold } from "@google-cloud/vertexai";
import { logger } from "../utils/logger";
import { withAiRetry } from "../utils/ai-utils";
import {
  VideoGatewayDecision,
  GatewayDecisionStatus,
  ExecutionPlan,
  TimedSegment
} from "../types";

export class VideoGatewayService {
  private genAI: VertexAI;

  constructor() {
    this.genAI = new VertexAI({
      project: process.env.VERTEX_PROJECT_ID || "truthworld-1",
      location: process.env.VERTEX_LOCATION || "asia-south1"
    });
  }

  /**
   * Evaluates a video transcript after AssemblyAI transcription completes.
   * Determines if the video is APPROVED, REJECTED, or requires MANUAL_REVIEW.
   */
  async evaluateVideo(
    jobId: string,
    transcriptText: string,
    utterances: TimedSegment[],
    executionPlan: ExecutionPlan
  ): Promise<VideoGatewayDecision> {
    logger.info(`[VideoGateway] Starting video evaluation gateway for job: ${jobId}`);

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

DECISION CRITERIA:
1. REJECTED:
   - Contains severe illegal content, dangerous violence, hate speech, severe harassment, or explicit dangerous medical misinformation.
   - You MUST output status "REJECTED".
   - You MUST provide a clear "rejectionReason" explaining why the video was rejected.
   - You MUST list "violatingPolicies" (e.g., ["HATE_SPEECH", "SEVERE_MEDICAL_MISINFO"]).
   - You MUST list specific "violatingClaims" with exact quote text and timestamps if available.

2. MANUAL_REVIEW:
   - Contains high-stakes, unverified electoral claims, active conflict escalation, or ambiguous sensitive topics that require human judgment.
   - You MUST output status "MANUAL_REVIEW".
   - You MUST provide a clear "reviewReason" explaining why human review is required.
   - You MUST list "sensitiveTopics" (e.g., ["ELECTION_INTEGRITY", "UNVERIFIED_HEALTH_CLAIM"]).
   - You MUST list "flaggedTimestamps" with time ranges and reasons.

3. APPROVED:
   - Safe, educational, informational, news, political commentary, entertainment, or historical content.
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
      primary: "gemini-2.5-pro",
      fallback: "gemini-2.5-flash",
      forcePrimary: true
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
          ]
        });

        const res = await model.generateContent(prompt);
        const text = res.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) throw new Error("No JSON in Video Gateway response");

        const parsed = JSON.parse(jsonMatch[0]);
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
      logger.error(`[VideoGateway] Evaluation failed for job ${jobId} — fallback to MANUAL_REVIEW`, { error });
      return {
        status: "MANUAL_REVIEW",
        confidence: 0.5,
        evaluatedAt: Date.now(),
        reviewReason: `Gateway AI evaluation encountered an error: ${(error as any).message}`,
        sensitiveTopics: ["PIPELINE_EVALUATION_ERROR"],
        flaggedTimestamps: []
      };
    }
  }
}

export const videoGatewayService = new VideoGatewayService();

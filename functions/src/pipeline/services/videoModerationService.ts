/**
 * 🛡️ VIDEO CONTENT MODERATION SERVICE (v2.0 — ZERO-FFmpeg)
 *
 * Gemini-powered video/audio analysis for Community Guidelines enforcement.
 * Sends video GCS URI directly to Gemini — no download, no FFmpeg, no re-upload.
 *
 * ✅ LOW-LATENCY DESIGN (v2.0):
 *   - Direct GCS URI → Gemini (zero intermediate steps)
 *   - Gemini 2.5 Flash (cheapest multimodal model)
 *   - 45s timeout with fail-safe
 *
 * ✅ INDUSTRY STANDARDS:
 *   - Structured JSON output with Zod validation
 *   - Category-level violation tagging
 *   - Automatic summary generation for approved content
 *   - Timeout protection with graceful degradation
 */

import { VertexAI } from "@google-cloud/vertexai";
import { z } from "zod";
import { PIPELINE_CONFIG } from "../config";

// ─── Response Schema ─────────────────────────────────────────────────────────

const VideoModerationResponseSchema = z.object({
  approved: z.boolean(),
  violationReason: z.string().default(""),
  violationCategories: z.array(z.string()).default([]),
  confidenceScore: z.number().min(0).max(1).default(0.5),
  summary: z.string(),
});

export interface VideoModerationResult {
  approved: boolean;
  violationReason: string;
  violationCategories: string[];
  confidenceScore: number;
  summary: string;
  processingTimeMs: number;
}

// ─── Community Guidelines Prompt ─────────────────────────────────────────────

const MODERATION_SYSTEM_PROMPT = `You are TruthWorld's professional video content moderation agent.
You are analyzing a user-uploaded video file.
Focus primarily on the AUDIO TRACK and any spoken content. If visible text or visual elements are apparent, factor those in as well.
Your task is to determine whether this content complies with our Community Guidelines.

## Community Guidelines — REJECT if any of the following are present:

1. **Hate Speech & Harassment**: Slurs, targeted abuse, dehumanization, or incitement against individuals or groups based on race, ethnicity, religion, gender, sexual orientation, disability, or nationality.

2. **Self-Harm & Suicide**: Content that promotes, instructs, or encourages self-harm, suicide, eating disorders, or dangerous body modification.

3. **Extreme Violence & Gore**: Gratuitous descriptions of violence, torture, graphic harm, or glorification of real-world violence. (Note: Educational/historical discussion with appropriate context is allowed.)

4. **Sexually Explicit Content**: Pornographic audio, explicit sexual descriptions, or content designed to sexually arouse. (Note: Clinical/educational sexual health content is allowed.)

5. **Promotion of Illegal Activities**: Instructions for creating weapons, drugs, or explosives; promotion of human trafficking, child exploitation, or terrorism.

6. **Real-Money Gambling & Betting**: Promotion of poker, sports betting, casino games, lotteries, or any games involving real-money wagering.

7. **Violent/Crime-Themed Games**: Content primarily featuring or promoting violent/crime games such as Free Fire, PUBG, GTA/Grand Theft Auto, Call of Duty, or similar. (Note: Clean/educational gaming like Minecraft, Chess, Tetris, or general family-friendly gaming is allowed.)

8. **Intense Romantic/Lustful Content**: Content with heavy romantic focus, dating/hookup themes, physical intimacy descriptions, or suggestive behavior designed to invoke physical attraction. (Note: Healthy marriage content, wedding vows, light affection appropriate for general public is allowed.)

9. **Misinformation & Dangerous Claims**: Deliberate spreading of dangerous health misinformation (e.g., "drink bleach to cure disease"), conspiracy theories that could cause real-world harm, or denial of well-documented atrocities.

## APPROVE if:
- The content is educational, informational, entertainment, or creative
- The content discusses sensitive topics in a responsible, journalistic, or educational manner
- The content is suitable for a general audience (13+)

## Output Format

You MUST return a JSON object matching this exact schema:
{
  "approved": boolean,
  "violationReason": "Clear explanation if rejected, empty string if approved",
  "violationCategories": ["category1", "category2"],
  "confidenceScore": 0.0 to 1.0 (how confident you are in your decision),
  "summary": "Concise 2-3 sentence summary of the video content for users to read"
}

Valid violation categories: "hate_speech", "self_harm", "violence", "sexual_content", "illegal_activity", "gambling", "violent_games", "romantic_content", "misinformation"

Be fair and balanced. Do NOT reject content simply because it discusses controversial topics — only reject if it actively promotes, glorifies, or instructs harmful behavior.`;

// ─── Service Implementation ──────────────────────────────────────────────────

export class VideoModerationService {
  private readonly vertexAI: VertexAI;

  constructor() {
    this.vertexAI = new VertexAI({
      project: "truthworld-1",
      location: "asia-south1",
    });
  }

  /**
   * Moderate a video by analyzing its content via GCS URI.
   *
   * v2.0: Accepts video files directly — Gemini reads from GCS natively.
   * No download, no FFmpeg, no re-upload needed.
   *
   * @param gcsUri - GCS URI of the video or audio file (gs://bucket/path)
   * @param mimeType - MIME type of the file (e.g., "video/mp4", "audio/mpeg")
   * @returns Moderation result with approve/reject decision
   */
  async moderate(gcsUri: string, mimeType: string = "video/mp4"): Promise<VideoModerationResult> {
    const t0 = Date.now();
    const MAX_RETRIES = 4;
    const BACKOFF_BASE_MS = 2000;

    let lastError: any = null;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const model = this.vertexAI.getGenerativeModel({
          model: PIPELINE_CONFIG.GEMINI_MODELS.synthesis || "gemini-2.5-flash",
          systemInstruction: MODERATION_SYSTEM_PROMPT,
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1, // Low temperature for consistent moderation decisions
          },
        });

        // Send file via GCS URI — Vertex AI reads from GCS directly (zero-copy)
        const result = await Promise.race([
          model.generateContent({
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
                    text: "Analyze this video content (focus on audio/speech) and determine if it complies with our Community Guidelines. Return your moderation decision as JSON.",
                  },
                ],
              },
            ],
          }),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error("MODERATION_TIMEOUT")), 45000)
          ),
        ]);

        const responseText =
          result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

        // Parse and validate response
        let parsedObj: any;
        try {
          parsedObj = JSON.parse(responseText);
        } catch {
          console.error("[VideoModeration] Failed to parse JSON response:", responseText.substring(0, 200));
          throw new Error("Moderation response was not valid JSON.");
        }

        const parsed = VideoModerationResponseSchema.safeParse(parsedObj);
        if (!parsed.success) {
          console.warn("[VideoModeration] Schema validation failed:", parsed.error.format());
          throw new Error("Moderation response schema mismatch.");
        }

        const processingTimeMs = Date.now() - t0;
        console.log("[VideoModeration] Completed", {
          approved: parsed.data.approved,
          confidence: parsed.data.confidenceScore,
          categories: parsed.data.violationCategories,
          durationMs: processingTimeMs,
        });

        return {
          approved: parsed.data.approved,
          violationReason: parsed.data.violationReason,
          violationCategories: parsed.data.violationCategories,
          confidenceScore: parsed.data.confidenceScore,
          summary: parsed.data.summary || "Summary unavailable.",
          processingTimeMs,
        };
      } catch (error) {
        lastError = error;
        const errorMsg = error instanceof Error ? error.message : String(error);
        console.error(`[VideoModeration] Attempt ${attempt + 1}/${MAX_RETRIES} failed:`, errorMsg);

        // Timeout gets a softer fail — allow manual review
        if (errorMsg === "MODERATION_TIMEOUT") {
          const processingTimeMs = Date.now() - t0;
          return {
            approved: false,
            violationReason: "Moderation timed out — queued for manual review.",
            violationCategories: ["timeout"],
            confidenceScore: 0,
            summary: "Video is pending moderation review.",
            processingTimeMs,
          };
        }

        // Check if error is rate limit (429 / resource exhausted)
        const isRateLimit = errorMsg.includes("429") ||
                            errorMsg.toLowerCase().includes("too many requests") ||
                            errorMsg.toLowerCase().includes("resource exhausted") ||
                            errorMsg.toLowerCase().includes("resource_exhausted");

        if (isRateLimit && attempt < MAX_RETRIES - 1) {
          const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
          console.log(`[VideoModeration] Rate limit hit. Retrying in ${delayMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        } else {
          // Throw the error so the trigger function catches it and flags it as a system error/retry
          throw error;
        }
      }
    }

    throw lastError || new Error("Moderation failed after maximum retries.");
  }
}

export const videoModerationService = new VideoModerationService();

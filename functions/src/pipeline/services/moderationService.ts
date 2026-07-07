import { VertexAI } from "@google-cloud/vertexai";
import { logger } from "../utils/logger";
import { z } from "zod";
import { PIPELINE_CONFIG } from "../config";

const ModerationResponseSchema = z.object({
  approved: z.boolean(),
  violationReason: z.string().optional().default(""),
  summary: z.string(),
});

export interface ModerationResult {
  approved: boolean;
  violationReason: string;
  summary: string;
}

/**
 * @deprecated Use `FactExtractionService.detectDomainAndStance` instead.
 * 
 * Moderation has been merged into the discovery phase of the credibility engine (06-credibility.ts)
 * to save cost and eliminate duplicate LLM calls. This service is kept solely for backward compatibility,
 * admin CLI tools, or external endpoints.
 */
export class ModerationService {
  private readonly genAI: VertexAI;

  constructor(apiKey: string) {
    this.genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
  }

  async checkAndSummarize(text: string): Promise<ModerationResult> {
    const t0 = Date.now();
    
    // Truncate to avoid excessive token usage if transcript is extremely long (max 80000 chars, ~100 mins of speech)
    const maxLength = 80000;
    const truncatedText = text.length > maxLength
      ? text.substring(0, maxLength) + "\n... [truncated for moderation analysis]"
      : text;

    const prompt = `TRANSCRIPT CONTENT:\n${truncatedText}`;

    try {
      const model = this.genAI.getGenerativeModel({
        model: PIPELINE_CONFIG.GEMINI_MODELS.synthesis || "gemini-2.5-flash",
        systemInstruction: `You are a professional video content moderation and summarization agent.
Analyze the provided transcript of a video.
Your task is two-fold:
1. Community Guidelines Verification: Check if the text violates platform community guidelines. Specifically, flag any content containing:
   - Hate speech or harassment
   - Self-harm or suicide encouragement
   - Extreme violence, gore, or graphic depictions of harm
   - Sexually explicit content or pornography
   - Promotion of illegal acts or dangerous activities
   - Real-money gaming, gambling, betting, or games involving money (e.g., Poker)
   - Violent/crime-themed games (e.g., Free Fire, PUBG, GTA/Grand Theft Auto)
   - Intense romantic focus, dating/hookup themes, physical intimacy, or suggestive/lustful behavior designed to invoke physical attraction. (Note: Healthy marriage and wedding content, including moderate expressions of romance like holding hands, wedding vows, light embraces, or gentle affection appropriate for general public spaces, are fully allowed.)
   (Note: Clean/wholesome/educational gaming like Minecraft, Chess, Tetris, or general family-friendly gaming are fully allowed.)
   If any guidelines are violated, set "approved" to false and provide a clear, concise "violationReason" explaining why (e.g. "Contains self-harm encouragement"). Otherwise, set "approved" to true.

2. Transcript Summarization: Generate a concise, high-quality summary of the video transcript for the users to read. The summary should be a faithful representation of the key arguments and information covered in the video, written in a neutral, informative tone.

You must return a JSON object matching this schema:
{
  "approved": boolean,
  "violationReason": "Reason if approved is false, otherwise empty string",
  "summary": "AI generated summary"
}`,
        generationConfig: {
          responseMimeType: "application/json",
        },
      });

      // Set timeout for 15 seconds
      const result = await Promise.race([
        model.generateContent(prompt),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("MODERATION_TIMEOUT")), 15000)
        ),
      ]);

      const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const parsedObj = JSON.parse(responseText);

      const parsed = ModerationResponseSchema.safeParse(parsedObj);
      if (!parsed.success) {
        logger.warn("[ModerationService] Schema validation failed", { errors: parsed.error.format() });
        return this.fallbackResult("Moderation response format was invalid.");
      }

      const duration = Date.now() - t0;
      logger.info("[ModerationService] Completed check", {
        approved: parsed.data.approved,
        durationMs: duration,
      });

      return {
        approved: parsed.data.approved,
        violationReason: parsed.data.violationReason ?? "",
        summary: parsed.data.summary || "Summary unavailable.",
      };

    } catch (error) {
      logger.error("[ModerationService] Critical error during moderation", { error: String(error) });
      return this.fallbackResult("Moderation system failed to process the request.");
    }
  }

  private fallbackResult(reason: string): ModerationResult {
    return {
      approved: false, // Fail safe on system failure
      violationReason: `System Fallback: ${reason}`,
      summary: "Video is undergoing moderation.",
    };
  }
}

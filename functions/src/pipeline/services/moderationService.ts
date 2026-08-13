import type { VertexAI } from "@google-cloud/vertexai";
import { logger } from "../utils/logger";
import { z } from "zod";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";

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
  private _genAI?: VertexAI;

  private get genAI(): VertexAI {
    if (!this._genAI) {
      this._genAI = getVertexAI();
    }
    return this._genAI;
  }

  constructor(apiKey?: string) {}

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

1. **Family-Friendly Delivery Check**:
   TruthWorld is an OPEN DEBATE PLATFORM. We VERIFY claims through our Credibility Engine — we do NOT censor content.
   
   Channels can upload debates, controversial opinions, lies, conspiracy theories, glorification of historical figures, political extremism — ANY topic is allowed. The Credibility Engine fact-checks all claims and shows sources to viewers.
   
   Your ONLY job is to ensure the DELIVERY is family-friendly. REJECT ONLY for HOW it is said, NOT for WHAT is said:
   - Profanity, vulgar language, slurs, or explicit curse words — NOT family-friendly delivery. THE TEST: Would it be bleeped on family TV? If yes → reject. Strong insults like "you eat like a pig", "they are idiots", "he is a liar" are ALLOWED (rude but clean). Actual curse words (f-word, s-word, MC/BC) and casteist/racial/religious slurs are REJECTED.
   - Sexually explicit content (pornographic material designed to arouse)
   - Graphic visual violence/gore for entertainment (fight compilations, execution videos)
   - Intense romantic/lustful content designed to arouse (hookup promotion, explicit intimacy)
   - Real-money gambling PROMOTION only (referral codes, "sign up and play" — NOT discussion about gambling)
   - Step-by-step dangerous manufacturing instructions (weapons, drugs, explosives — NOT discussion about these topics)
   - Kill compilations glorifying in-game violence

   DO NOT REJECT for: misinformation, lies, conspiracy theories, controversial opinions, glorification of historical figures, political extremism, hate speech IDEAS expressed in clean language, religious debates, or any debate topic — the Credibility Engine handles ALL of these.

   Example: "Hitler had good economic policies" = APPROVE (controversial opinion, clean delivery, Credibility Engine fact-checks).
   Example: "F*** those [slur], they should all die" = REJECT (profanity, slurs — not family-friendly delivery).
   Example: "Download Rush app! Use code RUSH100 for bonus!" = REJECT (gambling promotion).

   If rejected, set "approved" to false and provide a "violationReason" describing the DELIVERY violation (not the topic). Otherwise, set "approved" to true.

2. **Transcript Summarization**: Generate a concise, high-quality summary of the video transcript for users to read. The summary should be a faithful representation of the key arguments and information covered in the video, written in a neutral, informative tone.

You must return a JSON object matching this schema:
{
  "approved": boolean,
  "violationReason": "Delivery violation reason if rejected (describe HOW not WHAT), otherwise empty string",
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

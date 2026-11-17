/**
 * ⚡ FAST MULTIMODAL TRIAGE & OCR SERVICE (v1.0)
 *
 * Ultra-low latency pipeline stage that analyzes video files directly from GCS
 * using Gemini 3.5 Flash Lite multimodal vision + audio.
 *
 * Extracts:
 * 1. On-screen OCR text (news tickers, chyrons, slide bullet points, infographics)
 * 2. Primary spoken factual claims
 * 3. Rapid cross-reference with Tier-0 authoritative knowledge
 *
 * Produces an instantaneous Provisional Trust Score in < 45-60 seconds,
 * updating Firestore immediately so users never see a "blank" fact-check slate.
 */

import type { VertexAI } from "../utils/ai-client";
import * as admin from "firebase-admin";
import { z } from "zod";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { logger } from "../utils/logger";
import { tier0KnowledgeService } from "./tier0Knowledge";

const db = () => admin.firestore();

// @ts-ignore TS6133 - Used on lines 182-183 inside nested async scope
const SENSATIONAL_CLICKBAIT_REGEX =
  /\b(cure for|secret cure|miracle (cure|drug|food|herb|supplement)|they don't want you to know|what they hid|100% proven|hoax exposed|collapse imminent|guaranteed returns|get rich quick|conspiracy exposed|banned from tv|shocking truth|shocking discovery)\b/i;

const FastTriageClaimSchema = z.object({
  text: z.string(),
  sourceMedium: z.enum(["speech", "ocr_on_screen", "hybrid"]).default("speech"),
  verdict: z.string().default("unverified"),
  confidence: z.number().min(0).max(1).default(0.7),
  reasoning: z.string().default(""),
});

const FastTriageResponseSchema = z.object({
  provisionalScore: z.number().min(0).max(100),
  provisionalLabel: z.string(),
  provisionalViewerNote: z.string(),
  ocrExtractedText: z.array(z.string()).default([]),
  claims: z.array(FastTriageClaimSchema).default([]),
  detectedDomain: z.string().default("General"),
  isClickbaitOrSensational: z.boolean().default(false),
  titleDiscrepancyReason: z.string().optional().default(""),
});

export type FastTriageResult = z.infer<typeof FastTriageResponseSchema> & {
  processingTimeMs: number;
};

export class FastMultimodalTriageService {
  private _vertexAI?: VertexAI;

  private get vertexAI(): VertexAI {
    if (!this._vertexAI) {
      this._vertexAI = getVertexAI();
    }
    return this._vertexAI;
  }

  /**
   * Performs instant multimodal triage on a newly uploaded/published video.
   */
  async triageVideo(
    videoId: string,
    videoUrl: string,
    videoTitle?: string
  ): Promise<FastTriageResult | null> {
    const t0 = Date.now();
    logger.info("[FastTriage] Starting multimodal OCR & audio fast-check", {
      videoId,
      videoTitle,
    });

    const gcsUri = this.normalizeToGcsUri(videoUrl);
    if (!gcsUri) {
      logger.warn("[FastTriage] Video URL cannot be mapped to GCS URI, skipping fast triage", {
        videoId,
        videoUrl,
      });
      return null;
    }

    const mimeType = videoUrl.endsWith(".webm") ? "video/webm" : "video/mp4";

    const cleanTitle = (videoTitle || "Untitled").replace(/["\r\n]/g, " ").trim();
    const prompt = `You are TruthWorld's Fast-Triage Multimodal Credibility Engine.
Analyze this video directly using both the AUDIO TRACK (speech) and VISUAL FRAMES (on-screen OCR).

VIDEO METADATA:
Title: "${cleanTitle}"

YOUR TASKS:
1. TITLE & CLICKBAIT SCRUTINY: Compare the video title to the actual content and on-screen claims.
   - Detect if the title is sensational clickbait, alarmist, deceptive, making unsubstantiated medical/financial promises, or exhibiting title-content discrepancy.
   - Set "isClickbaitOrSensational": true/false and provide "titleDiscrepancyReason" if applicable.
2. ON-SCREEN OCR: Read any prominent text visible in the video (news chyrons, ticker tapes, presentation slides, charts, titles).
3. SPEECH ANALYSIS: Identify the top 3 to 5 core empirical factual claims made by the speaker(s).
4. RAPID VERIFICATION: Evaluate each claim's veracity based on established consensus facts.
   Allowed verdicts: "verified_true", "mostly_true", "false_claim", "misleading", "disputed", "opinion", "satire", "unverified".
5. PROVISIONAL TRIAGE CLASSIFICATION: This is a fast preliminary triage prior to deep multi-source Google Search grounding.
   - NEVER label any video "HIGH INTEGRITY" or assign a score > 75 during preliminary triage.
   - For clean, low-risk, verifiable content with 0 false/misleading claims: label "PRELIMINARY SCAN" (score 65-75).
   - For clickbait, sensationalism, or content with disputed/unverified claims: label "PRELIMINARY - SENSATIONAL / DISPUTED" or "PRELIMINARY - NEEDS CONTEXT" (score 30-50).
6. VIEWER ADVISORY: Write a crisp 1-2 sentence plain-language note explicitly stating this is a preliminary scan awaiting full multi-source grounding.

Return ONLY a valid JSON object matching this schema:
{
  "provisionalScore": 70,
  "provisionalLabel": "PRELIMINARY SCAN",
  "provisionalViewerNote": "Preliminary automated scan. Complete multi-source verification with Google Search grounding is currently processing in the background.",
  "ocrExtractedText": ["Ticker: Dow Jones drops 200 points", "Banner: Press Conference 2026"],
  "claims": [
    {
      "text": "Exact claim statement",
      "sourceMedium": "speech | ocr_on_screen | hybrid",
      "verdict": "verified_true | mostly_true | false_claim | misleading | disputed | opinion | satire | unverified",
      "confidence": 0.85,
      "reasoning": "Very simple 1-sentence explanation a 10-year-old can understand (never say 'this claim' or 'from internal data')"
    }
  ],
  "detectedDomain": "Science | Politics | Tech | Health | Finance | General",
  "isClickbaitOrSensational": false,
  "titleDiscrepancyReason": ""
}`;

    try {
      const model = this.vertexAI.getGenerativeModel({
        model: "gemini-3.5-flash-lite",
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.1,
        },
      });

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
                { text: prompt },
              ],
            },
          ],
        }),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("FAST_TRIAGE_TIMEOUT")), 45_000)
        ),
      ]);

      const candidate = result.response?.candidates?.[0] || result.candidates?.[0];
      const rawText =
        extractCandidateText(candidate) ||
        (result as any).text ||
        (result as any).response?.text ||
        candidate?.content?.parts?.[0]?.text ||
        "{}";
      const parsedObj = JSON.parse(rawText);
      const validated = FastTriageResponseSchema.parse(parsedObj);

      // Rapidly check Tier-0 knowledge for instant consensus corroboration
      if (validated.claims.length > 0) {
        try {
          const tier0Inputs = validated.claims.map((c, i) => ({
            claimId: `claim_${i}`,
            text: c.text,
          }));
          const contexts = await tier0KnowledgeService.getBatchContext(tier0Inputs);
          for (let i = 0; i < validated.claims.length; i++) {
            const ctx = contexts.find(x => x.claimId === `claim_${i}`)?.context;
            if (ctx && ctx.length > 20) {
              const snippet = ctx.substring(0, 120).trim();
              validated.claims[i].reasoning = `${validated.claims[i].reasoning} Helpful background: ${snippet}`.trim();
            }
          }
        } catch (tier0Err: any) {
          logger.warn("[FastTriage] Tier-0 context lookup skipped", { error: tier0Err?.message });
        }
      }

      // Server-side Defense-in-Depth Guard: detect clickbait & sensationalism independently of LLM
      const hasTitlePattern = SENSATIONAL_CLICKBAIT_REGEX.test(cleanTitle);
      const hasOcrPattern = validated.ocrExtractedText.some(ocr => SENSATIONAL_CLICKBAIT_REGEX.test(ocr));
      const hasNegativeClaims = validated.claims.some(c =>
        ['false_claim', 'misleading', 'disputed'].includes(c.verdict)
      );
      const hasUnverifiedClaims = validated.claims.some(c =>
        ['unverified'].includes(c.verdict)
      );

      const isSensational = validated.isClickbaitOrSensational || hasTitlePattern || hasOcrPattern;

      // Enforce strict policy: preliminary triage CANNOT be stamped "HIGH INTEGRITY"
      if (isSensational || hasNegativeClaims) {
        validated.provisionalScore = Math.min(validated.provisionalScore, 45);
        validated.provisionalLabel = hasNegativeClaims 
          ? "PRELIMINARY - DISPUTED / UNGROUNDED" 
          : "PRELIMINARY - SENSATIONAL / CLICKBAIT";
        validated.isClickbaitOrSensational = true;
        if (!validated.provisionalViewerNote.toLowerCase().includes("preliminary")) {
          validated.provisionalViewerNote = "Preliminary scan detected sensational claims or ungrounded assertions. Awaiting comprehensive multi-source grounding.";
        }
      } else if (hasUnverifiedClaims) {
        validated.provisionalScore = Math.min(validated.provisionalScore, 60);
        validated.provisionalLabel = "PRELIMINARY - NEEDS CONTEXT";
      } else {
        // Clean baseline claims - capped at 75 max during provisional stage (never premature 100)
        validated.provisionalScore = Math.min(validated.provisionalScore, 75);
        validated.provisionalLabel = "PRELIMINARY SCAN";
      }

      // Ensure viewer note always clearly communicates provisional status
      if (!validated.provisionalViewerNote.toLowerCase().includes("preliminary") && !validated.provisionalViewerNote.toLowerCase().includes("processing")) {
        validated.provisionalViewerNote = `${validated.provisionalViewerNote} (Preliminary scan; full multi-source verification is in progress.)`;
      }

      const processingTimeMs = Date.now() - t0;
      logger.info("[FastTriage] Completed fast triage successfully", {
        videoId,
        score: validated.provisionalScore,
        label: validated.provisionalLabel,
        isSensational,
        claimsCount: validated.claims.length,
        ocrCount: validated.ocrExtractedText.length,
        processingTimeMs,
      });

      // Instantly write provisional data to Firestore video document
      await db().collection("videos").doc(videoId).set(
        {
          trustLabel: validated.provisionalLabel,
          isProvisional: true,
          provisionalScore: validated.provisionalScore,
          provisionalLabel: validated.provisionalLabel,
          provisionalViewerNote: validated.provisionalViewerNote,
          isClickbaitOrSensational: validated.isClickbaitOrSensational,
          ocrTickerText: validated.ocrExtractedText,
          provisionalClaims: validated.claims,
          credibilityStatus: "provisional_ready",
          provisionalAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        ...validated,
        processingTimeMs,
      };
    } catch (err: any) {
      logger.warn("[FastTriage] Fast triage failed or timed out (non-fatal, deep pipeline continues)", {
        videoId,
        error: err?.message || String(err),
      });
      return null;
    }
  }

  private normalizeToGcsUri(url: string): string | null {
    if (!url) return null;
    if (url.startsWith("gs://")) return url;

    // Handle Firebase Storage HTTP URLs:
    // https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media...
    const fbMatch = url.match(/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/);
    if (fbMatch) {
      const bucket = fbMatch[1];
      const encodedPath = fbMatch[2];
      const decodedPath = decodeURIComponent(encodedPath);
      return `gs://${bucket}/${decodedPath}`;
    }

    // Handle Google Cloud Storage URLs:
    // https://storage.googleapis.com/{bucket}/{path}
    const gcsMatch = url.match(/storage\.googleapis\.com\/([^/]+)\/(.+)/);
    if (gcsMatch) {
      const bucket = gcsMatch[1];
      const path = decodeURIComponent(gcsMatch[2]);
      return `gs://${bucket}/${path}`;
    }

    return null;
  }
}

export const fastMultimodalTriageService = new FastMultimodalTriageService();

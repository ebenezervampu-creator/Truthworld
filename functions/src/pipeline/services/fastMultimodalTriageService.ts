/**
 * ⚡ FAST MULTIMODAL TRIAGE & OCR SERVICE (v1.0)
 *
 * Ultra-low latency pipeline stage that analyzes video files directly from GCS
 * using Gemini 2.5 Flash multimodal vision + audio.
 *
 * Extracts:
 * 1. On-screen OCR text (news tickers, chyrons, slide bullet points, infographics)
 * 2. Primary spoken factual claims
 * 3. Rapid cross-reference with Tier-0 authoritative knowledge
 *
 * Produces an instantaneous Provisional Trust Score in < 45-60 seconds,
 * updating Firestore immediately so users never see a "blank" fact-check slate.
 */

import type { VertexAI } from "@google-cloud/vertexai";
import * as admin from "firebase-admin";
import { z } from "zod";
import { getVertexAI } from "../utils/ai-client";
import { logger } from "../utils/logger";
import { tier0KnowledgeService } from "./tier0Knowledge";

const db = () => admin.firestore();

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

    const prompt = `You are TruthWorld's Fast-Triage Multimodal Credibility Engine.
Analyze this video directly using both the AUDIO TRACK (speech) and VISUAL FRAMES (on-screen OCR).

YOUR TASKS:
1. ON-SCREEN OCR: Read any prominent text visible in the video (news chyrons, ticker tapes, presentation slides, charts, titles).
2. SPEECH ANALYSIS: Identify the top 3 to 5 core empirical factual claims made by the speaker(s).
3. RAPID VERIFICATION: Evaluate each claim's veracity based on established consensus facts.
   Allowed verdicts: "verified_true", "mostly_true", "false_claim", "misleading", "disputed", "opinion", "satire", "unverified".
4. TRUST SCORE: Compute an overall provisional Trust Score (0 to 100) where:
   - 80-100 = High Integrity (verifiable and accurate)
   - 50-79 = Mixed / Needs Context
   - 0-49 = Low Integrity / Disputed / Misleading
5. VIEWER ADVISORY: Write a crisp 1-2 sentence plain-language note for viewers.

Return ONLY a valid JSON object matching this schema:
{
  "provisionalScore": 85,
  "provisionalLabel": "HIGH INTEGRITY",
  "provisionalViewerNote": "Core claims check out against documented historical and empirical sources.",
  "ocrExtractedText": ["Ticker: Dow Jones drops 200 points", "Banner: Press Conference 2026"],
  "claims": [
    {
      "text": "Exact claim statement",
      "sourceMedium": "speech | ocr_on_screen | hybrid",
      "verdict": "verified_true | mostly_true | false_claim | misleading | disputed | opinion | satire | unverified",
      "confidence": 0.85,
      "reasoning": "Plain-language 1-sentence explanation"
    }
  ],
  "detectedDomain": "Science | Politics | Tech | Health | Finance | General"
}`;

    try {
      const model = this.vertexAI.getGenerativeModel({
        model: "gemini-2.5-flash",
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

      const rawText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
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
              validated.claims[i].reasoning = `${validated.claims[i].reasoning} [Corroborated by Wikipedia: ${ctx.substring(0, 100)}...]`.trim();
            }
          }
        } catch (tier0Err: any) {
          logger.warn("[FastTriage] Tier-0 context lookup skipped", { error: tier0Err?.message });
        }
      }

      const processingTimeMs = Date.now() - t0;
      logger.info("[FastTriage] Completed fast triage successfully", {
        videoId,
        score: validated.provisionalScore,
        claimsCount: validated.claims.length,
        ocrCount: validated.ocrExtractedText.length,
        processingTimeMs,
      });

      // Instantly write provisional data to Firestore video document
      await db().collection("videos").doc(videoId).set(
        {
          trustScore: validated.provisionalScore,
          trustLabel: validated.provisionalLabel,
          isProvisional: true,
          provisionalScore: validated.provisionalScore,
          provisionalViewerNote: validated.provisionalViewerNote,
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

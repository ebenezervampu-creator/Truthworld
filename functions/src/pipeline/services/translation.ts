/**
 * 🌍 TRANSLATION SERVICE — Google Cloud Translation v3 (Advanced)
 *
 * ✅ UPGRADED from v2 → v3:
 *   - Uses `TranslationServiceClient` (not `v2.Translate`)
 *   - Supports glossaries, batch processing, regional endpoints
 *   - Better enterprise quality controls for Indian + global languages
 *   - Location-aware routing (asia-south1 for India-first)
 *
 * ✅ FALLBACK: If v3 client fails to initialize, falls back to v2 Basic API
 */

import { v3, v2 } from "@google-cloud/translate";
import { VertexAI } from "@google-cloud/vertexai";
import { TranslationResult, TranslatedSegment, CreatorDNA } from "../types";
import { SpeakerProfile } from "./speaker-profiling";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || "truthworld-1";

/**
 * Preferred location for v3 requests.
 * "global" is safest default; can be overridden to "asia-south1" for data residency.
 */
const TRANSLATION_LOCATION = process.env.TRANSLATION_LOCATION || "global";

/** Max segments per v3 batch call (API limit is 128 content items per request) */
const V3_BATCH_SIZE = 100;

export class TranslationService {
  private v3Client: v3.TranslationServiceClient | null = null;
  private v2Client: v2.Translate | null = null;
  private gemini:   VertexAI | null = null;

  /** v3 parent path: projects/{project}/locations/{location} */
  private get parent(): string {
    return `projects/${projectId}/locations/${TRANSLATION_LOCATION}`;
  }

  constructor() {
    const key = PIPELINE_CONFIG.GOOGLE_TRANSLATION_API_KEY;

    try {
      // ── Primary: v3 Advanced client ────────────────────────────────────────
      if (key) {
        this.v3Client = new v3.TranslationServiceClient({ key });
      }
    } catch (err) {
      console.warn("[Translation] v3 client init failed — falling back to v2", err);
    }

    try {
      // ── Fallback: v2 Basic client ──────────────────────────────────────────
      if (key) {
        this.v2Client = new v2.Translate({ 
          projectId, 
          key 
        });
      }
    } catch (err) {
      console.warn("[Translation] v2 client init failed", err);
    }

    // ── Premium: Gemini 2.0 Flash ───────────────────────────────────────────
    this.gemini = getVertexAI();
  }

  // ─── Single text translation ───────────────────────────────────────────────

  async translateText(
    text: string,
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<string> {
    // ── v3 path ────────────────────────────────────────────────────────────
    if (this.v3Client) {
      try {
        const [response] = await this.v3Client.translateText({
          parent: this.parent,
          contents: [text],
          mimeType: "text/plain",
          sourceLanguageCode: sourceLanguage,
          targetLanguageCode: targetLanguage,
        });

        const translated = response.translations?.[0]?.translatedText;
        if (translated) return translated;
      } catch (error) {
        console.error("[Translation] v3 translateText error — falling back to v2:", error);
      }
    }

    // ── v2 fallback ────────────────────────────────────────────────────────
    if (this.v2Client) {
      const [translations] = await this.v2Client.translate(text, {
        from: sourceLanguage,
        to: targetLanguage,
      });
      return Array.isArray(translations) ? translations[0] : translations;
    }

    throw new Error("No translation client available");
  }

  // ─── Batch segment translation ─────────────────────────────────────────────

  async translateSegments(
    jobId: string,
    segments: Array<{ start: number; end: number; text: string; speaker?: string; isHook?: boolean }>,
    sourceLanguage: string,
    targetLanguage: string,
    options?: { 
      model?: 'standard' | 'premium' | 'dynamic'; 
      tone?: 'casual' | 'formal'; 
      localeStyle?: 'neutral' | 'hinglish' | 'hinglish_urban' | 'hinglish_professional' | 'slang';
      targetPlatform?: 'youtube' | 'reels' | 'shorts' | 'linkedin' | 'tiktok';
      creatorDNA?: CreatorDNA;
      enableABHooks?: boolean;
      speakerProfiles?: SpeakerProfile[] 
    }
  ): Promise<TranslationResult> {
    try {
      const texts = segments.map((s) => s.text);
      let translatedTexts: string[] = new Array(texts.length);
      let confidenceScores: number[] = new Array(texts.length).fill(0.95);

      const requestedModel = options?.model || 'standard';

      // ── Lane Routing Logic ───────────────────────────────────────────────
      const premiumIndices: number[] = [];
      const standardIndices: number[] = [];

      if (requestedModel === 'dynamic') {
        texts.forEach((text, i) => {
          // Hook Priority: Always use Gemini for the first 10s (viral impact)
          if (segments[i].isHook || this.shouldEscalateToPremium(text)) {
            premiumIndices.push(i);
          } else {
            standardIndices.push(i);
          }
        });
        console.log(`[Translation] Dynamic routing: ${premiumIndices.length} premium (including hooks), ${standardIndices.length} standard`);
      } else if (requestedModel === 'premium') {
        texts.forEach((_, i) => premiumIndices.push(i));
      } else {
        texts.forEach((_, i) => standardIndices.push(i));
      }

      // ── Execution: Standard Lane (Google) ────────────────────────────────
      if (standardIndices.length > 0) {
        const standardTexts = standardIndices.map(i => texts[i]);
        const standardTranslated = await this.batchTranslateStandard(standardTexts, sourceLanguage, targetLanguage);
        standardIndices.forEach((idx, i) => {
          translatedTexts[idx] = standardTranslated[i];
          confidenceScores[idx] = 0.90;
        });
      }

      // ── Execution: Premium Lane (Gemini) ─────────────────────────────────
      if (premiumIndices.length > 0 && this.gemini) {
        try {
          const premiumSegments = premiumIndices.map(i => ({
            text: texts[i],
            speaker: segments[i].speaker,
            isHook: segments[i].isHook
          }));
          const premiumResult = await this.translatePremiumBatch(
            premiumSegments.map(s => s.text), 
            sourceLanguage, 
            targetLanguage, 
            options?.tone || 'formal',
            options?.localeStyle || 'neutral',
            options?.targetPlatform || 'youtube',
            options?.creatorDNA,
            options?.enableABHooks,
            options?.speakerProfiles,
            premiumSegments.map(s => s.speaker),
            premiumSegments.map(s => s.isHook)
          );
          premiumIndices.forEach((idx, i) => {
            translatedTexts[idx] = premiumResult.translations[i];
            confidenceScores[idx] = premiumResult.confidences[i];
          });
        } catch (error) {
          console.error("[Translation] Premium lane failed — falling back to standard:", error);
          const remainingTexts = premiumIndices.map(i => texts[i]);
          const fallbackTranslated = await this.batchTranslateStandard(remainingTexts, sourceLanguage, targetLanguage);
          premiumIndices.forEach((idx, i) => {
            translatedTexts[idx] = fallbackTranslated[i];
          });
        }
      }

      // ✅ Cost tracking: record actual character count translated
      const totalChars = texts.reduce((sum, t) => sum + t.length, 0);
      costEngine.recordTranslationCost(jobId, "__batch__", totalChars).catch(() => {});

      const translatedSegments: TranslatedSegment[] = segments.map(
        (segment, index) => ({
          original: segment.text,
          translated: translatedTexts[index] || segment.text,
          start: segment.start,
          end: segment.end,
          confidence: confidenceScores?.[index],
        })
      );

      return {
        jobId,
        sourceLanguage,
        targetLanguage,
        segments: translatedSegments,
      };
    } catch (error) {
      console.error(`[Translation] translateSegments error for job ${jobId}:`, error);
      throw error;
    }
  }

  // ─── Language detection ────────────────────────────────────────────────────

  async detectLanguage(text: string): Promise<string> {
    // ── v3 path ────────────────────────────────────────────────────────────
    if (this.v3Client) {
      try {
        const [response] = await this.v3Client.detectLanguage({
          parent: this.parent,
          content: text,
          mimeType: "text/plain",
        });
        const best = response.languages?.[0];
        if (best?.languageCode) return best.languageCode;
      } catch (error) {
        console.error("[Translation] v3 detectLanguage error — falling back:", error);
      }
    }

    // ── v2 fallback ────────────────────────────────────────────────────────
    if (this.v2Client) {
      try {
        const [detections] = await this.v2Client.detect(text);
        const detection = Array.isArray(detections) ? detections[0] : detections;
        return detection.language || "en";
      } catch (error) {
        console.error("[Translation] v2 detectLanguage error:", error);
      }
    }

    return "en"; // fallback
  }

  // ─── Batch language detection ──────────────────────────────────────────────

  async detectLanguages(texts: string[]): Promise<string[]> {
    // v3 doesn't have a batch detect — use v2 or iterate
    if (this.v2Client) {
      try {
        const [detections] = await this.v2Client.detect(texts);
        return detections.map((d: any) => d.language || "en");
      } catch (error) {
        console.error("[Translation] Batch language detection error:", error);
      }
    }

    // Fallback: iterate with v3
    if (this.v3Client) {
      const results: string[] = [];
      for (const text of texts) {
        results.push(await this.detectLanguage(text));
      }
      return results;
    }

    return texts.map(() => "en"); // fallback
  }

  // ─── Private: v3 batched translation ───────────────────────────────────────

  /**
   * Translate texts in batches via v3 API.
   * The v3 `translateText` accepts up to 128 content items per call.
   * We chunk into V3_BATCH_SIZE for safety.
   */
  private async batchTranslateV3(
    texts: string[],
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<string[]> {
    const allTranslations: string[] = [];

    for (let i = 0; i < texts.length; i += V3_BATCH_SIZE) {
      const batch = texts.slice(i, i + V3_BATCH_SIZE);

      const [response] = await this.v3Client!.translateText({
        parent: this.parent,
        contents: batch,
        mimeType: "text/plain",
        sourceLanguageCode: sourceLanguage,
        targetLanguageCode: targetLanguage,
      });

      const translations = (response.translations ?? []).map(
        (t) => t.translatedText ?? ""
      );

      allTranslations.push(...translations);
    }

    return allTranslations;
  }

  /**
   * Internal helper for batching standard translations with fallback logic.
   */
  private async batchTranslateStandard(texts: string[], source: string, target: string): Promise<string[]> {
    if (this.v3Client) {
      try {
        return await this.batchTranslateV3(texts, source, target);
      } catch (err) {
        console.warn("[Translation] v3 batch fallback to v2", err);
      }
    }
    if (this.v2Client) {
      const [translations] = await this.v2Client.translate(texts, { from: source, to: target });
      return Array.isArray(translations) ? translations : [translations];
    }
    throw new Error("Standard translation engine unavailable");
  }

  /**
   * Complexity Scouter: Determines if a segment requires premium Gemini processing.
   */
  private shouldEscalateToPremium(text: string): boolean {
    const regexPatterns = [
      /\b(?:Anthropic|Claude|Figma|Adobe|Nvidia|OpenAI|Google|Apple|Microsoft)\b/i, // Brands
      /\b(?:launched|announced|released|revealed|exclusive|breaking)\b/i,            // High-value keywords
      /[!?.]{2,}/,                                                                   // High emotion / punctuation
      /\b(?:UI|UX|API|SDK|LLM|GPU|AI|Interface)\b/i,                                 // Tech terms
      /\w{20,}/,                                                                     // Very long words (likely tech/medical)
    ];
    
    const isLong = text.length > 150;
    const matchesRegex = regexPatterns.some(p => p.test(text));

    return isLong || matchesRegex;
  }

  // ─── Private: Premium Gemini translation ───────────────────────────────────

  private async translatePremiumBatch(
    texts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    tone: 'casual' | 'formal',
    localeStyle: string,
    targetPlatform: string,
    creatorDNA?: CreatorDNA,
    enableABHooks?: boolean,
    speakerProfiles?: SpeakerProfile[],
    speakersInBatch?: (string | undefined)[],
    hooksInBatch?: (boolean | undefined)[]
  ): Promise<{ translations: string[], confidences: number[], variants?: any[] }> {
    const model = this.gemini!.getGenerativeModel({ model: PIPELINE_CONFIG.GEMINI_MODELS?.translation || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash" });

    // We translate in chunks to avoid prompt limits
    const CHUNK_SIZE = 20;
    const allTranslations: string[] = [];
    const allConfidences:  number[] = [];
    const allVariants:     any[]    = [];

    for (let i = 0; i < texts.length; i += CHUNK_SIZE) {
      const chunk = texts.slice(i, i + CHUNK_SIZE);
      const batchSpeakers = speakersInBatch?.slice(i, i + CHUNK_SIZE) || [];
      const batchHooks = hooksInBatch?.slice(i, i + CHUNK_SIZE) || [];
      
      // Inject speaker persona context if available
      let personaContext = "";
      if (speakerProfiles && batchSpeakers.length > 0) {
        const uniqueSpeakers = Array.from(new Set(batchSpeakers.filter(s => !!s)));
        const relevantProfiles = speakerProfiles.filter(p => uniqueSpeakers.includes(p.speakerId));
        if (relevantProfiles.length > 0) {
          personaContext = "\nSpeaker Personas for this batch:\n" + 
            relevantProfiles.map(p => `- ${p.speakerId}: ${p.ageTone} ${p.energy} energy, ${p.style} style`).join("\n");
        }
      }

      // Inject Creator DNA if available
      let dnaContext = "";
      if (creatorDNA) {
        dnaContext = `\nCreator DNA Style Memory:\n- Overall Vibe: ${creatorDNA.vibe}\n- Slang Tolerance: ${creatorDNA.slangTolerance}\n- Vocab Preference: ${creatorDNA.vocabPreference}`;
        if (creatorDNA.customInstructions) dnaContext += `\n- Extra Instructions: ${creatorDNA.customInstructions}`;
      }

      const prompt = `Translate the following ${sourceLanguage} text segments to ${targetLanguage}.
Tone: ${tone}
Style Preference: ${localeStyle}
Target Platform: ${targetPlatform}${personaContext}${dnaContext}

Special Rules:
1. Preserve brand names and technical terms in English or proper transliteration (e.g. Anthropic, Claude Design, Figma, Adobe, UI).
2. Audience Adaptation: 
   - If Style Preference is 'hinglish', use natural code-switching.
   - If 'hinglish_urban', use Gen-Z slang and very casual Mumbai/Delhi urban Hinglish.
   - If 'hinglish_professional', use a sophisticated Bangalore/Corporate Hinglish (mix of English professional terms with formal Hindi structure).
3. Platform Optimization:
   - If Target Platform is 'reels' or 'shorts', keep hooks fast-paced, high emotion, and catchy.
   - If 'linkedin', ensure the first few segments sound authoritative and deliver a punchy insight.
4. A/B Hook Generation: If a segment is marked with [HOOK] below AND enableABHooks is true, you MUST return 3 variants in a "variants" object:
   - viral: High-energy, catchy, slang-friendly.
   - safe: Reliable, standard translation.
   - professional: Authoritative, formal.
5. Ensure natural flow and adapt the tone to the speaker's persona (e.g. if they are youthful/energetic, use more modern/vibrant phrasing).
6. Return ONLY a JSON object with:
   - translations: array of strings
   - confidences: array of numbers (0-1) representing localization quality
   - variants: array of objects (one per segment, use null if no variants generated)

Segments to translate:
${JSON.stringify(chunk.map((t, idx) => `${batchHooks[idx] ? "[HOOK] " : ""}${t}`), null, 2)}`;

      const result = await model.generateContent(prompt);
      const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      
      if (!jsonMatch) throw new Error("No JSON in premium translation response");
      const parsed = JSON.parse(jsonMatch[0]);

      allTranslations.push(...(parsed.translations || chunk));
      allConfidences.push(...(parsed.confidences || chunk.map(() => 0.95)));
      allVariants.push(...(parsed.variants || chunk.map(() => null)));
    }

    return { translations: allTranslations, confidences: allConfidences, variants: allVariants };
  }
}

export const translationService = new TranslationService();

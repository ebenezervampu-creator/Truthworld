/**
 * Loads what a dubbing quote needs from Firestore. Used by BOTH the quote endpoint (what the creator
 * sees) and the dubbing request (what the server charges), so the two always agree.
 *
 * Character pricing is switched on with DUBBING_CHARACTER_PRICING=true. Until then the server keeps
 * charging the minute price and only logs what the character price would have been ("shadow" mode),
 * so the app can be updated to show server quotes before any creator is charged differently.
 */
import * as admin from "firebase-admin";
import { quoteDubbing, transcriptCharacters, type DubbingQuote } from "./dubbing-pricing";

export function characterPricingEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return (env.DUBBING_CHARACTER_PRICING || "").toLowerCase() === "true";
}

export interface PricingTranscript {
  chars: number;
  /** Language AssemblyAI detected — used instead of a client-supplied source language. */
  language?: string;
}

/** First transcript found among the given ids (job id, then video id), or null. */
export async function loadTranscriptForPricing(ids: Array<string | undefined>): Promise<PricingTranscript | null> {
  const seen = new Set<string>();
  for (const id of ids) {
    if (!id || seen.has(id)) continue;
    seen.add(id);
    try {
      const snap = await admin.firestore().collection("transcripts").doc(id).get();
      if (!snap.exists) continue;
      const data = snap.data() || {};
      const chars = transcriptCharacters(data as any);
      if (chars > 0) {
        return { chars, language: typeof data.language === "string" ? data.language : undefined };
      }
    } catch {
      // Try the next id.
    }
  }
  return null;
}

/** Quote from the stored transcript, or null while the video is still being transcribed. */
export async function quoteFromTranscript(input: {
  transcriptIds: Array<string | undefined>;
  durationSec: number;
  fallbackSourceLanguage: string;
  targetLanguages: string[];
  discountPercent: number;
  normalizeLanguage?: (code: string) => string;
}): Promise<DubbingQuote | null> {
  const transcript = await loadTranscriptForPricing(input.transcriptIds);
  if (!transcript) return null;
  const norm = input.normalizeLanguage ?? ((c: string) => c);
  return quoteDubbing({
    durationSec: input.durationSec,
    sourceChars: transcript.chars,
    sourceLanguage: transcript.language ? norm(transcript.language) : input.fallbackSourceLanguage,
    targetLanguages: input.targetLanguages,
    discountPercent: input.discountPercent,
  });
}

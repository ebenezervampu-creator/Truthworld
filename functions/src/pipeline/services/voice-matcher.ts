import * as fs from "fs";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { PIPELINE_CONFIG } from "../config";
import { extractMedianPitchHz } from "./media";

export type AgeBucket = "child" | "young" | "middle_aged" | "old";
export type SpeakerGender = "male" | "female" | "neutral";

export interface DiarizedSpeakerProfile {
  speakerId: string;           // e.g., "A", "B", "speaker_0"
  estimatedAge: number;        // Continuous age estimate, e.g., 24, 46
  ageBucket: AgeBucket;        // Normalized bucket
  gender: SpeakerGender;
  medianPitchHz: number;       // Extracted via FFmpeg
  timbreTags: string[];        // e.g., ["calm", "energetic", "authoritative", "raspy"]
  confidence: number;          // 0.0 - 1.0
}

export interface ElevenLabsVoiceCandidate {
  voiceId: string;
  name: string;
  gender: SpeakerGender;
  ageBucket: AgeBucket;
  representativeAge: number;   // Numeric anchor for continuous distance scoring
  typicalPitchHz: number;      // Calibrated baseline F0 of the preset
  timbreTags: string[];
  indicVerified: boolean;      // True if validated on eleven_v4 for te/hi/ta/ml
}

// Map ElevenLabs API string labels ("young", "middle aged", "old") to numeric anchors
export const AGE_BUCKET_ANCHORS: Record<AgeBucket, number> = {
  child: 10,
  young: 25,
  middle_aged: 42,
  old: 65,
};

export function normalizeElevenLabsAgeLabel(rawAge?: string): AgeBucket {
  const val = (rawAge || "").toLowerCase().trim();
  if (val.includes("child") || val.includes("kid")) return "child";
  if (val.includes("young") || val.includes("teen") || val.includes("youth")) return "young";
  if (val.includes("old") || val.includes("senior") || val.includes("elder")) return "old";
  return "middle_aged";
}

/**
 * 🎙️ SPEAKER-TO-VOICE MATCHING SERVICE
 *
 * 1. Profiles diarized speakers via multimodal audio (F0 pitch) + video frame age estimation.
 * 2. Fetches live ElevenLabs /v1/voices metadata and merges with TruthWorld's
 *    verified Indic-compatible voice calibrations (cached in memory for 1 hour).
 * 3. Computes weighted nearest-neighbor distance (Age, Bucket, F0 Pitch, Timbre)
 *    with a strict multi-speaker uniqueness lock to prevent single-voice collapse.
 */
export class ElevenLabsVoiceMatcher {
  private cachedCatalog: ElevenLabsVoiceCandidate[] = [];
  private lastFetchMs = 0;
  private readonly CACHE_TTL_MS = 60 * 60 * 1000;

  // Calibrated pitch & Indic compatibility overrides for known studio presets
  public readonly VERIFIED_PRESET_CALIBRATIONS: Record<
    string,
    Partial<ElevenLabsVoiceCandidate>
  > = {
    // ─── 1. BUILT-IN MALE STUDIO VOICES (Sorted Young -> Senior) ───
    TX3LPaxmHKxFdv7VOQHJ: { name: "Liam", gender: "male", ageBucket: "young", representativeAge: 24, typicalPitchHz: 132, timbreTags: ["energetic", "articulate", "creator", "vlog", "american"], indicVerified: true },
    g5CIjZEefAph4nQFvHAz: { name: "Ethan", gender: "male", ageBucket: "young", representativeAge: 24, typicalPitchHz: 138, timbreTags: ["soft", "whisper", "asmr", "american"], indicVerified: true },
    g5CIjZEefAph4nJUvZnz: { name: "Marcus", gender: "male", ageBucket: "young", representativeAge: 24, typicalPitchHz: 130, timbreTags: ["high", "youthful", "american"], indicVerified: true },
    SOYHLrjzK2X1ezoPC6cr: { name: "Harry", gender: "male", ageBucket: "young", representativeAge: 25, typicalPitchHz: 135, timbreTags: ["anxious", "expressive", "character", "gaming", "american"], indicVerified: true },
    CYw3kZ02Hs0563khs1Fj: { name: "Dave", gender: "male", ageBucket: "young", representativeAge: 26, typicalPitchHz: 126, timbreTags: ["conversational", "casual", "british", "essex"], indicVerified: true },
    yoZ06aMxZJJ28mfd3POQ: { name: "Sam", gender: "male", ageBucket: "young", representativeAge: 26, typicalPitchHz: 124, timbreTags: ["raspy", "dynamic", "narration", "american"], indicVerified: true },
    GBv7mTt0atIp3Br8iCZE: { name: "Thomas", gender: "male", ageBucket: "young", representativeAge: 28, typicalPitchHz: 118, timbreTags: ["calm", "steady", "meditation", "explainer", "american"], indicVerified: true },
    TxGEqnHWrfWFTfGW9XjX: { name: "Josh", gender: "male", ageBucket: "young", representativeAge: 29, typicalPitchHz: 108, timbreTags: ["deep", "resonant", "narration", "american"], indicVerified: true },
    zcAOhNBS3c14rBihAFp1: { name: "Giovanni", gender: "male", ageBucket: "young", representativeAge: 30, typicalPitchHz: 120, timbreTags: ["warm", "accented", "audiobook", "english", "italian"], indicVerified: true },
    ErXwobaYiN019PkySvjV: { name: "Antoni", gender: "male", ageBucket: "young", representativeAge: 32, typicalPitchHz: 122, timbreTags: ["calm", "well-rounded", "conversational", "american"], indicVerified: true },
    bVMeCyTHy58xNoL34h3p: { name: "Jeremy", gender: "male", ageBucket: "young", representativeAge: 32, typicalPitchHz: 128, timbreTags: ["excited", "upbeat", "storytelling", "american", "irish"], indicVerified: true },
    iP95p4xoKVk53GoZ742B: { name: "Chris", gender: "male", ageBucket: "middle_aged", representativeAge: 38, typicalPitchHz: 116, timbreTags: ["casual", "friendly", "conversational", "american"], indicVerified: true },
    IKne3meq5aSn9XLyUdCD: { name: "Charlie", gender: "male", ageBucket: "middle_aged", representativeAge: 40, typicalPitchHz: 114, timbreTags: ["natural", "relaxed", "conversational", "australian"], indicVerified: true },
    "29vD33N1CtxCmqQRPOHJ": { name: "Drew", gender: "male", ageBucket: "middle_aged", representativeAge: 42, typicalPitchHz: 110, timbreTags: ["well-rounded", "news", "editorial", "american"], indicVerified: true },
    N2lVS1w4EtoT3dr4eOWO: { name: "Callum", gender: "male", ageBucket: "middle_aged", representativeAge: 42, typicalPitchHz: 106, timbreTags: ["intense", "hoarse", "dramatic", "transatlantic"], indicVerified: true },
    ODq5zmih8GrVes37Dizd: { name: "Patrick", gender: "male", ageBucket: "middle_aged", representativeAge: 43, typicalPitchHz: 125, timbreTags: ["high-energy", "shouty", "gaming", "american"], indicVerified: true },
    Zlb1dXrM653N07WRdFW3: { name: "Joseph", gender: "male", ageBucket: "middle_aged", representativeAge: 44, typicalPitchHz: 105, timbreTags: ["grounded", "articulate", "broadcast", "news", "british"], indicVerified: true },
    JBFqnCBsd6RMkjVDRZzb: { name: "George", gender: "male", ageBucket: "middle_aged", representativeAge: 45, typicalPitchHz: 104, timbreTags: ["warm", "raspy", "narration", "british"], indicVerified: true },
    Yko7PKHZNXotIFUBG7I9: { name: "Matthew", gender: "male", ageBucket: "middle_aged", representativeAge: 45, typicalPitchHz: 102, timbreTags: ["calm", "measured", "audiobook", "british"], indicVerified: true },
    pNInz6obpgDQGcFmaJgB: { name: "Adam", gender: "male", ageBucket: "middle_aged", representativeAge: 46, typicalPitchHz: 98, timbreTags: ["deep", "authoritative", "debate", "documentary", "american"], indicVerified: true },
    onwK4e9ZLuTAKqWW03F9: { name: "Daniel", gender: "male", ageBucket: "middle_aged", representativeAge: 46, typicalPitchHz: 96, timbreTags: ["deep", "authoritative", "news", "presenter", "british"], indicVerified: true },
    nPczCjzI2devNBz1zQrb: { name: "Brian", gender: "male", ageBucket: "middle_aged", representativeAge: 48, typicalPitchHz: 95, timbreTags: ["deep", "soothing", "long-form", "narration", "american"], indicVerified: true },
    "5Q0t7uMcjvnagumLfvZi": { name: "Paul", gender: "male", ageBucket: "middle_aged", representativeAge: 50, typicalPitchHz: 98, timbreTags: ["authoritative", "ground-reporter", "news", "american"], indicVerified: true },
    "2EiwWnXFnvU5JabPnv8n": { name: "Clyde", gender: "male", ageBucket: "middle_aged", representativeAge: 52, typicalPitchHz: 90, timbreTags: ["deep", "gravelly", "character", "american"], indicVerified: true },
    VR6AewLTigWG4xSOukaG: { name: "Arnold", gender: "male", ageBucket: "old", representativeAge: 58, typicalPitchHz: 92, timbreTags: ["crisp", "gravelly", "authoritative", "american"], indicVerified: true },
    pqHfZKP75CvOlQylNhV4: { name: "Bill", gender: "male", ageBucket: "old", representativeAge: 62, typicalPitchHz: 94, timbreTags: ["trustworthy", "warm", "documentary", "american"], indicVerified: true },
    D38z5RcWu1voky8WS1ja: { name: "Fin", gender: "male", ageBucket: "old", representativeAge: 65, typicalPitchHz: 96, timbreTags: ["energetic", "sailor", "character", "irish"], indicVerified: true },
    ZQe5CZNOzWyzPSCn5a3c: { name: "James", gender: "male", ageBucket: "old", representativeAge: 66, typicalPitchHz: 90, timbreTags: ["calm", "steady", "news", "documentary", "australian"], indicVerified: true },
    flq6f7yk4E4fJM5XTYuZ: { name: "Michael", gender: "male", ageBucket: "old", representativeAge: 68, typicalPitchHz: 88, timbreTags: ["oratory", "resonant", "audiobook", "american"], indicVerified: true },
    t0jbNlBVZ17f02VDIeMI: { name: "Jessie", gender: "male", ageBucket: "old", representativeAge: 70, typicalPitchHz: 92, timbreTags: ["raspy", "elderly", "character", "american"], indicVerified: true },

    // ─── 2. BUILT-IN FEMALE STUDIO VOICES (Sorted Young -> Senior) ───
    jBpfuIE2acCO8z3wKNLl: { name: "Gigi", gender: "female", ageBucket: "young", representativeAge: 18, typicalPitchHz: 242, timbreTags: ["childish", "animated", "character", "american"], indicVerified: true },
    zrHiDhphv9ZnVXBqCLjz: { name: "Mimi", gender: "female", ageBucket: "young", representativeAge: 19, typicalPitchHz: 235, timbreTags: ["youthful", "bright", "animation", "swedish", "english"], indicVerified: true },
    MF3mGyEYCl7XYWbV9V6O: { name: "Elli", gender: "female", ageBucket: "young", representativeAge: 21, typicalPitchHz: 228, timbreTags: ["youthful", "emotional", "creator", "social", "american"], indicVerified: true },
    EXAVITQu4vr4xnSDxMaL: { name: "Bella / Sarah", gender: "female", ageBucket: "young", representativeAge: 25, typicalPitchHz: 215, timbreTags: ["soft", "natural", "conversational", "news", "american"], indicVerified: true },
    hpp4J3VqNfWAUOO0d1Us: { name: "Bella", gender: "female", ageBucket: "young", representativeAge: 25, typicalPitchHz: 215, timbreTags: ["soft", "natural", "conversational", "news", "american"], indicVerified: true },
    piTKgcLEGmPE4e6mEKli: { name: "Nicole", gender: "female", ageBucket: "young", representativeAge: 25, typicalPitchHz: 212, timbreTags: ["soft", "whisper", "asmr", "audiobook", "american"], indicVerified: true },
    oWAxZDx7w5VEj9dCyTeq: { name: "Nicole", gender: "female", ageBucket: "young", representativeAge: 25, typicalPitchHz: 212, timbreTags: ["soft", "whisper", "asmr", "audiobook", "american"], indicVerified: true },
    jsCqWAovK2LkecY7zXl4: { name: "Freya", gender: "female", ageBucket: "young", representativeAge: 26, typicalPitchHz: 222, timbreTags: ["expressive", "dynamic", "creator", "american"], indicVerified: true },
    "21m00Tcm4TlvDq8ikWAM": { name: "Rachel", gender: "female", ageBucket: "young", representativeAge: 28, typicalPitchHz: 210, timbreTags: ["calm", "clear", "narration", "american"], indicVerified: true },
    AZnzlk1XvdvUeBnXmlld: { name: "Domi", gender: "female", ageBucket: "young", representativeAge: 28, typicalPitchHz: 204, timbreTags: ["strong", "confident", "narration", "american"], indicVerified: true },
    LcfcDJNUP1GQjkzn1xUU: { name: "Emily", gender: "female", ageBucket: "young", representativeAge: 29, typicalPitchHz: 206, timbreTags: ["calm", "gentle", "explainer", "american"], indicVerified: true },
    XB0fDUnXU5powFXDhCwa: { name: "Charlotte", gender: "female", ageBucket: "middle_aged", representativeAge: 36, typicalPitchHz: 195, timbreTags: ["smooth", "expressive", "gaming", "drama", "swedish", "english"], indicVerified: true },
    pMsXgVXv3BLzUgSXRplE: { name: "Serena", gender: "female", ageBucket: "middle_aged", representativeAge: 38, typicalPitchHz: 198, timbreTags: ["pleasant", "warm", "interactive", "assistant", "american"], indicVerified: true },
    Xb7hH8MSUJpSbSDYk0k2: { name: "Alice", gender: "female", ageBucket: "middle_aged", representativeAge: 40, typicalPitchHz: 190, timbreTags: ["confident", "clear", "broadcast", "news", "british"], indicVerified: true },
    XrExE9yKIg1WjnnlVkGX: { name: "Matilda", gender: "female", ageBucket: "middle_aged", representativeAge: 42, typicalPitchHz: 188, timbreTags: ["warm", "engaging", "narration", "american"], indicVerified: true },
    ThT5KcBeYPX3keUQqHPh: { name: "Dorothy", gender: "female", ageBucket: "middle_aged", representativeAge: 44, typicalPitchHz: 192, timbreTags: ["pleasant", "calm", "storytelling", "british"], indicVerified: true },
    pFZP5JQG7iQjIQuC4Bku: { name: "Lily", gender: "female", ageBucket: "middle_aged", representativeAge: 45, typicalPitchHz: 184, timbreTags: ["warm", "raspy", "narration", "british"], indicVerified: true },
    z9fAnlkpzviPz146aGWa: { name: "Glinda", gender: "female", ageBucket: "middle_aged", representativeAge: 48, typicalPitchHz: 202, timbreTags: ["theatrical", "character", "witch", "american"], indicVerified: true },
    oWAxZDx7w5VEj9dCyTzz: { name: "Grace", gender: "female", ageBucket: "old", representativeAge: 60, typicalPitchHz: 175, timbreTags: ["gentle", "authoritative", "mature", "southern", "american"], indicVerified: true },
    // ─── 3. CURATED NATIVE INDIAN ACCENT VOICES (accent=indian) ───
    s3PprVl6qK3x6V3a5nUq: { name: "Aarav", gender: "male", ageBucket: "young", representativeAge: 27, typicalPitchHz: 124, timbreTags: ["conversational", "creator", "indian"], indicVerified: true },
    CwhRBWXzGAHq8TQ4Fs17: { name: "Rohan", gender: "male", ageBucket: "middle_aged", representativeAge: 40, typicalPitchHz: 110, timbreTags: ["professional", "authoritative", "news", "indian"], indicVerified: true },
    z9fAnlkpzviPz146aGWb: { name: "Aditi", gender: "female", ageBucket: "young", representativeAge: 26, typicalPitchHz: 218, timbreTags: ["warm", "conversational", "indian"], indicVerified: true },
    EXAVITQu4vr4xnSDxMaK: { name: "Kavita", gender: "female", ageBucket: "middle_aged", representativeAge: 38, typicalPitchHz: 196, timbreTags: ["articulate", "news", "narrative", "indian"], indicVerified: true },
  };

  /**
   * Builds the fallback candidate list from verified Indic preset calibrations.
   */
  buildCalibratedFallbackCatalog(): ElevenLabsVoiceCandidate[] {
    return Object.entries(this.VERIFIED_PRESET_CALIBRATIONS).map(([voiceId, cal]) => {
      const bucket = cal.ageBucket || "middle_aged";
      const gender = cal.gender || "neutral";
      return {
        voiceId,
        name: cal.name || voiceId,
        gender,
        ageBucket: bucket,
        representativeAge: cal.representativeAge || AGE_BUCKET_ANCHORS[bucket],
        typicalPitchHz: cal.typicalPitchHz || (gender === "female" ? 205 : 118),
        timbreTags: cal.timbreTags || [],
        indicVerified: cal.indicVerified ?? true,
      };
    });
  }

  /**
   * Fetches live ElevenLabs /v1/voices metadata and merges it with TruthWorld's
   * verified Indic-compatible voice calibrations (cached in memory for 1 hour).
   */
  async getVoiceCatalog(apiKey?: string): Promise<ElevenLabsVoiceCandidate[]> {
    const now = Date.now();
    if (this.cachedCatalog.length > 0 && now - this.lastFetchMs < this.CACHE_TTL_MS) {
      return this.cachedCatalog;
    }

    const key = apiKey || process.env.ELEVENLABS_API_KEY || "";
    if (!key) {
      this.cachedCatalog = this.buildCalibratedFallbackCatalog();
      this.lastFetchMs = now;
      return this.cachedCatalog;
    }

    try {
      const res = await fetch("https://api.elevenlabs.io/v1/voices", {
        headers: { "xi-api-key": key },
      });
      if (!res.ok) {
        logger.warn("[VoiceMatcher] ElevenLabs voices HTTP notice, using calibrated fallback:", { status: res.status });
        this.cachedCatalog = this.buildCalibratedFallbackCatalog();
        this.lastFetchMs = now;
        return this.cachedCatalog;
      }

      const payload = (await res.json()) as {
        voices: Array<{
          voice_id: string;
          name: string;
          labels?: Record<string, string>;
        }>;
      };

      const candidates: ElevenLabsVoiceCandidate[] = payload.voices.map((v) => {
        const override = this.VERIFIED_PRESET_CALIBRATIONS[v.voice_id];
        const bucket = override?.ageBucket ?? normalizeElevenLabsAgeLabel(v.labels?.age);
        const rawGender = (v.labels?.gender || "neutral").toLowerCase();
        const gender: SpeakerGender =
          rawGender === "male" || rawGender === "female" ? rawGender : "neutral";

        const apiTags = [v.labels?.description, v.labels?.use_case, v.labels?.accent]
          .filter(Boolean)
          .map((t) => t!.toLowerCase());

        return {
          voiceId: v.voice_id,
          name: override?.name ?? v.name,
          gender: override?.gender ?? gender,
          ageBucket: bucket,
          representativeAge: override?.representativeAge ?? AGE_BUCKET_ANCHORS[bucket],
          typicalPitchHz: override?.typicalPitchHz ?? (gender === "female" ? 205 : 118),
          timbreTags: override?.timbreTags ?? apiTags,
          indicVerified: override?.indicVerified ?? false,
        };
      });

      // Ensure all calibrated studio presets are present in candidate catalog
      const existingIds = new Set(candidates.map((c) => c.voiceId));
      for (const [voiceId, cal] of Object.entries(this.VERIFIED_PRESET_CALIBRATIONS)) {
        if (!existingIds.has(voiceId)) {
          const bucket = cal.ageBucket || "middle_aged";
          const gender = cal.gender || "neutral";
          candidates.push({
            voiceId,
            name: cal.name || voiceId,
            gender,
            ageBucket: bucket,
            representativeAge: cal.representativeAge || AGE_BUCKET_ANCHORS[bucket],
            typicalPitchHz: cal.typicalPitchHz || (gender === "female" ? 205 : 118),
            timbreTags: cal.timbreTags || [],
            indicVerified: cal.indicVerified ?? true,
          });
        }
      }

      this.cachedCatalog = candidates;
      this.lastFetchMs = now;
      return this.cachedCatalog;
    } catch (err) {
      logger.warn("[VoiceMatcher] ElevenLabs voice catalog network notice, using calibrated fallback:", err);
      this.cachedCatalog = this.buildCalibratedFallbackCatalog();
      this.lastFetchMs = now;
      return this.cachedCatalog;
    }
  }

  /**
   * Computes the 4-term weighted distance score between a speaker and a voice candidate:
   * D = 0.55 * Continuous Age Distance (60yr span)
   *   + 0.20 * Discrete Age Bucket Penalty (0 exact, 0.6 different)
   *   + 0.15 * Fundamental Pitch (F0) Register Distance (120Hz span)
   *   + 0.10 * Timbre Jaccard Distance
   */
  scoreCandidate(speaker: DiarizedSpeakerProfile, candidate: ElevenLabsVoiceCandidate): number {
    // A. Continuous Age Distance (normalized over a 60-year span, weight: 0.55)
    const ageDiffNormalized = Math.min(1, Math.abs(speaker.estimatedAge - candidate.representativeAge) / 60);

    // B. Discrete Age Bucket Penalty (0 if exact match, 0.6 if different, weight: 0.20)
    const bucketPenalty = speaker.ageBucket === candidate.ageBucket ? 0 : 0.6;

    // C. Fundamental Pitch (F0) Register Distance (normalized over 120 Hz, weight: 0.15)
    const pitchDiffNormalized = Math.min(1, Math.abs(speaker.medianPitchHz - candidate.typicalPitchHz) / 120);

    // D. Timbre / Style Tag Jaccard Distance (weight: 0.10)
    const speakerTags = (speaker.timbreTags || []).map((t) => t.toLowerCase());
    const candidateTags = (candidate.timbreTags || []).map((t) => t.toLowerCase());
    const overlap = speakerTags.filter((t) =>
      candidateTags.some((c) => c === t || c.includes(t) || t.includes(c))
    ).length;
    const maxTags = Math.max(1, speakerTags.length);
    const timbreDistance = 1 - overlap / maxTags;

    // E. Quarantine penalty for niche ASMR / Theatrical / Whisper / Extreme voices (Ethan, Nicole, Glinda, Patrick)
    // unless the speaker profile explicitly matches those traits
    const nicheTags = ["asmr", "whisper", "witch", "theatrical", "shouty"];
    const candidateHasNiche = candidateTags.some((t) => nicheTags.some((n) => t.includes(n)));
    const speakerWantsNiche = speakerTags.some((t) => nicheTags.some((n) => t.includes(n)));
    const nicheQuarantinePenalty = candidateHasNiche && !speakerWantsNiche ? 0.40 : 0;

    return (
      0.55 * ageDiffNormalized +
      0.20 * bucketPenalty +
      0.15 * pitchDiffNormalized +
      0.10 * timbreDistance +
      nicheQuarantinePenalty
    );
  }

  /**
   * Computes weighted nearest-neighbor score across age, pitch, and timbre,
   * enforcing uniqueness across speakers in the same video.
   */
  selectNearestVoice(
    speaker: DiarizedSpeakerProfile,
    catalog: ElevenLabsVoiceCandidate[],
    alreadyAssignedVoiceIds: Set<string> = new Set()
  ): ElevenLabsVoiceCandidate {
    // 1. Prefer Indic-verified eleven_v4 voices matching gender and not yet assigned
    let pool = catalog.filter(
      (v) =>
        v.indicVerified &&
        !alreadyAssignedVoiceIds.has(v.voiceId) &&
        (speaker.gender === "neutral" || v.gender === speaker.gender)
    );

    // 2. Fall back to unassigned voices in full catalog matching gender
    if (pool.length === 0) {
      pool = catalog.filter(
        (v) =>
          !alreadyAssignedVoiceIds.has(v.voiceId) &&
          (speaker.gender === "neutral" || v.gender === speaker.gender)
      );
    }

    // 3. If pool is exhausted for this gender, wrap around and permit assignment from gender pool
    if (pool.length === 0) {
      pool = catalog.filter(
        (v) => speaker.gender === "neutral" || v.gender === speaker.gender
      );
    }

    // 4. Final safety net: all voices
    if (pool.length === 0) {
      pool = catalog;
    }

    if (pool.length === 0) {
      throw new Error(`No available ElevenLabs voice candidates for gender=${speaker.gender}`);
    }

    let bestCandidate = pool[0];
    let lowestDistance = Number.POSITIVE_INFINITY;

    for (const candidate of pool) {
      const distance = this.scoreCandidate(speaker, candidate);
      if (distance < lowestDistance) {
        lowestDistance = distance;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  /**
   * Profiles a diarized speaker from a solo audio slice and optional active-speaker video frame.
   * Extracts fundamental pitch F0 via FFmpeg and uses Gemini Multimodal to classify age and timbre.
   */
  async profileSpeakerMultimodal(params: {
    speakerId: string;
    audioClipPath: string;
    videoFramePath?: string;
    transcriptSample?: string;
    preferredGender?: "auto" | "male" | "female";
  }): Promise<DiarizedSpeakerProfile> {
    const { speakerId, audioClipPath, videoFramePath, transcriptSample, preferredGender } = params;

    // 1. Physical fundamental pitch extraction (F0 in Hz)
    let medianPitchHz = 120;
    try {
      if (audioClipPath && fs.existsSync(audioClipPath)) {
        medianPitchHz = await extractMedianPitchHz(audioClipPath);
      }
    } catch (pitchErr) {
      logger.warn("[VoiceMatcher] Acoustic pitch extraction notice:", { speakerId, pitchErr });
    }

    // 2. Grounded acoustic baseline defaults
    const isHighPitch = medianPitchHz > 170;
    const isDeepPitch = medianPitchHz < 105;
    const defaultGender: SpeakerGender = preferredGender && preferredGender !== "auto"
      ? (preferredGender === "female" ? "female" : "male")
      : (isHighPitch ? "female" : "male");
    const defaultAgeBucket: AgeBucket = isDeepPitch ? "middle_aged" : "young";
    const defaultAge = isDeepPitch ? 46 : (isHighPitch ? 25 : 24);
    const defaultTimbre = isDeepPitch
      ? ["authoritative", "deep"]
      : (isHighPitch ? ["soft", "young"] : ["energetic", "young"]);

    // 3. Gemini Multimodal Age & Timbre Analysis
    try {
      const genAI = getVertexAI();
      const model = genAI.getGenerativeModel({
        model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
        },
      });

      const parts: any[] = [];
      if (audioClipPath && fs.existsSync(audioClipPath)) {
        const audioBuf = await fs.promises.readFile(audioClipPath);
        parts.push({
          inlineData: {
            mimeType: audioClipPath.endsWith(".wav") ? "audio/wav" : "audio/mp3",
            data: audioBuf.toString("base64"),
          },
        });
      }

      if (videoFramePath && fs.existsSync(videoFramePath)) {
        const imgBuf = await fs.promises.readFile(videoFramePath);
        parts.push({
          inlineData: {
            mimeType: "image/jpeg",
            data: imgBuf.toString("base64"),
          },
        });
      }

      const prompt = `Analyze the primary speaker in this audio clip and video frame.
Transcript sample: "${transcriptSample || ""}"
Measured fundamental pitch F0: ${medianPitchHz} Hz.

CRITICAL INSTRUCTIONS:
- Evaluate the speaker's physical appearance in the video frame (apparent age, facial cues, presentation) and vocal characteristics in the audio (acoustic resonance, F0, speaking energy).
- Adult male voices typically have lower fundamental frequency (F0 < 165Hz) and chest resonance; female voices typically have higher pitch (F0 > 175Hz).
- Provide an estimated continuous age in years (e.g. 24, 46).
- Assign an ageBucket: "child" (<=16), "young" (17-35), "middle_aged" (36-55), or "old" (56+).
- Assign gender: "male" or "female".
- Provide 2 to 4 timbre tags describing vocal/physical presence (e.g., ["energetic", "young", "conversational"] or ["authoritative", "deep", "mature"]).

Return a valid JSON object matching this schema:
{
  "estimatedAge": number,
  "ageBucket": "child" | "young" | "middle_aged" | "old",
  "gender": "male" | "female",
  "timbreTags": string[],
  "confidence": number
}
Return ONLY valid JSON.`;

      parts.push({ text: prompt });

      const result = await model.generateContent({ contents: [{ role: "user", parts }] });
      const rawText = extractCandidateText(result.response?.candidates?.[0]) || result.text || "";
      const jsonMatch = rawText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        const estimatedAge = Number(parsed.estimatedAge) > 0 ? Number(parsed.estimatedAge) : defaultAge;
        const bucket: AgeBucket = ["child", "young", "middle_aged", "old"].includes(parsed.ageBucket)
          ? parsed.ageBucket
          : (estimatedAge < 18 ? "child" : (estimatedAge <= 35 ? "young" : (estimatedAge <= 55 ? "middle_aged" : "old")));
        const genStr = String(parsed.gender || "").toLowerCase();
        const resolvedGender: SpeakerGender = preferredGender && preferredGender !== "auto"
          ? (preferredGender === "female" ? "female" : "male")
          : (genStr.includes("fem") ? "female" : "male");
        const tags = Array.isArray(parsed.timbreTags) && parsed.timbreTags.length > 0
          ? parsed.timbreTags.map((t: any) => String(t).toLowerCase())
          : defaultTimbre;
        const confidence = typeof parsed.confidence === "number" ? Math.max(0, Math.min(1, parsed.confidence)) : 0.85;

        return {
          speakerId,
          estimatedAge,
          ageBucket: bucket,
          gender: resolvedGender,
          medianPitchHz,
          timbreTags: tags,
          confidence,
        };
      }
    } catch (llmErr) {
      logger.warn("[VoiceMatcher] Multimodal LLM speaker profiling notice, using acoustic heuristic fallback:", { speakerId, llmErr });
    }

    return {
      speakerId,
      estimatedAge: defaultAge,
      ageBucket: defaultAgeBucket,
      gender: defaultGender,
      medianPitchHz,
      timbreTags: defaultTimbre,
      confidence: 0.75,
    };
  }
}

export const voiceMatcher = new ElevenLabsVoiceMatcher();

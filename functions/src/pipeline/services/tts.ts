/**
 * 🎙️ TRUTHWORLD ELEVENLABS V4 TEXT-TO-SPEECH (TTS) SERVICE
 *
 * Audio Tracks Dubbing & Voice Cloning Architecture:
 *   - Video Audio Tracks Dubbing & Voice Cloning: Strictly powered by ElevenLabs v4 (`eleven_v4`).
 *     Provides state-of-the-art multilingual generative AudioML across 80+ languages including
 *     all Indian subcontinent languages (Telugu, Hindi, Tamil, Kannada, Malayalam, Marathi, Bengali, etc.)
 *     and global languages.
 *   - Google Cloud Chirp 3: HD has been completely terminated. All dubbing routes strictly to ElevenLabs v4 only.
 */

import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import * as streamLib from "stream";
import { TTSResult, TTSRequest, PronunciationRule } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { createSilentMp3Buffer } from "./media";
import { normalizeScriptureCitationsForTts, applyTeluguTheologicalLexiconGuard } from "./translation";
import { expressiveV4Bus } from "./expressiveV4Bus";

const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1";

export interface VoiceDescriptor {
  id: string;
  name: string;
  gender: "MALE" | "FEMALE";
  pitchBand: "deep" | "mid" | "high";
  ageTone: "youthful" | "adult" | "mature";
}

export const ELEVENLABS_MULTI_SPEAKER_PALETTE: {
  MALE: VoiceDescriptor[];
  FEMALE: VoiceDescriptor[];
} = {
  MALE: [
    // Young (~24-32)
    { id: "TX3LPaxmHKxFdv7VOQHJ", name: "Liam", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "g5CIjZEefAph4nQFvHAz", name: "Ethan", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "SOYHLrjzK2X1ezoPC6cr", name: "Harry", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "CYw3kZ02Hs0563khs1Fj", name: "Dave", gender: "MALE", pitchBand: "mid", ageTone: "youthful" },
    { id: "yoZ06aMxZJJ28mfd3POQ", name: "Sam", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "GBv7mTt0atIp3Br8iCZE", name: "Thomas", gender: "MALE", pitchBand: "mid", ageTone: "youthful" },
    { id: "TxGEqnHWrfWFTfGW9XjX", name: "Josh", gender: "MALE", pitchBand: "deep", ageTone: "youthful" },
    { id: "zcAOhNBS3c14rBihAFp1", name: "Giovanni", gender: "MALE", pitchBand: "mid", ageTone: "youthful" },
    { id: "ErXwobaYiN019PkySvjV", name: "Antoni", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "bVMeCyTHy58xNoL34h3p", name: "Jeremy", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    // Middle-Aged (~38-52)
    { id: "iP95p4xoKVk53GoZ742B", name: "Chris", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "IKne3meq5aSn9XLyUdCD", name: "Charlie", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "29vD33N1CtxCmqQRPOHJ", name: "Drew", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", gender: "MALE", pitchBand: "deep", ageTone: "adult" },
    { id: "ODq5zmih8GrVes37Dizd", name: "Patrick", gender: "MALE", pitchBand: "high", ageTone: "adult" },
    { id: "Zlb1dXrM653N07WRdFW3", name: "Joseph", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "JBFqnCBsd6RMkjVDRZzb", name: "George", gender: "MALE", pitchBand: "mid", ageTone: "mature" },
    { id: "Yko7PKHZNXotIFUBG7I9", name: "Matthew", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "pNInz6obpgDQGcFmaJgB", name: "Adam", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "onwK4e9ZLuTAKqWW03F9", name: "Daniel", gender: "MALE", pitchBand: "deep", ageTone: "adult" },
    { id: "nPczCjzI2devNBz1zQrb", name: "Brian", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "5Q0t7uMcjvnagumLfvZi", name: "Paul", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "2EiwWnXFnvU5JabPnv8n", name: "Clyde", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    // Senior (~58-70)
    { id: "VR6AewLTigWG4xSOukaG", name: "Arnold", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "pqHfZKP75CvOlQylNhV4", name: "Bill", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "D38z5RcWu1voky8WS1ja", name: "Fin", gender: "MALE", pitchBand: "mid", ageTone: "mature" },
    { id: "ZQe5CZNOzWyzPSCn5a3c", name: "James", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "flq6f7yk4E4fJM5XTYuZ", name: "Michael", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "t0jbNlBVZ17f02VDIeMI", name: "Jessie", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
  ],
  FEMALE: [
    // Young (~18-29)
    { id: "jBpfuIE2acCO8z3wKNLl", name: "Gigi", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "zrHiDhphv9ZnVXBqCLjz", name: "Mimi", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "MF3mGyEYCl7XYWbV9V6O", name: "Elli", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "EXAVITQu4vr4xnSDxMaL", name: "Bella / Sarah", gender: "FEMALE", pitchBand: "high", ageTone: "adult" },
    { id: "hpp4J3VqNfWAUOO0d1Us", name: "Bella", gender: "FEMALE", pitchBand: "high", ageTone: "adult" },
    { id: "piTKgcLEGmPE4e6mEKli", name: "Nicole", gender: "FEMALE", pitchBand: "high", ageTone: "adult" },
    { id: "oWAxZDx7w5VEj9dCyTeq", name: "Nicole", gender: "FEMALE", pitchBand: "high", ageTone: "adult" },
    { id: "jsCqWAovK2LkecY7zXl4", name: "Freya", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "LcfcDJNUP1GQjkzn1xUU", name: "Emily", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    // Middle-Aged (~36-48)
    { id: "XB0fDUnXU5powFXDhCwa", name: "Charlotte", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "pMsXgVXv3BLzUgSXRplE", name: "Serena", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "Xb7hH8MSUJpSbSDYk0k2", name: "Alice", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "XrExE9yKIg1WjnnlVkGX", name: "Matilda", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "ThT5KcBeYPX3keUQqHPh", name: "Dorothy", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "pFZP5JQG7iQjIQuC4Bku", name: "Lily", gender: "FEMALE", pitchBand: "deep", ageTone: "mature" },
    { id: "z9fAnlkpzviPz146aGWa", name: "Glinda", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    // Senior (~60+)
    { id: "oWAxZDx7w5VEj9dCyTzz", name: "Grace", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "FGY2WhTYpPnrIDTdsKH5", name: "Laura", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
  ],
};

// Known ElevenLabs preset voice mappings to gender for seamless translation
export const ELEVENLABS_VOICE_GENDER_MAP: Record<string, "MALE" | "FEMALE"> = {
  // Male Voices (29 + legacy aliases)
  "TX3LPaxmHKxFdv7VOQHJ": "MALE",   // Liam (24)
  "g5CIjZEefAph4nQFvHAz": "MALE",   // Ethan (24)
  "g5CIjZEefAph4nJUvZnz": "MALE",   // Marcus (24)
  "SOYHLrjzK2X1ezoPC6cr": "MALE",   // Harry (25)
  "CYw3kZ02Hs0563khs1Fj": "MALE",   // Dave (26)
  "yoZ06aMxZJJ28mfd3POQ": "MALE",   // Sam (26)
  "GBv7mTt0atIp3Br8iCZE": "MALE",   // Thomas (28)
  "TxGEqnHWrfWFTfGW9XjX": "MALE",   // Josh (29)
  "zcAOhNBS3c14rBihAFp1": "MALE",   // Giovanni (30)
  "ErXwobaYiN019PkySvjV": "MALE",   // Antoni (32)
  "bVMeCyTHy58xNoL34h3p": "MALE",   // Jeremy (32)
  "iP95p4xoKVk53GoZ742B": "MALE",   // Chris (38)
  "IKne3meq5aSn9XLyUdCD": "MALE",   // Charlie (40)
  "29vD33N1CtxCmqQRPOHJ": "MALE",   // Drew (42)
  "N2lVS1w4EtoT3dr4eOWO": "MALE",   // Callum (42)
  "ODq5zmih8GrVes37Dizd": "MALE",   // Patrick (43)
  "Zlb1dXrM653N07WRdFW3": "MALE",   // Joseph (44)
  "JBFqnCBsd6RMkjVDRZzb": "MALE",   // George (45)
  "Yko7PKHZNXotIFUBG7I9": "MALE",   // Matthew (45)
  "pNInz6obpgDQGcFmaJgB": "MALE",   // Adam (46)
  "onwK4e9ZLuTAKqWW03F9": "MALE",   // Daniel (46)
  "nPczCjzI2devNBz1zQrb": "MALE",   // Brian (48)
  "5Q0t7uMcjvnagumLfvZi": "MALE",   // Paul (50)
  "2EiwWnXFnvU5JabPnv8n": "MALE",   // Clyde (52)
  "VR6AewLTigWG4xSOukaG": "MALE",   // Arnold (58)
  "pqHfZKP75CvOlQylNhV4": "MALE",   // Bill (62)
  "D38z5RcWu1voky8WS1ja": "MALE",   // Fin (65)
  "ZQe5CZNOzWyzPSCn5a3c": "MALE",   // James (66)
  "flq6f7yk4E4fJM5XTYuZ": "MALE",   // Michael (68)
  "t0jbNlBVZ17f02VDIeMI": "MALE",   // Jessie (70)

  // Female Voices (17 + legacy aliases)
  "jBpfuIE2acCO8z3wKNLl": "FEMALE", // Gigi (18)
  "zrHiDhphv9ZnVXBqCLjz": "FEMALE", // Mimi (19)
  "MF3mGyEYCl7XYWbV9V6O": "FEMALE", // Elli (21)
  "EXAVITQu4vr4xnSDxMaL": "FEMALE", // Bella / Sarah (25)
  "hpp4J3VqNfWAUOO0d1Us": "FEMALE", // Bella (25)
  "piTKgcLEGmPE4e6mEKli": "FEMALE", // Nicole (25)
  "oWAxZDx7w5VEj9dCyTeq": "FEMALE", // Nicole (25)
  "jsCqWAovK2LkecY7zXl4": "FEMALE", // Freya (26)
  "21m00Tcm4TlvDq8ikWAM": "FEMALE", // Rachel (28)
  "AZnzlk1XvdvUeBnXmlld": "FEMALE", // Domi (28)
  "LcfcDJNUP1GQjkzn1xUU": "FEMALE", // Emily (29)
  "XB0fDUnXU5powFXDhCwa": "FEMALE", // Charlotte (36)
  "pMsXgVXv3BLzUgSXRplE": "FEMALE", // Serena (38)
  "Xb7hH8MSUJpSbSDYk0k2": "FEMALE", // Alice (40)
  "XrExE9yKIg1WjnnlVkGX": "FEMALE", // Matilda (42)
  "ThT5KcBeYPX3keUQqHPh": "FEMALE", // Dorothy (44)
  "pFZP5JQG7iQjIQuC4Bku": "FEMALE", // Lily (45)
  "z9fAnlkpzviPz146aGWa": "FEMALE", // Glinda (48)
  "oWAxZDx7w5VEj9dCyTzz": "FEMALE", // Grace (60)
  "FGY2WhTYpPnrIDTdsKH5": "FEMALE", // Laura
};

export const TTS_MODELS = {
  v4: "eleven_v4",                           // Flagship Primary V4 — native support for 80+ languages for every video
  v3: "eleven_v4",                           // Deprecated alias: strictly mapped to eleven_v4 (Zero fallback models)
} as const;

/**
 * 80+ languages supported natively by ElevenLabs V4 Premium.
 * Covers Indian subcontinent, European, East/Southeast Asian, Middle Eastern, and African languages.
 */
export const V4_PREMIUM_80_LANGUAGES = new Set([
  // 15 Indian languages
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur", "sa", "ks", "sd",
  // Major Global & European languages
  "en", "es", "fr", "de", "it", "pt", "nl", "ru", "pl", "sv", "no", "da", "fi", "cs", "sk",
  "el", "hu", "ro", "bg", "hr", "sr", "uk", "sl", "lt", "lv", "et", "ga", "cy", "ca", "gl",
  "eu", "is", "sq", "mk", "bs",
  // East, Southeast & Central Asian languages
  "zh", "ja", "ko", "id", "ms", "vi", "th", "fil", "tl", "my", "km", "lo", "ka", "hy", "az",
  "kk", "uz", "mn", "ne", "si",
  // Middle Eastern languages
  "ar", "he", "fa", "tr", "ku", "ps",
  // African languages
  "sw", "af", "zu", "xh", "ha", "yo", "ig", "am", "so",
]);

const MAX_RETRIES = 2; // Retries transient 429/5xx strictly on eleven_v4 (Zero fallback models)

/**
 * Valid inline expressive audio tags supported by ElevenLabs eleven_v4.
 * Non-v4 bracketed noise annotations (e.g. [music], [applause]) are stripped so TTS does not read them aloud.
 */
export const VALID_ELEVENLABS_AUDIO_TAGS = new Set<string>([
  "whispers",
  "shouts",
  "laughs",
  "sighs",
  "gasps",
  "excited",
  "sorrowful",
  "sad",
  "angry",
  "said angrily",
  "sarcastic",
  "calm",
  "serious",
  "pauses",
  "hesitates",
  "stammers",
]);

function escapeRegExp(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Applies creator custom pronunciation glossary rules before ElevenLabs synthesis.
 */
export function applyPronunciationGlossary(text: string, glossary?: PronunciationRule[]): string {
  if (!text || !glossary || glossary.length === 0) return text;
  let updated = text;
  for (const rule of glossary) {
    const term = (rule.term || "").trim();
    const target = (rule.ipaOrPhonetic || rule.replacement || "").trim();
    if (!term || !target) continue;
    const flags = rule.caseSensitive ? "g" : "gi";
    const pattern = new RegExp(`\\b${escapeRegExp(term)}\\b`, flags);
    updated = updated.replace(pattern, target);
  }
  return updated;
}

/**
 * Normalizes text for ElevenLabs eleven_v4 synthesis while PRESERVING whitelisted
 * inline emotion/prosody Audio Tags (e.g. [whispers], [laughs], [excited]).
 */
export function sanitizeTextForElevenLabsV4(text: string, emotionTag?: string): string {
  if (!text) return "";
  let cleaned = text
    .replace(/\s+/g, " ")
    .replace(/[""]/g, '"')
    .replace(/['']/g, "'")
    .replace(/\.{3,}/g, "…")
    .replace(/\([^)]*\)/g, "")
    .replace(/\[([^\]]+)\]/g, (_full, inner: string) => {
      const norm = inner.toLowerCase().trim();
      return VALID_ELEVENLABS_AUDIO_TAGS.has(norm) ? `[${norm}]` : "";
    })
    .replace(/\s+/g, " ")
    .trim();

  const normalizedEmotion = emotionTag?.toLowerCase().trim();
  if (normalizedEmotion && VALID_ELEVENLABS_AUDIO_TAGS.has(normalizedEmotion)) {
    const tagRegex = new RegExp(`\\[${normalizedEmotion}\\]`, "i");
    if (!tagRegex.test(cleaned)) {
      cleaned = `[${normalizedEmotion}] ${cleaned}`.trim();
    }
  }

  return cleaned;
}

/**
 * Removes inline ElevenLabs Audio Tags before writing public .srt / .vtt captions.
 */
export function stripAudioTagsForSubtitles(text: string): string {
  if (!text) return "";
  return text
    .replace(/\[[^\]]*\]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Checks whether text contains articulable verbal content (characters, digits, letters)
 * beyond punctuation, audio tags [laughs], parenthetical notes (applause), emojis, and whitespace.
 */
export function hasVerbalContent(text: string): boolean {
  if (!text || typeof text !== "string") return false;
  const noParens = text.replace(/\([^)]*\)/g, "");
  const noTags = stripAudioTagsForSubtitles(noParens);
  const stripped = noTags
    .replace(/[\p{Extended_Pictographic}\uFE0F]/gu, "")
    .replace(/[\s.,/#!$%^&*;:{}=\-_`~()?'"…\\|<>@+=[\]]/gu, "");
  return stripped.trim().length > 0;
}

interface VoiceSettings {
  stability: number;
  similarity_boost: number;
  style?: number;
  use_speaker_boost?: boolean;
}

/**
 * 🛡️ Global TTS Concurrency & Circuit Breaker Manager
 *
 * Prevents account-wide HTTP 429 cascades across multiple Cloud Function instances.
 * Implements:
 *   1. Account-wide concurrency lease throttling
 *   2. Circuit Breaker for sustained upstream provider outages
 *   3. Dynamic Retry-After header enforcement
 */
export class GlobalTTSConcurrencyManager {
  private static activeSlots = 0;
  private static consecutiveFailures = 0;
  private static circuitState: "CLOSED" | "OPEN" | "HALF_OPEN" = "CLOSED";
  private static circuitOpenedAt = 0;
  private static isProbeActive = false;
  private static readonly CIRCUIT_COOLDOWN_MS = 30000; // 30s cooling period
  private static readonly MAX_FAILURES_BEFORE_TRIP = 5;
  private static readonly LEASE_DURATION_MS = 30000; // 30s distributed lease TTL

  public static getMaxConcurrency(): number {
    return Math.max(1, parseInt(process.env.ELEVENLABS_MAX_CONCURRENCY || "15", 10));
  }

  public static getCircuitState(): "CLOSED" | "OPEN" | "HALF_OPEN" {
    return this.circuitState;
  }

  public static getActiveSlots(): number {
    return this.activeSlots;
  }

  public static resetForTesting(): void {
    this.activeSlots = 0;
    this.consecutiveFailures = 0;
    this.circuitState = "CLOSED";
    this.circuitOpenedAt = 0;
    this.isProbeActive = false;
  }

  public static checkCircuit(): void {
    const now = Date.now();
    if (this.circuitState === "OPEN") {
      if (now - this.circuitOpenedAt > this.CIRCUIT_COOLDOWN_MS) {
        this.circuitState = "HALF_OPEN";
        this.isProbeActive = false;
        logger.info("[GlobalTTSConcurrencyManager] Circuit Breaker cooldown elapsed — entering HALF_OPEN state");
      } else {
        throw new Error("[GlobalTTSConcurrencyManager] Upstream TTS circuit breaker is OPEN due to sustained provider failures. Rejecting request to prevent cascading failure.");
      }
    }

    if (this.circuitState === "HALF_OPEN") {
      if (this.isProbeActive) {
        throw new Error("[GlobalTTSConcurrencyManager] Circuit breaker is HALF_OPEN and currently testing upstream health with an active probe. Concurrent requests rejected.");
      }
      this.isProbeActive = true;
      logger.info("[GlobalTTSConcurrencyManager] Dispatching single probe request in HALF_OPEN state");
    }
  }

  public static recordSuccess(): void {
    this.consecutiveFailures = 0;
    this.isProbeActive = false;
    this.circuitState = "CLOSED";

    const isDistributedEnabled =
      process.env.ENABLE_DISTRIBUTED_TTS_LEASING === "true" ||
      (process.env.NODE_ENV === "production" && process.env.FUNCTIONS_EMULATOR !== "true");

    if (isDistributedEnabled) {
      try {
        const admin = require("firebase-admin");
        admin
          .firestore()
          .collection("system_concurrency")
          .doc("elevenlabs_circuit_breaker")
          .set(
            {
              state: "CLOSED",
              consecutiveFailures: 0,
              probeOwnerId: null,
              probeLeaseExpiresAt: 0,
              updatedAt: Date.now(),
            },
            { merge: true }
          )
          .catch(() => {});
      } catch (_) {}
    }
  }

  public static recordFailure(is5xxOrSevere: boolean): void {
    const isDistributedEnabled =
      process.env.ENABLE_DISTRIBUTED_TTS_LEASING === "true" ||
      (process.env.NODE_ENV === "production" && process.env.FUNCTIONS_EMULATOR !== "true");

    if (this.circuitState === "HALF_OPEN") {
      this.circuitState = "OPEN";
      this.circuitOpenedAt = Date.now();
      this.isProbeActive = false;
      this.consecutiveFailures = this.MAX_FAILURES_BEFORE_TRIP;
      logger.error("[GlobalTTSConcurrencyManager] ⚠️ Probe request failed in HALF_OPEN state — circuit breaker tripped back to OPEN.");

      if (isDistributedEnabled) {
        try {
          const admin = require("firebase-admin");
          admin
            .firestore()
            .collection("system_concurrency")
            .doc("elevenlabs_circuit_breaker")
            .set(
              {
                state: "OPEN",
                circuitOpenedAt: Date.now(),
                probeOwnerId: null,
                probeLeaseExpiresAt: 0,
                consecutiveFailures: this.MAX_FAILURES_BEFORE_TRIP,
                updatedAt: Date.now(),
              },
              { merge: true }
            )
            .catch(() => {});
        } catch (_) {}
      }
      return;
    }

    if (!is5xxOrSevere) return;
    this.consecutiveFailures++;
    if (this.consecutiveFailures >= this.MAX_FAILURES_BEFORE_TRIP) {
      this.circuitState = "OPEN";
      this.circuitOpenedAt = Date.now();
      this.isProbeActive = false;
      logger.error(`[GlobalTTSConcurrencyManager] ⚠️ Upstream TTS circuit breaker TRIPPED to OPEN after ${this.consecutiveFailures} consecutive severe provider failures.`);

      if (isDistributedEnabled) {
        try {
          const admin = require("firebase-admin");
          admin
            .firestore()
            .collection("system_concurrency")
            .doc("elevenlabs_circuit_breaker")
            .set(
              {
                state: "OPEN",
                circuitOpenedAt: Date.now(),
                probeOwnerId: null,
                probeLeaseExpiresAt: 0,
                consecutiveFailures: this.consecutiveFailures,
                updatedAt: Date.now(),
              },
              { merge: true }
            )
            .catch(() => {});
        } catch (_) {}
      }
    }
  }

  /**
   * Distributed circuit check coordinating across multiple Cloud Function instances.
   */
  private static async checkDistributedCircuit(): Promise<void> {
    this.checkCircuit();

    const isDistributedEnabled =
      process.env.ENABLE_DISTRIBUTED_TTS_LEASING === "true" ||
      (process.env.NODE_ENV === "production" && process.env.FUNCTIONS_EMULATOR !== "true");

    if (!isDistributedEnabled) return;

    try {
      const admin = require("firebase-admin");
      const firestore = admin.firestore();
      const circuitRef = firestore.collection("system_concurrency").doc("elevenlabs_circuit_breaker");
      const instanceId = process.env.HOSTNAME || `inst_${uuidv4().slice(0, 8)}`;
      const now = Date.now();

      const allowed = await firestore.runTransaction(async (tx: any) => {
        const snap = await tx.get(circuitRef);
        if (!snap.exists) {
          tx.set(circuitRef, {
            state: "CLOSED",
            circuitOpenedAt: 0,
            probeOwnerId: null,
            probeLeaseExpiresAt: 0,
            consecutiveFailures: 0,
            generation: 1,
            updatedAt: now,
          });
          return true;
        }
        const data = snap.data();
        if (data.state === "OPEN") {
          if (now - (data.circuitOpenedAt || 0) > GlobalTTSConcurrencyManager.CIRCUIT_COOLDOWN_MS) {
            tx.update(circuitRef, {
              state: "HALF_OPEN",
              probeOwnerId: instanceId,
              probeLeaseExpiresAt: now + 15000,
              updatedAt: now,
            });
            GlobalTTSConcurrencyManager.circuitState = "HALF_OPEN";
            GlobalTTSConcurrencyManager.isProbeActive = true;
            return true;
          }
          GlobalTTSConcurrencyManager.circuitState = "OPEN";
          GlobalTTSConcurrencyManager.circuitOpenedAt = data.circuitOpenedAt || now;
          return false;
        } else if (data.state === "HALF_OPEN") {
          if (data.probeOwnerId === instanceId) {
            return true;
          }
          if (data.probeLeaseExpiresAt && data.probeLeaseExpiresAt < now) {
            tx.update(circuitRef, {
              probeOwnerId: instanceId,
              probeLeaseExpiresAt: now + 15000,
              updatedAt: now,
            });
            GlobalTTSConcurrencyManager.circuitState = "HALF_OPEN";
            GlobalTTSConcurrencyManager.isProbeActive = true;
            return true;
          }
          return false;
        }
        GlobalTTSConcurrencyManager.circuitState = "CLOSED";
        return true;
      });

      if (!allowed) {
        throw new Error(
          "[GlobalTTSConcurrencyManager] Distributed upstream TTS circuit breaker is OPEN or testing with a probe. Request rejected to prevent cluster-wide cascading failure."
        );
      }
    } catch (err: any) {
      if (err.message?.includes("circuit breaker is OPEN") || err.message?.includes("testing with a probe")) {
        throw err;
      }
      logger.warn("[GlobalTTSConcurrencyManager] Distributed circuit check fell back to local state", {
        err: err?.message,
      });
    }
  }

  /**
   * Acquires a concurrency slot respecting account ceilings.
   * Throws Error if slot cannot be acquired within timeoutMs (HARD CEILING: never exceeds maxConcurrency).
   * In multi-instance mode (Firestore available and not test), coordinates via distributed lease documents
   * with fencing tokens, heartbeat lease renewal, and fenced release verification.
   */
  public static async acquireSlot(timeoutMs = 15000): Promise<() => void> {
    await this.checkDistributedCircuit();
    const maxConcurrency = this.getMaxConcurrency();
    const start = Date.now();

    // 1. Process-local concurrency ceiling enforcement (Finding 3: Hard Timeout Limit)
    while (this.activeSlots >= maxConcurrency) {
      if (Date.now() - start > timeoutMs) {
        throw new Error(
          `[GlobalTTSConcurrencyManager] Concurrency slot acquisition timed out after ${timeoutMs}ms (activeSlots=${this.activeSlots}, max=${maxConcurrency}). Request rejected to prevent upstream provider quota exhaustion.`
        );
      }
      const waitMs = 40 + Math.floor(Math.random() * 80);
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }

    this.activeSlots++;

    // 2. Distributed lease coordination across multi-instance Cloud Functions with Fencing & Heartbeat
    let distributedSlotId: number | null = null;
    let leaseOwnerId: string = "";
    let activeFenceToken = 0;
    let heartbeatTimer: NodeJS.Timeout | null = null;

    const isDistributedEnabled =
      process.env.ENABLE_DISTRIBUTED_TTS_LEASING === "true" ||
      (process.env.NODE_ENV === "production" && process.env.FUNCTIONS_EMULATOR !== "true");

    if (isDistributedEnabled) {
      try {
        const admin = require("firebase-admin");
        const firestore = admin.firestore();
        const instanceId = process.env.HOSTNAME || `inst_${uuidv4().slice(0, 8)}`;
        leaseOwnerId = `${instanceId}_${uuidv4().slice(0, 8)}`;

        while (distributedSlotId === null) {
          if (Date.now() - start > timeoutMs) {
            this.activeSlots = Math.max(0, this.activeSlots - 1);
            throw new Error(
              `[GlobalTTSConcurrencyManager] Distributed slot lease acquisition timed out after ${timeoutMs}ms across instances. Request rejected to protect ElevenLabs quota.`
            );
          }

          for (let slot = 0; slot < maxConcurrency; slot++) {
            const slotRef = firestore.collection("tts_account_leases").doc(`slot_${slot}`);
            try {
              const acquired = await firestore.runTransaction(async (tx: any) => {
                const snap = await tx.get(slotRef);
                const now = Date.now();
                if (!snap.exists) {
                  activeFenceToken = 1;
                  tx.set(slotRef, {
                    slot,
                    instanceId,
                    leaseOwnerId,
                    fenceToken: 1,
                    leaseExpiresAt: now + GlobalTTSConcurrencyManager.LEASE_DURATION_MS,
                    acquiredAt: now,
                    lastHeartbeatAt: now,
                  });
                  return true;
                }
                const data = snap.data();
                if (!data.leaseExpiresAt || data.leaseExpiresAt < now) {
                  activeFenceToken = (data.fenceToken || 0) + 1;
                  tx.update(slotRef, {
                    instanceId,
                    leaseOwnerId,
                    fenceToken: activeFenceToken,
                    leaseExpiresAt: now + GlobalTTSConcurrencyManager.LEASE_DURATION_MS,
                    acquiredAt: now,
                    lastHeartbeatAt: now,
                  });
                  return true;
                }
                return false;
              });

              if (acquired) {
                distributedSlotId = slot;
                break;
              }
            } catch (_) {
              // Contention on this specific slot doc; try next slot
            }
          }

          if (distributedSlotId === null) {
            const jitterMs = 50 + Math.floor(Math.random() * 100);
            await new Promise((resolve) => setTimeout(resolve, jitterMs));
          }
        }

        // Heartbeat renewal: renews lease every 10s as long as request is in flight
        if (distributedSlotId !== null) {
          const currentSlot = distributedSlotId;
          const currentOwner = leaseOwnerId;
          const currentToken = activeFenceToken;
          heartbeatTimer = setInterval(async () => {
            try {
              const slotRef = firestore.collection("tts_account_leases").doc(`slot_${currentSlot}`);
              await firestore.runTransaction(async (tx: any) => {
                const snap = await tx.get(slotRef);
                if (!snap.exists) return;
                const data = snap.data();
                // Fencing check: verify we still hold the unexpired lease and token matches
                if (data.leaseOwnerId === currentOwner && data.fenceToken === currentToken) {
                  tx.update(slotRef, {
                    leaseExpiresAt: Date.now() + GlobalTTSConcurrencyManager.LEASE_DURATION_MS,
                    lastHeartbeatAt: Date.now(),
                  });
                }
              });
            } catch (_) {}
          }, 10000);
        }
      } catch (distErr: any) {
        if (distErr.message?.includes("timed out") || distErr.message?.includes("circuit breaker")) {
          throw distErr;
        }
        logger.warn("[GlobalTTSConcurrencyManager] Distributed lease check fell back to local bounding", {
          err: distErr.message,
        });
      }
    }

    let released = false;
    return () => {
      if (!released) {
        released = true;
        GlobalTTSConcurrencyManager.activeSlots = Math.max(0, GlobalTTSConcurrencyManager.activeSlots - 1);
        if (heartbeatTimer) {
          clearInterval(heartbeatTimer);
          heartbeatTimer = null;
        }
        if (distributedSlotId !== null) {
          try {
            const admin = require("firebase-admin");
            const firestore = admin.firestore();
            const slotRef = firestore.collection("tts_account_leases").doc(`slot_${distributedSlotId}`);
            const currentOwner = leaseOwnerId;
            const currentToken = activeFenceToken;
            firestore
              .runTransaction(async (tx: any) => {
                const snap = await tx.get(slotRef);
                if (!snap.exists) return;
                const data = snap.data();
                // Fencing verification: Only release if we still own the lease!
                if (data.leaseOwnerId === currentOwner && data.fenceToken === currentToken) {
                  tx.update(slotRef, {
                    leaseExpiresAt: 0,
                    releasedAt: Date.now(),
                  });
                }
              })
              .catch(() => {});
          } catch (_) {}
        }
      }
    };
  }
}

export class ElevenLabsTTSService {
  private apiKey: string;
  private defaultVoiceSettings: VoiceSettings = {
    stability: 0.5,
    similarity_boost: 0.75,
    use_speaker_boost: true,
  };

  constructor(apiKey?: string) {
    this.apiKey = apiKey || "";
  }

  public getApiKey(): string {
    return this.apiKey || PIPELINE_CONFIG.ELEVENLABS_API_KEY;
  }

  public selectModel(language?: string, request?: TTSRequest): string {
    // Strictly ElevenLabs v4 only
    return TTS_MODELS.v4;
  }

  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const isFemale = request.gender === "FEMALE" || (!request.gender && request.voiceId && ELEVENLABS_VOICE_GENDER_MAP[request.voiceId] === "FEMALE");

    let voiceId = request.voiceCloneId || request.voiceId;

    // Check if voiceId is a Google Cloud voice name (e.g. "te-IN-Standard-B" or "en-US-Chirp3-HD-Achernar")
    const isGoogleVoiceName = voiceId && (
      voiceId.includes("-Standard-") ||
      voiceId.includes("-Chirp") ||
      voiceId.includes("-Neural2-") ||
      voiceId.includes("-Wavenet-") ||
      voiceId.includes("-Journey-") ||
      voiceId.includes("-Studio-")
    );

    if (!voiceId || isGoogleVoiceName) {
      voiceId = isFemale ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV"; // Female: Sarah, Male: Antoni
    } else if (ELEVENLABS_VOICE_GENDER_MAP[voiceId]) {
      // Invariant: Enforce gender consistency on preset voices
      const knownGender = ELEVENLABS_VOICE_GENDER_MAP[voiceId];
      if (request.gender === "MALE" && knownGender === "FEMALE") {
        voiceId = "ErXwobaYiN019PkySvjV"; // Antoni (Male)
      } else if (request.gender === "FEMALE" && knownGender === "MALE") {
        voiceId = "EXAVITQu4vr4xnSDxMaL"; // Sarah (Female)
      }
    }
    const model = this.selectModel(request.language, request);
    const apiKey = this.getApiKey();

    if (!apiKey || apiKey.trim().length === 0 || apiKey.includes("YOUR_") || apiKey.includes("placeholder")) {
      throw new Error("ElevenLabs API key is missing. Video dubbing strictly requires ElevenLabs v4.");
    }

    logger.info("[ElevenLabsTTS] Synthesizing segment strictly with ElevenLabs V4", {
      jobId: request.jobId,
      language: request.language,
      model,
      voiceId,
      isVoiceClone: Boolean(request.voiceCloneId || request.preferVoiceCloning),
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    let glossarizedText = applyPronunciationGlossary(request.text, request.pronunciationGlossary);
    if (request.language === "te") {
      glossarizedText = applyTeluguTheologicalLexiconGuard(glossarizedText);
    }
    glossarizedText = normalizeScriptureCitationsForTts(glossarizedText, request.language);

    // 🛡️ Zero-Credit Non-Speech / Empty Segment Guard:
    // If text contains only audio tags, brackets, parentheses, punctuation, emojis, or whitespace
    // (e.g. "(music)", "[silence]", "...", "[laughs]" without dialogue), do NOT invoke ElevenLabs.
    // ElevenLabs rejects empty verbal text with HTTP 400 "input_text_empty".
    const hasSpoken = hasVerbalContent(glossarizedText);
    if (!hasSpoken) {
      logger.info("[ElevenLabsTTS] Non-speech segment detected — producing silent audio chunk", {
        jobId: request.jobId,
        language: request.language,
        originalText: request.text,
      });

      const silentMp3Buffer = await createSilentMp3Buffer(0.5);
      const bucket = storage().bucket();
      const filePath = `audio/${request.jobId}/${request.language}/chunk-${uuidv4()}.mp3`;
      const file = bucket.file(filePath);

      await file.save(silentMp3Buffer, {
        contentType: "audio/mpeg",
        metadata: {
          cacheControl: "public, max-age=31536000",
        },
      });

      const audioUrl = `gs://${bucket.name}/${filePath}`;
      return {
        jobId: request.jobId,
        language: request.language,
        audioUrl,
        duration: 0.5,
        format: "mp3",
        provider: "elevenlabs",
        voiceName: voiceId,
      };
    }

    const clamp01 = (v: number): number => Number(Math.max(0, Math.min(1, v)).toFixed(2));

    // Expressive v4 Bus dynamic parameterization fallback if not pre-computed
    let initialStability = request.stability;
    let initialSimilarity = request.similarityBoost;
    let initialStyle = request.style;
    let initialEmotionTag = request.emotionTag;

    if (initialStyle === undefined || initialStability === undefined) {
      const busResult = expressiveV4Bus.processSegment({
        jobId: request.jobId,
        language: request.language,
        translatedText: glossarizedText,
        telemetry: {
          energyDb: request.energyDb,
          emotionTag: request.emotionTag,
          stabilityOverride: request.stability,
          similarityBoostOverride: request.similarityBoost,
          styleOverride: request.style,
        },
        preferVoiceCloning: request.preferVoiceCloning,
        voiceType: request.voiceType as any,
      });
      initialStability = initialStability ?? busResult.voiceSettings.stability;
      initialSimilarity = initialSimilarity ?? busResult.voiceSettings.similarity_boost;
      initialStyle = initialStyle ?? busResult.voiceSettings.style;
      initialEmotionTag = initialEmotionTag ?? busResult.emotionTag;
    }

    const resolvedStability =
      typeof initialStability === "number" && Number.isFinite(initialStability)
        ? clamp01(initialStability)
        : (request.preferVoiceCloning ? 0.45 : this.defaultVoiceSettings.stability);
    const resolvedSimilarity =
      typeof initialSimilarity === "number" && Number.isFinite(initialSimilarity)
        ? clamp01(initialSimilarity)
        : (request.preferVoiceCloning ? 0.85 : this.defaultVoiceSettings.similarity_boost);

    const voiceSettings: VoiceSettings = {
      stability: resolvedStability,
      similarity_boost: resolvedSimilarity,
      use_speaker_boost: request.useSpeakerBoost ?? this.defaultVoiceSettings.use_speaker_boost ?? true,
      ...(typeof request.style === "number" && Number.isFinite(request.style) ? { style: clamp01(request.style) } : {}),
    };

    const releaseSlot = await GlobalTTSConcurrencyManager.acquireSlot();

    try {
      for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
        const currentModel = TTS_MODELS.v4; // Strictly eleven_v4 (zero fallback models)
        const synthesisText = sanitizeTextForElevenLabsV4(glossarizedText, initialEmotionTag);

        try {
          const response = await axios.post(
            `${ELEVENLABS_BASE_URL}/text-to-speech/${voiceId}`,
            {
              text: synthesisText || request.text,
              model_id: currentModel,
              voice_settings: voiceSettings,
            },
            {
              headers: {
                "xi-api-key": apiKey,
                "Content-Type": "application/json",
              },
              params: {
                output_format: "mp3_44100_128",
              },
              responseType: "arraybuffer",
              timeout: 60000,
            }
          );

          if (!response.data || (response.data.byteLength !== undefined && response.data.byteLength === 0)) {
            throw new Error("[ElevenLabsTTS] Empty audio response from ElevenLabs");
          }

          GlobalTTSConcurrencyManager.recordSuccess();

          const bucket = storage().bucket();
          const filePath = `audio/${request.jobId}/${request.language}/chunk-${uuidv4()}.mp3`;
          const file = bucket.file(filePath);

          // ⚡ Low latency: resumable: false performs direct single-shot PUT upload for small chunks
          await file.save(response.data, {
            resumable: false,
            metadata: {
              contentType: "audio/mpeg",
              metadata: {
                provider: "elevenlabs",
                model: currentModel,
                voiceId,
                language: request.language,
                isVoiceClone: String(Boolean(request.voiceCloneId || request.preferVoiceCloning)),
              },
            },
          });

          const audioUrl = `gs://${bucket.name}/${filePath}`;
          costEngine.recordTTSCost(
            request.jobId,
            request.userId || "__tts__",
            request.text.length,
            "elevenlabs"
          ).catch(() => {});

          logger.info("[ElevenLabsTTS] ✅ Segment synthesized", {
            jobId: request.jobId,
            language: request.language,
            audioUrl,
            bytes: response.data.byteLength,
          });

          return {
            jobId: request.jobId,
            language: request.language,
            audioUrl,
            duration: this.estimateDuration(request.text),
            format: "mp3",
            provider: "elevenlabs",
            voiceName: voiceId,
          };
        } catch (error: any) {
          const statusCode = error.response?.status;
          GlobalTTSConcurrencyManager.recordFailure(Boolean(statusCode && statusCode >= 500));
          let errorBody = error.message;
          if (error.response?.data) {
            try {
              if (Buffer.isBuffer(error.response.data) || error.response.data instanceof ArrayBuffer) {
                errorBody = new TextDecoder().decode(error.response.data);
              } else if (typeof error.response.data === "string") {
                errorBody = error.response.data;
              } else if (typeof (error.response.data as any)?.pipe === "function" || error.response.data instanceof streamLib.Readable) {
                errorBody = error.message || "ElevenLabs stream error";
              } else {
                errorBody = JSON.stringify(error.response.data);
              }
            } catch (_) {
              errorBody = error.message || "ElevenLabs error";
            }
          }

          logger.error("[ElevenLabsTTS] ❌ ElevenLabs API error", {
            jobId: request.jobId,
            language: request.language,
            attempt: attempt + 1,
            statusCode,
            error: errorBody,
            model: currentModel,
            voiceId,
          });

          const isQuota = statusCode === 401 && (
            errorBody.includes("quota_exceeded") ||
            errorBody.includes("credits remaining")
          );
          if (isQuota) {
            logger.error("[ElevenLabsTTS] ❌ Quota exhausted — halting synthesis to prevent partial dubbing", { jobId: request.jobId, error: errorBody });
            const quotaErr = new Error(`ElevenLabs quota exceeded: ${errorBody}`);
            (quotaErr as any).isQuota = true;
            (quotaErr as any).code = "QUOTA_EXCEEDED";
            throw quotaErr;
          }

          const isRateLimitOrConcurrency = statusCode === 429 || (
            typeof errorBody === "string" && (
              errorBody.includes("too_many_concurrent_requests") ||
              errorBody.includes("concurrent_requests_exceeded") ||
              errorBody.includes("rate_limit")
            )
          );
          if (isRateLimitOrConcurrency && attempt < MAX_RETRIES - 1) {
            const retryAfterHeader = error.response?.headers?.["retry-after"];
            let jitterMs = Math.floor(Math.random() * 1000) + 1200 * Math.pow(2, attempt);
            if (retryAfterHeader) {
              const parsedSec = parseInt(retryAfterHeader, 10);
              if (!isNaN(parsedSec) && parsedSec > 0) {
                jitterMs = Math.max(jitterMs, parsedSec * 1000);
              }
            }
            logger.warn(`[ElevenLabsTTS] ⚠️ Rate limit / concurrency limit hit (HTTP 429). Jittered backoff for ${jitterMs}ms before retry.`, {
              jobId: request.jobId,
              attempt: attempt + 1,
              error: errorBody,
              retryAfterHeader,
            });
            await new Promise((r) => setTimeout(r, jitterMs));
            continue;
          }

          if (attempt === MAX_RETRIES - 1) {
            throw new Error(`[ElevenLabsTTS] Failed with model ${TTS_MODELS.v4}: ${statusCode} — ${errorBody}`);
          }

          logger.info("[ElevenLabsTTS] Retrying synthesis strictly with eleven_v4", {
            jobId: request.jobId,
            nextAttempt: attempt + 2,
            model: TTS_MODELS.v4,
          });

          const delay = 1000 * Math.pow(2, attempt);
          await new Promise((r) => setTimeout(r, delay));
        }
      }
      throw new Error("[ElevenLabsTTS] Synthesize failed after all retries");
    } finally {
      releaseSlot();
    }
  }

  private estimateDuration(text: string): number {
    return text.length / 15;
  }

  /**
   * Clones a creator's voice using ElevenLabs Instant Voice Cloning (/v1/voices/add).
   * Downloads the audio sample from GCS or HTTPS, builds multipart/form-data,
   * calls /v1/voices/add, and returns the newly generated voice_id.
   */
  async cloneVoice(name: string, audioUrl: string): Promise<string> {
    const apiKey = this.getApiKey();
    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] API key missing for voice cloning");
    }

    let audioBuffer: Buffer;
    if (audioUrl.startsWith("gs://")) {
      const parts = audioUrl.replace("gs://", "").split("/");
      const bucketName = parts[0];
      const filePath = parts.slice(1).join("/");
      const [downloaded] = await storage().bucket(bucketName).file(filePath).download();
      audioBuffer = downloaded;
    } else {
      const resp = await axios.get(audioUrl, { responseType: "arraybuffer", timeout: 30000 });
      audioBuffer = Buffer.from(resp.data);
    }

    const formData = new FormData();
    formData.append("name", name);
    formData.append("description", `TruthWorld voice clone for ${name}`);
    const blob = new Blob([new Uint8Array(audioBuffer)], { type: "audio/mpeg" });
    formData.append("files", blob, "sample.mp3");

    const response = await axios.post(`${ELEVENLABS_BASE_URL}/voices/add`, formData, {
      headers: {
        "xi-api-key": apiKey,
      },
      timeout: 60000,
    });

    if (!response.data || !response.data.voice_id) {
      throw new Error("[ElevenLabsTTS] Voice cloning failed: missing voice_id in response");
    }

    const voiceId: string = response.data.voice_id;
    logger.info("[ElevenLabsTTS] ✅ Instant voice clone created", { name, voiceId });
    return voiceId;
  }

  /**
   * Cleans up a temporary cloned voice from ElevenLabs.
   */
  async deleteVoice(voiceId: string): Promise<boolean> {
    const apiKey = this.getApiKey();
    if (!apiKey || !voiceId) return false;
    try {
      await axios.delete(`${ELEVENLABS_BASE_URL}/voices/${voiceId}`, {
        headers: { "xi-api-key": apiKey },
        timeout: 10000,
      });
      logger.info("[ElevenLabsTTS] ✅ Cleaned up temporary voice clone", { voiceId });
      return true;
    } catch (err: any) {
      logger.warn("[ElevenLabsTTS] Could not delete voice (preset or already removed)", { voiceId, err: err?.message });
      return false;
    }
  }

  /**
   * Verifies the ElevenLabs API key and checks account quota without consuming character credits.
   * Strictly invokes GET /v1/user/subscription (0 characters / $0.00 cost).
   */
  async verifyConnection(): Promise<{
    valid: boolean;
    tier: string;
    characterCount: number;
    characterLimit: number;
    canUseInstantVoiceCloning: boolean;
    status: string;
  }> {
    const apiKey = this.getApiKey();
    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] No ElevenLabs API key configured in environment");
    }

    const response = await axios.get(`${ELEVENLABS_BASE_URL}/user/subscription`, {
      headers: { "xi-api-key": apiKey },
      timeout: 10000,
    });

    const data = response.data || {};
    return {
      valid: true,
      tier: data.tier || "unknown",
      characterCount: Number(data.character_count ?? 0),
      characterLimit: Number(data.character_limit ?? 0),
      canUseInstantVoiceCloning: Boolean(data.can_use_instant_voice_cloning),
      status: data.status || "active",
    };
  }
}

export class TTSService {
  private elevenLabsTts: ElevenLabsTTSService;

  constructor(
    _legacyProvider?: any,
    elevenLabsTts?: ElevenLabsTTSService
  ) {
    this.elevenLabsTts = elevenLabsTts || new ElevenLabsTTSService();
  }

  public async verifyElevenLabsConnection(): Promise<{
    valid: boolean;
    tier: string;
    characterCount: number;
    characterLimit: number;
    canUseInstantVoiceCloning: boolean;
    status: string;
  }> {
    return this.elevenLabsTts.verifyConnection();
  }

  /**
   * Unified synthesis entry point.
   * - Video Audio Tracks Dubbing & Voice Cloning: Strictly powered by ElevenLabs v4 (`eleven_v4`).
   *   Zero fallback models or alternative providers.
   *   Google Cloud Text-to-Speech (Chirp 3: HD / Neural2 / etc.) has been completely terminated.
   *   All dubbing strictly routes to ElevenLabs v4 (`eleven_v4`).
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const apiKey = this.elevenLabsTts.getApiKey();
    if (!apiKey || apiKey.trim().length === 0 || apiKey.includes("YOUR_") || apiKey.includes("placeholder")) {
      logger.error("[TTS] ❌ ElevenLabs API key is missing. Video dubbing strictly requires ElevenLabs v4.", {
        jobId: request.jobId,
        language: request.language,
      });
      throw new Error("ElevenLabs API key is missing. Video dubbing strictly requires ElevenLabs v4.");
    }

    logger.info("[TTS] Synthesizing audio track strictly with ElevenLabs v4 (eleven_v4, zero fallback models)", {
      jobId: request.jobId,
      language: request.language,
      voiceCloneId: request.voiceCloneId,
      preferVoiceCloning: request.preferVoiceCloning,
      textLength: request.text?.length,
    });

    return await this.elevenLabsTts.synthesize(request);
  }

  public estimateDuration(text: string): number {
    return text.length / 15;
  }

  public async cloneVoice(name: string, audioUrl: string): Promise<string> {
    return this.elevenLabsTts.cloneVoice(name, audioUrl);
  }

  public async deleteVoice(voiceId: string): Promise<boolean> {
    return this.elevenLabsTts.deleteVoice(voiceId);
  }
}

export const elevenLabsTtsService = new ElevenLabsTTSService();
export const ttsService = new TTSService();

export const DEFAULT_MAX_ELEVENLABS_CONCURRENCY = 15;

/**
 * Adaptive TTS batch size: maximizes ElevenLabs concurrency per video duration
 * while strictly adhering to provider concurrency limits to prevent HTTP 429 cascades.
 *
 * Concurrency tier ceilings:
 *   - Creator tier: 5
 *   - Pro tier: 10
 *   - Scale tier: 15 (default)
 *   - Business/Enterprise tier: 30+ (via ELEVENLABS_MAX_CONCURRENCY)
 */
export function getAdaptiveTTSBatchSize(
  segmentCount: number,
  videoDurationMs: number,
  maxConcurrency: number = parseInt(process.env.ELEVENLABS_MAX_CONCURRENCY || "15", 10)
): number {
  const cap = Math.max(1, maxConcurrency);
  if (videoDurationMs <= 0) return Math.min(25, cap);
  if (videoDurationMs < 180_000) return Math.min(segmentCount, cap);    // ≤ 3 min: bounded mega-batch
  if (videoDurationMs < 600_000) return Math.min(50, cap);             // 3–10 min: bounded batch
  return Math.min(25, cap);                                            // >10 min: conservative
}

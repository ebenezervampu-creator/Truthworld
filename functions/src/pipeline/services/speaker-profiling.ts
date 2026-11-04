/**
 * 👥 SPEAKER INTELLIGENCE SERVICE
 * 
 * Uses Gemini 2.5 Flash to profile speakers in a transcript, enabling 
 * accurate voice matching and identity preservation.
 */

import { PIPELINE_CONFIG } from "../config";
import { Utterance } from "../types";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText, normalizeToGcsUri } from "../utils/ai-utils";

const genAI = getVertexAI();

export interface SpeakerProfile {
  speakerId:   string;
  gender:      "male" | "female";
  style:       string;   // e.g. "warm", "energetic", "monotone"
  pitchBand:   "high" | "mid" | "deep";
  energy:      "high" | "moderate" | "low";
  ageTone:     "youthful" | "adult" | "mature";
  role:        "host" | "guest" | "expert" | "caller" | "other"; // v5.3: Path 2 Role Awareness
  wordCount:   number;
  segments:    number;
}

export class SpeakerProfilingService {
  private readonly model = genAI.getGenerativeModel({
    model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash",
  });

  /**
   * Profile all speakers in a transcript.
   * If audioUrl is provided, Gemini listens directly to the audio recording to analyze
   * the acoustic pitch and vocal resonance of the speaker's voice.
   */
  async profileSpeakers(
    utterances: Utterance[],
    audioUrl?: string,
    options?: { preferredGender?: "auto" | "male" | "female" }
  ): Promise<SpeakerProfile[]> {
    logger.info("[SpeakerIntelligence] Profiling speakers", {
      count: utterances.length,
      hasAudio: Boolean(audioUrl),
      preferredGender: options?.preferredGender,
    });

    const gcsUri = audioUrl
      ? (normalizeToGcsUri(audioUrl) || (audioUrl.startsWith("gs://") ? audioUrl : null))
      : null;

    // 1. Group utterances by speaker
    const speakerMap = new Map<string, Utterance[]>();
    utterances.forEach(u => {
      const id = u.speaker || "speaker_0";
      if (!speakerMap.has(id)) speakerMap.set(id, []);
      speakerMap.get(id)!.push(u);
    });

    const profiles: SpeakerProfile[] = [];

    // 2. Sample and profile each speaker concurrently in parallel
    const entries = Array.from(speakerMap.entries());
    const profiledList = await Promise.all(
      entries.map(async ([id, speakerUtterances]) => {
        const textSample = speakerUtterances.slice(0, 5).map(u => u.text).join(" ");
        const wordCount = speakerUtterances.reduce((sum, u) => sum + u.text.split(" ").length, 0);

        try {
          const prompt = `You are an expert audio and vocal intelligence engine.
Analyze this speaker's voice, style, and vocal characteristics.
Speech transcript sample: "${textSample}"

CRITICAL GENDER DETECTION GUIDELINES:
- Listen carefully to acoustic vocal pitch and resonance. Adult male voices typically have lower fundamental frequency (F0 < 165Hz) and chest resonance; female voices typically have higher pitch (F0 > 175Hz).
- In music videos, songs, and sung vocals: evaluate the singer's vocal register. If the singer sings with a male chest voice, tenor, baritone, or bass register, strictly classify as "male". Only classify as "female" if the singer has a clearly feminine soprano/alto vocal timbre.
- In conversations between a male speaker and a female speaker, strictly distinguish the male speaker (gender: "male") from the female speaker (gender: "female").
- Never classify a female speaker as "male", and never classify a male speaker or singer as "female".

Return a JSON object with:
- gender: ["male", "female"] (Mandatory: Determine speaker gender accurately from acoustics, pitch resonance, and linguistic markers)
- style: Short description of tone (e.g. "warm confident", "fast energetic")
- pitchBand: ["high", "mid", "deep"]
- energy: ["high", "moderate", "low"]
- ageTone: ["youthful", "adult", "mature"]
- role: Detect their role in the conversation ["host", "guest", "expert", "caller", "other"]

Return ONLY valid JSON.`;

          let result;
          if (gcsUri) {
            const mimeType = gcsUri.endsWith(".wav")
              ? "audio/wav"
              : (gcsUri.endsWith(".mp3") ? "audio/mp3" : "video/mp4");

            result = await this.model.generateContent({
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
            });
          } else {
            result = await this.model.generateContent(prompt);
          }

          const text = extractCandidateText(result.response.candidates?.[0]) || result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
          const jsonMatch = text.match(/\{[\s\S]*\}/);
          
          if (!jsonMatch) throw new Error("No JSON in speaker profile response");
          const parsed = JSON.parse(jsonMatch[0]);

          const detectedGender: "male" | "female" = options?.preferredGender && options.preferredGender !== "auto"
            ? options.preferredGender
            : (parsed.gender && String(parsed.gender).toLowerCase().includes("fem") ? "female" : "male");

          return {
            speakerId: id,
            wordCount,
            segments:  speakerUtterances.length,
            ...parsed,
            gender: detectedGender,
          };
        } catch (error) {
          logger.warn("[SpeakerIntelligence] Failed to profile speaker, applying linguistic heuristic fallback", { id, error });
          const femaleMarkers = /\b(girl|she|her|hers|woman|madam|lady|daughter|sister|aunt|mrs|ms|mam|student girl|karti|rahi|gayi|cheptondi|chestundi)\b/i;
          const maleMarkers = /\b(he|him|his|sir|man|gentleman|son|brother|uncle|mr|boy|teacher|karta|raha|gaya|unnadu|cheptunnadu)\b/i;
          const isFeminine = femaleMarkers.test(textSample);
          const isMasculine = maleMarkers.test(textSample);
          const fallbackGender: "male" | "female" = options?.preferredGender && options.preferredGender !== "auto"
            ? options.preferredGender
            : (isFeminine && !isMasculine ? "female" : "male");

          return {
            speakerId: id,
            gender: fallbackGender,
            style: "neutral",
            pitchBand: fallbackGender === "female" ? "high" : "mid",
            energy: "moderate",
            ageTone: fallbackGender === "female" ? "youthful" : "adult",
            role: fallbackGender === "female" ? "guest" : "host",
            wordCount,
            segments:  speakerUtterances.length,
          };
        }
      })
    );
    profiles.push(...profiledList);

    return profiles.sort((a, b) => b.wordCount - a.wordCount);
  }
}

export const speakerProfilingService = new SpeakerProfilingService();

/**
 * 👥 SPEAKER INTELLIGENCE SERVICE
 * 
 * Uses Gemini 2.0 to profile speakers in a transcript, enabling 
 * accurate voice matching and identity preservation.
 */

import { PIPELINE_CONFIG } from "../config";
import { Utterance } from "../types";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";

const genAI = getVertexAI();

export interface SpeakerProfile {
  speakerId:   string;
  style:       string;   // e.g. "warm", "energetic", "monotone"
  pitchBand:   "high" | "mid" | "deep";
  energy:      "high" | "moderate" | "low";
  ageTone:     "youthful" | "adult" | "mature";
  role:        "host" | "guest" | "expert" | "caller" | "other"; // v5.3: Path 2 Role Awareness
  wordCount:   number;
  segments:    number;
}

export class SpeakerProfilingService {
  private readonly model = genAI.getGenerativeModel({ model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash" });

  /**
   * Profile all speakers in a transcript
   */
  async profileSpeakers(utterances: Utterance[]): Promise<SpeakerProfile[]> {
    logger.info("[SpeakerIntelligence] Profiling speakers", { count: utterances.length });

    // 1. Group utterances by speaker
    const speakerMap = new Map<string, Utterance[]>();
    utterances.forEach(u => {
      const id = u.speaker || "speaker_0";
      if (!speakerMap.has(id)) speakerMap.set(id, []);
      speakerMap.get(id)!.push(u);
    });

    const profiles: SpeakerProfile[] = [];

    // 2. Sample and profile each speaker
    for (const [id, speakerUtterances] of speakerMap.entries()) {
      const textSample = speakerUtterances.slice(0, 5).map(u => u.text).join(" ");
      const wordCount = speakerUtterances.reduce((sum, u) => sum + u.text.split(" ").length, 0);

      try {
        const prompt = `Analyze this speaker's style and characteristics based on their speech: "${textSample}"
Return a JSON object with:
- style: Short description of tone (e.g. "warm confident", "fast energetic")
- pitchBand: [high, mid, deep]
- energy: [high, moderate, low]
- ageTone: [youthful, adult, mature]
- role: Detect their role in the conversation [host, guest, expert, caller, other]

Return ONLY valid JSON.`;

        const result = await this.model.generateContent(prompt);
        const text = extractCandidateText(result.response.candidates?.[0]) || result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        
        if (!jsonMatch) throw new Error("No JSON in speaker profile response");
        const parsed = JSON.parse(jsonMatch[0]);

        profiles.push({
          speakerId: id,
          wordCount,
          segments:  speakerUtterances.length,
          ...parsed
        });
      } catch (error) {
        logger.warn("[SpeakerIntelligence] Failed to profile speaker", { id, error });
        // Fallback for failed profiling
        profiles.push({
          speakerId: id,
          style: "neutral",
          pitchBand: "mid",
          energy: "moderate",
          ageTone: "adult",
          role: "other",
          wordCount,
          segments: speakerUtterances.length
        });
      }
    }

    return profiles.sort((a, b) => b.wordCount - a.wordCount);
  }
}

export const speakerProfilingService = new SpeakerProfilingService();

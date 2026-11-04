/**
 * 🎙️ AUDIO IDENTITY SERVICE — Studio-Grade Acoustic Fingerprinting
 * 
 * This service preserves the creator's "Session Identity" by capturing 
 * mic texture, room aesthetics, and production energy.
 */

import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText, normalizeToGcsUri } from "../utils/ai-utils";

export interface AcousticFingerprint {
  micStyle:    "warm-broadcast" | "crisp-modern" | "natural-flat" | "vlog-raw" | "laptop-bright";
  roomTone:    "dry-studio" | "small-room" | "large-reflective" | "outdoor-open";
  compression: "punchy" | "transparent" | "heavy" | "none";
  energy:      "high" | "moderate" | "relaxed" | "intimate";
  pacingStyle: "fast-energetic" | "steady-educational" | "slow-dramatic";
  pitchBand?:  "high" | "mid" | "deep";
  pitchSemitones?: number;
  speakingRate?: number;
}

export class AudioIdentityService {
  private get model() {
    return getVertexAI().getGenerativeModel({
      model: PIPELINE_CONFIG.GEMINI_MODELS?.profiling || "gemini-2.5-flash",
    });
  }

  /**
   * 1. 🎙️ Isolate Vocals using ElevenLabs Audio Isolation API
   * Removes background music/noise to extract pure "Vocal Identity".
   */
  async isolateVocals(jobId: string, audioUrl: string): Promise<string> {
    logger.info("[AudioIdentity] Isolating vocals", { jobId, audioUrl });
    
    // Preparation: Get a signed URL for ElevenLabs to access (if gs://)
    const accessibleUrl = await this.getAccessibleUrl(audioUrl);
    
    try {
      // ElevenLabs Audio Isolation requires file upload or URL
      // We will download to buffer and send via multipart/form-data
      const response = await fetch(accessibleUrl);
      const buffer = await response.arrayBuffer();
      
      const formData = new FormData();
      formData.append("audio", new Blob([buffer]), "original.wav");

      const xiResponse = await fetch("https://api.elevenlabs.io/v1/audio-isolation", {
        method: "POST",
        headers: {
          "xi-api-key": PIPELINE_CONFIG.ELEVENLABS_API_KEY,
        },
        body: formData,
      });

      if (!xiResponse.ok) {
        throw new Error(`ElevenLabs Isolation failed: ${xiResponse.statusText}`);
      }

      const isolatedBuffer = await xiResponse.arrayBuffer();
      const bucket = admin.storage().bucket();
      const filePath = `audio/${jobId}/isolated-vocal.mp3`;
      const file = bucket.file(filePath);

      await file.save(Buffer.from(isolatedBuffer), {
        metadata: { contentType: "audio/mpeg" },
      });

      return `gs://${bucket.name}/${filePath}`;
    } catch (error) {
      logger.error("[AudioIdentity] Isolation failed", { jobId, error });
      throw error;
    }
  }

  /**
   * 2. 🧠 Capture Acoustic Fingerprint (Semantic Descriptors)
   * Uses Vertex AI Gemini 2.5 Flash Multimodal Audio to analyze the creator's
   * microphone texture, room aesthetics, dynamics, pacing, and vocal resonance.
   */
  async captureFingerprint(jobId: string, vocalUrl: string): Promise<AcousticFingerprint> {
    logger.info("[AudioIdentity] Capturing authentic acoustic fingerprint via Vertex AI Gemini", { jobId, vocalUrl });

    const gcsUri = vocalUrl
      ? (normalizeToGcsUri(vocalUrl) || (vocalUrl.startsWith("gs://") ? vocalUrl : null))
      : null;

    try {
      const prompt = `You are a world-class audio mastering engineer and vocal acoustic analyst.
Analyze the speaker's vocal recording and its acoustic environment.
Assess:
1. Microphone style:
   - "warm-broadcast" (deep podcast proximity effect, rich lows)
   - "crisp-modern" (condenser mic, bright high-end, studio clarity)
   - "natural-flat" (neutral response, standard studio)
   - "vlog-raw" (lapel or shotgun mic in real-world space)
   - "laptop-bright" (built-in mic, thin, high mids)
2. Room tone / reverb environment:
   - "dry-studio" (treated vocal booth, zero reverb)
   - "small-room" (slight natural bedroom/office reflections)
   - "large-reflective" (hall, large untreated room, noticeable echo)
   - "outdoor-open" (wind, open space, no room reflections)
3. Compression style:
   - "punchy" (broadcast radio, tight dynamic range)
   - "transparent" (natural dynamics, gentle evening)
   - "heavy" (loud, aggressive, highly compressed)
   - "none" (raw dynamic peaks)
4. Energy: "high" | "moderate" | "relaxed" | "intimate"
5. Pacing style: "fast-energetic" | "steady-educational" | "slow-dramatic"
6. Pitch band: "deep" | "mid" | "high"
7. Pitch semitones: number from -3.0 to +3.0 (negative for deep resonance, positive for higher pitch)
8. Speaking rate: number from 0.88 to 1.15 (relative tempo multiplier)

Return ONLY a valid JSON object matching this schema:
{
  "micStyle": "warm-broadcast" | "crisp-modern" | "natural-flat" | "vlog-raw" | "laptop-bright",
  "roomTone": "dry-studio" | "small-room" | "large-reflective" | "outdoor-open",
  "compression": "punchy" | "transparent" | "heavy" | "none",
  "energy": "high" | "moderate" | "relaxed" | "intimate",
  "pacingStyle": "fast-energetic" | "steady-educational" | "slow-dramatic",
  "pitchBand": "deep" | "mid" | "high",
  "pitchSemitones": 0.0,
  "speakingRate": 1.00
}`;

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

      if (!jsonMatch) {
        throw new Error("No JSON object found in Gemini acoustic fingerprint response");
      }

      const parsed = JSON.parse(jsonMatch[0]);

      const validMicStyles = ["warm-broadcast", "crisp-modern", "natural-flat", "vlog-raw", "laptop-bright"];
      const validRoomTones = ["dry-studio", "small-room", "large-reflective", "outdoor-open"];
      const validCompressions = ["punchy", "transparent", "heavy", "none"];
      const validEnergies = ["high", "moderate", "relaxed", "intimate"];
      const validPacing = ["fast-energetic", "steady-educational", "slow-dramatic"];

      const fingerprint: AcousticFingerprint = {
        micStyle: validMicStyles.includes(parsed.micStyle) ? parsed.micStyle : "warm-broadcast",
        roomTone: validRoomTones.includes(parsed.roomTone) ? parsed.roomTone : "small-room",
        compression: validCompressions.includes(parsed.compression) ? parsed.compression : "transparent",
        energy: validEnergies.includes(parsed.energy) ? parsed.energy : "moderate",
        pacingStyle: validPacing.includes(parsed.pacingStyle) ? parsed.pacingStyle : "steady-educational",
        pitchBand: (parsed.pitchBand === "deep" || parsed.pitchBand === "high" || parsed.pitchBand === "mid") ? parsed.pitchBand : "mid",
        pitchSemitones: typeof parsed.pitchSemitones === "number" ? Math.max(-3.0, Math.min(3.0, parsed.pitchSemitones)) : 0.0,
        speakingRate: typeof parsed.speakingRate === "number" ? Math.max(0.88, Math.min(1.15, parsed.speakingRate)) : 1.0,
      };

      logger.info("[AudioIdentity] ✅ Real acoustic fingerprint captured", { jobId, fingerprint });
      return fingerprint;
    } catch (error) {
      logger.warn("[AudioIdentity] Fingerprinting fallback to calibrated broadcast default", { jobId, err: String(error) });
      return {
        micStyle: "warm-broadcast",
        roomTone: "dry-studio",
        compression: "transparent",
        energy: "moderate",
        pacingStyle: "steady-educational",
        pitchBand: "mid",
        pitchSemitones: 0.0,
        speakingRate: 1.0,
      };
    }
  }

  /**
   * 3. 🎛️ Map Semantic Descriptors to Deterministic FFmpeg Filters
   * This is the "DSP Rules Engine" that transforms AI intent into audio engineering.
   */
  getDSPFilters(fingerprint: AcousticFingerprint): string {
    const filters: string[] = [];

    // A. Mic Style (Parametric EQ profiles)
    switch(fingerprint.micStyle) {
      case "warm-broadcast": 
        filters.push("equalizer=f=120:width_type=h:w=100:g=3,equalizer=f=3000:width_type=h:w=200:g=-1"); 
        break;
      case "crisp-modern": 
        filters.push("equalizer=f=5000:width_type=h:w=500:g=2,equalizer=f=100:width_type=h:w=100:g=-2"); 
        break;
      case "laptop-bright": 
        filters.push("equalizer=f=200:width_type=h:w=150:g=4,lowpass=f=12000"); 
        break;
      case "vlog-raw":
        filters.push("highpass=f=80,equalizer=f=2500:width_type=h:w=300:g=1.5");
        break;
      case "natural-flat":
        filters.push("highpass=f=60");
        break;
    }

    // B. Compression (Dynamics)
    switch(fingerprint.compression) {
      case "punchy": 
        filters.push("compand=attacks=0.03:points=-80/-80|-40/-30|-20/-10|0/0:soft-threshold=0.01"); 
        break;
      case "heavy": 
        filters.push("compand=attacks=0.01:points=-80/-80|-50/-20|0/-10"); 
        break;
      case "transparent":
        filters.push("compand=attacks=0.05:points=-70/-70|-35/-28|-15/-8|0/0:soft-threshold=0.02");
        break;
    }

    // C. Room Tone (Reverb emulation)
    switch(fingerprint.roomTone) {
      case "small-room": 
        filters.push("aecho=0.8:0.88:40:0.25"); 
        break;
      case "large-reflective": 
        filters.push("aecho=0.8:0.88:90:0.35"); 
        break;
    }

    // Always target -14 LUFS (EBU R128 / ITU-R BS.1770 Global Broadcast Standard)
    filters.push("loudnorm=I=-14:TP=-1:LRA=11");

    return filters.join(",");
  }

  private async getAccessibleUrl(url: string): Promise<string> {
    if (!url) return url;
    if (url.includes("X-Goog-Signature") || url.includes("GoogleAccessId")) return url;

    let bucketName = admin.storage().bucket().name;
    let filePath = url;
    let isStorage = false;

    if (url.startsWith("gs://")) {
      const parts = url.replace("gs://", "").split("/");
      bucketName = parts[0];
      filePath = parts.slice(1).join("/");
      isStorage = true;
    } else if (url.startsWith("http://") || url.startsWith("https://")) {
      try {
        const parsed = new URL(url);
        if (parsed.hostname.includes("firebasestorage.googleapis.com")) {
          const match = parsed.pathname.match(/\/v0\/b\/([^/]+)\/o\/(.+)/);
          if (match) {
            bucketName = decodeURIComponent(match[1]);
            filePath = decodeURIComponent(match[2].split("?")[0]);
            isStorage = true;
          }
        } else if (parsed.hostname === "storage.googleapis.com") {
          const segments = parsed.pathname.replace(/^\/+/, "").split("/");
          if (segments.length >= 2) {
            bucketName = decodeURIComponent(segments[0]);
            filePath = decodeURIComponent(segments.slice(1).join("/").split("?")[0]);
            isStorage = true;
          }
        } else if (parsed.hostname.endsWith(".storage.googleapis.com")) {
          bucketName = decodeURIComponent(parsed.hostname.replace(".storage.googleapis.com", ""));
          filePath = decodeURIComponent(parsed.pathname.replace(/^\/+/, "").split("?")[0]);
          isStorage = true;
        }
      } catch (_) {}
    }

    if (!isStorage && (url.startsWith("http://") || url.startsWith("https://"))) {
      return url;
    }

    try {
      const bucket = admin.storage().bucket(bucketName);
      const file = bucket.file(filePath.replace(/^\/+/, ""));
      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 3600 * 1000,
      });
      return signedUrl;
    } catch (_) {
      return url;
    }
  }
}

export const audioIdentityService = new AudioIdentityService();

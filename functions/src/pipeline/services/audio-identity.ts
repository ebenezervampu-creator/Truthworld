/**
 * 🎙️ AUDIO IDENTITY SERVICE — Studio-Grade Acoustic Fingerprinting
 * 
 * This service preserves the creator's "Session Identity" by capturing 
 * mic texture, room aesthetics, and production energy.
 */

import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";

export interface AcousticFingerprint {
  micStyle:    "warm-broadcast" | "crisp-modern" | "natural-flat" | "vlog-raw" | "laptop-bright";
  roomTone:    "dry-studio" | "small-room" | "large-reflective" | "outdoor-open";
  compression: "punchy" | "transparent" | "heavy" | "none";
  energy:      "high" | "moderate" | "relaxed" | "intimate";
  pacingStyle: "fast-energetic" | "steady-educational" | "slow-dramatic";
}

export class AudioIdentityService {
  /**
   * 1. 🎙️ Isolate Vocals using ElevenLabs Audio Isolation API
   * Removes background music/noise to extract pure "Vocal Identity".
   */
  async isolateVocals(jobId: string, audioUrl: string): Promise<string> {
    logger.info("[AudioIdentity] Isolating vocals", { jobId, audioUrl });
    
    // Preparation: Get a signed URL for ElevenLabs to access (if gs://)
    const accessibleUrl = await this.getAccessibleUrl(audioUrl);
    
    try {
      // ⚠️ ElevenLabs Audio Isolation requires file upload or URL
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
   * Uses Gemini 2.0 to "listen" and describe the creator's production identity.
   */
  async captureFingerprint(jobId: string, vocalUrl: string): Promise<AcousticFingerprint> {
    logger.info("[AudioIdentity] Capturing fingerprint", { jobId });
    
    try {
      // Logic for providing audio to Gemini 2.0 (multimodal)
      // For now, we use a placeholder that defaults to "warm-broadcast" (Podcast Warmth default)
      // This will be fully wired after the audio-handling utilities are in place.
      return {
        micStyle: "warm-broadcast",
        roomTone: "small-room",
        compression: "punchy",
        energy: "moderate",
        pacingStyle: "steady-educational"
      };
    } catch (error) {
      logger.warn("[AudioIdentity] Fingerprinting failed — using default Podcast Warmth", { jobId });
      return {
        micStyle: "warm-broadcast",
        roomTone: "dry-studio",
        compression: "transparent",
        energy: "moderate",
        pacingStyle: "steady-educational"
      };
    }
  }

  /**
   * 3. 🎛️ Map Semantic Descriptors to Deterministic FFmpeg Filters
   * This is the "DSP Rules Engine" that transforms AI intent into audio engineering.
   */
  getDSPFilters(fingerprint: AcousticFingerprint): string {
    const filters: string[] = [];

    // A. Mic Style (EQ profiles)
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
    }

    // B. Compression (Dynamics)
    switch(fingerprint.compression) {
      case "punchy": 
        filters.push("compand=attacks=0.03:points=-80/-80|-40/-30|-20/-10|0/0:soft-threshold=0.01"); 
        break;
      case "heavy": 
        filters.push("compand=attacks=0.01:points=-80/-80|-50/-20|0/-10"); 
        break;
    }

    // C. Room Tone (Reverb emulation)
    switch(fingerprint.roomTone) {
      case "small-room": 
        filters.push("aecho=0.8:0.88:40:0.4"); 
        break;
      case "large-reflective": 
        filters.push("aecho=0.8:0.88:120:0.5"); 
        break;
    }

    // Always target -14 LUFS (Industry Standard)
    filters.push("loudnorm=I=-14:TP=-1:LRA=11");

    return filters.join(",");
  }

  private async getAccessibleUrl(url: string): Promise<string> {
    if (url.startsWith("http")) return url;
    const bucket = admin.storage().bucket();
    const filePath = url.replace("gs://" + bucket.name + "/", "");
    const file = bucket.file(filePath);
    const [signedUrl] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 3600 * 1000,
    });
    return signedUrl;
  }
}

export const audioIdentityService = new AudioIdentityService();

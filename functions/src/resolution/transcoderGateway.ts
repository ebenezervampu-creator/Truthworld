/**
 * ☁️ GOOGLE CLOUD TRANSCODER API GATEWAY
 *
 * Decoupled enterprise video transcoding service for heavy & long-form media.
 * Bypasses Cloud Functions 540s/60min timeout & memory limits (OOM prevention)
 * by delegating 4K and long-duration videos (> 15 minutes or > 500MB) directly
 * to the Google Cloud Video Transcoder API.
 *
 * ✅ Features:
 *   - Auto-detection of long-form or 4K/high-bitrate videos
 *   - Automated Google Cloud Transcoder v1 Job specification
 *   - HLS adaptive bitrate master manifest output (master.m3u8)
 *   - Fallback reconciliation and job polling
 */

import * as admin from "firebase-admin";
import axios from "axios";
import { tierFitsSource } from "./resolutionPlanning";

export interface TranscoderProfile {
  label: string;
  height: number;
  width: number;
  bitrateBps: number;
  frameRate?: number;
}

export interface TranscodeJobResult {
  jobId: string;
  name: string;
  state: "PENDING" | "RUNNING" | "SUCCEEDED" | "FAILED";
  outputUri: string;
  labels?: Record<string, string>;
  error?: any;
}

export class TranscoderGateway {
  private static readonly LOCATION = "asia-south1";
  private static readonly API_BASE = "https://transcoder.googleapis.com/v1";

  /**
   * Evaluates whether a video should bypass local Cloud Function ffmpeg
   * and be routed to Google Cloud Transcoder API.
   *
   * Gated on:
   * 1. File size > 500 MB (short-circuit before probing to save bandwidth/RAM)
   * 2. Duration > 10 minutes (600s: prevents exceeding the 540s event-driven worker timeout)
   * 3. 4K Ultra HD (shorter dimension > 1080p), guarded by Transcoder API minimum requirement (duration >= 5s)
   */
  static isLongFormOr4K(params: {
    fileSizeBytes?: number;
    durationSeconds?: number;
    height?: number;
    width?: number;
  }): boolean {
    const { fileSizeBytes = 0, durationSeconds = 0, height = 0, width = 0 } = params;

    // Threshold 1: File size > 500 MB (524,288,000 bytes)
    if (fileSizeBytes > 500 * 1024 * 1024) return true;

    // Threshold 2: Duration > 10 minutes (600 seconds) - guarantees 0 risk of 540s timeout
    if (durationSeconds > 600) return true;

    // Threshold 3: 4K Ultra HD (shorter dimension > 1080p, portrait & landscape aware)
    // Transcoder API requires input duration >= 5s
    const shortSide = (height > 0 && width > 0) ? Math.min(height, width) : height;
    if (shortSide > 1080 && (durationSeconds === 0 || durationSeconds >= 5)) return true;

    return false;
  }

  /**
   * Computes optimal periodic sprite interval to prevent sprite explosion on long videos.
   * Keeps the total sprite sheets bounded to ~6-12 sheets regardless of duration.
   * - <= 10m: 3s
   * - 10-30m: 5s
   * - 30-60m: 10s
   * - > 60m: 15s
   */
  static calculateSpriteInterval(durationSeconds?: number): string {
    const sec = Number(durationSeconds) || 600;
    if (sec > 3600) return "15s"; // > 1 hr
    if (sec > 1800) return "10s"; // 30-60 min
    if (sec > 600) return "5s";   // 10-30 min
    return "3s";                  // <= 10 min
  }

  /**
   * Builds dynamic resolution ladder for GCP Transcoder based on source dimensions.
   * - Prevents upscaling (never generates 1080p for a 480p or 720p source)
   * - Supports 4K (2160p, 1440p) when source is 4K
   * - Preserves aspect ratio for both portrait and landscape videos without squashing
   */
  static buildDynamicProfiles(params: {
    sourceWidth?: number;
    sourceHeight?: number;
    sourceFps?: number;
  }): TranscoderProfile[] {
    const { sourceWidth = 0, sourceHeight = 0, sourceFps = 30 } = params;
    const isPortrait = sourceHeight > 0 && sourceWidth > 0 && sourceHeight > sourceWidth;
    const shortSide = (sourceHeight > 0 && sourceWidth > 0)
      ? Math.min(sourceWidth, sourceHeight)
      : (sourceHeight || 1080);
    const fps = sourceFps >= 50 ? 60 : 30;

    const ALL_TIERS = [
      { label: "2160p", shortSide: 2160, bitrateBps: 18000000 },
      { label: "1440p", shortSide: 1440, bitrateBps: 10000000 },
      { label: "1080p", shortSide: 1080, bitrateBps: 4500000 },
      { label: "720p",  shortSide: 720,  bitrateBps: 2500000 },
      { label: "480p",  shortSide: 480,  bitrateBps: 1200000 },
      { label: "360p",  shortSide: 360,  bitrateBps: 600000 },
    ];

    // +16 px tolerance so a 1918x1078 source still gets its 1080p tier (re-audit R8)
    const applicable = ALL_TIERS.filter((t) => tierFitsSource(t.shortSide, shortSide));
    const selectedTiers = applicable.length > 0 ? applicable : [ALL_TIERS[ALL_TIERS.length - 1]];

    return selectedTiers.map((t) => {
      const tierFps = fps === 60 && t.shortSide >= 720 ? 60 : 30;
      const label = tierFps === 60 ? `${t.shortSide}p60` : `${t.shortSide}p`;
      const bitrateBps = tierFps === 60 ? Math.round(t.bitrateBps * 1.5) : t.bitrateBps;
      return {
        label,
        height: isPortrait ? 0 : t.shortSide, // 0 = auto-calculate aspect ratio in GCP Transcoder
        width: isPortrait ? t.shortSide : 0,  // 0 = auto-calculate aspect ratio in GCP Transcoder
        bitrateBps,
        frameRate: tierFps,
      };
    });
  }

  /**
   * Retrieves OAuth2 Access Token using Google Cloud Application Default Credentials.
   */
  private static async getAccessToken(): Promise<string> {
    const credential = admin.credential.applicationDefault();
    const token = await credential.getAccessToken();
    return token.access_token;
  }

  /**
   * Submits a batch transcoding job to Google Cloud Transcoder API.
   */
  static async submitTranscodingJob(params: {
    videoId: string;
    inputGcsUri: string;
    outputGcsUri: string;
    profiles?: TranscoderProfile[];
    durationSeconds?: number;
    hasAudio?: boolean;
    sourceWidth?: number;
    sourceHeight?: number;
    sourceFps?: number;
  }): Promise<TranscodeJobResult> {
    const {
      videoId,
      inputGcsUri,
      outputGcsUri,
      profiles,
      durationSeconds,
      hasAudio = true,
      sourceWidth,
      sourceHeight,
      sourceFps,
    } = params;
    const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || "truthworld-1";
    const parent = `projects/${projectId}/locations/${this.LOCATION}`;

    const activeProfiles: TranscoderProfile[] = (profiles && profiles.length > 0)
      ? profiles
      : this.buildDynamicProfiles({ sourceWidth, sourceHeight, sourceFps });

    // Build elementary video and audio streams
    const elementaryStreams: any[] = [];
    if (hasAudio) {
      elementaryStreams.push({
        key: "audio-stream",
        audioStream: {
          codec: "aac",
          bitrateBps: 192000,
          channelCount: 2,
          sampleRateHertz: 48000,
        },
      });
    }

    const muxStreams: any[] = [];
    const hlsManifestElements: string[] = [];

    activeProfiles.forEach((profile) => {
      const streamKey = `video-${profile.label}`;
      const muxKey = `hls-${profile.label}`;

      const h264Settings: Record<string, any> = {
        bitrateBps: profile.bitrateBps,
        frameRate: profile.frameRate || 30,
        pixelFormat: "yuv420p",
        rateControlMode: "vbr",
      };
      if (profile.height && profile.height > 0) {
        h264Settings.heightPixels = profile.height;
      }
      if (profile.width && profile.width > 0) {
        h264Settings.widthPixels = profile.width;
      }

      elementaryStreams.push({
        key: streamKey,
        videoStream: {
          h264: h264Settings,
        },
      });

      const elementaryStreamKeys = [streamKey];
      if (hasAudio) {
        elementaryStreamKeys.push("audio-stream");
      }

      muxStreams.push({
        key: muxKey,
        container: "ts",
        elementaryStreams: elementaryStreamKeys,
        segmentSettings: {
          segmentDuration: { seconds: 6 },
        },
      });

      hlsManifestElements.push(muxKey);
    });

    const spriteInterval = this.calculateSpriteInterval(durationSeconds);

    const jobConfig = {
      inputUri: inputGcsUri,
      outputUri: outputGcsUri.endsWith("/") ? outputGcsUri : `${outputGcsUri}/`,
      config: {
        elementaryStreams,
        muxStreams,
        manifests: [
          {
            fileName: "master.m3u8",
            type: "HLS",
            muxStreams: hlsManifestElements,
          },
        ],
        // Native GCP Transcoder periodic sprite sheet generation:
        // - spriteHeightPixels is intentionally omitted so GCP auto-calculates height
        //   and strictly preserves the native aspect ratio for 9:16 portrait, 1:1, or 16:9 videos.
        // - interval is scaled dynamically by duration to prevent sprite sheet explosion on long videos.
        spriteSheets: [
          {
            filePrefix: "storyboard",
            spriteWidthPixels: 320,
            columnCount: 5,
            rowCount: 5,
            interval: spriteInterval,
            quality: 85,
          },
        ],
        pubsubDestination: {
          topic: `projects/${projectId}/topics/transcoder.completed`,
        },
      },
      labels: {
        videoid: videoId.toLowerCase().replace(/[^a-z0-9_-]/g, "_"),
        service: "truthworld-transcoder",
      },
    };

    try {
      const accessToken = await this.getAccessToken();
      const response = await axios.post(
        `${this.API_BASE}/${parent}/jobs`,
        jobConfig,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        }
      );

      const jobData = response.data;
      return {
        jobId: jobData.name?.split("/").pop() || videoId,
        name: jobData.name,
        state: jobData.state || "PENDING",
        outputUri: outputGcsUri,
        labels: jobData.labels || jobConfig.labels,
      };
    } catch (err: any) {
      console.error("[TranscoderGateway] Failed to submit GCP Transcoder job", {
        videoId,
        error: err.response?.data || err.message,
      });
      throw new Error(`Cloud Transcoder submission failed: ${err.message}`);
    }
  }

  /**
   * Inspects the status of an active GCP Transcoder job.
   */
  static async getJobStatus(jobName: string): Promise<TranscodeJobResult> {
    const accessToken = await this.getAccessToken();
    const response = await axios.get(`${this.API_BASE}/${jobName}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    const data = response.data;
    return {
      jobId: data.name?.split("/").pop() || "",
      name: data.name,
      state: data.state,
      outputUri: data.config?.outputUri || "",
      labels: data.labels || data.config?.labels || {},
      error: data.error,
    };
  }
}

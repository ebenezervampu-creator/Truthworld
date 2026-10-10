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
}

export class TranscoderGateway {
  private static readonly LOCATION = "asia-south1";
  private static readonly API_BASE = "https://transcoder.googleapis.com/v1";

  /**
   * Evaluates whether a video should bypass local Cloud Function ffmpeg
   * and be routed to Google Cloud Transcoder API.
   */
  static isLongFormOr4K(params: {
    fileSizeBytes?: number;
    durationSeconds?: number;
    height?: number;
  }): boolean {
    const { fileSizeBytes = 0, durationSeconds = 0, height = 0 } = params;

    // Threshold 1: 4K Ultra HD (height > 1080p)
    if (height > 1080) return true;

    // Threshold 2: Duration > 15 minutes (900 seconds)
    if (durationSeconds > 900) return true;

    // Threshold 3: File size > 500 MB (524,288,000 bytes)
    if (fileSizeBytes > 524288000) return true;

    return false;
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
  }): Promise<TranscodeJobResult> {
    const { videoId, inputGcsUri, outputGcsUri, profiles } = params;
    const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || "truthworld-1";
    const parent = `projects/${projectId}/locations/${this.LOCATION}`;

    const activeProfiles: TranscoderProfile[] = profiles && profiles.length > 0
      ? profiles
      : [
          { label: "1080p", height: 1080, width: 1920, bitrateBps: 4500000, frameRate: 30 },
          { label: "720p", height: 720, width: 1280, bitrateBps: 2500000, frameRate: 30 },
          { label: "480p", height: 480, width: 854, bitrateBps: 1200000, frameRate: 30 },
          { label: "360p", height: 360, width: 640, bitrateBps: 600000, frameRate: 30 },
        ];

    // Build elementary video and audio streams
    const elementaryStreams: any[] = [
      {
        key: "audio-stream",
        audioStream: {
          codec: "aac",
          bitrateBps: 192000,
          channelCount: 2,
          sampleRateHertz: 48000,
        },
      },
    ];

    const muxStreams: any[] = [];
    const hlsManifestElements: string[] = [];

    activeProfiles.forEach((profile) => {
      const streamKey = `video-${profile.label}`;
      const muxKey = `hls-${profile.label}`;

      elementaryStreams.push({
        key: streamKey,
        videoStream: {
          h264: {
            heightPixels: profile.height,
            widthPixels: profile.width,
            bitrateBps: profile.bitrateBps,
            frameRate: profile.frameRate || 30,
            pixelFormat: "yuv420p",
            rateControlMode: "vbr",
            crfLevel: 21,
          },
        },
      });

      muxStreams.push({
        key: muxKey,
        container: "ts",
        elementaryStreams: [streamKey, "audio-stream"],
        segmentSettings: {
          segmentDuration: { seconds: 6 },
        },
      });

      hlsManifestElements.push(muxKey);
    });

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
    };
  }
}

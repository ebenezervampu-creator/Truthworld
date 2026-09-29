import axios from "axios";
import { PIPELINE_CONFIG } from "../config";
import { storage } from "firebase-admin";

/**
 * Media processing service - handles FFmpeg operations
 */
export class MediaService {
  async mergeAudioToVideo(request: any): Promise<string> {
    try {
      const outputPath = `videos/${request.jobId}/${request.language}-dubbed.mp4`;
      const ffmpegServiceUrl = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;
      
      if (!ffmpegServiceUrl || ffmpegServiceUrl.includes("placeholder")) {
        return `gs://${storage().bucket().name}/${outputPath}`;
      }
      
      const response = await axios.post(`${ffmpegServiceUrl}/merge`, request, { timeout: 300000 });
      return response.data.videoUrl;
    } catch (error) {
      console.error("Error merging audio:", error);
      throw error;
    }
  }

  async extractAudio(videoUrl: string, jobId: string): Promise<string> {
    try {
      const outputPath = `audio/${jobId}/original.mp3`;
      const ffmpegServiceUrl = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;

      if (!ffmpegServiceUrl || ffmpegServiceUrl.includes("placeholder")) {
        return `gs://${storage().bucket().name}/${outputPath}`;
      }

      const response = await axios.post(`${ffmpegServiceUrl}/extract-audio`, { videoUrl, outputPath });
      return response.data.audioUrl;
    } catch (error) {
      console.error("Error extracting audio:", error);
      throw error;
    }
  }

  async generateSubtitles(jobId: string, segments: any[], language: string, format: string): Promise<string> {
    const srtContent = this.generateSrt(segments);
    const vttContent = "WEBVTT\n\n" + srtContent.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
    
    const content = format === "vtt" ? vttContent : srtContent;
    // Industry Standard: Add UTF-8 BOM (\uFEFF) to ensure players (especially Windows/VLC) 
    // correctly identify the file as UTF-8.
    const contentWithBom = "\uFEFF" + content;

    const outputPath = `subtitles/${jobId}/${language}.${format}`;
    const bucket = storage().bucket();
    const file = bucket.file(outputPath);

    await file.save(contentWithBom, {
      metadata: { 
        contentType: format === "vtt" ? "text/vtt; charset=utf-8" : "text/plain; charset=utf-8" 
      },
    });

    return `gs://${bucket.name}/${outputPath}`;
  }

  /**
   * Generates and uploads ALL THREE subtitle formats (.json, .vtt, .srt) for a language.
   * e.g., for Telugu 'te': te.json, te.vtt, and te.srt.
   */
  async generateAllSubtitles(
    jobId: string,
    segments: any[],
    language: string
  ): Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string }> {
    const srtContent = this.generateSrt(segments);
    const vttContent = "WEBVTT\n\n" + srtContent.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2");
    const jsonContent = JSON.stringify(segments, null, 2);

    const bucket = storage().bucket();

    const srtPath = `subtitles/${jobId}/${language}.srt`;
    const vttPath = `subtitles/${jobId}/${language}.vtt`;
    const jsonPath = `subtitles/${jobId}/${language}.json`;

    await Promise.all([
      bucket.file(srtPath).save("\uFEFF" + srtContent, {
        metadata: { contentType: "text/plain; charset=utf-8" },
      }),
      bucket.file(vttPath).save("\uFEFF" + vttContent, {
        metadata: { contentType: "text/vtt; charset=utf-8" },
      }),
      bucket.file(jsonPath).save(jsonContent, {
        metadata: { contentType: "application/json" },
      }),
    ]);

    return {
      srtUrl: `gs://${bucket.name}/${srtPath}`,
      vttUrl: `gs://${bucket.name}/${vttPath}`,
      jsonUrl: `gs://${bucket.name}/${jsonPath}`,
    };
  }


  private generateSrt(segments: any[]): string {
    return segments
      .map((s, i) => {
        const start = this.formatSrtTime(s.start);
        const end = this.formatSrtTime(s.end);
        // Ensure segment text is trimmed and newlines are handled
        const text = s.text.trim();
        return `${i + 1}\n${start} --> ${end}\n${text}\n`;
      })
      .join("\n");
  }

  private formatSrtTime(ms: number): string {
    const hours = Math.floor(ms / 3600000).toString().padStart(2, "0");
    const minutes = Math.floor((ms % 3600000) / 60000).toString().padStart(2, "0");
    const seconds = Math.floor((ms % 60000) / 1000).toString().padStart(2, "0");
    const milliseconds = Math.floor(ms % 1000).toString().padStart(3, "0");
    return `${hours}:${minutes}:${seconds},${milliseconds}`;
  }

  async mergeAudioChunks(jobId: string, audioUrls: string[], language: string = "default"): Promise<string> {
    try {
      const valid = audioUrls.filter((u) => !!u);
      if (valid.length === 0) {
        throw new Error("No valid TTS audio chunks provided to mergeAudioChunks");
      }
      const bucket = storage().bucket();
      const outputPath = `audio/${jobId}/${language}/stitched.mp3`;

      if (valid.length === 1) {
        return valid[0];
      }

      // Download all chunks and concatenate their MPEG audio buffers
      const buffers: Buffer[] = [];
      for (const u of valid) {
        try {
          const filePath = u.startsWith("gs://")
            ? u.replace(`gs://${bucket.name}/`, "")
            : (u.includes(bucket.name) ? u.split(`${bucket.name}/`)[1] : u);
          const [data] = await bucket.file(filePath).download();
          buffers.push(data);
        } catch (downloadErr) {
          console.warn("[MediaService] Failed to download chunk for merge:", u, downloadErr);
        }
      }

      if (buffers.length === 0) {
        return valid[0];
      }

      const mergedBuffer = Buffer.concat(buffers);
      const file = bucket.file(outputPath);
      await file.save(mergedBuffer, {
        metadata: {
          contentType: "audio/mpeg",
          metadata: { jobId, language, chunks: String(buffers.length) },
        },
      });

      return `gs://${bucket.name}/${outputPath}`;
    } catch (err) {
      console.error("[MediaService] Error merging audio chunks:", err);
      return audioUrls.find((u) => !!u) || `gs://${storage().bucket().name}/audio/${jobId}/${language}/stitched.mp3`;
    }
  }
}

export const mediaService = new MediaService();

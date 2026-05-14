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

  async mergeAudioChunks(jobId: string, audioUrls: string[]): Promise<string> {
    const outputPath = `audio/${jobId}/final-stitched.mp3`;
    // For now, return path where they WILL be stored
    return `gs://${storage().bucket().name}/${outputPath}`;
  }
}

export const mediaService = new MediaService();

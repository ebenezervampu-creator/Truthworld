/**
 * I/O for listen-and-retake (listen-retake.ts): Gemini audio call and 16 kHz mono WAV clips.
 * Kept apart so the pure module is testable without Vertex or FFmpeg.
 */
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { execFile } from "child_process";
import { promisify } from "util";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { downloadStorageBuffer, getFfmpegPath } from "./media";
import { LISTEN, type ListenGenerateFn } from "./listen-retake";

const execFileAsync = promisify(execFile);

/** Model for listening: GEMINI_MODEL_DUBBING_LISTEN, else the given default (the diarization model). */
export function listenModel(fallback: string): string {
  return process.env.GEMINI_MODEL_DUBBING_LISTEN || fallback;
}

export function geminiListenGenerate(model: string): ListenGenerateFn {
  return async ({ prompt, sourceWavBase64, dubWavBase64 }) => {
    const m = getVertexAI().getGenerativeModel({ model });
    const result = await m.generateContent({
      contents: [
        {
          role: "user",
          parts: [
            { text: "Audio 1 (original):" },
            { inlineData: { mimeType: "audio/wav", data: sourceWavBase64 } },
            { text: "Audio 2 (dubbed):" },
            { inlineData: { mimeType: "audio/wav", data: dubWavBase64 } },
            { text: prompt },
          ],
        },
      ],
      generationConfig: { responseMimeType: "application/json", temperature: 0.1 },
    } as any);
    return extractCandidateText((result as any)?.response?.candidates?.[0]) || "";
  };
}

async function ffmpegToWav(args: string[]): Promise<Buffer | null> {
  const ffmpegPath = getFfmpegPath();
  if (!ffmpegPath) return null;
  const { stdout } = await execFileAsync(
    ffmpegPath,
    [...args, "-ar", "16000", "-ac", "1", "-f", "wav", "pipe:1"],
    { encoding: "buffer", maxBuffer: 50 * 1024 * 1024, timeout: 30000 } as any
  );
  const buf = Buffer.from(stdout as unknown as Buffer);
  return buf.length > 256 ? buf : null;
}

/**
 * Original-audio source for one language: downloaded once, sliced per line. Call dispose() at the end.
 */
export async function openSourceAudio(url: string): Promise<{ clip(startMs: number, endMs: number): Promise<Buffer | null>; dispose(): void }> {
  const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "tw_listen_"));
  const local = path.join(dir, "source.bin");
  await fs.promises.writeFile(local, await downloadStorageBuffer(url));
  return {
    clip: (startMs, endMs) => {
      const start = Math.max(0, startMs - 100) / 1000;
      const dur = Math.min(LISTEN.maxClipSec, Math.max(0.3, (endMs - startMs + 200) / 1000));
      return ffmpegToWav(["-v", "error", "-ss", start.toFixed(3), "-t", dur.toFixed(3), "-i", local]);
    },
    dispose: () => {
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

/** A dubbed take (any format in storage) as a WAV clip, at most LISTEN.maxClipSec long. */
export async function takeAsWav(url: string): Promise<Buffer | null> {
  const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "tw_take_"));
  try {
    const local = path.join(dir, "take.bin");
    await fs.promises.writeFile(local, await downloadStorageBuffer(url));
    return await ffmpegToWav(["-v", "error", "-t", String(LISTEN.maxClipSec), "-i", local]);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

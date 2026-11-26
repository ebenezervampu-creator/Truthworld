/**
 * Measures the real pitch of candidate voices from their public preview audio, so voice matching
 * compares the original speaker with each voice on the same measured scale (pitch-estimation.ts).
 *
 * Results are cached in memory and in Firestore (voice_acoustics/{voiceId}), so each voice is
 * downloaded and measured once, not once per job. Never throws: a voice that cannot be measured
 * keeps pitchMeasured=false, and the matcher then lets age and timbre decide for it.
 */
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import type { PitchEstimate } from "./pitch-estimation";
import { mapWithConcurrency } from "./concurrency";
import { emitDubbingTiming } from "../utils/dubbing-timing";

/** Bump when the measuring method changes, so old cached values are re-measured. */
export const VOICE_ACOUSTICS_METHOD = "yin-v1";

export interface VoiceAcoustics {
  pitchHz: number;
  spreadSemitones: number;
  previewUrl: string;
  method: string;
}

export interface MeasurableVoice {
  voiceId: string;
  previewUrl?: string;
  typicalPitchHz: number;
  pitchMeasured?: boolean;
}

export interface VoiceAcousticsDeps {
  /** Downloads and measures one preview; null when it cannot be measured. */
  measurePreview(previewUrl: string): Promise<PitchEstimate | null>;
  cacheGet(voiceIds: string[]): Promise<Record<string, VoiceAcoustics>>;
  cacheSet(voiceId: string, value: VoiceAcoustics): Promise<void>;
}

export interface MeasureSummary {
  measured: number;
  fromCache: number;
  failed: number;
  skipped: number;
  /** Why voices failed, with counts (e.g. "http 403", "timed out", "error: Cannot find module"). Only present when something failed. */
  failureReasons?: Record<string, number>;
}

const memory = new Map<string, VoiceAcoustics>();

/** For tests. */
export function clearVoiceAcousticsMemory(): void {
  memory.clear();
}

const usable = (a: VoiceAcoustics | undefined, previewUrl: string): a is VoiceAcoustics =>
  Boolean(a && a.method === VOICE_ACOUSTICS_METHOD && a.previewUrl === previewUrl && a.pitchHz > 0);

/**
 * Returns copies of the candidates with typicalPitchHz set to the measured pitch and
 * pitchMeasured=true where a measurement exists. Voices without a preview are returned unchanged.
 */
export async function withMeasuredPitch<C extends MeasurableVoice>(
  candidates: C[],
  deps: VoiceAcousticsDeps,
  options: { concurrency?: number; budgetMs?: number; jobId?: string; lang?: string } = {}
): Promise<{ candidates: C[]; summary: MeasureSummary }> {
  const summary: MeasureSummary = { measured: 0, fromCache: 0, failed: 0, skipped: 0 };
  const deadline = Date.now() + (options.budgetMs ?? 60_000);
  const results = new Map<string, VoiceAcoustics>();
  const wanted = candidates.filter((c) => c.previewUrl && c.pitchMeasured !== true);
  summary.skipped = candidates.length - wanted.length;

  const missing: C[] = [];
  for (const c of wanted) {
    const hit = memory.get(c.voiceId);
    if (usable(hit, c.previewUrl!)) {
      results.set(c.voiceId, hit);
      summary.fromCache++;
    } else {
      missing.push(c);
    }
  }

  if (missing.length > 0) {
    let stored: Record<string, VoiceAcoustics> = {};
    try {
      stored = await deps.cacheGet(missing.map((c) => c.voiceId));
    } catch {
      stored = {};
    }
    const toMeasure: C[] = [];
    for (const c of missing) {
      const hit = stored[c.voiceId];
      if (usable(hit, c.previewUrl!)) {
        memory.set(c.voiceId, hit);
        results.set(c.voiceId, hit);
        summary.fromCache++;
      } else {
        toMeasure.push(c);
      }
    }

    const fail = (reason: string) => {
      summary.failed++;
      const reasons = (summary.failureReasons ??= {});
      reasons[reason] = (reasons[reason] || 0) + 1;
    };
    await mapWithConcurrency(toMeasure, options.concurrency ?? 4, async (c) => {
      if (Date.now() > deadline) {
        fail("timed out");
        return;
      }
      const tProbe = Date.now();
      try {
        const estimate = await deps.measurePreview(c.previewUrl!);
        if (!estimate) {
          if (options.jobId) {
            emitDubbingTiming("voices.live_probe", tProbe, {
              jobId: options.jobId,
              lang: options.lang,
              voiceId: c.voiceId,
              status: "no_pitch",
            });
          }
          fail("no pitch");
          return;
        }
        const value: VoiceAcoustics = {
          pitchHz: estimate.medianHz,
          spreadSemitones: estimate.spreadSemitones,
          previewUrl: c.previewUrl!,
          method: VOICE_ACOUSTICS_METHOD,
        };
        memory.set(c.voiceId, value);
        results.set(c.voiceId, value);
        summary.measured++;
        if (options.jobId) {
          emitDubbingTiming("voices.live_probe", tProbe, {
            jobId: options.jobId,
            lang: options.lang,
            voiceId: c.voiceId,
            status: "ok",
          });
        }
        await deps.cacheSet(c.voiceId, value).catch(() => undefined);
      } catch (err: any) {
        if (options.jobId) {
          emitDubbingTiming("voices.live_probe", tProbe, {
            jobId: options.jobId,
            lang: options.lang,
            voiceId: c.voiceId,
            status: "error",
          });
        }
        fail(`error: ${String(err?.message || err).slice(0, 120)}`);
      }
    });
  }

  return {
    candidates: candidates.map((c) => {
      const a = results.get(c.voiceId);
      return a ? { ...c, typicalPitchHz: a.pitchHz, pitchMeasured: true } : c;
    }),
    summary,
  };
}

const MAX_PREVIEW_BYTES = 5 * 1024 * 1024;

/** Production dependencies: fetch the preview, measure it with ffmpeg + YIN, cache in Firestore. */
export function defaultVoiceAcousticsDeps(): VoiceAcousticsDeps {
  return {
    async measurePreview(previewUrl: string) {
      const res = await fetch(previewUrl);
      if (!res.ok) throw new Error(`http ${res.status}`);
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length === 0 || buf.length > MAX_PREVIEW_BYTES) return null;
      const file = path.join(os.tmpdir(), `tw_voice_preview_${Date.now()}_${Math.random().toString(36).slice(2)}.mp3`);
      await fs.promises.writeFile(file, buf);
      try {
        // require, not import("./media.js"): a dynamic import of "./media.js" only resolves in the compiled
        // lib/ build; under ts-node (scripts/dubbing/local-dub-test.ts) there is no media.js, so every
        // preview failed (24 Nov: 0 of 40 te voices, 0 of 41 ta voices measured). Lazy to avoid a cycle.
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const { mediaService } = require("./media") as typeof import("./media");
        return await mediaService.extractPitch(file);
      } finally {
        await fs.promises.rm(file, { force: true }).catch(() => undefined);
      }
    },
    async cacheGet(voiceIds: string[]) {
      const admin = await import("firebase-admin");
      const col = admin.firestore().collection("voice_acoustics");
      const out: Record<string, VoiceAcoustics> = {};
      for (let i = 0; i < voiceIds.length; i += 100) {
        const refs = voiceIds.slice(i, i + 100).map((id) => col.doc(id));
        const snaps = await admin.firestore().getAll(...refs);
        for (const snap of snaps) {
          const d = snap.data() as VoiceAcoustics | undefined;
          if (d) out[snap.id] = d;
        }
      }
      return out;
    },
    async cacheSet(voiceId: string, value: VoiceAcoustics) {
      const admin = await import("firebase-admin");
      await admin
        .firestore()
        .collection("voice_acoustics")
        .doc(voiceId)
        .set({ ...value, measuredAt: admin.firestore.FieldValue.serverTimestamp() });
    },
  };
}

/**
 * Replicate Demucs was removed from the dubbing pipeline on 2026-11-21. Voice / background
 * separation runs only on the self-hosted Demucs worker (DEMUX_SERVICE_URL); without it, the M&E
 * path in 07-dubbing.ts step 1.6c builds the background track.
 *
 * This guard fails if Replicate code or settings come back. (The file keeps its old name so the
 * former adapter tests are not silently re-added under it; rename freely.)
 */
import * as fs from "fs";
import * as path from "path";

function tsFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) return e.name === "__tests__" ? [] : tsFiles(p);
    return e.name.endsWith(".ts") ? [p] : [];
  });
}

describe("Replicate Demucs is removed from the dubbing pipeline", () => {
  const pipelineDir = path.join(__dirname, "../../src/pipeline");
  const files = tsFiles(pipelineDir);

  it("no pipeline source refers to Replicate", () => {
    // Matches the Replicate platform/API (package, host, token, client), not the English verb/noun in scientific fact-checking.
    const isReplicateService = (content: string) =>
      /(?:from\s+["']replicate["']|require\(["']replicate["']\)|replicate\.com|replicate\/demucs|replicateToken|new\s+Replicate\b|separateWithReplicate)/i.test(
        content
      ) || /\bREPLICATE_[A-Z_]+\b/.test(content);
    const offenders = files.filter((f) => isReplicateService(fs.readFileSync(f, "utf8")));
    expect(offenders.map((f) => path.relative(pipelineDir, f))).toEqual([]);
  });

  it("MediaService has no Replicate separation method", async () => {
    const { MediaService } = await import("../../src/pipeline/services/media");
    expect((MediaService.prototype as any).separateWithReplicateDemucs).toBeUndefined();
    expect(typeof (MediaService.prototype as any).separateWithDemuxWorker).toBe("function");
  });

  it("the self-hosted Demucs worker is still the separation engine in 07-dubbing.ts", () => {
    const src = fs.readFileSync(path.join(pipelineDir, "layers/07-dubbing.ts"), "utf8");
    expect(src).toContain("mediaService.separateWithDemuxWorker(jobId, stereoSource)");
  });
});

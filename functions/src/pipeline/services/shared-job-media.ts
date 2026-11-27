import * as crypto from "crypto";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

function sanitizeSegment(raw: string): string {
  return String(raw || "default").replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 80);
}

/**
 * Normalizes a GCS/Firebase/local path into a stable cache key so gs:// and
 * storage.googleapis.com / firebasestorage.googleapis.com references hit the same file.
 */
export function canonicalMediaKey(urlOrPath: string): string {
  const trimmed = String(urlOrPath || "").trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("gs://")) return trimmed;
  try {
    const u = new URL(trimmed);
    if (u.hostname === "storage.googleapis.com") {
      const parts = u.pathname.replace(/^\/+/, "").split("/");
      if (parts.length >= 2) return `gs://${parts[0]}/${parts.slice(1).join("/")}`;
    }
    if (u.hostname === "firebasestorage.googleapis.com") {
      const m = u.pathname.match(/\/v0\/b\/([^/]+)\/o\/(.+)$/);
      if (m) return `gs://${m[1]}/${decodeURIComponent(m[2])}`;
    }
  } catch {
    // Non-URL local path
  }
  return trimmed;
}

/**
 * Job-scoped local `/tmp` media cache.
 *
 * Prevents a single Cloud Function invocation from downloading or decoding the same
 * 10-minute video/audio asset multiple times across separation, profiling, prosody,
 * mixing, delivery verification, and remuxing.
 */
export class SharedJobMediaRegistry {
  private readonly inflight = new Map<string, Map<string, Promise<string>>>();

  private jobDir(jobId: string): string {
    return path.join(os.tmpdir(), `tw_shared_${sanitizeSegment(jobId)}`);
  }

  private filePathFor(jobId: string, key: string, defaultExt: string): string {
    const ext = defaultExt.startsWith(".") ? defaultExt : `.${defaultExt}`;
    const digest = crypto.createHash("sha256").update(key).digest("hex").slice(0, 20);
    return path.join(this.jobDir(jobId), `${digest}${ext}`);
  }

  private getJobMap(jobId: string): Map<string, Promise<string>> {
    let map = this.inflight.get(jobId);
    if (!map) {
      map = new Map<string, Promise<string>>();
      this.inflight.set(jobId, map);
    }
    return map;
  }

  async getCachedLocalFile(jobId: string, urlOrPath: string): Promise<string | null> {
    if (!jobId || !urlOrPath) return null;
    const key = canonicalMediaKey(urlOrPath);
    if (fs.existsSync(key)) {
      const stat = await fs.promises.stat(key).catch(() => null);
      if (stat && stat.size > 0) return key;
    }
    const map = this.inflight.get(jobId);
    const existing = map?.get(key);
    if (!existing) return null;
    try {
      const resolved = await existing;
      const stat = await fs.promises.stat(resolved).catch(() => null);
      if (stat && stat.size > 0) return resolved;
      map?.delete(key);
      return null;
    } catch {
      map?.delete(key);
      return null;
    }
  }

  async ensureLocalFile(
    jobId: string,
    urlOrPath: string,
    defaultExt: string,
    fetcher: (destPath: string) => Promise<void>
  ): Promise<string> {
    const key = canonicalMediaKey(urlOrPath);
    if (fs.existsSync(key)) {
      const stat = await fs.promises.stat(key).catch(() => null);
      if (stat && stat.size > 0) return key;
    }

    const map = this.getJobMap(jobId);
    const existing = map.get(key);
    if (existing) {
      try {
        const resolved = await existing;
        const stat = await fs.promises.stat(resolved).catch(() => null);
        if (stat && stat.size > 0) return resolved;
      } catch {
        // Retry on failed previous fetch
      }
      map.delete(key);
    }

    const dir = this.jobDir(jobId);
    const dest = this.filePathFor(jobId, key, defaultExt);
    const promise = (async () => {
      await fs.promises.mkdir(dir, { recursive: true });
      const tmpDest = `${dest}.${process.pid}.${Date.now()}.part`;
      try {
        await fetcher(tmpDest);
        await fs.promises.rename(tmpDest, dest);
        return dest;
      } catch (err) {
        await fs.promises.unlink(tmpDest).catch(() => {});
        throw err;
      }
    })();

    map.set(key, promise);
    try {
      return await promise;
    } catch (err) {
      map.delete(key);
      throw err;
    }
  }

  async registerLocalFile(
    jobId: string,
    urlOrPath: string,
    sourceLocalPath: string,
    defaultExt?: string
  ): Promise<string | null> {
    if (!jobId || !urlOrPath || !sourceLocalPath || !fs.existsSync(sourceLocalPath)) {
      return null;
    }
    const stat = await fs.promises.stat(sourceLocalPath).catch(() => null);
    if (!stat || stat.size === 0) return null;
    const key = canonicalMediaKey(urlOrPath);
    const ext = defaultExt || path.extname(sourceLocalPath) || ".bin";
    const dest = this.filePathFor(jobId, key, ext);
    const dir = this.jobDir(jobId);
    await fs.promises.mkdir(dir, { recursive: true });
    if (path.resolve(sourceLocalPath) !== path.resolve(dest)) {
      await fs.promises.copyFile(sourceLocalPath, dest);
    }
    const map = this.getJobMap(jobId);
    map.set(key, Promise.resolve(dest));
    return dest;
  }

  async releaseJob(jobId: string): Promise<void> {
    if (!jobId) return;
    this.inflight.delete(jobId);
    await fs.promises.rm(this.jobDir(jobId), { recursive: true, force: true }).catch(() => {});
  }
}

export const sharedJobMedia = new SharedJobMediaRegistry();

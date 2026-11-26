import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { SCHEMA_VERSION } from "../schema/schemaConfig";
import { SNAPSHOT_VERSION } from "../render/htmlRenderer";
import { getMemorySnapshot, setMemorySnapshot } from "./memoryCache";

export interface SnapshotManifest {
  snapshotVersion: number;
  schemaVersion: number;
  etag: string;
  lastModified: string;
  storagePath: string;
  status: "ready" | "stale" | "error";
  generatedAt: string;
}

export function computeEtag(content: string): string {
  const hash = crypto.createHash("sha256").update(content, "utf8").digest("hex");
  return `"sha256-${hash.substring(0, 32)}"`;
}

function getStorageBucket() {
  const currentProject = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || process.env.GCP_PROJECT_ID || "truthworld-1";
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET || process.env.STORAGE_BUCKET || (currentProject !== "truthworld-1"
    ? `${currentProject}.firebasestorage.app`
    : "truthworld-1.firebasestorage.app");
  try {
    return admin.storage().bucket(bucketName);
  } catch (_) {
    return admin.storage().bucket();
  }
}

export async function getCachedSnapshot(
  cacheKey: string
): Promise<{ html: string; etag: string; lastModified: string } | null> {
  // 1. Check L1 Memory Cache
  const memoryHit = getMemorySnapshot(cacheKey);
  if (memoryHit) {
    return {
      html: memoryHit.html,
      etag: memoryHit.etag,
      lastModified: memoryHit.lastModified
    };
  }

  // 2. Check L2 Firebase Storage Bucket
  try {
    const bucket = getStorageBucket();
    const filePath = `seo/snapshots/${cacheKey}.html`;
    const manifestPath = `seo/manifests/${cacheKey}.json`;

    const file = bucket.file(filePath);
    const manifestFile = bucket.file(manifestPath);

    // Parallel download to eliminate sequential round-trip latency
    const [htmlResult, manifestResult] = await Promise.allSettled([
      file.download(),
      manifestFile.download()
    ]);

    if (htmlResult.status !== "fulfilled") {
      return null;
    }

    const html = htmlResult.value[0].toString("utf8");
    let etag = "";
    let lastModified = new Date().toUTCString();

    if (manifestResult.status === "fulfilled") {
      try {
        const manifest: SnapshotManifest = JSON.parse(manifestResult.value[0].toString("utf8"));
        if (manifest.snapshotVersion !== SNAPSHOT_VERSION || manifest.schemaVersion !== SCHEMA_VERSION) {
          // Version mismatch, invalidate snapshot
          return null;
        }
        etag = manifest.etag;
        lastModified = manifest.lastModified;
      } catch (_) {}
    }

    if (!etag) {
      etag = computeEtag(html);
    }

    // Populate L1 cache
    setMemorySnapshot(cacheKey, html, etag, lastModified);

    return { html, etag, lastModified };
  } catch (err) {
    console.error("StorageCache read error for key:", cacheKey, err);
    return null;
  }
}

export async function saveSnapshot(
  cacheKey: string,
  html: string,
  lastModifiedDate?: Date
): Promise<{ etag: string; lastModified: string }> {
  const etag = computeEtag(html);
  const lastModified = (lastModifiedDate || new Date()).toUTCString();
  const generatedAt = new Date().toISOString();

  // Populate L1 Memory Cache immediately to accelerate concurrent requests
  setMemorySnapshot(cacheKey, html, etag, lastModified);

  const filePath = `seo/snapshots/${cacheKey}.html`;
  const manifestPath = `seo/manifests/${cacheKey}.json`;

  try {
    const bucket = getStorageBucket();
    const file = bucket.file(filePath);
    const manifestFile = bucket.file(manifestPath);

    const manifest: SnapshotManifest = {
      snapshotVersion: SNAPSHOT_VERSION,
      schemaVersion: SCHEMA_VERSION,
      etag,
      lastModified,
      storagePath: filePath,
      status: "ready",
      generatedAt
    };

    // Parallel save to minimize I/O duration
    await Promise.all([
      file.save(html, {
        contentType: "text/html; charset=utf-8",
        metadata: {
          cacheControl: "public, max-age=300, s-maxage=3600",
          metadata: {
            etag,
            lastModified,
            schemaVersion: String(SCHEMA_VERSION),
            snapshotVersion: String(SNAPSHOT_VERSION)
          }
        }
      }),
      manifestFile.save(JSON.stringify(manifest, null, 2), {
        contentType: "application/json",
        metadata: {
          cacheControl: "no-cache"
        }
      })
    ]);
  } catch (err) {
    console.error("StorageCache write error for key:", cacheKey, err);
  }

  return { etag, lastModified };
}

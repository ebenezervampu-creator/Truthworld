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
    const bucket = admin.storage().bucket();
    const filePath = `seo/snapshots/${cacheKey}.html`;
    const manifestPath = `seo/manifests/${cacheKey}.json`;

    const file = bucket.file(filePath);
    const [exists] = await file.exists();
    if (!exists) return null;

    // Read manifest
    const manifestFile = bucket.file(manifestPath);
    const [manifestExists] = await manifestFile.exists();
    let etag = "";
    let lastModified = new Date().toUTCString();

    if (manifestExists) {
      const [manifestBuffer] = await manifestFile.download();
      const manifest: SnapshotManifest = JSON.parse(manifestBuffer.toString("utf8"));
      if (manifest.snapshotVersion !== SNAPSHOT_VERSION || manifest.schemaVersion !== SCHEMA_VERSION) {
        // Version mismatch, invalidate snapshot
        return null;
      }
      etag = manifest.etag;
      lastModified = manifest.lastModified;
    }

    const [htmlBuffer] = await file.download();
    const html = htmlBuffer.toString("utf8");

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

  const filePath = `seo/snapshots/${cacheKey}.html`;
  const manifestPath = `seo/manifests/${cacheKey}.json`;

  try {
    const bucket = admin.storage().bucket();

    // 1. Save HTML Snapshot
    const file = bucket.file(filePath);
    await file.save(html, {
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
    });

    // 2. Save Manifest JSON
    const manifest: SnapshotManifest = {
      snapshotVersion: SNAPSHOT_VERSION,
      schemaVersion: SCHEMA_VERSION,
      etag,
      lastModified,
      storagePath: filePath,
      status: "ready",
      generatedAt
    };

    const manifestFile = bucket.file(manifestPath);
    await manifestFile.save(JSON.stringify(manifest, null, 2), {
      contentType: "application/json",
      metadata: {
        cacheControl: "no-cache"
      }
    });

    // Populate L1 Memory Cache
    setMemorySnapshot(cacheKey, html, etag, lastModified);
  } catch (err) {
    console.error("StorageCache write error for key:", cacheKey, err);
  }

  return { etag, lastModified };
}

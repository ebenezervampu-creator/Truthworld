/**
 * 🛡️ Videos Collection Integrity Guard
 *
 * Enforces that the `videos` Firestore collection ONLY ever contains
 * real video documents — one document per video, keyed by its UUID.
 *
 * Prevents accidental writes using job IDs, temp IDs, or any
 * non-video identifier as document keys.
 *
 * Every write path that targets `collection("videos").doc(someId)`
 * MUST call `assertVideoId(someId)` before the write.
 */

import * as functions from "firebase-functions";

const log = functions.logger;

// Pattern: a valid video document ID is a UUID v4 (8-4-4-4-12 hex chars)
// This rejects job_ prefixed ids, numeric ids, empty strings, etc.
const UUID_V4_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Returns true if `id` is a valid UUID-format video document ID.
 * Returns false for job_ prefixed IDs, numeric IDs, empty strings, etc.
 */
export function isVideoId(id: string | null | undefined): boolean {
  if (!id || typeof id !== "string") return false;
  if (id.startsWith("job_")) return false;
  return UUID_V4_RE.test(id);
}

/**
 * Throws an error if `id` is not a valid video document ID.
 * Use before every `.set()`, `.update()`, `.delete()` on `collection("videos").doc(id)`.
 *
 * @param id  - the document ID to validate
 * @param tag - caller label for log context (e.g. "[MyFunction]")
 */
export function assertVideoId(id: string | null | undefined, tag = "[videosCollectionGuard]"): void {
  if (!isVideoId(id)) {
    const msg = `${tag} Refused to write to videos collection with non-video id: "${id}". Only UUID video IDs are allowed.`;
    log.error(msg, { invalidId: id });
    throw new Error(msg);
  }
}

/**
 * Filters an array of IDs, keeping only valid video document IDs.
 * Logs a warning for every ID that is dropped.
 *
 * @param ids - array of candidate document IDs
 * @param tag - caller label for log context
 */
export function filterVideoIds(ids: string[], tag = "[videosCollectionGuard]"): string[] {
  return ids.filter((id) => {
    if (isVideoId(id)) return true;
    log.warn(`${tag} Dropping non-video id from videos write batch`, { droppedId: id });
    return false;
  });
}

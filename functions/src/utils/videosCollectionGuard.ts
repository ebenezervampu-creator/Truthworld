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

import * as admin from "firebase-admin";
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
export function isVideoId(id: string | null | undefined): id is string {
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

/**
 * Checks whether `videos/{videoId}` is both a valid UUID v4 and currently exists in Firestore.
 */
export async function videoDocExists(
  videoId: string | null | undefined,
  tag = "[videosCollectionGuard]"
): Promise<boolean> {
  if (!isVideoId(videoId)) {
    if (videoId) {
      log.warn(`${tag} Rejecting non-video id for videos collection`, { videoId });
    }
    return false;
  }
  const snap = await admin.firestore().collection("videos").doc(videoId!).get();
  if (!snap.exists) {
    log.warn(`${tag} Target video document does not exist in videos collection`, { videoId });
    return false;
  }
  return true;
}

/**
 * Filters candidate IDs to ONLY valid UUIDs whose `videos/{id}` document already exists.
 */
export async function filterExistingVideoIds(
  ids: string[],
  tag = "[videosCollectionGuard]"
): Promise<string[]> {
  const validIds = Array.from(new Set(filterVideoIds(ids, tag)));
  if (validIds.length === 0) return [];
  const firestore = admin.firestore();
  const refs = validIds.map((id) => firestore.collection("videos").doc(id));
  const snaps =
    typeof firestore.getAll === "function"
      ? await firestore.getAll(...refs)
      : await Promise.all(refs.map((r) => r.get()));
  const existing: string[] = [];
  for (const snap of snaps) {
    if (snap.exists) {
      existing.push(snap.id);
    } else {
      log.warn(`${tag} Dropping non-existent video id from videos write`, { droppedId: snap.id });
    }
  }
  return existing;
}

/**
 * Atomically merges fields into an EXISTING `videos/{videoId}` document.
 * NEVER creates a new document in `videos` — only real user uploads create documents there.
 *
 * Returns `true` if the existing document was updated, `false` if skipped.
 */
export async function safeMergeExistingVideo(
  videoId: string | null | undefined,
  data: Record<string, any>,
  tag = "[videosCollectionGuard]"
): Promise<boolean> {
  if (!isVideoId(videoId)) {
    log.warn(`${tag} Refused to write to videos collection with non-video id`, { invalidId: videoId });
    return false;
  }
  const firestore = admin.firestore();
  const ref = firestore.collection("videos").doc(videoId!);

  if (typeof firestore.runTransaction === "function") {
    const updated = await firestore.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return false;
      tx.set(ref, data, { merge: true });
      return true;
    });
    if (!updated) {
      log.warn(`${tag} Refused to create new document in videos collection (doc does not exist)`, { videoId });
    }
    return updated;
  }

  const snap = await ref.get();
  if (!snap?.exists) {
    log.warn(`${tag} Refused to create new document in videos collection (doc does not exist)`, { videoId });
    return false;
  }
  await ref.set(data, { merge: true });
  return true;
}

/**
 * Atomically merges fields into a subcollection document under an EXISTING `videos/{videoId}` document.
 * Prevents creating phantom parent documents in `videos`.
 */
export async function safeMergeExistingVideoSubdoc(
  videoId: string | null | undefined,
  subcollection: string,
  docId: string,
  data: Record<string, any>,
  tag = "[videosCollectionGuard]"
): Promise<boolean> {
  if (!isVideoId(videoId)) {
    log.warn(`${tag} Refused subcollection write under non-video id`, { invalidId: videoId, subcollection, docId });
    return false;
  }
  const firestore = admin.firestore();
  const parentRef = firestore.collection("videos").doc(videoId!);
  const subRef = parentRef.collection(subcollection).doc(docId);

  if (typeof firestore.runTransaction === "function") {
    const updated = await firestore.runTransaction(async (tx) => {
      const parentSnap = await tx.get(parentRef);
      if (!parentSnap.exists) return false;
      tx.set(subRef, data, { merge: true });
      return true;
    });
    if (!updated) {
      log.warn(`${tag} Refused subcollection write because parent videos/${videoId} does not exist`, {
        videoId,
        subcollection,
        docId,
      });
    }
    return updated;
  }

  const parentSnap = await parentRef.get();
  if (!parentSnap?.exists) {
    log.warn(`${tag} Refused subcollection write because parent videos/${videoId} does not exist`, {
      videoId,
      subcollection,
      docId,
    });
    return false;
  }
  await subRef.set(data, { merge: true });
  return true;
}

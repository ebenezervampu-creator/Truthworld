/**
 * Access rules for the resolution service (pure functions, no Firebase calls).
 *
 * Kept separate from resolution.ts so the ownership and visibility decisions
 * can be unit-tested without Storage, Firestore or ffmpeg.
 *
 * Mirrors the rules in firestore.rules / storage.rules:
 *  - a video's owner is ownerId || userId || uploaderId on videos/{videoId}
 *  - "private", "draft" and "private_draft" visibilities are hidden from
 *    everyone except the owner and admins (case-insensitive)
 */

/** Visibility values that hide a video from anyone but its owner and admins. */
const PRIVATE_VISIBILITIES = new Set(["private", "draft", "private_draft"]);

/** Fields of a resolution variant that are safe to return from a public endpoint. */
const PUBLIC_VARIANT_FIELDS = [
  "label",
  "height",
  "width",
  "bitrateKbps",
  "audioBitrateKbps",
  "fps",
  "status",
  "downloadUrl",
  "fallback",
  "processedAt",
] as const;

export type UploadRejectionReason =
  | "video_doc_missing"
  | "owner_missing"
  | "not_source_file"
  | "uploader_missing"
  | "uploader_not_owner";

export interface UploadOwnershipDecision {
  allowed: boolean;
  /** Verified owner of the video (only set when allowed). */
  ownerId?: string;
  reason?: UploadRejectionReason;
}

/** Returns the owner uid recorded on a videos/{id} document, or "" when none is set. */
export function getVideoOwnerId(videoData: Record<string, any> | null | undefined): string {
  if (!videoData) return "";
  for (const key of ["ownerId", "userId", "uploaderId"]) {
    const value = videoData[key];
    if (typeof value === "string" && value.trim().length > 0) return value;
  }
  return "";
}

/** True when the visibility hides the video from the public (private / draft). */
export function isPrivateVisibility(visibility: unknown): boolean {
  if (typeof visibility !== "string") return false;
  return PRIVATE_VISIBILITIES.has(visibility.trim().toLowerCase());
}

/**
 * True when `filePath` is the video's source upload: the path stored in
 * `storage.videoPath`, or `videos/{videoId}/original.<ext>` when no path is stored.
 * Anything else under videos/{videoId}/ (voice samples, dubbed outputs, extra
 * files) must not start the resolution pipeline.
 */
export function isSourceUploadPath(
  filePath: string,
  videoId: string,
  videoData: Record<string, any>
): boolean {
  const prefix = `videos/${videoId}/`;
  if (!filePath.startsWith(prefix)) return false;

  const storedPath = videoData?.storage?.videoPath;
  if (typeof storedPath === "string" && storedPath.startsWith(prefix)) {
    return filePath === storedPath;
  }

  const fileName = filePath.slice(prefix.length);
  return /^original\.[a-z0-9]{2,5}$/i.test(fileName);
}

/**
 * Decides whether an object finalized in Storage may start (or restart) the
 * resolution pipeline for videos/{videoId}.
 *
 * Allowed only when the Firestore video exists, the file is its source upload,
 * and the uploader recorded in the object's `uploaderId` metadata is the video's
 * owner (or an admin). Storage rules already force `uploaderId == request.auth.uid`
 * for client uploads, so this ties the file to a real, owning user.
 */
export function evaluateUploadOwnership(input: {
  filePath: string;
  videoId: string;
  uploaderId: string | undefined | null;
  videoData: Record<string, any> | null | undefined;
  uploaderIsAdmin: boolean;
}): UploadOwnershipDecision {
  const { filePath, videoId, uploaderId, videoData, uploaderIsAdmin } = input;

  if (!videoData) return { allowed: false, reason: "video_doc_missing" };

  const ownerId = getVideoOwnerId(videoData);
  if (!ownerId) return { allowed: false, reason: "owner_missing" };

  if (!isSourceUploadPath(filePath, videoId, videoData)) {
    return { allowed: false, reason: "not_source_file" };
  }

  const uploader = typeof uploaderId === "string" ? uploaderId.trim() : "";
  if (!uploader) return { allowed: false, reason: "uploader_missing" };

  if (uploader !== ownerId && !uploaderIsAdmin) {
    return { allowed: false, reason: "uploader_not_owner" };
  }

  return { allowed: true, ownerId };
}

/** True when the requester may see the resolution status / stream URLs of this video. */
export function canViewResolution(input: {
  videoData: Record<string, any> | null | undefined;
  requesterUid?: string | null;
  requesterIsAdmin?: boolean;
}): boolean {
  const { videoData, requesterUid, requesterIsAdmin } = input;
  if (requesterIsAdmin) return true;
  if (!videoData) return false;
  if (!isPrivateVisibility(videoData.visibility)) return true;
  const ownerId = getVideoOwnerId(videoData);
  return !!requesterUid && !!ownerId && requesterUid === ownerId;
}

/**
 * Strips internal fields (storage paths, raw ffmpeg / Firestore error text) from
 * resolution variants before they leave the backend.
 */
export function toPublicVariants(
  variants: Record<string, any> | null | undefined
): Record<string, Record<string, unknown>> {
  const result: Record<string, Record<string, unknown>> = {};
  if (!variants || typeof variants !== "object") return result;

  for (const [label, variant] of Object.entries(variants)) {
    if (!variant || typeof variant !== "object") continue;
    const clean: Record<string, unknown> = {};
    for (const field of PUBLIC_VARIANT_FIELDS) {
      if (variant[field] !== undefined) clean[field] = variant[field];
    }
    result[label] = clean;
  }
  return result;
}

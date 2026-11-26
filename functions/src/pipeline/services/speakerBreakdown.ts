/**
 * Speaker breakdown — who spoke in the video and how many claims each speaker made.
 *
 * Groups claims by their `speaker` field and reports, per speaker, the detected role,
 * an estimated word count and the claim count. It deliberately assigns no score or
 * rating to any speaker.
 */

import { VerifiedClaim, SpeakerBreakdown } from "../types";
import { logger } from "../utils/logger";

/**
 * Builds the per-speaker breakdown from the video's claims.
 *
 * @param verifiedClaims - All claims of the video (including opinions)
 * @param roles - Optional map of speakerId to detected role (Host, Guest, ...)
 * @returns SpeakerBreakdown[] sorted by claim count, most active speaker first
 */
export function computeSpeakerBreakdown(
  verifiedClaims: VerifiedClaim[],
  roles: Record<string, string> = {}
): SpeakerBreakdown[] {
  if (!verifiedClaims || verifiedClaims.length === 0) return [];

  const speakerMap = new Map<string, VerifiedClaim[]>();
  for (const claim of verifiedClaims) {
    const speaker = claim.speaker || "Speaker A"; // Default when the transcript is not diarized
    if (!speakerMap.has(speaker)) speakerMap.set(speaker, []);
    speakerMap.get(speaker)!.push(claim);
  }

  const breakdowns: SpeakerBreakdown[] = [];
  for (const [speakerId, claims] of speakerMap.entries()) {
    breakdowns.push({
      speakerId,
      label: speakerId,
      role: roles[speakerId] || "Other",
      wordCount: claims.reduce((sum, c) => sum + String(c.text || "").split(/\s+/).filter(Boolean).length, 0),
      claimCount: claims.length,
    });
  }

  breakdowns.sort((a, b) => b.claimCount - a.claimCount);

  logger.info("[SpeakerBreakdown] Computed", {
    speakers: breakdowns.length,
    breakdown: breakdowns.map((s) => `${s.label}: ${s.claimCount} claims`),
  });

  return breakdowns;
}

/**
 * Grounding Attribution — maps Google Search grounding chunks to the specific claim
 * they support inside a multi-claim (batched) Gemini response.
 *
 * Why this exists:
 *   Gemini never sees the index numbers of the grounding chunks it retrieves, so any
 *   "citedChunkIndices" it writes for live search results are guesses (almost always 0).
 *   Treating them as real indices attached the first search result to most claims in a
 *   batch. The only trustworthy link between a claim and a live search result is
 *   `groundingMetadata.groundingSupports`: each support names a span of the response text
 *   and the chunk indices that back that span. Because the response is a JSON array with
 *   one item per claim, the span's position tells us which claim's item it belongs to.
 */

export interface GroundingSupportLike {
  segment?: {
    startIndex?: number;
    endIndex?: number;
    text?: string;
  };
  groundingChunkIndices?: number[];
}

interface ItemSpan {
  claimId: string;
  startByte: number;
  endByte: number;
  startChar: number;
  endChar: number;
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Locates the character span of each claim's JSON object inside the raw response text.
 * Items are delimited by the position of their `"claimId": "<id>"` key; each item runs
 * until the next item's key (or the end of the text).
 */
export function locateClaimItemSpans(responseText: string, claimIds: string[]): ItemSpan[] {
  const found: Array<{ claimId: string; pos: number }> = [];
  for (const id of claimIds) {
    if (!id) continue;
    const rx = new RegExp(`"claimId"\\s*:\\s*"${escapeRegExp(id)}"`);
    const m = rx.exec(responseText);
    if (m) found.push({ claimId: id, pos: m.index });
  }
  found.sort((a, b) => a.pos - b.pos);

  return found.map((f, i) => {
    // Expand start back to the opening brace of this item so a support that covers
    // fields written before "claimId" is still attributed correctly.
    const prevEnd = i > 0 ? found[i - 1].pos : 0;
    const braceIdx = responseText.lastIndexOf("{", f.pos);
    const startChar = braceIdx >= prevEnd ? braceIdx : f.pos;
    const endChar = i + 1 < found.length
      ? Math.max(startChar, responseText.lastIndexOf("{", found[i + 1].pos))
      : responseText.length;
    return {
      claimId: f.claimId,
      startChar,
      endChar,
      startByte: Buffer.byteLength(responseText.slice(0, startChar), "utf8"),
      endByte: Buffer.byteLength(responseText.slice(0, endChar), "utf8"),
    };
  });
}

/**
 * Returns, for each claimId, the grounding chunk indices that back text inside that
 * claim's own JSON item, ordered by how often they were cited (most-cited first).
 *
 * Gemini reports segment offsets in UTF-8 bytes; we also fall back to locating the
 * segment text when offsets are missing.
 */
export function attributeGroundingChunks(
  responseText: string,
  groundingSupports: GroundingSupportLike[] | undefined,
  claimIds: string[],
  chunkCount: number
): Map<string, number[]> {
  const result = new Map<string, number[]>();
  for (const id of claimIds) result.set(id, []);
  if (!responseText || !Array.isArray(groundingSupports) || groundingSupports.length === 0) {
    return result;
  }

  const spans = locateClaimItemSpans(responseText, claimIds);
  if (spans.length === 0) return result;

  const tallies = new Map<string, Map<number, number>>();
  for (const span of spans) tallies.set(span.claimId, new Map());

  for (const sup of groundingSupports) {
    const indices = Array.isArray(sup?.groundingChunkIndices) ? sup.groundingChunkIndices : [];
    if (indices.length === 0) continue;

    let owner: ItemSpan | undefined;
    const seg = sup.segment || {};
    if (typeof seg.endIndex === "number" && seg.endIndex > 0) {
      const startB = typeof seg.startIndex === "number" ? seg.startIndex : 0;
      const midB = startB + Math.max(0, (seg.endIndex - startB) / 2);
      owner = spans.find((s) => midB >= s.startByte && midB < s.endByte);
    }
    if (!owner && seg.text && seg.text.trim().length >= 8) {
      const charPos = responseText.indexOf(seg.text.trim());
      if (charPos >= 0) {
        owner = spans.find((s) => charPos >= s.startChar && charPos < s.endChar);
      }
    }
    if (!owner) continue;

    const tally = tallies.get(owner.claimId)!;
    for (const idx of indices) {
      if (!Number.isInteger(idx) || idx < 0 || idx >= chunkCount) continue;
      tally.set(idx, (tally.get(idx) || 0) + 1);
    }
  }

  for (const [claimId, tally] of tallies) {
    const ordered = Array.from(tally.entries())
      .sort((a, b) => b[1] - a[1] || a[0] - b[0])
      .map(([idx]) => idx);
    result.set(claimId, ordered);
  }
  return result;
}

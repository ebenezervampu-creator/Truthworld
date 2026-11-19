/**
 * 🧩 CLAIM CLUSTERING SERVICE (TruthWorld Phase 1 Optimization)
 *
 * Groups extracted claims into cohesive thematic clusters prior to adjudication.
 *
 * Key Architectural Benefits:
 * 1. Amortizes Vertex Google Search Grounding queries: Groups 2-4 related claims so
 *    Gemini executes a single unified search query instead of N separate queries.
 * 2. Maximizes Tier 4A Pre-retrieval coverage: Thematically aligned claims share
 *    pre-retrieved sources (Wikipedia, PubMed, Crossref), allowing entire clusters
 *    to flip to `useClosedWorldOnly = true`, completely eliminating the $0.014 fee.
 * 3. Improves Contextual Reasoning: LLMs reason more accurately when evaluating
 *    interconnected claims within their shared topical context.
 */

import type { ModernExtractedClaim } from "./factExtraction";

export interface ClusteredClaimBatch {
  clusterId: string;
  domain: string;
  topicSummary: string;
  claims: ModernExtractedClaim[];
  sharedEntities: string[];
}

const COMMON_STOPWORDS = new Set([
  "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of",
  "with", "by", "from", "as", "is", "was", "are", "were", "been", "be", "have",
  "has", "had", "do", "does", "did", "that", "this", "these", "those", "it",
  "its", "they", "their", "we", "our", "you", "your", "he", "his", "she", "her",
  "also", "than", "then", "into", "over", "after", "before", "about", "more",
  "most", "all", "any", "both", "each", "few", "other", "some", "such", "no",
  "nor", "not", "only", "same", "so", "can", "will", "just", "should", "now"
]);

/**
 * Tokenizes text into normalized alphanumeric keywords (length >= 3, lowercase, no stopwords).
 */
export function extractKeywords(text: string): Set<string> {
  if (!text) return new Set();
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 3 && !COMMON_STOPWORDS.has(w));
  return new Set(words);
}

/**
 * Calculates Jaccard similarity coefficient between two sets of strings.
 */
export function jaccardSimilarity(setA: Set<string>, setB: Set<string>): number {
  if (setA.size === 0 || setB.size === 0) return 0;
  let intersectionSize = 0;
  for (const item of setA) {
    if (setB.has(item)) intersectionSize++;
  }
  const unionSize = setA.size + setB.size - intersectionSize;
  return unionSize === 0 ? 0 : intersectionSize / unionSize;
}

export interface ClusteringOptions {
  maxClusterSize?: number;
  minClusterSize?: number;
  similarityThreshold?: number;
}

export class ClaimClusteringService {
  private static readonly DEFAULT_MAX_CLUSTER_SIZE = 4;
  private static readonly DEFAULT_MIN_SIMILARITY = 0.15; // Realistic lexical Jaccard threshold

  /**
   * Clusters claims by domain, shared named entities, and keyword similarity.
   * Claims that do not meet the similarity threshold remain in smaller clusters
   * or are grouped with domain-adjacent peers up to maxClusterSize.
   */
  public static clusterClaims(
    claims: ModernExtractedClaim[],
    options: ClusteringOptions = {}
  ): ClusteredClaimBatch[] {
    if (!claims || claims.length === 0) return [];

    const maxClusterSize = options.maxClusterSize ?? this.DEFAULT_MAX_CLUSTER_SIZE;
    const minSimilarity = options.similarityThreshold ?? this.DEFAULT_MIN_SIMILARITY;

    // 1. Partition claims by domain to prevent cross-domain contamination
    const byDomain = new Map<string, ModernExtractedClaim[]>();
    for (const claim of claims) {
      const domain = claim.domain || "GENERAL_FACT";
      const list = byDomain.get(domain) || [];
      list.push(claim);
      byDomain.set(domain, list);
    }

    const allClusters: ClusteredClaimBatch[] = [];
    let clusterCounter = 1;

    for (const [domain, domainClaims] of byDomain.entries()) {
      if (domainClaims.length <= maxClusterSize) {
        // Domain is already small enough to form a single cohesive cluster
        allClusters.push(this.createCluster(`cluster_${clusterCounter++}`, domain, domainClaims));
        continue;
      }

      // Pre-extract keywords and entities for each claim in this domain
      const claimProfiles = domainClaims.map((claim) => {
        const text = `${claim.normalizedClaim || ""} ${claim.verbatimQuote || ""}`;
        const keywords = extractKeywords(text);
        const entities = new Set(
          (claim.topicEntities || []).map((e: string) => e.toLowerCase().trim()).filter(Boolean)
        );
        return {
          claim,
          keywords,
          entities,
          assigned: false,
        };
      });

      // 2. Greedy thematic agglomeration
      for (let i = 0; i < claimProfiles.length; i++) {
        const base = claimProfiles[i];
        if (base.assigned) continue;

        const currentClusterClaims: ModernExtractedClaim[] = [base.claim];
        const currentKeywords = new Set(base.keywords);
        const currentEntities = new Set(base.entities);
        base.assigned = true;

        // Find candidate matches with highest combined similarity
        const candidates: Array<{ index: number; score: number }> = [];

        for (let j = i + 1; j < claimProfiles.length; j++) {
          const target = claimProfiles[j];
          if (target.assigned) continue;

          // Check entity overlap
          let entityOverlap = 0;
          for (const ent of target.entities) {
            if (currentEntities.has(ent)) entityOverlap++;
          }

          const keywordSim = jaccardSimilarity(currentKeywords, target.keywords);
          // Entities provide a strong boost to thematic clustering
          const score = keywordSim + (entityOverlap > 0 ? 0.35 : 0);

          if (score >= minSimilarity || entityOverlap > 0) {
            candidates.push({ index: j, score });
          }
        }

        // Sort candidates by score descending
        candidates.sort((a, b) => b.score - a.score);

        // Fill current cluster up to maxClusterSize
        for (const cand of candidates) {
          if (currentClusterClaims.length >= maxClusterSize) break;
          const matchedProfile = claimProfiles[cand.index];
          if (!matchedProfile.assigned) {
            currentClusterClaims.push(matchedProfile.claim);
            matchedProfile.keywords.forEach((k) => currentKeywords.add(k));
            matchedProfile.entities.forEach((e) => currentEntities.add(e));
            matchedProfile.assigned = true;
          }
        }

        allClusters.push(
          this.createCluster(`cluster_${clusterCounter++}`, domain, currentClusterClaims)
        );
      }
    }

    return allClusters;
  }

  /**
   * Slices clusters into batches of ModernExtractedClaim[] for consumption by adjudication runners.
   */
  public static toBatches(clusters: ClusteredClaimBatch[]): ModernExtractedClaim[][] {
    return clusters.map((c) => c.claims);
  }

  private static createCluster(
    clusterId: string,
    domain: string,
    claims: ModernExtractedClaim[]
  ): ClusteredClaimBatch {
    // Extract top shared entities or keywords for topic summary
    const entityCounts = new Map<string, number>();
    const keywordCounts = new Map<string, number>();

    for (const c of claims) {
      if (Array.isArray(c.topicEntities)) {
        for (const ent of c.topicEntities) {
          const clean = ent.trim();
          if (clean) entityCounts.set(clean, (entityCounts.get(clean) || 0) + 1);
        }
      }
      const kw = extractKeywords(c.normalizedClaim || c.verbatimQuote || "");
      for (const k of kw) {
        keywordCounts.set(k, (keywordCounts.get(k) || 0) + 1);
      }
    }

    const sortedEntities = Array.from(entityCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([ent]) => ent);

    const sortedKeywords = Array.from(keywordCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([k]) => k);

    const summaryParts = [
      ...sortedEntities.slice(0, 2),
      ...sortedKeywords.slice(0, 3),
    ];
    const topicSummary = summaryParts.length > 0 ? summaryParts.join(", ") : domain;

    return {
      clusterId,
      domain,
      topicSummary,
      claims,
      sharedEntities: sortedEntities,
    };
  }
}

export const claimClusteringService = ClaimClusteringService;

/**
 * Opportunistic L1 In-Memory LRU Cache for warm Cloud Function instances.
 */

interface CacheEntry {
  html: string;
  etag: string;
  lastModified: string;
  cachedAt: number;
}

const MEMORY_CACHE = new Map<string, CacheEntry>();
const MAX_ENTRIES = 200;
const TTL_MS = 300 * 1000; // 5 minutes in-memory TTL

export function getMemorySnapshot(key: string): CacheEntry | null {
  const entry = MEMORY_CACHE.get(key);
  if (!entry) return null;
  if (Date.now() - entry.cachedAt > TTL_MS) {
    MEMORY_CACHE.delete(key);
    return null;
  }
  return entry;
}

export function setMemorySnapshot(key: string, html: string, etag: string, lastModified: string): void {
  if (MEMORY_CACHE.size >= MAX_ENTRIES) {
    // Evict oldest entry
    const firstKey = MEMORY_CACHE.keys().next().value;
    if (firstKey) MEMORY_CACHE.delete(firstKey);
  }
  MEMORY_CACHE.set(key, {
    html,
    etag,
    lastModified,
    cachedAt: Date.now()
  });
}

export function clearMemoryCache(): void {
  MEMORY_CACHE.clear();
}

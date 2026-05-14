/**
 * 💾 IN-MEMORY CACHE UTILITY
 *
 * Per-instance ephemeral LRU cache for hot data.
 * Each instance maintains its own cache (no shared state).
 *
 * ✅ BENEFITS:
 *   - Zero network calls (in-process)
 *   - Zero cost (memory-based)
 *   - Automatic TTL + eviction
 *   - 5000-key capacity per instance
 *   - ~<1ms lookup time
 */

const lruCache = new Map<string, { value: any; expiresAt: number }>();

/** Max keys in cache */
const MAX_CACHE_SIZE = 5000;

/** Default TTL in seconds */
const DEFAULT_TTL_SECONDS = 3600; // 1 hour

/**
 * Get a value from cache.
 * Returns undefined if not found or expired.
 */
export function getCache(key: string): any {
  const entry = lruCache.get(key);
  
  if (!entry) {
    return undefined;
  }
  
  // Check if expired
  if (Date.now() > entry.expiresAt) {
    lruCache.delete(key);
    return undefined;
  }
  
  return entry.value;
}

/**
 * Set a value in cache with optional TTL (in seconds).
 * Auto-evicts oldest entry if cache is full.
 */
export function setCache(key: string, value: any, ttlSeconds?: number): void {
  const ttl = (ttlSeconds ?? DEFAULT_TTL_SECONDS) * 1000; // ms
  const expiresAt = Date.now() + ttl;
  
  // If cache is full, delete oldest entry
  if (lruCache.size >= MAX_CACHE_SIZE && !lruCache.has(key)) {
    const oldestKey = lruCache.keys().next().value;
    if (oldestKey) {
      lruCache.delete(oldestKey);
    }
  }
  
  lruCache.set(key, { value, expiresAt });
}

/**
 * Delete a specific key from cache.
 */
export function deleteCache(key: string): void {
  lruCache.delete(key);
}

/**
 * Clear entire cache.
 */
export function clearCache(): void {
  lruCache.clear();
}

/**
 * Get cache statistics (for monitoring).
 */
export function getCacheStats(): {
  size: number;
  maxSize: number;
  usage: string;
} {
  // Clean up expired entries first
  const now = Date.now();
  for (const [key, entry] of lruCache.entries()) {
    if (now > entry.expiresAt) {
      lruCache.delete(key);
    }
  }
  
  return {
    size: lruCache.size,
    maxSize: MAX_CACHE_SIZE,
    usage: `${lruCache.size}/${MAX_CACHE_SIZE} (${Math.round((lruCache.size / MAX_CACHE_SIZE) * 100)}%)`,
  };
}

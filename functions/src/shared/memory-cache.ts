/**
 * 🧠 MEMORY CACHE (SHARED CORE)
 * 
 * High-performance L1 cache to avoid redundant Firestore reads.
 * Shared by all independent services.
 */

const cache = new Map<string, { value: any; expiry: number }>();

export function setCache(key: string, value: any, ttlSeconds: number): void {
  cache.set(key, {
    value,
    expiry: Date.now() + ttlSeconds * 1000,
  });
}

export function getCache<T>(key: string): T | undefined {
  const item = cache.get(key);
  if (!item) return undefined;
  
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return undefined;
  }
  
  return item.value as T;
}

export function deleteCache(key: string): void {
  cache.delete(key);
}

export function clearCache(): void {
  cache.clear();
}

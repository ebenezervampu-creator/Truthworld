/**
 * 🧠 DUAL-BOUNDED LRU MEMORY CACHE (SHARED CORE)
 *
 * High-performance, memory-safe L1 in-process cache to avoid redundant Firestore reads.
 * Protects 256 MiB Cloud Function containers from heap bloat and OOM crashes.
 *
 * Constraints:
 *   - Maximum entries: 150
 *   - Maximum serialized payload: 16 MiB (16,777,216 bytes)
 *   - Maximum single entry size: 256 KiB (262,144 bytes)
 *   - Absolute TTL: 60 seconds
 *   - Eviction: Least-Recently-Used (LRU) on both count and byte limits
 *   - Heap & RSS telemetry alerts when heapUsed > 180 MiB
 */

export interface CacheEntry<T> {
  value: T;
  bytes: number;
  expiry: number;
  generation: number;
}

export class DualBoundedLruCache {
  private readonly maxEntries: number;
  private readonly maxTotalBytes: number;
  private readonly maxEntryBytes: number;
  private readonly defaultTtlMs: number;

  private currentTotalBytes = 0;
  private readonly map = new Map<string, CacheEntry<any>>();
  private feedGeneration = 1;

  constructor(options?: {
    maxEntries?: number;
    maxTotalBytes?: number;
    maxEntryBytes?: number;
    defaultTtlSeconds?: number;
  }) {
    this.maxEntries = options?.maxEntries ?? 150;
    this.maxTotalBytes = options?.maxTotalBytes ?? 16 * 1024 * 1024; // 16 MiB
    this.maxEntryBytes = options?.maxEntryBytes ?? 256 * 1024;       // 256 KiB
    this.defaultTtlMs = (options?.defaultTtlSeconds ?? 60) * 1000;
  }

  private estimateBytes(value: any): number {
    if (typeof value === "string") {
      return Buffer.byteLength(value, "utf8");
    }
    try {
      return Buffer.byteLength(JSON.stringify(value), "utf8");
    } catch {
      return 1024; // Fallback estimate
    }
  }

  public getGeneration(): number {
    return this.feedGeneration;
  }

  public invalidateGeneration(): void {
    this.feedGeneration += 1;
  }

  public get<T>(key: string): T | undefined {
    const entry = this.map.get(key);
    if (!entry) return undefined;

    // Check TTL expiry
    if (Date.now() > entry.expiry) {
      this.delete(key);
      return undefined;
    }

    // Check feed generation
    if (entry.generation !== this.feedGeneration) {
      this.delete(key);
      return undefined;
    }

    // Refresh recency for LRU
    this.map.delete(key);
    this.map.set(key, entry);

    return entry.value as T;
  }

  public set<T>(key: string, value: T, ttlSeconds?: number): boolean {
    const bytes = this.estimateBytes(value);

    // Reject unexpectedly oversized payloads
    if (bytes > this.maxEntryBytes) {
      console.warn(
        `[MemoryCache] Payload for key "${key}" (${bytes} bytes) exceeds single entry limit of ${this.maxEntryBytes} bytes. Skipping cache.`
      );
      return false;
    }

    // Remove existing key if present to recalculate bytes
    if (this.map.has(key)) {
      this.delete(key);
    }

    // Enforce byte and entry limits via LRU eviction
    while (
      (this.map.size >= this.maxEntries || this.currentTotalBytes + bytes > this.maxTotalBytes) &&
      this.map.size > 0
    ) {
      const oldestKey = this.map.keys().next().value;
      if (oldestKey) {
        this.delete(oldestKey);
      } else {
        break;
      }
    }

    const ttlMs = ttlSeconds ? ttlSeconds * 1000 : this.defaultTtlMs;
    const entry: CacheEntry<T> = {
      value,
      bytes,
      expiry: Date.now() + ttlMs,
      generation: this.feedGeneration,
    };

    this.map.set(key, entry);
    this.currentTotalBytes += bytes;

    // Monitor container memory
    this.checkMemoryHeadroom();
    return true;
  }

  public delete(key: string): boolean {
    const entry = this.map.get(key);
    if (entry) {
      this.currentTotalBytes -= entry.bytes;
      if (this.currentTotalBytes < 0) this.currentTotalBytes = 0;
      this.map.delete(key);
      return true;
    }
    return false;
  }

  public clear(): void {
    this.map.clear();
    this.currentTotalBytes = 0;
  }

  public getStats() {
    return {
      size: this.map.size,
      totalBytes: this.currentTotalBytes,
      maxEntries: this.maxEntries,
      maxTotalBytes: this.maxTotalBytes,
      feedGeneration: this.feedGeneration,
    };
  }

  private checkMemoryHeadroom(): void {
    // Skip warning in test environments where Jest harness consumes high heap
    if (process.env.NODE_ENV === "test") return;

    if (typeof process !== "undefined" && process.memoryUsage) {
      const mem = process.memoryUsage();
      const heapUsedMB = mem.heapUsed / (1024 * 1024);
      if (heapUsedMB > 180) {
        console.warn(
          `[MemoryCache Warning] Cloud Function container heap is elevated: ${heapUsedMB.toFixed(1)} MiB used (RSS: ${(mem.rss / (1024 * 1024)).toFixed(1)} MiB). Purging half of cache.`
        );
        // Aggressively evict oldest half
        const purgeCount = Math.floor(this.map.size / 2);
        for (let i = 0; i < purgeCount; i++) {
          const oldest = this.map.keys().next().value;
          if (oldest) this.delete(oldest);
        }
      }
    }
  }
}

// Global shared singleton
export const sharedLruCache = new DualBoundedLruCache();

export function setCache(key: string, value: any, ttlSeconds: number): void {
  sharedLruCache.set(key, value, ttlSeconds);
}

export function getCache<T>(key: string): T | undefined {
  return sharedLruCache.get<T>(key);
}

export function deleteCache(key: string): void {
  sharedLruCache.delete(key);
}

export function clearCache(): void {
  sharedLruCache.clear();
}

export function invalidateFeedGeneration(): void {
  sharedLruCache.invalidateGeneration();
}

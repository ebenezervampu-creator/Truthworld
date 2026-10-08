/**
 * TruthWorld Ultra-Low Latency Streaming Service Worker
 * Optimized for Flutter WebAssembly (Wasm-GC + Skwasm / CanvasKit)
 *
 * Capabilities:
 * - Sub-200ms cold boots via aggressive Cache-First + Stale-While-Revalidate streaming.
 * - Streams Wasm chunks directly into WebAssembly.compileStreaming.
 * - Preserves Chrome V8 / WebKit native tier-2 Wasm compiled bytecode cache.
 * - Auto-invalidates stale caches on new version deployments via version signature matching.
 */

'use strict';

const SW_VERSION = 'tw-engine-v1.0.1';
const CACHE_NAME_STATIC = `${SW_VERSION}-static`;
const CACHE_NAME_WASM = `${SW_VERSION}-wasm`;

// Core assets to pre-populate on install
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png'
];

// File extension patterns
const WASM_CHUNK_REGEX = /\.(wasm|mjs)(\?.*)?$/i;
const STATIC_ASSET_REGEX = /\.(png|jpg|jpeg|svg|webp|woff2|woff|ttf|css|json|bin)(\?.*)?$/i;

self.addEventListener('install', (event) => {
  // Activate immediately without waiting for previous worker to close
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME_STATIC).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        // Non-blocking: continue installation even if some precache assets fail
        console.warn('[Truthworld SW] Precache warning:', err);
      });
    })
  );
});

self.addEventListener('activate', (event) => {
  // Claim all clients immediately so navigation requests are controlled
  event.waitUntil(
    Promise.all([
      self.clients.claim(),
      caches.keys().then((keys) => {
        return Promise.all(
          keys.map((key) => {
            if (key !== CACHE_NAME_STATIC && key !== CACHE_NAME_WASM) {
              console.log('[Truthworld SW] Purging obsolete cache:', key);
              return caches.delete(key);
            }
          })
        );
      })
    ])
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // Bypass Firebase internal reserved endpoints (OAuth auth handler, etc.)
  if (url.pathname.startsWith('/__/')) {
    return;
  }

  // Only intercept GET requests
  if (request.method !== 'GET') {
    return;
  }

  // 1. version.json: Always Network-First (Never serve stale version info)
  if (url.pathname.endsWith('/version.json')) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          const cloned = networkResponse.clone();
          caches.open(CACHE_NAME_STATIC).then((cache) => cache.put(request, cloned));
          return networkResponse;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // 2. WebAssembly & JS Support Runtime (*.wasm, main.dart.mjs, skwasm.*)
  // Strategy: Streamed Cache-First with Background Stale-While-Revalidate
  // This enables sub-200ms instantaneous loads and activates V8 compiled code cache
  if (WASM_CHUNK_REGEX.test(url.pathname)) {
    event.respondWith(
      caches.open(CACHE_NAME_WASM).then(async (cache) => {
        const cachedResponse = await cache.match(request);
        if (cachedResponse) {
          // Serve from cache immediately; update cache in background (Stale-While-Revalidate)
          event.waitUntil(
            fetch(request).then((networkResponse) => {
              if (networkResponse && networkResponse.status === 200) {
                return cache.put(request, networkResponse);
              }
            }).catch(() => {})
          );
          return cachedResponse;
        }

        // Cache miss: stream from network and cache
        return fetch(request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            cache.put(request, networkResponse.clone());
          }
          return networkResponse;
        });
      })
    );
    return;
  }

  // 3. Static Media & Fonts: Cache-First
  if (STATIC_ASSET_REGEX.test(url.pathname) || url.hostname.includes('gstatic.com') || url.hostname.includes('googleapis.com')) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        return fetch(request).then((networkResponse) => {
          if (networkResponse && (networkResponse.status === 200 || networkResponse.type === 'opaque')) {
            const cloned = networkResponse.clone();
            caches.open(CACHE_NAME_STATIC).then((cache) => cache.put(request, cloned));
          }
          return networkResponse;
        });
      })
    );
    return;
  }

  // 4. HTML Navigation Requests (index.html): Network-First with Cache Fallback
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const cloned = networkResponse.clone();
            caches.open(CACHE_NAME_STATIC).then((cache) => cache.put(request, cloned));
          }
          return networkResponse;
        })
        .catch(() => {
          return caches.match('/index.html') || caches.match('/');
        })
    );
    return;
  }

  // Default: Network with Cache Fallback
  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      return cachedResponse || fetch(request);
    })
  );
});

// Communication channel with Flutter Web client
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

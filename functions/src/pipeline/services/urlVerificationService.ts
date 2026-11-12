import * as crypto from "crypto";
import * as dns from "dns";
import * as http from "http";
import * as https from "https";
import * as net from "net";
import * as zlib from "zlib";
import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import {
  ClaimNature,
  DeterministicVerification,
  EvidenceCandidate,
  EvidenceLevel,
  RichSource,
  SourceTier,
  UrlVerificationRecord,
  UrlVerificationStatus,
  VerifiedClaim,
} from "../types";
import { logger } from "../utils/logger";
import { getCache, setCache } from "../utils/memory-cache";

export interface HttpProbeResponse {
  statusCode: number;
  headers: Record<string, string | string[] | undefined>;
  bodyText: string;
  remoteAddress?: string;
}

export type HttpProbeTransport = (
  url: URL,
  options: {
    pinnedIp: string;
    pinnedFamily: 4 | 6;
    timeoutMs: number;
    maxBytes: number;
    userAgent: string;
  }
) => Promise<HttpProbeResponse>;

export type DnsLookupFn = (
  hostname: string
) => Promise<Array<{ address: string; family: 4 | 6 }>>;

export interface VerifyUrlOptions {
  allowHomepage?: boolean;
  bypassCache?: boolean;
  relevanceQueries?: string[];
  verifierMethod?: UrlVerificationRecord["verifierMethod"];
  timeoutMs?: number;
}

interface ParsedHtmlSignals {
  title: string;
  h1: string;
  metaDescription: string;
  canonicalHref?: string;
  robotsMeta: string;
  visibleText: string;
}

const HEALTH_CACHE_COLLECTION = "url_health_cache";
const DEFAULT_USER_AGENT =
  "TruthWorldFactCheckBot/2.0 (+https://truthworld.co/verification; Mozilla/5.0 compatible)";

const TRACKING_QUERY_PARAMS = new Set([
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_term",
  "utm_content",
  "utm_id",
  "fbclid",
  "gclid",
  "dclid",
  "msclkid",
  "mc_cid",
  "mc_eid",
  "_hsenc",
  "_hsmi",
  "igshid",
  "ref_src",
]);

const STRONG_SOFT_404_PATTERNS: RegExp[] = [
  /^404\b/i,
  /\b404\s*(?:error|not\s+found|page)\b/i,
  /\berror\s*404\b/i,
  /\bhttp\s*(?:error\s*)?404\b/i,
  /\bstatus\s*:\s*404\b/i,
  /\bpage\s+not\s+found\b/i,
  /\bthis\s+page\s+(?:could|can)\s*not\s+be\s+found\b/i,
  /\bthe\s+page\s+you\s+(?:are\s+trying\s+to\s+reach|requested|were\s+looking\s+for)\s+(?:is\s+not\s+available|was\s+not\s+found|could\s+not\s+be\s+found|doesn['’]?t\s+exist)\b/i,
  /\boops!?\s*looks\s+like\s+we['’]?ve\s+hit\s+a\s+bit\s+of\s+a\s+snag\b/i,
  /\bwe\s+seem\s+to\s+have\s+misplaced\s+this\s+page\b/i,
  /\bmessage\s*:\s*not\s+found\b/i,
  /\bsorry,\s+we\s+can['’]?t\s+find\s+that\s+page\b/i,
  /\barticle\s+(?:was\s+)?not\s+found\b/i,
  /\bcontent\s+(?:is\s+)?no\s+longer\s+available\b/i,
  /\bdocument\s+not\s+found\b/i,
];

const ERROR_PATH_PATTERNS: RegExp[] = [
  /\/404\.(?:html?|php|aspx)$/i,
  /\/not-?found\/?$/i,
  /\/page-not-found\/?$/i,
  /\/error-?404\/?$/i,
  /\/errors?\/404\/?$/i,
];

const HOMEPAGE_ALLOWLIST_PATHS = new Set<string>([
  "physics.nist.gov/cuu/Constants/",
  "physics.nist.gov/cuu/Constants",
  "earthdata.nasa.gov/",
  "earthdata.nasa.gov",
]);

const STOPWORDS = new Set([
  "the", "and", "for", "that", "with", "from", "this", "are", "was", "were",
  "have", "has", "had", "not", "but", "can", "could", "will", "would", "may",
  "might", "should", "into", "onto", "about", "after", "before", "over", "under",
  "between", "through", "during", "while", "where", "when", "what", "which",
  "who", "whom", "whose", "how", "than", "then", "also", "more", "most", "some",
  "such", "only", "same", "other", "their", "there", "they", "them", "these",
  "those", "being", "been", "does", "did", "doing", "because", "your", "our",
]);

function ipv4ToInt(ip: string): number | null {
  const parts = ip.split(".");
  if (parts.length !== 4) return null;
  let value = 0;
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part)) return null;
    const n = Number(part);
    if (n < 0 || n > 255) return null;
    value = (value << 8) | n;
  }
  return value >>> 0;
}

function inIpv4Cidr(ipInt: number, base: string, prefixLen: number): boolean {
  const baseInt = ipv4ToInt(base);
  if (baseInt === null) return true;
  const mask = prefixLen === 0 ? 0 : (~0 << (32 - prefixLen)) >>> 0;
  return (ipInt & mask) === (baseInt & mask);
}

function expandIpv6ToHextets(rawIp: string): number[] | null {
  let ip = rawIp.toLowerCase();
  const zoneIdx = ip.indexOf("%");
  if (zoneIdx !== -1) {
    ip = ip.slice(0, zoneIdx);
  }
  if (!ip.includes(":")) return null;

  // Handle trailing dotted IPv4 (e.g. ::ffff:127.0.0.1)
  const lastColon = ip.lastIndexOf(":");
  const tail = ip.slice(lastColon + 1);
  if (tail.includes(".")) {
    const v4Int = ipv4ToInt(tail);
    if (v4Int === null) return null;
    const hi = ((v4Int >>> 16) & 0xffff).toString(16);
    const lo = (v4Int & 0xffff).toString(16);
    ip = `${ip.slice(0, lastColon + 1)}${hi}:${lo}`;
  }

  const halves = ip.split("::");
  if (halves.length > 2) return null;

  const left = halves[0] ? halves[0].split(":").filter(Boolean) : [];
  const right = halves.length === 2 && halves[1] ? halves[1].split(":").filter(Boolean) : [];
  const missing = 8 - (left.length + right.length);
  if (halves.length === 1 && missing !== 0) return null;
  if (missing < 0) return null;

  const parts = [...left, ...Array(missing).fill("0"), ...right];
  if (parts.length !== 8) return null;

  const hextets: number[] = [];
  for (const p of parts) {
    if (!/^[0-9a-f]{1,4}$/i.test(p)) return null;
    hextets.push(parseInt(p, 16));
  }
  return hextets;
}

/**
 * Checks whether an IPv4 or IPv6 address belongs to loopback, private, link-local,
 * carrier-grade NAT, documentation, multicast, or cloud metadata address space.
 */
export function isPrivateOrReservedIp(rawIp: string): boolean {
  const cleaned = rawIp.trim().replace(/^\[|\]$/g, "");
  const ipVersion = net.isIP(cleaned);
  if (ipVersion === 0) return true;

  if (ipVersion === 4) {
    const ipInt = ipv4ToInt(cleaned);
    if (ipInt === null) return true;
    const blockedV4Cidrs: Array<[string, number]> = [
      ["0.0.0.0", 8],
      ["10.0.0.0", 8],
      ["100.64.0.0", 10], // RFC 6598 CGNAT
      ["127.0.0.0", 8],
      ["169.254.0.0", 16], // Link-local & cloud metadata
      ["172.16.0.0", 12],
      ["192.0.0.0", 24],
      ["192.0.2.0", 24],
      ["192.88.99.0", 24],
      ["192.168.0.0", 16],
      ["198.18.0.0", 15],
      ["198.51.100.0", 24],
      ["203.0.113.0", 24],
      ["224.0.0.0", 4],
      ["240.0.0.0", 4],
    ];
    return blockedV4Cidrs.some(([base, prefix]) => inIpv4Cidr(ipInt, base, prefix));
  }

  const h = expandIpv6ToHextets(cleaned);
  if (!h) return true;

  const isAllZero = h.every((x) => x === 0);
  const isLoopback = h.slice(0, 7).every((x) => x === 0) && h[7] === 1;
  if (isAllZero || isLoopback) return true;

  // ::ffff:0:0/96 (IPv4-mapped IPv6)
  if (h.slice(0, 5).every((x) => x === 0) && h[5] === 0xffff) {
    const v4 = `${h[6] >>> 8}.${h[6] & 0xff}.${h[7] >>> 8}.${h[7] & 0xff}`;
    return isPrivateOrReservedIp(v4);
  }

  // 64:ff9b::/96 (NAT64 well-known prefix)
  if (h[0] === 0x0064 && h[1] === 0xff9b && h.slice(2, 6).every((x) => x === 0)) {
    const v4 = `${h[6] >>> 8}.${h[6] & 0xff}.${h[7] >>> 8}.${h[7] & 0xff}`;
    return isPrivateOrReservedIp(v4);
  }

  // 64:ff9b:1::/48 (NAT64 local-use)
  if (h[0] === 0x0064 && h[1] === 0xff9b && h[2] === 0x0001) return true;

  // 100::/64 (Discard-only)
  if (h[0] === 0x0100 && h[1] === 0 && h[2] === 0 && h[3] === 0) return true;

  // 2001:db8::/32 (Documentation)
  if (h[0] === 0x2001 && h[1] === 0x0db8) return true;

  // fc00::/7 (Unique Local Addresses)
  if ((h[0] & 0xfe00) === 0xfc00) return true;

  // fe80::/10 (Link-Local)
  if ((h[0] & 0xffc0) === 0xfe80) return true;

  // ff00::/8 (Multicast)
  if ((h[0] & 0xff00) === 0xff00) return true;

  return false;
}

/**
 * Validates URL scheme, port, credentials, and obvious local/internal hostnames before DNS lookup.
 */
export function validateSafeExternalUrl(rawUrl: string): URL | null {
  if (!rawUrl || typeof rawUrl !== "string") return null;
  const trimmed = rawUrl.trim();
  if (trimmed.length < 10 || trimmed.length > 2048 || /[\x00-\x1f\x7f]/.test(trimmed)) {
    return null;
  }

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }

  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    return null;
  }
  if (parsed.username || parsed.password) {
    return null;
  }

  // Restrict to standard web ports so internal service ports cannot be probed
  if (parsed.port) {
    if (
      !(parsed.protocol === "http:" && parsed.port === "80") &&
      !(parsed.protocol === "https:" && parsed.port === "443")
    ) {
      return null;
    }
  }

  const hostLower = parsed.hostname.toLowerCase();
  if (
    !hostLower ||
    hostLower === "localhost" ||
    hostLower.endsWith(".localhost") ||
    hostLower.endsWith(".local") ||
    hostLower.endsWith(".internal") ||
    hostLower.endsWith(".localdomain") ||
    hostLower === "metadata.google.internal" ||
    hostLower === "instance-data"
  ) {
    return null;
  }

  // If hostname is a literal IP (v4 or v6), enforce immediate public-IP check
  const bareHost = hostLower.replace(/^\[|\]$/g, "");
  if (net.isIP(bareHost) !== 0) {
    if (isPrivateOrReservedIp(bareHost)) return null;
  } else if (!hostLower.includes(".")) {
    // Reject single-label intranet hostnames
    return null;
  }

  return parsed;
}

/**
 * Strips marketing/tracking query parameters and normalizes trailing artifacts.
 */
export function canonicalizeUrl(rawUrl: string): string {
  const parsed = new URL(rawUrl);
  parsed.hostname = parsed.hostname.toLowerCase();
  for (const key of Array.from(parsed.searchParams.keys())) {
    if (TRACKING_QUERY_PARAMS.has(key.toLowerCase())) {
      parsed.searchParams.delete(key);
    }
  }
  if ((parsed.protocol === "https:" && parsed.port === "443") || (parsed.protocol === "http:" && parsed.port === "80")) {
    parsed.port = "";
  }
  return parsed.toString();
}

/**
 * Detects generic root homepages so broken deep links are never silently replaced with a publisher root.
 */
export function isGenericHomepageUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    const hostClean = parsed.hostname.toLowerCase().replace(/^www\./, "");
    const hostPlusPath = `${hostClean}${parsed.pathname}`;
    if (HOMEPAGE_ALLOWLIST_PATHS.has(hostPlusPath)) {
      return false;
    }

    if (
      hostClean === "vertexaisearch.cloud.google.com" ||
      parsed.pathname.includes("grounding-api-redirect")
    ) {
      return false;
    }

    // Meaningful query strings (?id=123, ?p=45) are valid deep links even at root path
    const nonTrackingParams = Array.from(parsed.searchParams.keys()).filter(
      (k) => !TRACKING_QUERY_PARAMS.has(k.toLowerCase())
    );
    if (nonTrackingParams.length > 0) {
      return false;
    }

    const path = parsed.pathname.toLowerCase().replace(/\/+$/, "");
    if (!path || path === "/index.html" || path === "/index.htm" || path === "/index.php" || path === "/home") {
      return true;
    }
    // Single 2-letter language code homepages like /en, /te, /hi, /en-us
    if (/^\/[a-z]{2}(?:-[a-z]{2})?$/.test(path)) {
      return true;
    }
    return false;
  } catch {
    return true;
  }
}

function decodeHtmlEntities(input: string): string {
  return input
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&nbsp;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function extractHtmlSignals(html: string): ParsedHtmlSignals {
  const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  const h1Match = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  const metaDescMatch =
    html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([\s\S]*?)["'][^>]*>/i) ||
    html.match(/<meta[^>]+content=["']([\s\S]*?)["'][^>]+name=["']description["'][^>]*>/i);
  const canonicalMatch =
    html.match(/<link[^>]+rel=["']canonical["'][^>]+href=["']([\s\S]*?)["'][^>]*>/i) ||
    html.match(/<link[^>]+href=["']([\s\S]*?)["'][^>]+rel=["']canonical["'][^>]*>/i);
  const robotsMatch =
    html.match(/<meta[^>]+name=["']robots["'][^>]+content=["']([\s\S]*?)["'][^>]*>/i) ||
    html.match(/<meta[^>]+content=["']([\s\S]*?)["'][^>]+name=["']robots["'][^>]*>/i);

  const stripTags = (s: string) => decodeHtmlEntities(s.replace(/<[^>]+>/g, " "));

  const cleanedBody = decodeHtmlEntities(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
      .replace(/<svg[\s\S]*?<\/svg>/gi, " ")
      .replace(/<[^>]+>/g, " ")
  );

  return {
    title: titleMatch ? stripTags(titleMatch[1]) : "",
    h1: h1Match ? stripTags(h1Match[1]) : "",
    metaDescription: metaDescMatch ? decodeHtmlEntities(metaDescMatch[1]) : "",
    canonicalHref: canonicalMatch ? decodeHtmlEntities(canonicalMatch[1]) : undefined,
    robotsMeta: robotsMatch ? decodeHtmlEntities(robotsMatch[1]).toLowerCase() : "",
    visibleText: cleanedBody.slice(0, 4000),
  };
}

export function detectSoft404(
  finalUrl: string,
  originalUrl: string,
  signals: ParsedHtmlSignals,
  allowHomepage: boolean
): { isSoft404: boolean; reason?: string } {
  let parsedFinal: URL;
  let parsedOrig: URL;
  try {
    parsedFinal = new URL(finalUrl);
    parsedOrig = new URL(originalUrl);
  } catch {
    return { isSoft404: true, reason: "Invalid final URL" };
  }

  // 1. Explicit error paths or query indicators
  const redirectedTo404Path =
    parsedFinal.href !== parsedOrig.href && /\/404\/?$/i.test(parsedFinal.pathname);
  if (
    redirectedTo404Path ||
    ERROR_PATH_PATTERNS.some((rx) => rx.test(parsedFinal.pathname)) ||
    parsedFinal.searchParams.get("error") === "404" ||
    parsedFinal.searchParams.get("status") === "404"
  ) {
    return { isSoft404: true, reason: `Redirected to error path: ${parsedFinal.pathname}` };
  }

  // 2. Dead deep article path silently redirected to root homepage
  const origIsRedirectWrapper =
    parsedOrig.hostname.includes("vertexaisearch.cloud.google.com") ||
    parsedOrig.pathname.includes("grounding-api-redirect");
  if (
    !allowHomepage &&
    !origIsRedirectWrapper &&
    !isGenericHomepageUrl(originalUrl) &&
    isGenericHomepageUrl(finalUrl)
  ) {
    return {
      isSoft404: true,
      reason: `Deep article URL silently redirected to generic homepage (${finalUrl})`,
    };
  }

  // 3. Title or H1 strong error page phrases
  for (const rx of STRONG_SOFT_404_PATTERNS) {
    if (signals.title && rx.test(signals.title)) {
      return { isSoft404: true, reason: `HTML <title> indicates not found: "${signals.title}"` };
    }
    if (signals.h1 && rx.test(signals.h1)) {
      return { isSoft404: true, reason: `HTML <h1> indicates not found: "${signals.h1}"` };
    }
  }

  // 4. Short shell body matching Soft-404 signature (avoids false-positives on long articles about HTTP 404)
  if (signals.visibleText.length < 3500) {
    for (const rx of STRONG_SOFT_404_PATTERNS) {
      if (rx.test(signals.visibleText)) {
        return { isSoft404: true, reason: `Body indicates Soft-404 (${rx.source})` };
      }
    }
  }

  // 5. noindex combined with unavailability phrasing in prominent body head
  if (signals.robotsMeta.includes("noindex")) {
    const headSnippet = signals.visibleText.slice(0, 600);
    if (/\b(?:not\s+found|404|unavailable|misplaced\s+this\s+page)\b/i.test(headSnippet)) {
      return { isSoft404: true, reason: "noindex + error notice in page body" };
    }
  }

  return { isSoft404: false };
}

function tokenizeRelevantTerms(input: string): string[] {
  return input
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 3 && !STOPWORDS.has(w) && !/^\d+$/.test(w));
}

function defaultDnsLookup(hostname: string): Promise<Array<{ address: string; family: 4 | 6 }>> {
  return dns.promises.lookup(hostname, { all: true }).then((entries) =>
    entries.map((e) => ({
      address: e.address,
      family: e.family === 6 ? 6 : 4,
    }))
  );
}

/**
 * Performs an HTTP/HTTPS GET pinned to a previously validated public IP address so DNS
 * rebinding cannot occur between DNS validation and TCP socket connection.
 */
function defaultPinnedHttpTransport(
  url: URL,
  options: {
    pinnedIp: string;
    pinnedFamily: 4 | 6;
    timeoutMs: number;
    maxBytes: number;
    userAgent: string;
  }
): Promise<HttpProbeResponse> {
  return new Promise((resolve, reject) => {
    const isHttps = url.protocol === "https:";
    const mod = isHttps ? https : http;

    const customLookup: http.AgentOptions["lookup"] = ((
      _hostname: string,
      opts: any,
      cb: (...args: any[]) => void
    ) => {
      const callback = typeof opts === "function" ? opts : cb;
      if (typeof opts === "object" && opts?.all) {
        callback(null, [{ address: options.pinnedIp, family: options.pinnedFamily }]);
      } else {
        callback(null, options.pinnedIp, options.pinnedFamily);
      }
    }) as any;

    const req = mod.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port ? Number(url.port) : isHttps ? 443 : 80,
        path: `${url.pathname}${url.search}`,
        method: "GET",
        agent: false, // Never reuse sockets across untrusted external domains
        lookup: customLookup,
        ...(isHttps ? { servername: url.hostname } : {}),
        headers: {
          "User-Agent": options.userAgent,
          Accept: "text/html,application/xhtml+xml,application/pdf,application/json;q=0.9,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9",
          "Accept-Encoding": "gzip, deflate, br",
          Connection: "close",
        },
        timeout: options.timeoutMs,
      },
      (res) => {
        const statusCode = res.statusCode ?? 0;

        // Defense-in-depth: confirm actual socket peer IP is public before reading bytes
        const peerIp = res.socket?.remoteAddress;
        if (peerIp && isPrivateOrReservedIp(peerIp)) {
          res.destroy();
          reject(new Error(`SSRF blocked on connected socket peer IP: ${peerIp}`));
          return;
        }

        // On redirects, do not buffer body; let caller follow Location cleanly
        if (statusCode >= 300 && statusCode < 400 && res.headers.location) {
          res.resume();
          resolve({
            statusCode,
            headers: res.headers as Record<string, string | string[] | undefined>,
            bodyText: "",
            remoteAddress: peerIp,
          });
          return;
        }

        const encodingHeader = String(res.headers["content-encoding"] || "").toLowerCase();
        let stream: NodeJS.ReadableStream = res;
        if (encodingHeader.includes("br")) {
          stream = res.pipe(zlib.createBrotliDecompress());
        } else if (encodingHeader.includes("gzip")) {
          stream = res.pipe(zlib.createGunzip());
        } else if (encodingHeader.includes("deflate")) {
          stream = res.pipe(zlib.createInflate());
        }

        const chunks: Buffer[] = [];
        let totalBytes = 0;
        let settled = false;

        const finish = () => {
          if (settled) return;
          settled = true;
          resolve({
            statusCode,
            headers: res.headers as Record<string, string | string[] | undefined>,
            bodyText: Buffer.concat(chunks).toString("utf8"),
            remoteAddress: peerIp,
          });
        };

        stream.on("data", (chunk: Buffer) => {
          const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
          const remaining = options.maxBytes - totalBytes;
          if (remaining > 0) {
            chunks.push(buf.subarray(0, remaining));
            totalBytes += Math.min(buf.length, remaining);
          }
          if (totalBytes >= options.maxBytes) {
            res.destroy();
            if ("destroy" in stream && typeof (stream as any).destroy === "function") {
              (stream as any).destroy();
            }
            finish();
          }
        });

        stream.on("end", finish);
        stream.on("close", finish);
        stream.on("error", (err) => {
          if (totalBytes > 0) {
            finish();
          } else if (!settled) {
            settled = true;
            reject(err);
          }
        });
      }
    );

    req.on("socket", (socket) => {
      socket.on("connect", () => {
        if (socket.remoteAddress && isPrivateOrReservedIp(socket.remoteAddress)) {
          req.destroy(new Error(`SSRF blocked on socket connect to ${socket.remoteAddress}`));
        }
      });
    });

    req.on("timeout", () => {
      req.destroy(new Error(`HTTP probe timeout after ${options.timeoutMs}ms`));
    });
    req.on("error", reject);
    req.end();
  });
}

class HostConcurrencyLimiter {
  private readonly active = new Map<string, number>();
  private readonly queues = new Map<string, Array<() => void>>();

  constructor(private readonly maxPerHost = 2) {}

  async run<T>(host: string, fn: () => Promise<T>): Promise<T> {
    const key = host.toLowerCase();
    await this.acquire(key);
    try {
      return await fn();
    } finally {
      this.release(key);
    }
  }

  private acquire(key: string): Promise<void> {
    const count = this.active.get(key) ?? 0;
    if (count < this.maxPerHost) {
      this.active.set(key, count + 1);
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      const q = this.queues.get(key) ?? [];
      q.push(resolve);
      this.queues.set(key, q);
    });
  }

  private release(key: string): void {
    const q = this.queues.get(key);
    if (q && q.length > 0) {
      const next = q.shift()!;
      if (q.length === 0) this.queues.delete(key);
      next();
      return;
    }
    const count = (this.active.get(key) ?? 1) - 1;
    if (count <= 0) {
      this.active.delete(key);
    } else {
      this.active.set(key, count);
    }
  }
}

export class UrlVerificationService {
  private readonly transport: HttpProbeTransport;
  private readonly dnsLookup: DnsLookupFn;
  private readonly useFirestoreCache: boolean;
  private readonly hostLimiter = new HostConcurrencyLimiter(2);

  constructor(deps?: {
    transport?: HttpProbeTransport;
    dnsLookup?: DnsLookupFn;
    useFirestoreCache?: boolean;
  }) {
    this.transport = deps?.transport ?? defaultPinnedHttpTransport;
    this.dnsLookup = deps?.dnsLookup ?? defaultDnsLookup;
    this.useFirestoreCache =
      deps?.useFirestoreCache ?? (process.env.NODE_ENV !== "test" && admin.apps.length > 0);
  }

  async verifyBatch(
    urls: string[],
    options?: VerifyUrlOptions
  ): Promise<Map<string, UrlVerificationRecord>> {
    const unique = Array.from(new Set(urls.map((u) => (u || "").trim()).filter(Boolean)));
    const results = new Map<string, UrlVerificationRecord>();
    const settled = await Promise.all(
      unique.map(async (u) => ({ url: u, res: await this.verifyUrl(u, options) }))
    );
    for (const item of settled) {
      results.set(item.url, item.res);
    }
    return results;
  }

  async verifyUrl(rawUrl: string, options: VerifyUrlOptions = {}): Promise<UrlVerificationRecord> {
    const nowIso = new Date().toISOString();
    const initialParsed = validateSafeExternalUrl(rawUrl);
    if (!initialParsed) {
      return this.buildFailure(rawUrl, rawUrl, "FETCH_FAILED", 0, "Invalid or unsafe URL", nowIso);
    }

    const allowHomepage = options.allowHomepage ?? false;
    const initialCanonical = canonicalizeUrl(initialParsed.toString());
    const cacheKey = this.buildCacheKey(initialCanonical, allowHomepage);

    if (!options.bypassCache) {
      const cached = await this.readHealthCache(cacheKey);
      if (cached) {
        return this.applyRelevanceCheck(cached, options.relevanceQueries);
      }
    }

    const timeoutMs = options.timeoutMs ?? PIPELINE_CONFIG.CLOSED_WORLD_CITATIONS.URL_FETCH_TIMEOUT_MS;
    const maxHops = PIPELINE_CONFIG.CLOSED_WORLD_CITATIONS.MAX_REDIRECT_HOPS;
    const maxBytes = PIPELINE_CONFIG.CLOSED_WORLD_CITATIONS.MAX_HTML_BYTES;

    let currentUrl = initialParsed;
    let redirectHops = 0;
    const visitedUrls = new Set<string>([currentUrl.toString()]);

    try {
      while (redirectHops <= maxHops) {
        const pinned = await this.resolveAndPinPublicAddress(currentUrl);
        if (!pinned) {
          const fail = this.buildFailure(
            rawUrl,
            currentUrl.toString(),
            "FETCH_FAILED",
            0,
            "SSRF protection blocked non-public DNS/IP resolution",
            nowIso,
            redirectHops
          );
          await this.writeHealthCache(cacheKey, fail);
          return fail;
        }

        const resp = await this.hostLimiter.run(currentUrl.hostname, () =>
          this.transport(currentUrl, {
            pinnedIp: pinned.address,
            pinnedFamily: pinned.family,
            timeoutMs,
            maxBytes,
            userAgent: DEFAULT_USER_AGENT,
          })
        );

        // Redirect hop validation
        if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.location) {
          const locationHeader = Array.isArray(resp.headers.location)
            ? resp.headers.location[0]
            : resp.headers.location;
          let resolvedNext: URL;
          try {
            resolvedNext = new URL(locationHeader, currentUrl);
          } catch {
            const fail = this.buildFailure(
              rawUrl,
              currentUrl.toString(),
              "FETCH_FAILED",
              resp.statusCode,
              "Malformed redirect Location header",
              nowIso,
              redirectHops
            );
            await this.writeHealthCache(cacheKey, fail);
            return fail;
          }

          const safeNext = validateSafeExternalUrl(resolvedNext.toString());
          if (!safeNext) {
            const fail = this.buildFailure(
              rawUrl,
              resolvedNext.toString(),
              "FETCH_FAILED",
              resp.statusCode,
              "SSRF protection blocked unsafe redirect destination",
              nowIso,
              redirectHops
            );
            await this.writeHealthCache(cacheKey, fail);
            return fail;
          }

          if (visitedUrls.has(safeNext.toString())) {
            const fail = this.buildFailure(
              rawUrl,
              safeNext.toString(),
              "FETCH_FAILED",
              resp.statusCode,
              "Redirect loop detected",
              nowIso,
              redirectHops
            );
            await this.writeHealthCache(cacheKey, fail);
            return fail;
          }

          visitedUrls.add(safeNext.toString());
          currentUrl = safeNext;
          redirectHops += 1;
          continue;
        }

        const finalCanonical = canonicalizeUrl(currentUrl.toString());
        const finalDomain = currentUrl.hostname.toLowerCase().replace(/^www\./, "");
        const contentType = String(resp.headers["content-type"] || "").split(";")[0].trim().toLowerCase();

        // Explicit status classification (Decision / Requirement B)
        if (resp.statusCode === 404 || resp.statusCode === 410 || resp.statusCode === 451) {
          const notFound = this.buildFailure(
            rawUrl,
            finalCanonical,
            "NOT_FOUND",
            resp.statusCode,
            `HTTP ${resp.statusCode}`,
            nowIso,
            redirectHops,
            contentType
          );
          await this.writeHealthCache(cacheKey, notFound);
          return notFound;
        }

        if (resp.statusCode === 403 || resp.statusCode === 429) {
          const blocked = this.buildFailure(
            rawUrl,
            finalCanonical,
            "BOT_BLOCKED",
            resp.statusCode,
            `Publisher returned HTTP ${resp.statusCode} (bot protection / rate limit)`,
            nowIso,
            redirectHops,
            contentType
          );
          await this.writeHealthCache(cacheKey, blocked);
          return blocked;
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          const failed = this.buildFailure(
            rawUrl,
            finalCanonical,
            "FETCH_FAILED",
            resp.statusCode,
            `HTTP ${resp.statusCode}`,
            nowIso,
            redirectHops,
            contentType
          );
          await this.writeHealthCache(cacheKey, failed);
          return failed;
        }

        // Prevent bare homepage fallback unless explicitly allowlisted
        const isHomepage = isGenericHomepageUrl(finalCanonical);
        if (!allowHomepage && isHomepage) {
          const origHadDeepPath = !isGenericHomepageUrl(initialCanonical) &&
            !initialCanonical.includes("grounding-api-redirect");
          const status: UrlVerificationStatus = origHadDeepPath ? "SOFT_404" : "FETCH_FAILED";
          const fail = {
            ...this.buildFailure(
              rawUrl,
              finalCanonical,
              status,
              resp.statusCode,
              "Resolved to generic homepage instead of specific article/document",
              nowIso,
              redirectHops,
              contentType
            ),
            isSoft404: origHadDeepPath,
            isGenericHomepage: true,
          };
          await this.writeHealthCache(cacheKey, fail);
          return fail;
        }

        // Content & Soft-404 evaluation
        const isHtml = !contentType || contentType.includes("html") || contentType.includes("xml");
        let signals: ParsedHtmlSignals = {
          title: "",
          h1: "",
          metaDescription: "",
          robotsMeta: "",
          visibleText: "",
        };

        if (isHtml && resp.bodyText) {
          signals = extractHtmlSignals(resp.bodyText);
          const softCheck = detectSoft404(finalCanonical, rawUrl, signals, allowHomepage);
          if (softCheck.isSoft404) {
            const softFail: UrlVerificationRecord = {
              status: "SOFT_404",
              originalUrl: rawUrl,
              canonicalUrl: finalCanonical,
              domain: finalDomain,
              httpStatus: resp.statusCode,
              redirectHops,
              isSoft404: true,
              soft404Reason: softCheck.reason,
              isGenericHomepage: isHomepage,
              contentType,
              contentTitle: signals.title || signals.h1 || undefined,
              verifiedAtUtc: nowIso,
              verifierMethod: options.verifierMethod ?? (redirectHops > 0 ? "grounding_resolved" : "http_get"),
              fetchStatus: "SOFT_404",
              errorReason: softCheck.reason,
            };
            await this.writeHealthCache(cacheKey, softFail);
            return softFail;
          }
        }

        const snippetCandidate =
          signals.metaDescription ||
          signals.visibleText.slice(0, 320) ||
          (contentType === "application/pdf" ? "Verified PDF document" : "");

        const verifiedRecord: UrlVerificationRecord = {
          status: "VERIFIED",
          originalUrl: rawUrl,
          canonicalUrl: finalCanonical,
          domain: finalDomain,
          httpStatus: resp.statusCode,
          redirectHops,
          isSoft404: false,
          isGenericHomepage: isHomepage,
          contentType: contentType || "text/html",
          contentTitle: signals.title || signals.h1 || undefined,
          excerpt: snippetCandidate || undefined,
          verifiedAtUtc: nowIso,
          verifierMethod: options.verifierMethod ?? (redirectHops > 0 ? "grounding_resolved" : "http_get"),
          fetchStatus: "HTTP_200_OK",
        };

        await this.writeHealthCache(cacheKey, verifiedRecord);
        return this.applyRelevanceCheck(verifiedRecord, options.relevanceQueries);
      }

      const tooMany = this.buildFailure(
        rawUrl,
        currentUrl.toString(),
        "FETCH_FAILED",
        0,
        `Exceeded maximum redirect hops (${maxHops})`,
        nowIso,
        redirectHops
      );
      await this.writeHealthCache(cacheKey, tooMany);
      return tooMany;
    } catch (err: any) {
      const fail = this.buildFailure(
        rawUrl,
        currentUrl.toString(),
        "FETCH_FAILED",
        0,
        err?.message || "Network/probe failure",
        nowIso,
        redirectHops
      );
      logger.warn("[UrlVerificationService] Verification failed", {
        url: rawUrl,
        error: fail.errorReason,
      });
      await this.writeHealthCache(cacheKey, fail);
      return fail;
    }
  }

  /**
   * Evaluates topical relevance against retrieved English/normalized queries without corrupting
   * the cached URL health record itself.
   */
  applyRelevanceCheck(
    record: UrlVerificationRecord,
    relevanceQueries?: string[]
  ): UrlVerificationRecord {
    if (record.status !== "VERIFIED" || !relevanceQueries || relevanceQueries.length === 0) {
      return record;
    }

    const queryTokens = new Set<string>();
    for (const q of relevanceQueries) {
      for (const tok of tokenizeRelevantTerms(q)) {
        queryTokens.add(tok);
      }
    }

    // If queries are purely non-Latin/script tokens or too short, skip lexical relevance gate
    if (queryTokens.size === 0) {
      return record;
    }

    const haystack = [
      record.contentTitle || "",
      record.excerpt || "",
      record.canonicalUrl.replace(/[-/_]+/g, " "),
    ]
      .join(" ")
      .toLowerCase();

    if (!haystack.trim()) {
      return record;
    }

    let matched = 0;
    for (const tok of queryTokens) {
      if (haystack.includes(tok)) matched += 1;
    }
    const score = matched / queryTokens.size;
    if (matched === 0 && score < PIPELINE_CONFIG.CLOSED_WORLD_CITATIONS.MIN_RELEVANCE_SCORE) {
      return {
        ...record,
        status: "IRRELEVANT",
        errorReason: `Zero keyword overlap between claim queries and fetched page (${record.contentTitle || record.canonicalUrl})`,
      };
    }

    return record;
  }

  private async resolveAndPinPublicAddress(
    url: URL
  ): Promise<{ address: string; family: 4 | 6 } | null> {
    const bareHost = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
    const literalFamily = net.isIP(bareHost);
    if (literalFamily === 4 || literalFamily === 6) {
      if (isPrivateOrReservedIp(bareHost)) return null;
      return { address: bareHost, family: literalFamily };
    }

    const records = await this.dnsLookup(bareHost);
    if (!records || records.length === 0) {
      return null;
    }

    // Reject if ANY DNS answer resolves to private/reserved address space (prevents split-answer DNS rebinding)
    for (const rec of records) {
      if (isPrivateOrReservedIp(rec.address)) {
        return null;
      }
    }

    const preferredV4 = records.find((r) => r.family === 4);
    return preferredV4 ?? records[0];
  }

  private buildFailure(
    originalUrl: string,
    finalUrl: string,
    status: UrlVerificationStatus,
    httpStatus: number,
    errorReason: string,
    verifiedAtUtc: string,
    redirectHops = 0,
    contentType?: string
  ): UrlVerificationRecord {
    let domain = "";
    try {
      domain = new URL(finalUrl).hostname.toLowerCase().replace(/^www\./, "");
    } catch {
      domain = "";
    }

    const fetchStatusMap: Record<UrlVerificationStatus, DeterministicVerification["fetchStatus"]> = {
      VERIFIED: "HTTP_200_OK",
      NOT_FOUND: "NOT_FOUND",
      SOFT_404: "SOFT_404",
      BOT_BLOCKED: "BOT_BLOCKED",
      FETCH_FAILED: "FETCH_FAILED",
      IRRELEVANT: "HTTP_200_OK",
      UNVERIFIED: "UNVERIFIED",
    };

    return {
      status,
      originalUrl,
      canonicalUrl: finalUrl,
      domain,
      httpStatus,
      redirectHops,
      isSoft404: status === "SOFT_404",
      soft404Reason: status === "SOFT_404" ? errorReason : undefined,
      contentType,
      verifiedAtUtc,
      verifierMethod: "http_get",
      fetchStatus: fetchStatusMap[status],
      errorReason,
    };
  }

  private buildCacheKey(canonicalUrl: string, allowHomepage: boolean): string {
    const hash = crypto
      .createHash("sha256")
      .update(`${allowHomepage ? "home" : "deep"}:${canonicalUrl}`)
      .digest("hex");
    return `url_health:${hash}`;
  }

  private getTtlSeconds(status: UrlVerificationStatus): number {
    switch (status) {
      case "VERIFIED":
        return 24 * 3600; // 24 hours
      case "NOT_FOUND":
      case "SOFT_404":
        return 6 * 3600; // 6 hours
      case "BOT_BLOCKED":
      case "FETCH_FAILED":
      default:
        return 3600; // 1 hour (transient blocks/timeouts retry sooner)
    }
  }

  private async readHealthCache(cacheKey: string): Promise<UrlVerificationRecord | null> {
    const l1 = getCache(cacheKey) as UrlVerificationRecord | undefined;
    if (l1) return l1;

    if (!this.useFirestoreCache) return null;
    try {
      const docId = cacheKey.replace(/^url_health:/, "");
      const snap = await admin.firestore().collection(HEALTH_CACHE_COLLECTION).doc(docId).get();
      if (!snap.exists) return null;
      const data = snap.data() as (UrlVerificationRecord & { expiresAtMs?: number }) | undefined;
      if (!data || (data.expiresAtMs && Date.now() > data.expiresAtMs)) {
        return null;
      }
      setCache(cacheKey, data, 3600);
      return data;
    } catch (err) {
      logger.warn("[UrlVerificationService] L2 health cache read skipped", err);
      return null;
    }
  }

  private async writeHealthCache(cacheKey: string, record: UrlVerificationRecord): Promise<void> {
    const ttlSeconds = this.getTtlSeconds(record.status);
    setCache(cacheKey, record, ttlSeconds);

    if (!this.useFirestoreCache) return;
    try {
      const docId = cacheKey.replace(/^url_health:/, "");
      await admin
        .firestore()
        .collection(HEALTH_CACHE_COLLECTION)
        .doc(docId)
        .set({
          ...record,
          expiresAtMs: Date.now() + ttlSeconds * 1000,
        });
    } catch (err) {
      logger.warn("[UrlVerificationService] L2 health cache write skipped", err);
    }
  }
}

export const urlVerificationService = new UrlVerificationService();

/**
 * Builds a schema-compliant UrlVerificationRecord for unverified or rejected candidates.
 */
export function buildUnverifiedVerificationRecord(input: {
  url: string;
  canonicalUrl?: string;
  domain?: string;
  status?: UrlVerificationStatus;
  httpStatus?: number;
  isSoft404?: boolean;
  errorReason: string;
  fetchStatus?: DeterministicVerification["fetchStatus"];
  verifiedAtUtc?: string;
}): UrlVerificationRecord {
  const verifiedAtUtc = input.verifiedAtUtc || new Date().toISOString();
  return {
    status: input.status ?? "UNVERIFIED",
    originalUrl: input.url,
    canonicalUrl: input.canonicalUrl ?? input.url,
    domain: input.domain ?? "",
    httpStatus: typeof input.httpStatus === "number" ? input.httpStatus : 0,
    redirectHops: 0,
    isSoft404: input.isSoft404 === true,
    verifiedAtUtc,
    verifierMethod: "snapshot",
    fetchStatus: input.fetchStatus ?? "UNVERIFIED",
    errorReason: input.errorReason,
  };
}

/**
 * Converts a catalog EvidenceCandidate into a strict RichSource carrying verified
 * bibliographic metadata and URL verification state.
 */
export function evidenceCandidateToRichSource(
  cand: EvidenceCandidate,
  fallbackVerifiedAtUtc?: string
): RichSource {
  const tier: SourceTier = cand.tier ?? "B";
  const canonicalTarget = cand.canonicalUrl || cand.url;
  const meta = cand.verifiedAcademicMetadata;
  const yearNumeric =
    meta?.yearPublished ??
    (cand.publishedAt && /^\d{4}/.test(cand.publishedAt)
      ? Number(cand.publishedAt.slice(0, 4))
      : undefined);

  return {
    evidenceId: cand.evidenceId,
    title: cand.title,
    url: canonicalTarget,
    directUrl: canonicalTarget,
    domain: cand.domain,
    publisher: cand.publisher || cand.domain,
    type: tier === "A" || tier === "B" ? "primary" : "secondary",
    tier,
    publishedAt: cand.publishedAt,
    snippet: cand.snippet || "",
    sourceType: cand.sourceType,
    retrievalMethod: cand.retrievalMethod,
    retrievalProvider: cand.retrievalProvider,
    doi: cand.doi || meta?.doi,
    yearPublished: Number.isFinite(yearNumeric) ? yearNumeric : undefined,
    author: meta?.authors?.join(", "),
    journalName: meta?.journalName,
    urlVerification: cand.verification,
    lastVerified: cand.verification?.verifiedAtUtc || fallbackVerifiedAtUtc,
  };
}

/**
 * Verifies whether a RichSource satisfies the Closed-World Citation Firewall:
 * - Valid http(s) URL (no generic homepage root)
 * - Explicitly verified via UrlVerificationService (HTTP 200, not Soft-404)
 * - Admitted through domain trust / relevance gates (non Tier-E)
 */
export function isVerifiedRichSource(src: RichSource | null | undefined): boolean {
  if (!src || !src.url || typeof src.url !== "string") return false;
  const trimmed = src.url.trim();
  if (!/^https?:\/\//i.test(trimmed)) return false;
  if (isGenericHomepageUrl(trimmed)) return false;
  if (src.tier === "E") return false;
  if (src.evidenceAssessment && src.evidenceAssessment.admissionStatus !== "admitted") {
    return false;
  }
  const uv = src.urlVerification;
  if (!uv) return false;
  return uv.status === "VERIFIED" && uv.httpStatus === 200 && uv.isSoft404 !== true;
}

/**
 * Closed-World Citation Firewall (Backend + Persistence Boundary Invariant):
 * Strips any unverified, LLM-synthesized, 404, Soft-404, or bare-homepage URL from
 * verified sources and moves it to quarantinedSources. Retains non-clickable
 * verifiedAcademicMetadata cleanly and enforces `sourceStatus: 'missing'` when no
 * verified clickable URL remains for a factual claim.
 */
export function enforceClosedWorldCitationFirewall(claim: VerifiedClaim): VerifiedClaim {
  const inputRich = Array.isArray(claim.richSources) ? claim.richSources : [];
  const admitted: RichSource[] = [];
  const quarantined: RichSource[] = Array.isArray(claim.quarantinedSources)
    ? [...claim.quarantinedSources]
    : [];
  const seenAdmittedUrls = new Set<string>();
  const seenQuarantinedUrls = new Set<string>(
    quarantined.map((q) => (q.url || "").trim().toLowerCase()).filter(Boolean)
  );

  for (const src of inputRich) {
    if (!src) continue;
    const rawUrl = (src.url || src.directUrl || "").trim();
    const urlKey = rawUrl.toLowerCase();

    if (isVerifiedRichSource(src)) {
      if (!seenAdmittedUrls.has(urlKey)) {
        seenAdmittedUrls.add(urlKey);
        admitted.push({
          ...src,
          url: src.urlVerification?.canonicalUrl || rawUrl,
          directUrl: src.urlVerification?.canonicalUrl || rawUrl,
        });
      }
    } else if (!seenQuarantinedUrls.has(urlKey)) {
      seenQuarantinedUrls.add(urlKey);
      const nowIso = new Date().toISOString();
      quarantined.push({
        ...src,
        urlVerification:
          src.urlVerification ??
          buildUnverifiedVerificationRecord({
            url: rawUrl,
            domain: src.domain || "",
            verifiedAtUtc: nowIso,
            errorReason: "Blocked by Closed-World Citation Firewall (no live HTTP 200 verification)",
          }),
        evidenceAssessment: src.evidenceAssessment ?? {
          admissionStatus: "quarantined",
          publisherTier: src.tier || "D",
          publisherVerified: false,
          claimRelevanceScore: 0,
          directEvidenceScore: 0,
          isPrimaryEvidence: false,
          isIndependent: false,
          retrievedAt: nowIso,
          rejectionReason: "UNVERIFIED_LLM_URL: Stripped at Closed-World Citation Firewall",
        },
      });
    }
  }

  const isFactual =
    claim.nature === ClaimNature.VERIFIABLE_FACT ||
    claim.nature === ClaimNature.HISTORICAL_FACT ||
    claim.nature === ClaimNature.SCIENTIFIC_CLAIM ||
    claim.nature === ClaimNature.ESTIMATION;

  const isAdmittedUrlMatch = (rawCandidateUrl: string | undefined): boolean => {
    const normalized = (rawCandidateUrl || "").trim().toLowerCase();
    if (!normalized) return false;
    if (seenAdmittedUrls.has(normalized)) return true;
    const withoutFragment = normalized.split("#")[0];
    return Boolean(withoutFragment) && seenAdmittedUrls.has(withoutFragment);
  };

  // Scrub any unverified URLs inside trace/registry structures as defense-in-depth
  let cleanedTraceability = claim.evidenceTraceability;
  if (cleanedTraceability?.evidenceTraces?.length) {
    cleanedTraceability = {
      ...cleanedTraceability,
      evidenceTraces: cleanedTraceability.evidenceTraces.map((tr) => {
        const isAdmittedUrl = isAdmittedUrlMatch(tr.sourceUrl);
        return isAdmittedUrl
          ? tr
          : {
              ...tr,
              sourceUrl: "",
              automatedVerification: tr.automatedVerification
                ? { ...tr.automatedVerification, urlResolved: false }
                : undefined,
            };
      }),
    };
  }

  let cleanedAssessmentV2 = claim.assessmentV2;
  if (cleanedAssessmentV2?.evidenceRegistry) {
    const nextRegistry: typeof cleanedAssessmentV2.evidenceRegistry = {};
    for (const [key, item] of Object.entries(cleanedAssessmentV2.evidenceRegistry)) {
      const isAdmittedUrl = isAdmittedUrlMatch(item?.sourceIdentity?.url);
      nextRegistry[key] = isAdmittedUrl
        ? {
            ...item,
            deterministicVerification: {
              ...item.deterministicVerification,
              fetchStatus: "HTTP_200_OK",
            },
          }
        : {
            ...item,
            sourceIdentity: {
              ...item.sourceIdentity,
              url: "",
            },
            deterministicVerification: {
              ...item.deterministicVerification,
              fetchStatus: "UNVERIFIED",
            },
          };
    }
    cleanedAssessmentV2 = {
      ...cleanedAssessmentV2,
      evidenceRegistry: nextRegistry,
    };
  }

  const verifiedCount = admitted.length;
  const nextSourceStatus: "complete" | "partial" | "missing" =
    verifiedCount === 0
      ? isFactual
        ? "missing"
        : claim.sourceStatus || "complete"
      : verifiedCount >= 2
      ? "complete"
      : "partial";

  return {
    ...claim,
    richSources: admitted,
    quarantinedSources: quarantined,
    sources: admitted.map((s) => s.title || s.domain || "Verified Source"),
    sourceStatus: nextSourceStatus,
    evidenceLevel: verifiedCount === 0 && isFactual ? EvidenceLevel.NONE : claim.evidenceLevel,
    isGrounded: verifiedCount > 0,
    evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
    evidenceCatalogVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
    evidenceTraceability: cleanedTraceability,
    assessmentV2: cleanedAssessmentV2,
    ...(verifiedCount === 0 && isFactual
      ? {
          evidenceSummary: {
            independentPublishers: 0,
            tierA: 0,
            tierB: 0,
            secondarySources: 0,
          },
        }
      : {}),
  };
}

/**
 * Cache Read Gate: verifies that a cached claim record conforms to v2_verified_urls
 * schema AND every cached richSource carries valid HTTP 200 verification.
 */
export function isClosedWorldCacheEntryValid(record: any): boolean {
  if (!record || typeof record !== "object") return false;
  if (PIPELINE_CONFIG.CLOSED_WORLD_CITATIONS?.ALLOW_UNVERIFIED_CACHE_SERVING) {
    return true;
  }

  const version = record.evidenceSchemaVersion || record.claim?.evidenceSchemaVersion;
  if (version !== PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION) {
    return false;
  }

  const richSources: RichSource[] = Array.isArray(record.richSources)
    ? record.richSources
    : Array.isArray(record.claim?.richSources)
    ? record.claim.richSources
    : [];

  if (richSources.length === 0) {
    return false;
  }

  return richSources.every((s) => isVerifiedRichSource(s));
}

/**
 * Persistence Boundary Sanitizer (GCS / Firestore Write Invariant):
 * Ensures no unverified URLs enter `factChecks/{jobId}`, `final_outputs/{jobId}`,
 * or explainability reports — even if injected by future code paths.
 */
export function sanitizeReportPayloadForClosedWorld<T>(payload: T): T {
  if (!payload || typeof payload !== "object") return payload;
  const clone: any = { ...payload };
  const verifiedUrlSet = new Set<string>();

  const sanitizeClaimsArray = (claims: any[]): any[] =>
    claims.map((c) => {
      if (!c || typeof c !== "object") return c;
      const firewalled = enforceClosedWorldCitationFirewall(c as VerifiedClaim);
      for (const s of firewalled.richSources || []) {
        if (s.url) verifiedUrlSet.add(s.url.trim().toLowerCase());
      }
      return firewalled;
    });

  if (Array.isArray(clone.claims)) clone.claims = sanitizeClaimsArray(clone.claims);
  if (Array.isArray(clone.verifiedClaims)) clone.verifiedClaims = sanitizeClaimsArray(clone.verifiedClaims);
  if (Array.isArray(clone.claimsLedger)) clone.claimsLedger = sanitizeClaimsArray(clone.claimsLedger);

  if (clone.credibility && typeof clone.credibility === "object") {
    clone.credibility = sanitizeReportPayloadForClosedWorld(clone.credibility);
    for (const c of [...(clone.credibility.claims || []), ...(clone.credibility.verifiedClaims || []), ...(clone.credibility.claimsLedger || [])]) {
      for (const s of c?.richSources || []) {
        if (s?.url) verifiedUrlSet.add(s.url.trim().toLowerCase());
      }
    }
  }

  if (Array.isArray(clone.explainability)) {
    clone.explainability = clone.explainability.map((exp: any) => {
      if (!exp || typeof exp !== "object") return exp;
      const rawExpSources = Array.isArray(exp.sources) ? exp.sources : [];
      const filteredExpSources = rawExpSources.filter((s: any) => {
        const u = String(s?.url || "").trim();
        if (!/^https?:\/\//i.test(u) || isGenericHomepageUrl(u)) return false;
        const uv = s?.urlVerification;
        if (uv && uv.status === "VERIFIED" && uv.httpStatus === 200 && !uv.isSoft404) return true;
        return verifiedUrlSet.has(u.toLowerCase());
      });
      return {
        ...exp,
        sources: filteredExpSources,
        sourceStatus: filteredExpSources.length === 0 ? "missing" : exp.sourceStatus || "partial",
      };
    });
  }

  if (clone.synthesis && typeof clone.synthesis === "object") {
    const synClone = { ...clone.synthesis };
    if (Array.isArray(synClone.sources)) {
      synClone.sources = synClone.sources.filter((s: any) => {
        const u = String(s?.url || "").trim();
        if (!/^https?:\/\//i.test(u) || isGenericHomepageUrl(u)) return false;
        const uv = s?.urlVerification;
        if (uv && uv.status === "VERIFIED" && uv.httpStatus === 200 && !uv.isSoft404) return true;
        return verifiedUrlSet.has(u.toLowerCase());
      });
    }
    clone.synthesis = synClone;
  }

  if (Array.isArray(clone.sources)) {
    clone.sources = clone.sources.filter((s: any) => {
      if (typeof s === "string") return !/^https?:\/\//i.test(s) || verifiedUrlSet.has(s.trim().toLowerCase());
      const u = String(s?.url || "").trim();
      if (!/^https?:\/\//i.test(u) || isGenericHomepageUrl(u)) return false;
      const uv = s?.urlVerification;
      if (uv && uv.status === "VERIFIED" && uv.httpStatus === 200 && !uv.isSoft404) return true;
      return verifiedUrlSet.has(u.toLowerCase());
    });
  }

  clone.evidenceSchemaVersion = PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION;
  return clone as T;
}

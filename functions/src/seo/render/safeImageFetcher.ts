/**
 * 🛡️ TruthWorld SSRF-Safe Image Fetching Utility
 *
 * Prevents Server-Side Request Forgery (SSRF), internal network scanning,
 * metadata exfiltration (e.g., 169.254.169.254), and memory exhaustion DoS
 * when rendering dynamic social preview cards.
 */

import axios from "axios";
import { logger } from "firebase-functions/v2";

/**
 * Validates whether an image URL is safe to fetch server-side.
 * Rejects non-HTTP(S) protocols, loopback addresses, link-local metadata endpoints,
 * private RFC 1918 IPv4 networks, and internal cloud hostnames.
 */
export function isSafeImageUrl(rawUrl: string): boolean {
  if (!rawUrl || typeof rawUrl !== "string") return false;
  try {
    const trimmed = rawUrl.trim();
    if (!trimmed.startsWith("https://") && !trimmed.startsWith("http://")) {
      return false;
    }

    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return false;
    }

    let hostname = parsed.hostname.toLowerCase();
    // Strip IPv6 bracket notation (e.g., "[::1]" -> "::1")
    if (hostname.startsWith("[") && hostname.endsWith("]")) {
      hostname = hostname.slice(1, -1);
    }

    // Reject loopback, link-local, GCP metadata, and internal domains
    if (
      hostname === "localhost" ||
      hostname.endsWith(".localhost") ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname === "0.0.0.0" ||
      hostname === "169.254.169.254" ||
      hostname.includes("metadata.google") ||
      hostname.endsWith(".internal") ||
      hostname.endsWith(".local")
    ) {
      return false;
    }

    // Check for standard IPv4 patterns and block private/reserved address spaces
    const ipv4Regex = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    const match = hostname.match(ipv4Regex);
    if (match) {
      const b0 = parseInt(match[1], 10);
      const b1 = parseInt(match[2], 10);
      const b2 = parseInt(match[3], 10);
      const b3 = parseInt(match[4], 10);

      if (b0 > 255 || b1 > 255 || b2 > 255 || b3 > 255) return false;

      // 0.0.0.0/8 (Current network)
      if (b0 === 0) return false;
      // 10.0.0.0/8 (Private network)
      if (b0 === 10) return false;
      // 127.0.0.0/8 (Loopback)
      if (b0 === 127) return false;
      // 169.254.0.0/16 (Link-local / cloud metadata)
      if (b0 === 169 && b1 === 254) return false;
      // 172.16.0.0/12 (Private network)
      if (b0 === 172 && b1 >= 16 && b1 <= 31) return false;
      // 192.168.0.0/16 (Private network)
      if (b0 === 192 && b1 === 168) return false;
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Fetches an external image safely with SSRF defense, timeouts, and byte limits.
 *
 * @param url The image URL to retrieve.
 * @param userAgent The user-agent identifier to send with the request.
 * @param timeoutMs Timeout in milliseconds (default: 4000ms).
 * @param maxBytes Maximum allowable image size in bytes (default: 10MB).
 */
export async function safeFetchImageBuffer(
  url: string,
  userAgent: string,
  timeoutMs = 5000,
  maxBytes = 10 * 1024 * 1024
): Promise<Buffer | null> {
  if (!url || typeof url !== "string") return null;
  const trimmed = url.trim();

  // Support inline data URI directly without network fetch
  if (trimmed.startsWith("data:image/")) {
    const commaIdx = trimmed.indexOf(",");
    if (commaIdx !== -1) {
      try {
        return Buffer.from(trimmed.substring(commaIdx + 1), "base64");
      } catch (_) {
        return null;
      }
    }
  }

  if (!isSafeImageUrl(trimmed)) {
    logger.warn(`[safeFetchImageBuffer] Blocked unsafe image fetch: ${trimmed}`);
    return null;
  }

  try {
    const resp = await axios.get(trimmed, {
      responseType: "arraybuffer",
      timeout: timeoutMs,
      maxContentLength: maxBytes,
      maxBodyLength: maxBytes,
      maxRedirects: 5,
      headers: { "User-Agent": userAgent },
      validateStatus: (status) => status >= 200 && status < 300,
    });
    return Buffer.from(resp.data);
  } catch (err) {
    logger.info(`[safeFetchImageBuffer] Image fetch non-fatal error: ${trimmed}`);
    return null;
  }
}

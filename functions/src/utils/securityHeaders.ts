/**
 * 🛡️ TruthWorld Enterprise Security Headers & Hardening Utilities
 *
 * Enforces OWASP-recommended HTTP response headers across all Cloud Functions
 * endpoints to prevent Clickjacking, MIME-confusion, cross-site leaks, and MITM.
 */

import { Response } from "express";

/**
 * Applies enterprise-grade security headers to an HTTP Response.
 */
export function applySecurityHeaders(res: Response): void {
  // Prevent MIME-sniffing
  res.setHeader("X-Content-Type-Options", "nosniff");

  // Prevent Clickjacking / framing
  res.setHeader("X-Frame-Options", "DENY");

  // Enforce HTTPS HSTS for 1 year with subdomains and preload
  res.setHeader(
    "Strict-Transport-Security",
    "max-age=31536000; includeSubDomains; preload"
  );

  // Modern Referrer Policy
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");

  // Restrict browser features and sensors while permitting verified payment APIs
  res.setHeader(
    "Permissions-Policy",
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(self \"https://*.cashfree.com\" \"https://sdk.cashfree.com\"), usb=()"
  );

  // Cross-Origin policies
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin-allow-popups");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
}

/**
 * Checks whether an authenticated token's authentication timestamp is recent.
 * Enforces step-up authentication for high-impact administrator actions.
 *
 * @param authTime The `auth_time` claim (in seconds since epoch) from DecodedIdToken.
 * @param maxAgeSeconds Maximum allowable session age for high-impact actions (default: 3600s / 1 hour).
 */
export function isSessionRecent(authTime: number | undefined, maxAgeSeconds: number = 3600): boolean {
  if (!authTime) return false;
  const currentSeconds = Math.floor(Date.now() / 1000);
  return currentSeconds - authTime <= maxAgeSeconds;
}

/**
 * 🔐 Auth Utilities for HTTP (onRequest) Cloud Functions
 *
 * Provides reusable helpers to verify Firebase Auth tokens
 * on HTTP endpoints that don't get automatic auth from onCall.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import { Request, Response } from "express";
import { applySecurityHeaders, isSessionRecent } from "./securityHeaders";

export interface AuthenticatedUser {
  uid: string;
  email?: string;
  isAdmin: boolean;
  authTime?: number;
  emailVerified?: boolean;
}

/**
 * Verifies the Firebase Auth Bearer token from the Authorization header.
 * Returns the decoded user if valid, or null if missing/invalid.
 *
 * Usage:
 * ```
 * const user = await verifyAuth(req);
 * if (!user) { res.status(401).json({ error: "Unauthorized" }); return; }
 * ```
 */
/**
 * Verifies the Firebase Auth Bearer token from the Authorization header.
 * Returns the decoded user if valid, or null if missing/invalid.
 *
 * Usage:
 * ```
 * const user = await verifyAuth(req);
 * if (!user) { res.status(401).json({ error: "Unauthorized" }); return; }
 * ```
 */
export async function verifyAuth(req: Request): Promise<AuthenticatedUser | null> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.split("Bearer ")[1];
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const email = (decoded.email || "").toLowerCase();
    const isEmailVerified = decoded.email_verified === true;

    // Admin status is determined solely by JWT custom claims or the admin_members collection.
    // No hardcoded email list — admin provisioning must go through setCustomUserClaims.
    let isAdminUser =
      decoded.admin === true ||
      decoded.role === "admin";

    // Check admin_members collection in Firestore if not already identified (strictly require email verification)
    if (!isAdminUser && email && isEmailVerified) {
      try {
        const memberDoc = await admin.firestore().collection("admin_members").doc(email).get();
        if (memberDoc.exists && memberDoc.data()?.status !== "suspended") {
          isAdminUser = true;
        }
      } catch (docErr) {
        logger.warn("[Auth] Could not check admin_members doc:", docErr);
      }
    }

    // Auto-provision admin JWT custom claim for admin_members-identified admins.
    // Runs once per token refresh cycle (only when decoded.admin is not yet set).
    if (isAdminUser && !decoded.admin) {
      try {
        await admin.auth().setCustomUserClaims(decoded.uid, { admin: true, role: "admin" });
        logger.info(`[Auth] Auto-set admin claims for admin ${decoded.uid} (${email})`);
      } catch (claimErr) {
        logger.warn("[Auth] Could not auto-set admin claim:", claimErr);
      }
    }

    // NOTE: Admin status is intentionally NOT written to the client-readable `users` collection.
    // Admin checks must always use JWT custom claims (decoded.admin) or admin_members collection.

    return {
      uid: decoded.uid,
      email: decoded.email,
      isAdmin: isAdminUser,
      authTime: decoded.auth_time,
      emailVerified: isEmailVerified,
    };
  } catch (err) {
    logger.warn("[Auth] Invalid token:", err);
    return null;
  }
}

/**
 * Sets standard CORS headers and enterprise security headers on HTTP response.
 */
export function setCorsHeaders(req: Request, res: Response): void {
  applySecurityHeaders(res);
  const allowedOrigins = [
    "https://admin.truthworld.in",
    "https://admin.truthworld.app",
    "https://truthworld.in",
    "https://truthworld.app",
    "http://localhost:5173",
  ];
  const origin = (req.headers.origin as string) || "";
  if (allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  } else {
    res.set("Access-Control-Allow-Origin", "https://admin.truthworld.in");
  }
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With");
}

/**
 * Requires Firebase Auth. Returns 401 if not authenticated.
 * Returns the authenticated user if valid.
 */
export async function requireAuth(req: Request, res: Response): Promise<AuthenticatedUser | null> {
  setCorsHeaders(req, res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return null;
  }

  const user = await verifyAuth(req);
  if (!user) {
    res.status(401).json({ error: "Unauthorized. Bearer token required." });
    return null;
  }
  return user;
}

/**
 * Requires Firebase Auth + admin custom claim.
 * Returns 401 if not authenticated, 403 if not admin.
 */
export async function requireAdmin(req: Request, res: Response): Promise<AuthenticatedUser | null> {
  setCorsHeaders(req, res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return null;
  }

  const user = await verifyAuth(req);
  if (!user) {
    res.status(401).json({ error: "Unauthorized. Bearer token required." });
    return null;
  }
  if (!user.isAdmin) {
    res.status(403).json({ error: "Forbidden. Admin access required." });
    return null;
  }
  return user;
}

/**
 * Requires Firebase Auth + admin custom claim + recent authentication (step-up auth).
 * Returns 401 if unauthenticated, 403 if not admin, 403 if session is older than maxAgeSeconds.
 */
export async function requireRecentAdmin(
  req: Request,
  res: Response,
  maxAgeSeconds: number = 3600
): Promise<AuthenticatedUser | null> {
  const user = await requireAdmin(req, res);
  if (!user) return null;

  if (user.authTime && !isSessionRecent(user.authTime, maxAgeSeconds)) {
    res.status(403).json({
      error: "Step-up authentication required. Please re-authenticate to perform this administrative action.",
      code: "AUTH_STEP_UP_REQUIRED",
    });
    return null;
  }

  return user;
}

/**
 * Checks if a Callable function context/auth payload has verified admin privileges.
 */
export function isCallableAdmin(auth: any): boolean {
  if (!auth) return false;
  const token = auth.token || {};
  return token.admin === true || token.role === "admin";
}

/**
 * Checks if a Callable function context has verified admin privileges and recent authentication.
 */
export function isCallableRecentAdmin(auth: any, maxAgeSeconds: number = 3600): boolean {
  if (!isCallableAdmin(auth)) return false;
  const authTime = auth?.token?.auth_time;
  if (!authTime) return false; // fail closed
  return isSessionRecent(authTime, maxAgeSeconds);
}


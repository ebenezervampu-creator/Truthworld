/**
 * 🔐 Auth Utilities for HTTP (onRequest) Cloud Functions
 *
 * Provides reusable helpers to verify Firebase Auth tokens
 * on HTTP endpoints that don't get automatic auth from onCall.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import { Request, Response } from "express";

export interface AuthenticatedUser {
  uid: string;
  email?: string;
  isAdmin: boolean;
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
    const ADMIN_EMAILS = [
      "ebenezervampu4@gmail.com",
      "admin@truthworld.com",
    ];

    let isAdminUser =
      decoded.admin === true ||
      decoded.role === "admin" ||
      ADMIN_EMAILS.includes(email);

    if (!isAdminUser) {
      // Fallback check in Firestore users collection
      try {
        const userDoc = await admin.firestore().collection("users").doc(decoded.uid).get();
        if (userDoc.exists) {
          const data = userDoc.data();
          if (data?.role === "admin" || data?.isAdmin === true || data?.role === "superadmin") {
            isAdminUser = true;
          }
        }
      } catch (docErr) {
        logger.warn("[Auth] Firestore admin role check failed:", docErr);
      }
    }

    if (isAdminUser && !decoded.admin) {
      try {
        await admin.auth().setCustomUserClaims(decoded.uid, { admin: true, role: "admin" });
        logger.info(`[Auth] Auto-set admin claims for user ${decoded.uid} (${email})`);
      } catch (claimErr) {
        logger.warn("[Auth] Could not auto-set admin claim:", claimErr);
      }
    }

    return {
      uid: decoded.uid,
      email: decoded.email,
      isAdmin: isAdminUser,
    };
  } catch (err) {
    logger.warn("[Auth] Invalid token:", err);
    return null;
  }
}

/**
 * Sets standard CORS headers on HTTP response.
 */
export function setCorsHeaders(req: Request, res: Response): void {
  res.set("Access-Control-Allow-Origin", "*");
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


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
export async function verifyAuth(req: Request): Promise<AuthenticatedUser | null> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.split("Bearer ")[1];
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      uid: decoded.uid,
      email: decoded.email,
      isAdmin: decoded.admin === true,
    };
  } catch (err) {
    logger.warn("[Auth] Invalid token:", err);
    return null;
  }
}

/**
 * Requires Firebase Auth. Returns 401 if not authenticated.
 * Returns the authenticated user if valid.
 */
export async function requireAuth(req: Request, res: Response): Promise<AuthenticatedUser | null> {
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

/**
 * 🔐 Auth Utilities for HTTP (onRequest) Cloud Functions
 *
 * Provides reusable helpers to verify Firebase Auth tokens
 * on HTTP endpoints that don't get automatic auth from onCall.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import { HttpsError } from "firebase-functions/v2/https";
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

    // Admin status is determined by JWT custom claims, director master privilege, or admin_members collection.
    let isAdminUser =
      decoded.admin === true ||
      decoded.role === "admin";

    // 👑 TruthWorld Director & Authorized Owner Master Privilege:
    const authorizedOwners = [
      "hello@truthworld.in",
      "ebenezervampu4@gmail.com",
    ];
    const isDirector = isEmailVerified && authorizedOwners.includes(email);
    if (isDirector) {
      isAdminUser = true;
    }

    // Check admin_members collection in Firestore if not already identified (strictly require email verification)
    let memberData: FirebaseFirestore.DocumentData | undefined;
    if (!isAdminUser && email && isEmailVerified) {
      try {
        const memberDoc = await admin.firestore().collection("admin_members").doc(email).get();
        if (memberDoc.exists && memberDoc.data()?.status !== "suspended") {
          isAdminUser = true;
          memberData = memberDoc.data();
        } else {
          const uidDoc = await admin.firestore().collection("admin_members").doc(decoded.uid).get();
          if (uidDoc.exists && uidDoc.data()?.status !== "suspended") {
            isAdminUser = true;
            memberData = uidDoc.data();
          }
        }
      } catch (docErr) {
        logger.warn("[Auth] Could not check admin_members doc:", docErr);
      }
    }

    // Auto-provision admin JWT custom claim for admin_members-identified admins or Director.
    // Runs once per token refresh cycle (only when decoded.admin is not yet set).
    if (isAdminUser && !decoded.admin) {
      try {
        // Preserve the member's assigned role from memberDoc or roles; do NOT hardcode Super Admin privileges!
        const assignedRole = isDirector
          ? "Super Admin"
          : (memberData?.role || (Array.isArray(memberData?.roles) && memberData.roles[0]) || "admin");
        const assignedRoles: string[] = isDirector
          ? ["Super Admin", "Owner", "Director"]
          : (Array.isArray(memberData?.roles) && memberData.roles.length > 0 ? memberData.roles : [assignedRole]);
        const isSuperAdmin =
          isDirector ||
          assignedRole === "Super Admin" ||
          assignedRole === "Owner" ||
          assignedRoles.includes("Super Admin") ||
          assignedRoles.includes("Owner");

        await admin.auth().setCustomUserClaims(decoded.uid, {
          admin: true,
          role: assignedRole,
          roles: assignedRoles,
          isDirector: isDirector || undefined,
          isSuperAdmin: isSuperAdmin || undefined,
        });

        // Ensure director / owner record is synced in admin_members collection (both by email and UID)
        // Only director/owner records receive Super Admin master privileges.
        if (isDirector) {
          const adminDocData = {
            email: email,
            name: decoded.name || (email.startsWith("ebenezer") ? "Ebenezer Vampu" : "Truthworld Director"),
            role: "Super Admin",
            roles: ["Super Admin", "Owner", "Director"],
            status: "active",
            uid: decoded.uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          await admin.firestore().collection("admin_members").doc(email).set(
            adminDocData,
            { merge: true }
          );
          await admin.firestore().collection("admin_members").doc(decoded.uid).set(
            adminDocData,
            { merge: true }
          );
        } else if (memberData) {
          // Sync UID to member record if missing, preserving assigned role and permissions
          const uidUpdate: Record<string, any> = {
            uid: decoded.uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (email) {
            await admin.firestore().collection("admin_members").doc(email).set(
              uidUpdate,
              { merge: true }
            );
          }
          await admin.firestore().collection("admin_members").doc(decoded.uid).set(
            {
              ...memberData,
              uid: decoded.uid,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        logger.info(`[Auth] Auto-set admin claims for admin ${decoded.uid} (${email}) with role: ${assignedRole}`);
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
  ];
  const origin = (req.headers.origin as string) || "";
  const isDevOrEmulator =
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.NODE_ENV !== "production";
  const isLocalhost =
    isDevOrEmulator &&
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);

  if (allowedOrigins.includes(origin) || isLocalhost) {
    res.set("Access-Control-Allow-Origin", origin);
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With");
  }
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
  const isEmailVerified = token.email_verified !== false;
  const hasAdminClaim = token.admin === true || token.role === "admin";
  return hasAdminClaim && isEmailVerified;
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

/**
 * Checks if a Callable function context/auth payload has verified Super Admin privileges.
 */
export async function isCallableSuperAdmin(auth: any): Promise<boolean> {
  if (!auth || !auth.uid) return false;
  const token = auth.token || {};
  const email = (token.email || "").toLowerCase();

  const authorizedOwnerEmails = [
    "hello@truthworld.in",
    "ebenezervampu4@gmail.com",
  ];
  if (authorizedOwnerEmails.includes(email)) return true;

  // Strictly Super Admin: token roles check
  const tokenRoles = Array.isArray(token.roles) ? token.roles.map((r: any) => String(r).toLowerCase()) : [];
  if (
    token.role === "Super Admin" ||
    token.isSuperAdmin === true ||
    token.isDirector === true ||
    tokenRoles.some((r: string) => r.includes("super admin") || r.includes("owner") || r.includes("director"))
  ) {
    return true;
  }

  // Check admin_members document for verified role
  if (email) {
    try {
      const doc = await admin.firestore().collection("admin_members").doc(email).get();
      if (doc.exists) {
        const d = doc.data() || {};
        if ((d.status || "active") !== "suspended") {
          const role = (d.role || "").toLowerCase();
          const roles = Array.isArray(d.roles) ? d.roles.map((r: any) => String(r).toLowerCase()) : [];
          if (
            role.includes("super admin") ||
            role.includes("owner") ||
            role.includes("director") ||
            roles.some((r: string) => r.includes("super admin") || r.includes("owner") || r.includes("director"))
          ) {
            return true;
          }
        }
      }
    } catch {
      // Fail closed
    }
  }

  return false;
}

/**
 * Asserts that the caller of a Callable function is an authenticated Director
 * or holds administrative privileges with a verified email.
 */
export async function assertAdminCaller(authContext: any): Promise<AuthenticatedUser> {
  if (!authContext || !authContext.uid) {
    throw new HttpsError("unauthenticated", "Authentication required for administrative operations.");
  }

  const token = authContext.token || {};
  const isEmailVerified = token.email_verified === true;
  if (!isEmailVerified) {
    throw new HttpsError("permission-denied", "Verified email address required for administrative operations.");
  }

  const email = (token.email || "").toLowerCase();
  const isAdmin =
    token.admin === true ||
    token.role === "admin" ||
    token.isDirector === true ||
    token.isSuperAdmin === true;

  if (!isAdmin) {
    try {
      const memberDoc = await admin.firestore().collection("admin_members").doc(email).get();
      if (!memberDoc.exists || memberDoc.data()?.status === "suspended") {
        throw new HttpsError("permission-denied", "Director or Super Admin access required.");
      }
    } catch {
      throw new HttpsError("permission-denied", "Director or Super Admin access required.");
    }
  }

  return {
    uid: authContext.uid,
    email: email || "admin",
    isAdmin: true,
    emailVerified: true,
    authTime: token.auth_time,
  };
}



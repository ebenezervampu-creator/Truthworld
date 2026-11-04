/**
 * 👑 ADMIN MEMBER MANAGEMENT & AUTH ENDPOINTS
 *
 * Dedicated Cloud Functions for:
 * 1. sendAdminCredentials: Sends credentials via email when a team member is created.
 * 2. verifyAdminUsername: Two-step authentication identity resolver for the Admin Portal.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { EmailService } from "../services/emailService";

const db = () => admin.firestore();

/**
 * Helper to verify that the caller is an authenticated Super Admin or platform Owner.
 */
async function assertSuperAdminCaller(authContext: any): Promise<{ uid: string; email: string }> {
  if (!authContext || !authContext.uid) {
    throw new HttpsError("unauthenticated", "Authentication required to perform admin team operations.");
  }

  const token = authContext.token || {};
  const isEmailVerified = token.email_verified === true || (process.env.NODE_ENV === "test" && token.email_verified !== false);

  const email = (token.email || "").toLowerCase();

  const isOwner =
    token.isDirector === true ||
    ((email === "hello@truthworld.in" || email === "ebenezervampu4@gmail.com") && isEmailVerified);

  const isSuperAdmin =
    isOwner ||
    token.isSuperAdmin === true ||
    token.role === "Super Admin" ||
    token.role === "Owner" ||
    (Array.isArray(token.roles) && (token.roles.includes("Super Admin") || token.roles.includes("Owner")));

  if (!isSuperAdmin) {
    try {
      const memberDoc = await db().collection("admin_members").doc(email).get();
      const data = memberDoc.exists ? memberDoc.data() : null;
      const isDocSuperAdmin =
        data &&
        data.status !== "suspended" &&
        (data.role === "Super Admin" ||
         data.role === "Owner" ||
         data.role === "Owner / Super Admin" ||
         (Array.isArray(data.roles) && (data.roles.includes("Super Admin") || data.roles.includes("Owner"))));

      if (!isDocSuperAdmin) {
        const uidDoc = await db().collection("admin_members").doc(authContext.uid).get();
        const uidData = uidDoc.exists ? uidDoc.data() : null;
        const isUidSuperAdmin =
          uidData &&
          uidData.status !== "suspended" &&
          (uidData.role === "Super Admin" ||
           uidData.role === "Owner" ||
           uidData.role === "Owner / Super Admin" ||
           (Array.isArray(uidData.roles) && (uidData.roles.includes("Super Admin") || uidData.roles.includes("Owner"))));

        if (!isUidSuperAdmin) {
          throw new HttpsError("permission-denied", "Super Admin or Owner privileges required.");
        }
      }
    } catch (e: any) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("permission-denied", "Super Admin or Owner privileges required.");
    }
  }

  if (!isEmailVerified) {
    throw new HttpsError("permission-denied", "Verified email address required for administrative operations.");
  }

  return { uid: authContext.uid, email: email || "admin" };
}

/**
 * 📧 SEND ADMIN CREDENTIALS EMAIL (onCall)
 *
 * Sends login credentials directly to a new team member's email address upon creation.
 */
export const sendAdminCredentials = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    // 1. Authorize caller
    const caller = await assertSuperAdminCaller(request.auth);

    const { email, username, password, role, roles, name, portalUrl } = request.data || {};
    const cleanEmail = (email || "").toString().trim().toLowerCase();
    const cleanUsername = (username || cleanEmail.split("@")[0] || "").toString().trim().toLowerCase();
    const cleanPassword = (password || "").toString().trim();
    const cleanRole = (role || "Content Moderator").toString().trim();
    const cleanName = (name || cleanUsername).toString().trim();
    const targetUrl = (portalUrl || "https://truthworld.in/admin").toString().trim();
    const assignedRoles: string[] = Array.isArray(roles) && roles.length > 0
      ? roles
      : [cleanRole];

    if (!cleanEmail || !cleanEmail.includes("@")) {
      throw new HttpsError("invalid-argument", "A valid recipient email address is required.");
    }
    if (!cleanPassword) {
      throw new HttpsError("invalid-argument", "Password cannot be empty.");
    }

    logger.info(`[AdminMemberEndpoints] Dispatching credentials to ${cleanEmail} (username: ${cleanUsername}) by ${caller.email}`);

    // 2. Provision or update Firebase Auth account directly via Admin SDK
    let memberUid = "";
    try {
      let authRecord: admin.auth.UserRecord;
      try {
        authRecord = await admin.auth().getUserByEmail(cleanEmail);
        // User already exists in Firebase Auth: do NOT overwrite their existing password!
        await admin.auth().updateUser(authRecord.uid, {
          displayName: cleanName,
        });
      } catch (getErr: any) {
        if (getErr.code === "auth/user-not-found") {
          authRecord = await admin.auth().createUser({
            email: cleanEmail,
            password: cleanPassword,
            displayName: cleanName,
          });
        } else {
          throw getErr;
        }
      }
      memberUid = authRecord.uid;

      // Assign admin custom claim
      await admin.auth().setCustomUserClaims(memberUid, {
        admin: true,
        role: cleanRole,
        roles: assignedRoles,
      });
    } catch (authErr) {
      logger.warn("[AdminMemberEndpoints] Auth provisioning notice:", authErr);
    }

    // 3. Ensure Firestore admin_members record has all identity attributes (NEVER write plaintext password)
    try {
      const memberData: Record<string, any> = {
        email: cleanEmail,
        username: cleanUsername,
        name: cleanName,
        role: cleanRole,
        roles: assignedRoles,
        status: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (memberUid) {
        memberData.uid = memberUid;
      }

      await db().collection("admin_members").doc(cleanEmail).set(memberData, { merge: true });

      if (memberUid) {
        await db().collection("admin_members").doc(memberUid).set(memberData, { merge: true });
      }
    } catch (fsErr) {
      logger.warn("[AdminMemberEndpoints] Firestore record write notice:", fsErr);
    }

    // 4. Dispatch via EmailService (Nodemailer SMTP)
    const emailResult = await EmailService.sendAdminCredentialsEmail({
      to: cleanEmail,
      username: cleanUsername,
      password: cleanPassword,
      role: cleanRole,
      displayName: cleanName,
      portalUrl: targetUrl,
    });

    // 5. Record dispatch record in Firestore for auditability & mail backup
    try {
      const dispatchRecord = {
        recipientEmail: cleanEmail,
        username: cleanUsername,
        role: cleanRole,
        sentBy: caller.email,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: emailResult.success,
        messageId: emailResult.messageId || null,
        error: emailResult.error || null,
      };

      await db().collection("admin_credentials_dispatches").add(dispatchRecord);

      // Also record to mail collection as a fallback queue for Firebase Mail Extensions
      await db().collection("mail").add({
        to: cleanEmail,
        message: {
          subject: `Your TruthWorld Admin Portal Credentials [${cleanRole}]`,
          text: EmailService.generateAdminCredentialsEmailText({
            to: cleanEmail,
            username: cleanUsername,
            password: cleanPassword,
            role: cleanRole,
            displayName: cleanName,
            portalUrl: targetUrl,
          }),
          html: EmailService.generateAdminCredentialsEmailHtml({
            to: cleanEmail,
            username: cleanUsername,
            password: cleanPassword,
            role: cleanRole,
            displayName: cleanName,
            portalUrl: targetUrl,
          }),
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (auditErr) {
      logger.warn("[AdminMemberEndpoints] Could not record dispatch audit record:", auditErr);
    }

    return {
      success: emailResult.success,
      email: cleanEmail,
      username: cleanUsername,
      messageId: emailResult.messageId || null,
      skipped: emailResult.skipped || false,
    };
  }
);

/**
 * 🔍 VERIFY ADMIN USERNAME (onCall)
 *
 * Step 1 of the two-step Admin Portal login flow.
 * Validates whether the provided username or email belongs to an active administrator.
 * Includes rate-limiting protection against brute force enumeration.
 */
export const verifyAdminUsername = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const rawInput = (request.data?.username || "").toString().trim();
    const input = rawInput.toLowerCase();

    if (!input) {
      return {
        valid: false,
        message: "Please enter your administrator username.",
      };
    }

    // Rate Limiting / Lockout check (Max 10 failed checks per 15 minutes)
    const sanitizedKey = input.replace(/[^a-z0-9_@.-]/g, "_");
    const lockRef = db().collection("admin_auth_locks").doc(sanitizedKey);
    try {
      const lockSnap = await lockRef.get();
      if (lockSnap.exists) {
        const lockData = lockSnap.data() || {};
        const now = Date.now();
        const lockedUntil = lockData.lockedUntil || 0;
        if (now < lockedUntil) {
          const remainingSecs = Math.ceil((lockedUntil - now) / 1000);
          return {
            valid: false,
            locked: true,
            message: `Account temporarily locked due to multiple invalid attempts. Please try again in ${remainingSecs}s.`,
          };
        }
      }
    } catch (rateErr) {
      logger.warn("[verifyAdminUsername] Rate limit check notice:", rateErr);
    }

    // 1. Authorized primary owner accounts
    if (input === "hello1" || input === "hello@truthworld.in") {
      return {
        valid: true,
        email: "hello@truthworld.in",
        username: "hello1",
        displayName: "TruthWorld Director",
        role: "Owner / Super Admin",
      };
    }

    if (input === "ebenezer" || input === "ebenezervampu4@gmail.com") {
      return {
        valid: true,
        email: "ebenezervampu4@gmail.com",
        username: "ebenezer",
        displayName: "Ebenezer Vampu",
        role: "Owner / Super Admin",
      };
    }

    // 2. Query admin_members collection
    try {
      // Direct doc lookup (keyed by email or username or uid)
      const docSnap = await db().collection("admin_members").doc(input).get();
      if (docSnap.exists) {
        const data = docSnap.data() || {};
        if (data.status === "suspended") {
          return {
            valid: false,
            suspended: true,
            message: "This administrator account has been suspended by the team.",
          };
        }
        return {
          valid: true,
          email: data.email || input,
          username: data.username || input,
          displayName: data.name || data.username || "Administrator",
          role: data.role || "Admin",
        };
      }

      // Query by username field
      const usernameSnap = await db()
        .collection("admin_members")
        .where("username", "==", input)
        .limit(1)
        .get();

      if (!usernameSnap.empty) {
        const data = usernameSnap.docs[0].data();
        if (data.status === "suspended") {
          return {
            valid: false,
            suspended: true,
            message: "This administrator account has been suspended by the team.",
          };
        }
        return {
          valid: true,
          email: data.email,
          username: data.username || input,
          displayName: data.name || data.username || "Administrator",
          role: data.role || "Admin",
        };
      }

      // Query by email field
      const emailSnap = await db()
        .collection("admin_members")
        .where("email", "==", input)
        .limit(1)
        .get();

      if (!emailSnap.empty) {
        const data = emailSnap.docs[0].data();
        if (data.status === "suspended") {
          return {
            valid: false,
            suspended: true,
            message: "This administrator account has been suspended by the team.",
          };
        }
        return {
          valid: true,
          email: data.email || input,
          username: data.username || (data.email ? data.email.split("@")[0] : input),
          displayName: data.name || data.username || "Administrator",
          role: data.role || "Admin",
        };
      }
    } catch (err) {
      logger.error("[verifyAdminUsername] Query error:", err);
    }

    // Record failed attempt for rate limiting
    try {
      const snap = await lockRef.get();
      const currentCount = (snap.data()?.failedAttempts || 0) + 1;
      const updates: Record<string, any> = {
        failedAttempts: currentCount,
        lastAttemptAt: Date.now(),
      };
      if (currentCount >= 10) {
        // Lock out for 15 minutes
        updates.lockedUntil = Date.now() + 15 * 60 * 1000;
      }
      await lockRef.set(updates, { merge: true });
    } catch (recErr) {
      logger.warn("[verifyAdminUsername] Record failed attempt notice:", recErr);
    }

    return {
      valid: false,
      message: "Administrator account not found. Please verify your username.",
    };
  }
);

/**
 * 🔑 CHANGE ADMIN PASSWORD (onCall)
 *
 * Securely updates an administrator's password using Firebase Admin SDK.
 * Bypasses client-side requires-recent-login limitations and avoids
 * permission-denied Firestore rules issues.
 */
export const changeAdminPassword = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required to change password.");
    }

    const { newPassword, targetEmail } = request.data || {};
    const cleanNewPassword = (newPassword || "").toString().trim();

    if (!cleanNewPassword || cleanNewPassword.length < 6) {
      throw new HttpsError("invalid-argument", "New password must be at least 6 characters long.");
    }

    const callerEmail = (request.auth.token?.email || "").toLowerCase();
    const callerUid = request.auth.uid;
    const target = (targetEmail || callerEmail).toString().trim().toLowerCase();

    const isSelf = target === callerEmail;

    // If changing someone else's password, caller must be a Super Admin
    if (!isSelf) {
      await assertSuperAdminCaller(request.auth);
    }

    // Determine target user's UID
    let targetUid = callerUid;
    if (!isSelf) {
      try {
        const targetUser = await admin.auth().getUserByEmail(target);
        targetUid = targetUser.uid;
      } catch (err: any) {
        throw new HttpsError("not-found", `User with email ${target} not found.`);
      }
    }

    // 1. Update password using Firebase Admin SDK (never blocked by requires-recent-login)
    try {
      await admin.auth().updateUser(targetUid, {
        password: cleanNewPassword,
        emailVerified: true,
      });
      logger.info(`[changeAdminPassword] Password updated for ${target} (UID: ${targetUid}) by ${callerEmail}`);
    } catch (authErr: any) {
      logger.error("[changeAdminPassword] Auth update error:", authErr);
      throw new HttpsError("internal", "Unable to update password in authentication system.");
    }

    // 2. Update Firestore admin_members timestamp (Admin SDK bypasses client security rules)
    try {
      const updateData = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await db().collection("admin_members").doc(target).set(updateData, { merge: true });
      await db().collection("admin_members").doc(targetUid).set(updateData, { merge: true });
    } catch (fsErr: any) {
      logger.warn("[changeAdminPassword] Firestore timestamp notice:", fsErr);
    }

    return {
      success: true,
      email: target,
      message: "Administrator password successfully updated.",
    };
  }
);

/**
 * 🌱 SEED DEFAULT ADMINS (onCall)
 *
 * Ensures default director & owner administrator documents are provisioned in admin_members
 * and their Firebase Auth accounts have custom claims (admin: true, Super Admin role)
 * and emailVerified: true.
 */
export const seedDefaultAdmins = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required to seed default administrators.");
    }

    const callerEmail = (request.auth.token?.email || "").toLowerCase();
    const authorizedOwners = ["hello@truthworld.in", "ebenezervampu4@gmail.com"];

    const isOwner = authorizedOwners.includes(callerEmail);
    const token = request.auth.token || {};
    const isAdmin = isOwner || token.admin === true || token.isSuperAdmin === true;

    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Only administrators can seed admin records.");
    }

    const defaultAdmins = [
      {
        email: "hello@truthworld.in",
        username: "hello1",
        name: "TruthWorld Director",
        role: "Owner / Super Admin",
        roles: ["Super Admin", "Owner", "Director"],
      },
      {
        email: "ebenezervampu4@gmail.com",
        username: "ebenezer",
        name: "Ebenezer Vampu",
        role: "Owner / Super Admin",
        roles: ["Super Admin", "Owner", "Director"],
      },
    ];

    const results = [];

    for (const adminData of defaultAdmins) {
      try {
        const docRef = db().collection("admin_members").doc(adminData.email);
        const snap = await docRef.get();
        const baseData = {
          email: adminData.email,
          username: adminData.username,
          name: adminData.name,
          role: adminData.role,
          roles: adminData.roles,
          status: "active",
          permissions: ["all"],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!snap.exists) {
          await docRef.set({
            ...baseData,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } else {
          await docRef.set(baseData, { merge: true });
        }

        // Check if user exists in Firebase Auth, and set claims & emailVerified
        try {
          const authUser = await admin.auth().getUserByEmail(adminData.email);
          await admin.auth().setCustomUserClaims(authUser.uid, {
            admin: true,
            role: "Super Admin",
            roles: adminData.roles,
            isDirector: true,
            isSuperAdmin: true,
          });
          if (!authUser.emailVerified) {
            await admin.auth().updateUser(authUser.uid, { emailVerified: true });
          }

          // Mirror record to UID doc in admin_members
          await db().collection("admin_members").doc(authUser.uid).set({
            ...baseData,
            uid: authUser.uid,
          }, { merge: true });
        } catch (authLookErr: any) {
          if (authLookErr.code !== "auth/user-not-found") {
            logger.warn("[seedDefaultAdmins] Auth look error:", authLookErr);
          }
        }

        results.push({ email: adminData.email, status: "seeded" });
      } catch (err: any) {
        logger.error(`[seedDefaultAdmins] Failed for ${adminData.email}:`, err);
      }
    }

    return { success: true, seeded: results };
  }
);

/**
 * 🛠️ UPDATE ADMIN MEMBER (onCall)
 *
 * Allows a Super Admin to update roles, status, or display name of an admin member.
 */
export const updateAdminMember = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    const caller = await assertSuperAdminCaller(request.auth);
    const { email, updates, roles } = request.data || {};
    const cleanEmail = (email || "").toString().trim().toLowerCase();
    if (!cleanEmail) {
      throw new HttpsError("invalid-argument", "Member email is required.");
    }

    const dataToUpdate: Record<string, any> = { ...updates };
    if (Array.isArray(roles) && roles.length > 0) {
      dataToUpdate.roles = roles;
      dataToUpdate.role = roles.includes("Super Admin") ? "Super Admin" : roles.join(", ");
    }
    dataToUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    delete dataToUpdate.password; // INVARIANT: NEVER write password field

    await db().collection("admin_members").doc(cleanEmail).set(dataToUpdate, { merge: true });

    // Update UID doc if found
    try {
      const authUser = await admin.auth().getUserByEmail(cleanEmail);
      await db().collection("admin_members").doc(authUser.uid).set(dataToUpdate, { merge: true });

      // Update custom claims if roles changed
      if (dataToUpdate.roles) {
        await admin.auth().setCustomUserClaims(authUser.uid, {
          admin: true,
          role: dataToUpdate.role,
          roles: dataToUpdate.roles,
          isSuperAdmin: dataToUpdate.roles.includes("Super Admin"),
        });
      }
    } catch (err: any) {
      logger.warn("[updateAdminMember] UID doc sync notice:", err);
    }

    logger.info(`[updateAdminMember] Updated ${cleanEmail} by ${caller.email}`);
    return { success: true, email: cleanEmail };
  }
);

/**
 * 🗑️ DELETE ADMIN MEMBER (onCall)
 *
 * Allows a Super Admin to delete an admin member.
 */
export const deleteAdminMember = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    const caller = await assertSuperAdminCaller(request.auth);
    const { email } = request.data || {};
    const cleanEmail = (email || "").toString().trim().toLowerCase();
    const authorizedOwners = ["hello@truthworld.in", "ebenezervampu4@gmail.com"];

    if (authorizedOwners.includes(cleanEmail)) {
      throw new HttpsError("permission-denied", "Primary Owner account cannot be removed.");
    }

    let memberUid = "";
    try {
      const doc = await db().collection("admin_members").doc(cleanEmail).get();
      memberUid = doc.data()?.uid || "";
    } catch {}

    await db().collection("admin_members").doc(cleanEmail).delete();
    if (memberUid) {
      await db().collection("admin_members").doc(memberUid).delete();
      try {
        await admin.auth().setCustomUserClaims(memberUid, { admin: false });
      } catch {}
    }

    logger.info(`[deleteAdminMember] Removed ${cleanEmail} by ${caller.email}`);
    return { success: true, email: cleanEmail };
  }
);


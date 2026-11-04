/**
 * 👑 SEED ADMIN USER & CLAIMS SCRIPT
 *
 * Sets Firebase Auth custom claims (admin: true) and creates the required
 * /admin_members/{uid} and /admin_members/{email} records in Firestore.
 *
 * Usage:
 *   node scripts/seed_admin_user.js <UID> <EMAIL> [NAME]
 *
 * Example:
 *   node scripts/seed_admin_user.js oj3JOhUbOvZHjWmzFpXBVDB1vap1 ebenezervampu4@gmail.com "Ebenezer Vampu"
 */

const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

const uid = process.argv[2];
const email = process.argv[3];
const name = process.argv[4] || "TruthWorld Admin";

if (!uid || !email) {
  console.error("❌ Usage: node scripts/seed_admin_user.js <UID> <EMAIL> [NAME]");
  console.error("Example: node scripts/seed_admin_user.js oj3JOhUbOvZHjWmzFpXBVDB1vap1 ebenezervampu4@gmail.com \"Ebenezer Vampu\"");
  process.exit(1);
}

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  // Uses GOOGLE_APPLICATION_CREDENTIALS or default credentials
  admin.initializeApp({
    projectId: "truthworld-1",
  });
}

async function seedAdmin() {
  console.log(`\n👑 Seeding Admin Privileges:`);
  console.log(`   UID:   ${uid}`);
  console.log(`   Email: ${email}`);
  console.log(`   Name:  ${name}\n`);

  try {
    // 1. Set Custom User Claims on Firebase Auth
    await admin.auth().setCustomUserClaims(uid, {
      admin: true,
      role: "admin",
      isSuperAdmin: true,
      isDirector: true,
    });
    console.log("✅ Set Firebase Auth custom claims: { admin: true, role: 'admin', isSuperAdmin: true }");

    // 2. Write document keyed by UID (required by firestore.rules isAdmin() check)
    const db = admin.firestore();
    const adminData = {
      uid: uid,
      email: email.toLowerCase(),
      name: name,
      role: "Super Admin",
      roles: ["Super Admin", "Owner", "Director"],
      status: "active",
      permissions: ["all"],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection("admin_members").doc(uid).set(adminData, { merge: true });
    console.log(`✅ Created Firestore record: admin_members/${uid}`);

    // 3. Write document keyed by email (for email-based admin queries in backend)
    await db.collection("admin_members").doc(email.toLowerCase()).set(adminData, { merge: true });
    console.log(`✅ Created Firestore record: admin_members/${email.toLowerCase()}`);

    console.log("\n🎉 Admin privileges successfully granted! Hot restart your Flutter app (press 'R') or refresh Chrome.\n");
  } catch (err) {
    console.error("❌ Failed to seed admin:", err.message);
    if (err.message.includes("invalid_grant") || err.message.includes("Could not load the default credentials")) {
      console.log("\n👉 Tip: Run 'gcloud auth application-default login' first, or add the document manually in Firebase Console.");
    }
  }
}

seedAdmin();

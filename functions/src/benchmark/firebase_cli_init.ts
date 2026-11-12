import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "truthworld-1",
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "truthworld-1.firebasestorage.app",
  });
}

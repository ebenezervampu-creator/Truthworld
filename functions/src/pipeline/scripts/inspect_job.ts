import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

async function inspectJob(jobId: string) {
  const doc = await admin.firestore().collection("video_jobs").doc(jobId).get();
  if (!doc.exists) {
    console.log("❌ Job not found");
    return;
  }
  console.log(JSON.stringify(doc.data(), null, 2));
}

inspectJob("job_1776921568038_13f88ec6");

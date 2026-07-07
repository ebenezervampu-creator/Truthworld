import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

async function inspect(videoId: string, jobId: string) {
  console.log("=== VIDEO DOCUMENT ===");
  const videoDoc = await admin.firestore().collection("videos").doc(videoId).get();
  if (videoDoc.exists) {
    console.log(JSON.stringify(videoDoc.data(), null, 2));
  } else {
    console.log("❌ Video doc not found");
  }

  console.log("\n=== RESOLUTION JOB ===");
  const resJobDoc = await admin.firestore().collection("resolution_jobs").doc(videoId).get();
  if (resJobDoc.exists) {
    console.log(JSON.stringify(resJobDoc.data(), null, 2));
  } else {
    console.log("❌ Resolution job doc not found");
  }

  console.log("\n=== VIDEO JOB ===");
  const videoJobDoc = await admin.firestore().collection("video_jobs").doc(jobId).get();
  if (videoJobDoc.exists) {
    console.log(JSON.stringify(videoJobDoc.data(), null, 2));
  } else {
    console.log("❌ Video job doc not found");
  }
}

inspect("ccc6f754-e32c-4da9-9764-7947747497f3", "job_1782365065724_c6656bb9");

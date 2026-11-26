import * as admin from "firebase-admin";
import * as fs from "fs";

async function run() {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: "truthworld-1",
      storageBucket: "truthworld-1.firebasestorage.app"
    });
  }

  const bucket = admin.storage().bucket();
  console.log("Accessing bucket:", bucket.name);
  
  const [files] = await bucket.getFiles({ prefix: "factChecks/", maxResults: 100 });
  console.log("Total files found:", files.length);

  const fulls = files
    .filter((f) => f.name.endsWith("/full.json"))
    .sort((a, b) => String(b.metadata.updated || "").localeCompare(String(a.metadata.updated || "")));

  if (fulls.length === 0) {
    console.log("No full.json files found under factChecks/");
    // Also check videos collection in Firestore
    const db = admin.firestore();
    const snap = await db.collection("videos").orderBy("createdAt", "desc").limit(5).get();
    console.log("Videos in firestore:", snap.size);
    for (const doc of snap.docs) {
      console.log(`Video ${doc.id}: factCheckUrl =`, doc.data().factCheckUrl);
    }
    return;
  }

  const latest = fulls[0];
  console.log("Latest factCheck file:", latest.name, "updated:", latest.metadata.updated);
  const [buf] = await latest.download();
  const dest = "latest_factcheck_full.json";
  fs.writeFileSync(dest, buf);
  console.log(`Saved ${buf.length} bytes to ${dest}`);
}

run().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});

import * as admin from "firebase-admin";

process.env.FIRESTORE_EMULATOR_HOST = "localhost:9012";
admin.initializeApp({
  projectId: "truthworld-1"
});

const db = admin.firestore();

async function run() {
  console.log("=== TOPICS ===");
  const topics = await db.collection("topics").get();
  console.log("Count:", topics.docs.length);
  for (const doc of topics.docs) {
    console.log(doc.id, {
      title: doc.data().title,
      status: doc.data().status,
      slug: doc.data().slug,
      category: doc.data().category,
    });
  }

  console.log("\n=== VIDEOS ===");
  const videos = await db.collection("videos").get();
  console.log("Count:", videos.docs.length);
  for (const doc of videos.docs) {
    console.log(doc.id, {
      title: doc.data().title,
      status: doc.data().status,
      visibility: doc.data().visibility,
      uploadedAt: doc.data().uploadedAt,
      createdAt: doc.data().createdAt,
      videoUrl: doc.data().videoUrl,
      category: doc.data().category,
    });
  }
}

run().catch(console.error);

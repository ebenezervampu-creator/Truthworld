import * as admin from "firebase-admin";

export interface SeoMetricEvent {
  eventType: "cache_hit" | "cache_miss" | "ssr_render" | "sitemap_built" | "indexnow_submitted" | "error";
  path?: string;
  durationMs?: number;
  statusCode?: number;
  details?: string;
}

export function logSeoEvent(event: SeoMetricEvent) {
  // Structured log for Cloud Logging / GCP Monitoring
  console.info(`[SEO_METRIC] ${JSON.stringify({
    timestamp: new Date().toISOString(),
    ...event
  })}`);
}

export async function recordDailySeoSummary(db: admin.firestore.Firestore, metrics: Record<string, any>) {
  const dateId = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const docRef = db.collection("seo_metrics").doc(dateId);
  await docRef.set({
    date: dateId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...metrics
  }, { merge: true });
}

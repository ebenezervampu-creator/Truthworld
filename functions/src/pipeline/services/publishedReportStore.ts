/**
 * Read/write access to the fact-check report a video currently points at
 * (videos/{id}.factCheckUrl), plus the job's canonical full.json / latest.json copies.
 * Every post-publication update (community evidence, source healing, freshness sweep)
 * must write HERE, or viewers keep seeing the old report.
 */
import * as admin from "firebase-admin";

const db = () => admin.firestore();

/** Storage access for the published report (injectable for tests). */
export interface ReportStore {
  load(videoId: string): Promise<{ report: any; paths: string[] } | null>;
  save(paths: string[], report: any): Promise<void>;
}

/** Default storage-backed report access: resolves the object the video currently points at. */
export const gcsReportStore: ReportStore = {
  async load(videoId: string) {
    const videoSnap = await db().collection("videos").doc(videoId).get();
    const v = videoSnap.data() || {};
    const bucket = admin.storage().bucket();
    const candidates: string[] = [];
    const pushPath = (raw: unknown) => {
      const s = String(raw || "");
      if (!s) return;
      if (s.startsWith("gs://")) {
        candidates.push(s.replace(/^gs:\/\/[^/]+\//, ""));
      } else if (s.includes("/o/")) {
        const encoded = s.split("/o/")[1].split("?")[0];
        candidates.push(decodeURIComponent(encoded));
      }
    };
    pushPath(v.factCheckUrl);
    pushPath(v.media?.factCheckUrl);

    const primary = candidates.find(Boolean);
    if (!primary) return null;
    const [buf] = await bucket.file(primary).download();
    const report = JSON.parse(buf.toString("utf8"));

    // Keep the job's canonical copies in sync with the version the video points at.
    const paths = new Set<string>([primary]);
    const jobMatch = primary.match(/^factChecks\/([^/]+)\//);
    if (jobMatch) {
      paths.add(`factChecks/${jobMatch[1]}/full.json`);
      paths.add(`factChecks/${jobMatch[1]}/latest.json`);
    }
    return { report, paths: Array.from(paths) };
  },
  async save(paths: string[], report: any) {
    const bucket = admin.storage().bucket();
    const body = JSON.stringify(report);
    await Promise.all(
      paths.map((p) =>
        bucket.file(p).save(body, {
          metadata: { contentType: "application/json", cacheControl: "no-cache, max-age=0" },
        })
      )
    );
  },
};


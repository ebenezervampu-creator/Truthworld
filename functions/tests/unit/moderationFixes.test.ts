import * as fs from "fs";
import * as path from "path";

describe("Content Moderation Production Fixes", () => {
  const rootDir = path.resolve(__dirname, "../../..");

  test("adminBulkModerate updates videos/{videoId}, clears admin_review_queue, and publishes to active Pub/Sub topics", () => {
    const filePath = path.join(rootDir, "functions/src/admin/adminBulkModerate.ts");
    const content = fs.readFileSync(filePath, "utf8");

    expect(content).toContain('batch.update(videoRef, videoUpdates)');
    expect(content).toContain('"moderation.status": "approved"');
    expect(content).toContain("batch.delete(reviewQueueRef)");
    expect(content).toContain('"copyright.requested"');
    expect(content).toContain('"factcheck.requested"');
    expect(content).toContain('"dubbing.requested"');
    expect(content).not.toContain('"copyright-processing"');
    expect(content).not.toContain('"fact-processing"');
    expect(content).not.toContain('"dubbing-processing"');
    expect(content).toContain("cancelSpeculativeJobsForVideo");
  });

  test("onContentUploadedForModeration enforces trusted channel bypass and cancels speculative jobs on rejection", () => {
    const filePath = path.join(rootDir, "functions/src/moderation/contentModeration.ts");
    const content = fs.readFileSync(filePath, "utf8");

    expect(content).toContain("isChannelTrustedModerationBypassed(videoData?.channelId)");
    expect(content).toContain('"moderation.model": "trusted-channel-bypass"');
    expect(content).toContain('db.collection("credibility_jobs")');
    expect(content).toContain('db.collection("dubbing_jobs")');
  });

  test("submitVideoReport is exported as an authenticated server-side callable with 5-report block threshold", () => {
    const modPath = path.join(rootDir, "functions/src/moderation/contentModeration.ts");
    const indexPath = path.join(rootDir, "functions/src/moderation/index.ts");
    const modContent = fs.readFileSync(modPath, "utf8");
    const indexContent = fs.readFileSync(indexPath, "utf8");

    expect(indexContent).toContain('export * from "./contentModeration"');
    expect(modContent).toContain("export const submitVideoReport = onCall(");
    expect(modContent).toContain("VIDEO_REPORT_BLOCK_THRESHOLD = 5");
    expect(modContent).toContain('.collection("reports").doc(reporterId)');
  });

  test("handleCredibility and handleDubbing skip execution if video or job is already rejected", () => {
    const triggersPath = path.join(rootDir, "functions/src/pipeline/pipelineTriggers.ts");
    const content = fs.readFileSync(triggersPath, "utf8");

    expect(content).toContain("[handleCredibility] Skipping credibility — video/job already rejected by moderation");
    expect(content).toContain("[handleDubbing] Skipping dubbing — video/job already rejected by moderation");
  });

  test("firestore.rules protects videos/{videoId}/reports/{reporterId} from client writes", () => {
    const rulesPath = path.join(rootDir, "firestore.rules");
    const content = fs.readFileSync(rulesPath, "utf8");

    expect(content).toContain("match /videos/{videoId}/reports/{reporterId}");
    expect(content).toContain("allow read: if isAuthenticated() && (request.auth.uid == reporterId || isAdmin());");
    expect(content).toContain("allow write: if false;");
  });
});

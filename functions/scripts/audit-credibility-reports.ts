/**
 * Grades already-published fact-check reports with the same output quality audit that
 * now runs on every new report (src/pipeline/services/reportQualityAudit.ts).
 *
 * READ-ONLY: it only reads factChecks/{jobId}/full.json from Cloud Storage and prints a
 * summary + CSV. Use it to find which existing videos were hit by the shared-source /
 * Caution bugs and need fact-checking re-run, and to compare a video before/after a re-run.
 *
 * Usage (from functions/, with Application Default Credentials):
 *   npx ts-node scripts/audit-credibility-reports.ts --bucket <bucket-name> [--limit 300] [--job <jobId>] [--csv out.csv]
 *   npx ts-node scripts/audit-credibility-reports.ts --bucket <bucket-name> --job <jobId> --spotcheck 5
 *
 * With --job, also prints the live-test checklist numbers for that report:
 *   unique sources, quality grade, Caution-without-sources (must be 0),
 *   verified-with-A/B/C-source-downgraded (must be 0), and with --spotcheck N,
 *   N claims whose sources carry no explicit stance — read them and confirm each source
 *   really supports/refutes the claim rather than only mentioning the topic.
 */
import * as admin from "firebase-admin";
import * as fs from "fs";
import { auditCredibilityReport, ReportQualityAudit } from "../src/pipeline/services/reportQualityAudit";
import { liveSources } from "../src/pipeline/services/verdictGate";

/** Live-test checklist for a single report (see header). */
function printLiveTestChecklist(report: any, spotcheck: number) {
  const claims: any[] = Array.isArray(report?.claims) ? report.claims : [];
  const urls = new Set<string>();
  for (const c of claims) for (const s of liveSources(c)) urls.add(String(s.url).toLowerCase());
  const cautionWithoutSources = claims.filter((c) => c.publicVerdict === "CAUTION" && liveSources(c).length === 0);
  const strongDowngradedToCaution = claims.filter(
    (c) => c.publicVerdict === "CAUTION" &&
      Array.isArray(c.verdictHistory) &&
      c.verdictHistory.some((h: any) => ["verified_true", "mostly_true"].includes(h.previousStatus)) &&
      liveSources(c).some((s) => ["A", "B", "C"].includes(String(s.tier)))
  );
  const counts = report?.publicVerdictCounts || {};
  console.log("\n=== Live-test checklist ===");
  console.log(`1. Unique live sources across the video: ${urls.size}`);
  console.log(`2. Quality grade: ${report?.qualityAudit?.grade ?? "(not graded)"}  checks: ${(report?.qualityAudit?.checks || []).map((c: any) => `${c.id}:${c.severity}`).join(", ") || "none"}`);
  console.log(`3. Public verdicts: ${JSON.stringify(counts)}`);
  console.log(`   Caution with zero live sources (must be 0): ${cautionWithoutSources.length}`);
  console.log(`   Verified→Caution despite a live A/B/C source (must be 0): ${strongDowngradedToCaution.length}`);
  const gateDemotions = claims.filter((c) => c.gateDemotion);
  console.log(`   Gate demotions to "No evidence yet": ${gateDemotions.length}`);
  for (const c of gateDemotions.slice(0, 10)) console.log(`     - [${c.gateDemotion.from}] ${String(c.claim || c.text).slice(0, 90)} — ${c.gateDemotion.reason}`);

  if (spotcheck > 0) {
    const unlabelled = claims.filter((c) => ["VERIFIED", "FALSE", "CAUTION"].includes(c.publicVerdict) &&
      liveSources(c).some((s: any) => !s.stance && !s.isContradictory));
    console.log(`\n=== Spot-check (${Math.min(spotcheck, unlabelled.length)} of ${unlabelled.length} claims with unlabelled-stance sources) ===`);
    for (const c of unlabelled.slice(0, spotcheck)) {
      console.log(`\n[${c.publicVerdict}] ${String(c.claim || c.text)}`);
      for (const s of liveSources(c)) console.log(`   - (${s.tier}) ${s.title || s.domain} — ${s.url}\n     "${String(s.snippet || "").slice(0, 200)}"`);
    }
    console.log("\nFor each: does the source actually confirm/refute the claim, or only mention the same topic?");
  }
}

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const bucketName = arg("bucket") || process.env.FIREBASE_STORAGE_BUCKET;
  const limit = Number(arg("limit") || 300);
  const onlyJob = arg("job");
  const csvPath = arg("csv") || "credibility_quality_audit.csv";
  const spotcheck = Number(arg("spotcheck") || 0);

  if (!admin.apps.length) admin.initializeApp(bucketName ? { storageBucket: bucketName } : undefined);
  const bucket = admin.storage().bucket(bucketName);

  const paths: string[] = [];
  if (onlyJob) {
    paths.push(`factChecks/${onlyJob}/full.json`);
  } else {
    const [files] = await bucket.getFiles({ prefix: "factChecks/", autoPaginate: true });
    const fulls = files
      .filter((f) => f.name.endsWith("/full.json"))
      .sort((a, b) => String(b.metadata.updated || "").localeCompare(String(a.metadata.updated || "")));
    paths.push(...fulls.slice(0, limit).map((f) => f.name));
  }

  const rows: Array<{ jobId: string; audit: ReportQualityAudit }> = [];
  for (const p of paths) {
    try {
      const [buf] = await bucket.file(p).download();
      const report = JSON.parse(buf.toString("utf8"));
      rows.push({ jobId: p.split("/")[1], audit: auditCredibilityReport(report) });
      if (onlyJob) printLiveTestChecklist(report, spotcheck);
    } catch (err) {
      console.error(`Skipped ${p}: ${String(err)}`);
    }
  }

  const count = (g: string) => rows.filter((r) => r.audit.grade === g).length;
  console.log(`\nAudited ${rows.length} report(s): PASS ${count("PASS")} | WARN ${count("WARN")} | FAIL ${count("FAIL")}\n`);
  for (const r of rows.filter((x) => x.audit.grade !== "PASS")) {
    console.log(`${r.audit.grade}  ${r.jobId}`);
    for (const c of r.audit.checks) console.log(`   - [${c.severity}] ${c.id}: ${c.message}`);
  }

  const header = "jobId,grade,checks,factualClaims,cautionRatio,zeroSourceFactRatio,maxSharedSourceRatio,maxSharedSourceUrl,distinctClaimSources,videoLevelSources,contradictions,unverifiedDisplayedSources";
  const lines = rows.map(({ jobId, audit: a }) =>
    [
      jobId, a.grade, a.checks.map((c) => `${c.id}:${c.severity}`).join("|"), a.metrics.factualClaims,
      a.metrics.cautionRatio, a.metrics.zeroSourceFactRatio, a.metrics.maxSharedSourceRatio,
      `"${(a.metrics.maxSharedSourceUrl || "").replace(/"/g, "'")}"`, a.metrics.distinctClaimSources,
      a.metrics.videoLevelSources, a.metrics.contradictions, a.metrics.unverifiedDisplayedSources,
    ].join(",")
  );
  fs.writeFileSync(csvPath, [header, ...lines].join("\n"));
  console.log(`\nCSV written to ${csvPath}`);
}

main().catch((err) => {
  console.error("Audit failed:", err);
  process.exit(1);
});

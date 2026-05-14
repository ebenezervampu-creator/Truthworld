/**
 * 🧪 TRUTHWORLD BENCHMARK CLI
 *
 * Entry point for running the benchmark suite.
 *
 * Usage:
 *   npx ts-node src/benchmark/index.ts
 *   npm run benchmark
 *
 * Output:
 *   - Console report with all metrics
 *   - JSON results file saved to benchmark/results/
 */

import * as fs from "fs";
import * as path from "path";
import { BenchmarkRunner } from "./runner";
import { BenchmarkDataset, BenchmarkRun, BenchmarkMetrics } from "./types";

// ─── Load Dataset ────────────────────────────────────────────────────────────

function loadDataset(): BenchmarkDataset {
  const datasetPath = path.join(__dirname, "dataset", "seed-v1.json");

  if (!fs.existsSync(datasetPath)) {
    console.error(`❌ Dataset not found at: ${datasetPath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(datasetPath, "utf-8");
  return JSON.parse(raw) as BenchmarkDataset;
}

// ─── Report Formatter ────────────────────────────────────────────────────────

function printReport(run: BenchmarkRun): void {
  const m = run.metrics;

  console.log(`\n\n`);
  console.log(`╔══════════════════════════════════════════════════════════════════╗`);
  console.log(`║              TRUTHWORLD BENCHMARK REPORT v1                    ║`);
  console.log(`╚══════════════════════════════════════════════════════════════════╝`);
  console.log(``);
  console.log(`  Run ID:       ${run.runId}`);
  console.log(`  Timestamp:    ${run.timestamp}`);
  console.log(`  Pipeline:     ${run.version}`);
  console.log(`  Dataset:      ${run.datasetVersion} (${run.results.length} claims)`);
  console.log(`  Duration:     ${(run.duration / 1000).toFixed(1)}s`);
  console.log(``);
  console.log(`  Models:`);
  console.log(`    Extraction:   ${run.config.extractionModel}`);
  console.log(`    Verification: ${run.config.verificationModel}`);
  console.log(`    Grounding:    ${run.config.groundingMode}`);

  // ─── Accuracy ──────────────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  📊 MODEL ACCURACY                                            │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  Exact Match:        ${padR(m.accuracy.exactMatchRate + "%", 8)}                              │`);
  console.log(`│  Acceptable Match:   ${padR(m.accuracy.acceptableMatchRate + "%", 8)}  ← primary metric          │`);
  console.log(`│  High-Risk Accuracy: ${padR(m.accuracy.highRiskAccuracy + "%", 8)}                              │`);
  console.log(`│  Low-Risk Accuracy:  ${padR(m.accuracy.lowRiskAccuracy + "%", 8)}                              │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  // ─── Error Analysis ────────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  🚨 ERROR ANALYSIS                                            │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  False Accusation Rate:  ${padR(m.errors.falseAccusationRate + "%", 8)}  (safe claims → incorrect) │`);
  console.log(`│  False Leniency Rate:    ${padR(m.errors.falseLeniencyRate + "%", 8)}  (harmful → correct)       │`);
  console.log(`│  Total Mismatches:       ${padR(String(m.errors.totalMismatches), 8)}                            │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  if (m.errors.worstMismatches.length > 0) {
    console.log(`\n  ⚠️  Worst Mismatches:`);
    m.errors.worstMismatches.forEach((r, i) => {
      const icon = r.isFalseAccusation ? "🚨" : (r.isFalseLeniency ? "💀" : "❌");
      console.log(`    ${i + 1}. ${icon} [${r.id}] predicted=${r.predictedLabel}, truth=${r.groundTruth}`);
      console.log(`       "${r.claim.substring(0, 70)}..."`);
    });
  }

  // ─── Routing ───────────────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  🔀 ROUTING QUALITY                                           │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  Routed to Pro:        ${padR(String(m.routing.routedToPro), 4)} / ${m.routing.totalClaims}                          │`);
  console.log(`│  Routed to Flash:      ${padR(String(m.routing.routedToFlash), 4)} / ${m.routing.totalClaims}                          │`);
  console.log(`│  Escalation Rate:      ${padR(m.routing.escalationRate + "%", 8)}                              │`);
  console.log(`│  Routing Accuracy:     ${padR(m.routing.routingAccuracy + "%", 8)}                              │`);
  console.log(`│  Missed Escalations:   ${padR(String(m.routing.missedEscalations), 4)}                                  │`);
  console.log(`│  Unnecessary Pro:      ${padR(String(m.routing.unnecessaryPro), 4)}                                  │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  // ─── Domain Breakdown ──────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  🌐 DOMAIN BREAKDOWN                                          │`);
  console.log(`├──────────────────┬────────┬──────────┬─────────────────────────┤`);
  console.log(`│  Domain          │ Total  │ Correct  │ Accuracy                │`);
  console.log(`├──────────────────┼────────┼──────────┼─────────────────────────┤`);

  Object.entries(m.domainAccuracy).forEach(([domain, stats]) => {
    const bar = "█".repeat(Math.round(stats.accuracy / 5));
    console.log(`│  ${padR(domain, 16)} │  ${padR(String(stats.total), 4)}  │  ${padR(String(stats.acceptableMatch), 4)}    │ ${padR(stats.accuracy + "%", 7)} ${bar.padEnd(15)} │`);
  });

  console.log(`└──────────────────┴────────┴──────────┴─────────────────────────┘`);

  // ─── Nuance Recognition ────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  🧠 NUANCE RECOGNITION (Competitive Differentiator)           │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  mostly_correct:   ${padR(m.nuance.mostlyCorrectRecognition + "%", 8)}                                │`);
  console.log(`│  outdated:         ${padR(m.nuance.outdatedRecognition + "%", 8)}                                │`);
  console.log(`│  needs_context:    ${padR(m.nuance.needsContextRecognition + "%", 8)}                                │`);
  console.log(`│  unsupported:      ${padR(m.nuance.unsupportedRecognition + "%", 8)}                                │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  // ─── TruthWorld Metrics ────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  🔥 TRUTHWORLD TRUST METRICS (Unique Moat)                    │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  Creator Harm Index:          ${padR(m.trustMetrics.creatorHarmIndex + "%", 8)}                      │`);
  console.log(`│  Misinformation Escape Rate:  ${padR(m.trustMetrics.misinformationEscapeRate + "%", 8)}                      │`);
  console.log(`│  Nuance Recognition Score:    ${padR(String(m.trustMetrics.nuanceRecognitionScore), 8)}                      │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  // ─── Performance ───────────────────────────────────────────────────────

  console.log(`\n┌─────────────────────────────────────────────────────────────────┐`);
  console.log(`│  ⚡ PERFORMANCE & COST                                        │`);
  console.log(`├─────────────────────────────────────────────────────────────────┤`);
  console.log(`│  Avg Latency:         ${padR(m.performance.avgLatencyMs + "ms", 10)}                            │`);
  console.log(`│  Avg Latency (Flash): ${padR(m.performance.avgLatencyFlash + "ms", 10)}                            │`);
  console.log(`│  Avg Latency (Pro):   ${padR(m.performance.avgLatencyPro + "ms", 10)}                            │`);
  console.log(`│  Est. Cost / 100:     $${padR(String(m.performance.estimatedCostPer100), 9)}                           │`);
  console.log(`└─────────────────────────────────────────────────────────────────┘`);

  // ─── Label Distribution ────────────────────────────────────────────────

  console.log(`\n  📈 Label Distribution:`);
  console.log(`  ${"Label".padEnd(22)} ${"Predicted".padEnd(12)} ${"Expected".padEnd(12)}`);
  console.log(`  ${"─".repeat(46)}`);

  const allLabels = new Set([
    ...Object.keys(m.labelDistribution.predicted),
    ...Object.keys(m.labelDistribution.expected),
  ]);

  Array.from(allLabels).sort().forEach(label => {
    const pred = m.labelDistribution.predicted[label] || 0;
    const exp  = m.labelDistribution.expected[label] || 0;
    const drift = pred !== exp ? ` ← ${pred > exp ? "+" : ""}${pred - exp}` : "";
    console.log(`  ${label.padEnd(22)} ${String(pred).padEnd(12)} ${String(exp).padEnd(12)}${drift}`);
  });

  // ─── Final Verdict ─────────────────────────────────────────────────────

  console.log(`\n╔══════════════════════════════════════════════════════════════════╗`);
  const grade = getGrade(m);
  console.log(`║  VERDICT: ${grade.label.padEnd(52)} ║`);
  console.log(`║  Score:   ${(grade.score + "/10").padEnd(52)} ║`);
  console.log(`╚══════════════════════════════════════════════════════════════════╝\n`);
}

function getGrade(m: BenchmarkMetrics): { label: string; score: number } {
  const acc = m.accuracy.acceptableMatchRate;
  const harm = m.trustMetrics.creatorHarmIndex;
  const escape = m.trustMetrics.misinformationEscapeRate;

  // Weighted composite
  const score = Math.round((
    (acc / 10) * 0.4 +
    ((100 - harm) / 10) * 0.25 +
    ((100 - escape) / 10) * 0.25 +
    (m.trustMetrics.nuanceRecognitionScore * 10) * 0.1
  ) * 10) / 10;

  let label: string;
  if (score >= 9)      label = "🏆 ELITE — Production-ready truth engine";
  else if (score >= 8) label = "✅ STRONG — Minor calibration needed";
  else if (score >= 7) label = "👍 GOOD — Some gaps to address";
  else if (score >= 6) label = "⚠️  FAIR — Significant improvements needed";
  else                 label = "🚨 WEAK — Major overhaul required";

  return { label, score };
}

function padR(str: string, len: number): string {
  return str.padEnd(len);
}

// ─── Save Results ────────────────────────────────────────────────────────────

function saveResults(run: BenchmarkRun): string {
  const resultsDir = path.join(__dirname, "results");
  if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
  }

  const filename = `benchmark_${new Date().toISOString().replace(/[:.]/g, "-")}.json`;
  const filepath = path.join(resultsDir, filename);

  fs.writeFileSync(filepath, JSON.stringify(run, null, 2));
  return filepath;
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n🚀 Starting TruthWorld Benchmark Suite v1...\n`);

  // Load dataset
  const dataset = loadDataset();
  console.log(`📂 Loaded ${dataset.claims.length} claims from dataset v${dataset.version}`);

  // Run benchmark
  const runner = new BenchmarkRunner();
  const run = await runner.run(dataset);

  // Print report
  printReport(run);

  // Save results
  const filepath = saveResults(run);
  console.log(`\n💾 Results saved to: ${filepath}`);
  console.log(`   Use this file for regression comparison.\n`);
}

main().catch(err => {
  console.error("❌ Benchmark failed:", err);
  process.exit(1);
});

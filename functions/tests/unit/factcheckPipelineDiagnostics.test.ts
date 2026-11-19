/**
 * 🧪 UNIT TEST: FACTCHECK PIPELINE DIAGNOSTICS & TRACEABILITY
 *
 * Verifies that the Factcheck Pipeline observability engine:
 * 1. Accurately tracks all 11 stages of the pipeline lifecycle.
 * 2. Records granular per-stage latencies, metrics, and execution breadcrumbs.
 * 3. Enriches errors into FactcheckPipelineError with stage, component, and root-cause remedy.
 * 4. Ensures any developer or AI agent can immediately identify where a bug originated.
 */

import {
  FactcheckStage,
  FactcheckDiagnosticTracker,
  FactcheckPipelineError,
} from "../../src/pipeline/layers/credibilityDiagnostics";
import { CredibilityEngine } from "../../src/pipeline/layers/06-credibility";

describe("Unit: Factcheck Pipeline Diagnostics & Bug Traceability", () => {
  const TEST_JOB_ID = "job_test_factcheck_123";
  const TEST_VIDEO_ID = "video_test_truth_456";
  const TEST_USER_ID = "user_test_creator_789";

  it("1. Successfully initializes diagnostic tracker with preflight stage and metadata", () => {
    const tracker = new FactcheckDiagnosticTracker(TEST_JOB_ID, TEST_VIDEO_ID, TEST_USER_ID);
    expect(tracker.jobId).toBe(TEST_JOB_ID);
    expect(tracker.videoId).toBe(TEST_VIDEO_ID);
    expect(tracker.userId).toBe(TEST_USER_ID);

    const telemetry = tracker.getDiagnosticTelemetry();
    expect(telemetry.activeStage).toBe(FactcheckStage.STAGE_01_PREFLIGHT);
    expect(telemetry.totalElapsedMs).toBeGreaterThanOrEqual(0);
    expect(Array.isArray(telemetry.breadcrumbs)).toBe(true);
  });

  it("2. Transitions through pipeline stages and accurately tracks stage latencies", async () => {
    const tracker = new FactcheckDiagnosticTracker(TEST_JOB_ID, TEST_VIDEO_ID, TEST_USER_ID);

    tracker.enterStage(FactcheckStage.STAGE_02_INPUT_RESOLUTION, { source: "transcript" });
    await new Promise((resolve) => setTimeout(resolve, 20));
    const stage2Duration = tracker.completeStage(FactcheckStage.STAGE_02_INPUT_RESOLUTION);
    expect(stage2Duration).toBeGreaterThanOrEqual(15);

    tracker.enterStage(FactcheckStage.STAGE_04_CLAIM_EXTRACTION, { chunkCount: 3 });
    tracker.recordMetric("extractedClaimsCount", 12);
    tracker.recordMetric("domain", "HEALTH_MEDICAL");
    await new Promise((resolve) => setTimeout(resolve, 15));
    const stage4Duration = tracker.completeStage(FactcheckStage.STAGE_04_CLAIM_EXTRACTION);
    expect(stage4Duration).toBeGreaterThanOrEqual(10);

    const telemetry = tracker.getDiagnosticTelemetry();
    expect(telemetry.stageLatenciesMs[FactcheckStage.STAGE_02_INPUT_RESOLUTION]).toBeGreaterThanOrEqual(15);
    expect(telemetry.stageLatenciesMs[FactcheckStage.STAGE_04_CLAIM_EXTRACTION]).toBeGreaterThanOrEqual(10);
    expect(telemetry.metrics.extractedClaimsCount).toBe(12);
    expect(telemetry.metrics.domain).toBe("HEALTH_MEDICAL");
    expect(telemetry.breadcrumbs.length).toBeGreaterThanOrEqual(3);
  });

  it("3. Executes action within executeStage successfully when no errors occur", async () => {
    const tracker = new FactcheckDiagnosticTracker(TEST_JOB_ID, TEST_VIDEO_ID, TEST_USER_ID);

    const result = await tracker.executeStage(
      FactcheckStage.STAGE_05_RANKING_AND_STREAMING,
      "StreamingClaimProcessor",
      async () => {
        return { rankedCount: 5, status: "streamed" };
      },
      { inputClaims: 5 }
    );

    expect(result.rankedCount).toBe(5);
    expect(result.status).toBe("streamed");

    const telemetry = tracker.getDiagnosticTelemetry();
    expect(telemetry.stageLatenciesMs[FactcheckStage.STAGE_05_RANKING_AND_STREAMING]).toBeDefined();
  });

  it("4. Automatically catches errors in executeStage and wraps them with granular bug attribution", async () => {
    const tracker = new FactcheckDiagnosticTracker(TEST_JOB_ID, TEST_VIDEO_ID, TEST_USER_ID);

    let caughtError: FactcheckPipelineError | null = null;
    try {
      await tracker.executeStage(
        FactcheckStage.STAGE_07_CASCADE_VERIFICATION,
        "VerificationCascadeService",
        async () => {
          throw new Error("Vertex AI Google Grounding quota exceeded (RESOURCE_EXHAUSTED 429)");
        },
        { currentClaimId: "claim_03", domain: "GEOPOLITICS_WAR" },
        "Verify Vertex AI Grounding project quota and billing credentials in GCP console"
      );
    } catch (err: any) {
      caughtError = err;
    }

    expect(caughtError).toBeInstanceOf(FactcheckPipelineError);
    expect(caughtError!.stage).toBe(FactcheckStage.STAGE_07_CASCADE_VERIFICATION);
    expect(caughtError!.component).toBe("VerificationCascadeService");
    expect(caughtError!.jobId).toBe(TEST_JOB_ID);
    expect(caughtError!.videoId).toBe(TEST_VIDEO_ID);
    expect(caughtError!.suggestedRemedy).toBe(
      "Verify Vertex AI Grounding project quota and billing credentials in GCP console"
    );
    expect(caughtError!.context?.currentClaimId).toBe("claim_03");

    const summary = caughtError!.toDiagnosticSummary();
    expect(summary.errorType).toBe("FactcheckPipelineError");
    expect(summary.stage).toBe(FactcheckStage.STAGE_07_CASCADE_VERIFICATION);
    expect(summary.component).toBe("VerificationCascadeService");

    const telemetry = tracker.getDiagnosticTelemetry();
    expect(telemetry.lastError).toBeDefined();
    expect(telemetry.lastError!.stage).toBe(FactcheckStage.STAGE_07_CASCADE_VERIFICATION);
    expect(telemetry.lastError!.component).toBe("VerificationCascadeService");
  });

  it("5. Verifies CredibilityEngine exposes all modular stages and methods", () => {
    const engine = new CredibilityEngine("test-api-key");
    expect(typeof engine.runCredibilityPipeline).toBe("function");
    expect(typeof engine.runSynthesisPass).toBe("function");
    expect(typeof engine.cacheCheck).toBe("function");
    expect(typeof engine.cacheWithTTL).toBe("function");
    expect(typeof (engine as any).executeStage01Preflight).toBe("function");
    expect(typeof (engine as any).executeStage02InputResolution).toBe("function");
    expect(typeof (engine as any).executeStage03QuotaAndSafety).toBe("function");
    expect(typeof (engine as any).executeStage04ClaimExtraction).toBe("function");
    expect(typeof (engine as any).executeStage05RankingAndStreaming).toBe("function");
    expect(typeof (engine as any).executeStage06HarvestSources).toBe("function");
    expect(typeof (engine as any).executeStage07CascadeVerification).toBe("function");
    expect(typeof (engine as any).executeStage08CompileLedgerAndExplainability).toBe("function");
    expect(typeof (engine as any).executeStage09PersistDraftAndTriggerSynthesis).toBe("function");
    expect(typeof (engine as any).executeStage10AssembleAndStoreResult).toBe("function");
    expect(typeof (engine as any).executeStage11RecordCostAttribution).toBe("function");
  });
});

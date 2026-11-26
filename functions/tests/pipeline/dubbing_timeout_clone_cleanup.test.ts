/**
 * 25 Nov: a 540 s timeout left 8 temporary clones on the ElevenLabs account (the race rejected while
 * the pipeline kept running, so its `finally` never ran) and the next run hit voice_limit_reached.
 * The timeout guard now deletes the clones the job made, and the job cannot dispatch reels after it.
 */
import { DubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { EdgeLayer } from "../../src/pipeline/layers/01-edge";
import { ttsService } from "../../src/pipeline/services/tts";
import { testFirestore } from "../helpers/mockFirestore";

describe("timeout guard deletes the job's temporary voice clones", () => {
  const Engine: any = DubbingEngine;
  let deleteSpy: jest.SpyInstance;

  beforeEach(() => {
    deleteSpy = jest.spyOn(ttsService, "deleteVoice").mockResolvedValue(true as any);
    jest.spyOn(EdgeLayer, "updateStageSync").mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, "failStage").mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, "upsertDubbingJob").mockResolvedValue(undefined as any);
  });
  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.DUBBING_TIMEOUT_MS;
  });

  it("tracks clones per job and deletes exactly that job's clones", async () => {
    Engine.trackTempClone("job_a", "v1");
    Engine.trackTempClone("job_a", "v2");
    Engine.trackTempClone("job_b", "v3");
    expect(await Engine.deletePendingTempClones("job_a")).toBe(2);
    expect(deleteSpy.mock.calls.map((c) => c[0]).sort()).toEqual(["v1", "v2"]);
    expect(await Engine.deletePendingTempClones("job_a")).toBe(0);
    Engine.releaseTempClones("job_b");
    expect(await Engine.deletePendingTempClones("job_b")).toBe(0);
  });

  it("when the timeout fires, the clones made so far are deleted and the job is marked timed out", async () => {
    process.env.DUBBING_TIMEOUT_MS = "50";
    const engine: any = new DubbingEngine();
    engine.distribution = { checkAndMarkEventId: async () => "NEW", markEventCompleted: async () => undefined };
    let finish: () => void = () => undefined;
    engine.executeDubbingPipeline = async (jobId: string) => {
      Engine.trackTempClone(jobId, "clone_x");
      Engine.trackTempClone(jobId, "clone_y");
      await new Promise<void>((resolve) => { finish = resolve; });
      return [];
    };
    // Transcription already done, so the guard is reached without calling any outside service.
    await testFirestore.collection("video_jobs").doc("job_timeout").set({ stages: { transcription: { status: "completed" } } });
    const plan: any = { generateDubbing: true, dubbingLanguages: ["te"], languages: ["te"] };
    await expect(engine.runDubbingPipeline("job_timeout", "u1", "gs://b/v.mp4", plan, "evt1")).rejects.toThrow(/maximum cloud engine duration/);
    expect(deleteSpy.mock.calls.map((c) => c[0]).sort()).toEqual(["clone_x", "clone_y"]);
    expect(Engine.timedOutJobs.has("job_timeout")).toBe(true);
    finish();
    Engine.timedOutJobs.delete("job_timeout");
  });
});

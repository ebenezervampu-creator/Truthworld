import * as fs from "fs";

const execCalls: Array<{ cmd: string; args: string[]; opts: any }> = [];

jest.mock("child_process", () => {
  const actual = jest.requireActual("child_process");
  return {
    ...actual,
    execFile: jest.fn((cmd: any, args: any, opts: any, cb: any) => {
      const callback = typeof opts === "function" ? opts : cb;
      execCalls.push({ cmd, args: [...args], opts: typeof opts === "object" ? opts : {} });
      if (callback) callback(null, { stdout: "", stderr: "" });
      return {} as any;
    }),
  };
});

jest.mock("firebase-admin", () => ({
  storage: () => ({
    bucket: () => ({
      name: "test-bucket",
      upload: jest.fn().mockResolvedValue(undefined),
    }),
  }),
}));

describe("MediaService.mergeAudioToVideo industry-standard remux safety", () => {
  beforeEach(() => {
    execCalls.length = 0;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("omits bare unbounded apad when isPreMastered=true and durationSeconds is unset, passes -nostdin and bounded timeout", async () => {
    const { MediaService } = require("../../src/pipeline/services/media");
    const svc = new MediaService();
    jest.spyOn(svc, "downloadToStream").mockResolvedValue(undefined);
    jest.spyOn(fs.promises, "unlink").mockResolvedValue(undefined);

    await svc.mergeAudioToVideo({
      jobId: "job_test_remux",
      videoUrl: "gs://test-bucket/v.mp4",
      audioUrl: "gs://test-bucket/a.mp3",
      language: "te",
      isPreMastered: true,
    });

    expect(execCalls).toHaveLength(1);
    const { args, opts } = execCalls[0];
    expect(args).toContain("-nostdin");
    expect(args).not.toContain("apad");
    expect(args).not.toContain("-filter:a");
    expect(opts.timeout).toBeGreaterThanOrEqual(120_000);
    expect(opts.timeout).toBeLessThanOrEqual(300_000);
  });

  it("uses single bounded apad=whole_len without leading bare apad when durationSeconds is provided", async () => {
    const { MediaService } = require("../../src/pipeline/services/media");
    const svc = new MediaService();
    jest.spyOn(svc, "downloadToStream").mockResolvedValue(undefined);
    jest.spyOn(fs.promises, "unlink").mockResolvedValue(undefined);

    await svc.mergeAudioToVideo({
      jobId: "job_test_remux_dur",
      videoUrl: "gs://test-bucket/v.mp4",
      audioUrl: "gs://test-bucket/a.mp3",
      language: "te",
      isPreMastered: true,
      durationSeconds: 30,
    });

    expect(execCalls).toHaveLength(1);
    const filterIdx = execCalls[0].args.indexOf("-filter:a");
    expect(filterIdx).toBeGreaterThan(-1);
    expect(execCalls[0].args[filterIdx + 1]).toBe(`apad=whole_len=${30 * 44100}`);
  });
});

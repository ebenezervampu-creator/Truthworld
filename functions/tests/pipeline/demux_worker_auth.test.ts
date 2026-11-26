/**
 * Self-hosted Demux worker (scripts/modal_demux_worker.py) — the pipeline side of its auth.
 * The worker refuses /demix without the shared token (2026-11-21: Modal showed the endpoint as
 * "Unauthenticated", so anyone with the URL could run the GPU and read creators' stems).
 */
jest.mock("firebase-admin", () => ({ storage: () => ({ bucket: () => ({ name: "test-bucket" }) }) }));
jest.mock("../../src/pipeline/services/audio-identity.js", () => ({ audioIdentityService: { getAccessibleUrl: async (u: string) => `https://storage.googleapis.com/signed/${u}` } }), { virtual: true });
jest.mock("../../src/pipeline/services/audio-identity", () => ({ audioIdentityService: { getAccessibleUrl: async (u: string) => `https://storage.googleapis.com/signed/${u}` } }));
jest.mock("ffmpeg-static", () => "/usr/local/bin/ffmpeg", { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: { DEMUX_SERVICE_URL: "https://worker.example.modal.run/" } }));

const post = jest.fn();
jest.mock("axios", () => ({ __esModule: true, default: { post: (...a: any[]) => post(...a), get: jest.fn() } }));

import { demuxWorkerRequestConfig, mediaService } from "../../src/pipeline/services/media";

const TOKEN = "x".repeat(48);

beforeEach(() => {
  post.mockReset();
  delete process.env.DEMUX_WORKER_TOKEN;
  delete process.env.DEMUX_TIMEOUT_MS;
});

describe("demux worker auth", () => {
  test("no token configured → the worker is not called at all", async () => {
    expect(demuxWorkerRequestConfig()).toBeNull();
    await expect(mediaService.separateWithDemuxWorker("job1", "gs://b/a.mp3")).resolves.toBeNull();
    expect(post).not.toHaveBeenCalled();
  });

  test("token configured → Bearer header, 300 s default timeout, signed GCS link, both stems returned", async () => {
    process.env.DEMUX_WORKER_TOKEN = TOKEN;
    post.mockResolvedValue({ data: { status: "success", mneUrl: "gs://b/audio/job1/m_and_e.mp3", vocalsUrl: "gs://b/audio/job1/vocals.mp3", engine: "demucs_v4_neural", degraded: false } });
    const r = await mediaService.separateWithDemuxWorker("job1", "gs://b/a.mp3");
    expect(r).toEqual({ mneUrl: "gs://b/audio/job1/m_and_e.mp3", vocalsUrl: "gs://b/audio/job1/vocals.mp3", engine: "demucs_v4_neural", degraded: false });
    const [url, body, cfg] = post.mock.calls[0];
    expect(url).toBe("https://worker.example.modal.run/demix");
    expect(body).toEqual({ jobId: "job1", audioUrl: "https://storage.googleapis.com/signed/gs://b/a.mp3" });
    expect(cfg.headers.Authorization).toBe(`Bearer ${TOKEN}`);
    expect(cfg.timeout).toBe(300000);
  });

  test("worker rejects (401) or reports degraded → null, caller falls back", async () => {
    process.env.DEMUX_WORKER_TOKEN = TOKEN;
    post.mockRejectedValueOnce(Object.assign(new Error("Request failed with status code 401"), { response: { status: 401 } }));
    await expect(mediaService.separateWithDemuxWorker("job1", "gs://b/a.mp3")).resolves.toBeNull();
    post.mockResolvedValueOnce({ data: { mneUrl: "gs://b/x.mp3", degraded: true } });
    await expect(mediaService.separateWithDemuxWorker("job1", "gs://b/a.mp3")).resolves.toBeNull();
  });

  test("DEMUX_TIMEOUT_MS overrides the timeout", () => {
    process.env.DEMUX_WORKER_TOKEN = TOKEN;
    process.env.DEMUX_TIMEOUT_MS = "450000";
    expect(demuxWorkerRequestConfig()!.timeout).toBe(450000);
  });
});

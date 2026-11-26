import axios from "axios";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";
import { demuxWorkerRequestConfig } from "../../src/pipeline/services/media";

describe("Background Separation Worker: Live Reachability & Configuration", () => {
  const serviceUrl = PIPELINE_CONFIG.DEMUX_SERVICE_URL;

  it("has a configured non-placeholder DEMUX_SERVICE_URL", () => {
    expect(serviceUrl).toBeTruthy();
    expect(serviceUrl).not.toContain("placeholder");
    expect(serviceUrl).toMatch(/^https:\/\/.+/);
  });

  it("can connect to the live Demux worker /health endpoint and receives 200 OK with A10G Demucs v4", async () => {
    const healthUrl = `${serviceUrl.replace(/\/$/, "")}/health`;
    const res = await axios.get(healthUrl, { timeout: 15000 });

    expect(res.status).toBe(200);
    expect(res.data).toEqual(
      expect.objectContaining({
        status: "healthy",
        service: "truthworld-demux-worker",
        engine: "demucs_v4_neural",
        model: "htdemucs",
        gpu: "A10G",
      })
    );
  });

  it("verifies that unauthorized requests without DEMUX_WORKER_TOKEN are rejected with 401 Unauthorized", async () => {
    const demixUrl = `${serviceUrl.replace(/\/$/, "")}/demix`;
    try {
      await axios.post(
        demixUrl,
        { jobId: "probe_unauthorized", audioUrl: "https://storage.googleapis.com/test.mp3" },
        { headers: { Authorization: "Bearer bad-token-00000000000000000000000000000000" }, timeout: 10000 }
      );
      fail("Expected 401 Unauthorized");
    } catch (err: any) {
      expect(err.response?.status).toBe(401);
    }
  });

  it("verifies that authorized requests validate and protect against arbitrary SSRF URLs with 400 Bad Request", async () => {
    const token = process.env.DEMUX_WORKER_TOKEN || "5frtw54ey4oioiiafgmxip658wlb2n9bzm2lkmabcy4nl47k";
    const demixUrl = `${serviceUrl.replace(/\/$/, "")}/demix`;

    try {
      await axios.post(
        demixUrl,
        { jobId: "probe_ssrf", audioUrl: "https://malicious-external-host.com/evil.mp3" },
        { headers: { Authorization: `Bearer ${token}` }, timeout: 10000 }
      );
      fail("Expected 400 Bad Request");
    } catch (err: any) {
      expect(err.response?.status).toBe(400);
      expect(err.response?.data?.detail).toMatch(/audioUrl must be an authenticated https Google Cloud Storage link/i);
    }
  });
});

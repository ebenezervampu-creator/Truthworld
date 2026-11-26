import axios from "axios";
import {
  TTSService,
  isTransientElevenLabsError,
  retryElevenLabsTransient,
} from "../../src/pipeline/services/tts";

jest.mock("axios");
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe("ElevenLabs clone & probe transient retry", () => {
  const noSleep = async () => {};

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("classifies 429 system_busy, 5xx, 409 already_running, and network errors as transient", () => {
    expect(
      isTransientElevenLabsError({
        response: { status: 429, data: { detail: { status: "system_busy", message: "heavy traffic" } } },
      })
    ).toBe(true);
    expect(isTransientElevenLabsError({ response: { status: 503, data: "unavailable" } })).toBe(true);
    expect(
      isTransientElevenLabsError({
        response: { status: 409, data: Buffer.from(JSON.stringify({ detail: { code: "already_running" } })) },
      })
    ).toBe(true);
    expect(isTransientElevenLabsError({ message: "timeout of 30000ms exceeded" })).toBe(true);
  });

  it("does not classify 401/403/400/404 refusals as transient", () => {
    expect(
      isTransientElevenLabsError({
        response: { status: 401, data: { detail: { status: "detected_captcha_voice" } } },
      })
    ).toBe(false);
    expect(isTransientElevenLabsError({ response: { status: 403, data: "voice_not_allowed" } })).toBe(false);
    expect(isTransientElevenLabsError({ response: { status: 400, data: "bad request" } })).toBe(false);
  });

  it("retries transient 429 system_busy errors and succeeds when a later attempt works", async () => {
    let calls = 0;
    const result = await retryElevenLabsTransient(
      "probeVoice(test)",
      async () => {
        calls++;
        if (calls < 3) {
          const err: any = new Error("Request failed with status code 429");
          err.response = {
            status: 429,
            data: { detail: { status: "system_busy", message: "The system is experiencing heavy traffic" } },
          };
          throw err;
        }
        return "ok";
      },
      { maxRetries: 3, baseMs: 1, sleep: noSleep }
    );
    expect(result).toBe("ok");
    expect(calls).toBe(3);
  });

  it("stops immediately without retrying on non-transient 401 detected_captcha_voice", async () => {
    let calls = 0;
    await expect(
      retryElevenLabsTransient(
        "probeVoice(test)",
        async () => {
          calls++;
          const err: any = new Error("Request failed with status code 401");
          err.response = {
            status: 401,
            data: { detail: { status: "detected_captcha_voice", message: "This voice requires verification" } },
          };
          throw err;
        },
        { maxRetries: 3, baseMs: 1, sleep: noSleep }
      )
    ).rejects.toThrow("401");
    expect(calls).toBe(1);
  });

  it("probeVoice recovers from transient 429 system_busy without failing the clone", async () => {
    const setTimeoutSpy = jest.spyOn(global, "setTimeout").mockImplementation((cb: any) => {
      cb();
      return 0 as any;
    });
    const prevKey = process.env.ELEVENLABS_API_KEY;
    process.env.ELEVENLABS_API_KEY = "test-key";

    try {
      mockedAxios.post
        .mockRejectedValueOnce({
          response: {
            status: 429,
            data: Buffer.from(
              JSON.stringify({
                detail: {
                  status: "system_busy",
                  message: "The system is experiencing heavy traffic, please try again.",
                },
              })
            ),
          },
        })
        .mockResolvedValueOnce({ data: Buffer.from("mp3-bytes") } as any);

      const tts = new TTSService();
      const res = await tts.probeVoice("UYYXs1916fgrjhNTQs1P", "Hello.");
      expect(res).toEqual({ ok: true });
      expect(mockedAxios.post).toHaveBeenCalledTimes(2);
    } finally {
      setTimeoutSpy.mockRestore();
      if (prevKey === undefined) delete process.env.ELEVENLABS_API_KEY;
      else process.env.ELEVENLABS_API_KEY = prevKey;
    }
  });
});

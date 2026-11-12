/**
 * 🧪 ZERO-CREDIT ELEVENLABS PRODUCTION VERIFICATION TEST
 *
 * Verifies that:
 * 1. ElevenLabsTTSService has verifyConnection() wired to /v1/user/subscription
 * 2. It requires an API key and sends the xi-api-key header
 * 3. It never calls the synthesize or billing endpoints
 * 4. It properly normalizes plan tier and character usage metrics
 */

import { ElevenLabsTTSService, TTSService } from "../../src/pipeline/services/tts";
import axios from "axios";

// Mock axios for unit contract testing
jest.mock("axios");
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe("ElevenLabs Zero-Credit Verification Suite", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("throws error when no API key is provided", async () => {
    const service = new ElevenLabsTTSService("");
    // Ensure getApiKey returns empty string
    jest.spyOn(service, "getApiKey").mockReturnValue("");

    await expect(service.verifyConnection()).rejects.toThrow(
      "No ElevenLabs API key configured in environment"
    );
  });

  test("calls /v1/user/subscription with xi-api-key and zero character cost", async () => {
    const testApiKey = "sk_test_fake_elevenlabs_key_12345";
    const service = new ElevenLabsTTSService(testApiKey);

    mockedAxios.get.mockResolvedValueOnce({
      data: {
        tier: "creator",
        status: "active",
        character_count: 14200,
        character_limit: 100000,
        can_use_instant_voice_cloning: true,
      },
    });

    const result = await service.verifyConnection();

    expect(mockedAxios.get).toHaveBeenCalledTimes(1);
    expect(mockedAxios.get).toHaveBeenCalledWith(
      "https://api.elevenlabs.io/v1/user/subscription",
      expect.objectContaining({
        headers: { "xi-api-key": testApiKey },
      })
    );

    // Verify parsed payload
    expect(result.valid).toBe(true);
    expect(result.tier).toBe("creator");
    expect(result.status).toBe("active");
    expect(result.characterCount).toBe(14200);
    expect(result.characterLimit).toBe(100000);
    expect(result.canUseInstantVoiceCloning).toBe(true);
  });

  test("TTSService wraps ElevenLabs verifyConnection correctly", async () => {
    const mockElevenService = {
      verifyConnection: jest.fn().mockResolvedValue({
        valid: true,
        tier: "pro",
        characterCount: 500,
        characterLimit: 500000,
        canUseInstantVoiceCloning: true,
        status: "active",
      }),
    } as any;

    const tts = new TTSService(undefined, mockElevenService);
    const result = await tts.verifyElevenLabsConnection();

    expect(mockElevenService.verifyConnection).toHaveBeenCalledTimes(1);
    expect(result.valid).toBe(true);
    expect(result.tier).toBe("pro");
  });
});

import { googleTextToSpeechService, RECOMMENDED_VOICES, EXTENDED_VOICE_CATALOG } from "../services/googleTextToSpeechService";
import { TTSRequest } from "../types";

describe("Audio Starter Male Voice and Background Music Preservation", () => {
  test("1. Chirp 3: HD Male voice mapping must be Fenrir (never Achernar)", () => {
    // 1. Verify Telugu (te-IN)
    const teVoices = RECOMMENDED_VOICES["te-IN"];
    expect(teVoices).toBeDefined();
    expect(teVoices.MALE.voiceName).toContain("Fenrir");
    expect(teVoices.MALE.voiceName).not.toContain("Achernar");
    expect(teVoices.FEMALE.voiceName).toContain("Kore");

    // 2. Verify all locales in RECOMMENDED_VOICES map MALE to Fenrir or male personas
    for (const [, voices] of Object.entries(RECOMMENDED_VOICES)) {
      expect(voices.MALE.voiceName).not.toContain("Achernar");
      if (voices.MALE.voiceName.includes("Chirp3-HD")) {
        expect(voices.MALE.voiceName).toContain("Fenrir");
      }
    }

    // 3. Verify EXTENDED_VOICE_CATALOG does not list Achernar as MALE
    for (const [, catalog] of Object.entries(EXTENDED_VOICE_CATALOG)) {
      if (catalog.MALE) {
        for (const voice of catalog.MALE) {
          expect(voice).not.toContain("Achernar");
        }
      }
      if (catalog.FEMALE) {
        // Achernar should be categorized as FEMALE if present
        const hasAchernar = catalog.FEMALE.some((v) => v.includes("Achernar"));
        if (catalog.FEMALE.some((v) => v.includes("Chirp3-HD-Achernar"))) {
          expect(hasAchernar).toBe(true);
        }
      }
    }
  });

  test("2. resolveVoice with MALE gender always yields male voice", () => {
    // When requesting male voice for Telugu
    const teReq: TTSRequest = {
      jobId: "test_job_te",
      text: "యేసు పాటలు",
      language: "te",
      gender: "MALE",
    };
    const resolvedTeMale = (googleTextToSpeechService as any).resolveVoice(teReq);
    expect(resolvedTeMale.voiceName).toBe("te-IN-Chirp3-HD-Fenrir");
    expect(resolvedTeMale.voiceName).not.toContain("Achernar");

    // When requesting male voice for English
    const enReq: TTSRequest = {
      jobId: "test_job_en",
      text: "Jesus songs",
      language: "en",
      gender: "MALE",
    };
    const resolvedEnMale = (googleTextToSpeechService as any).resolveVoice(enReq);
    expect(resolvedEnMale.voiceName).toBe("en-US-Chirp3-HD-Fenrir");

    // When requesting male voice for Hindi
    const hiReq: TTSRequest = {
      jobId: "test_job_hi",
      text: "यीशु के गीत",
      language: "hi",
      gender: "MALE",
    };
    const resolvedHiMale = (googleTextToSpeechService as any).resolveVoice(hiReq);
    expect(resolvedHiMale.voiceName).toBe("hi-IN-Chirp3-HD-Fenrir");

    // If an invalid/female voice was accidentally passed with gender='MALE', it must be replaced with Fenrir
    const correctedReq: TTSRequest = {
      jobId: "test_job_corr",
      text: "Test text",
      language: "te-IN",
      gender: "MALE",
      voiceId: "te-IN-Chirp3-HD-Achernar",
    };
    const correctedVoice = (googleTextToSpeechService as any).resolveVoice(correctedReq);
    expect(correctedVoice.voiceName).toBe("te-IN-Chirp3-HD-Fenrir");
  });

  test("3. resolveVoice with FEMALE gender yields female voice", () => {
    const teFemaleReq: TTSRequest = {
      jobId: "test_job_female",
      text: "హలో",
      language: "te",
      gender: "FEMALE",
    };
    const resolvedTeFemale = (googleTextToSpeechService as any).resolveVoice(teFemaleReq);
    expect(resolvedTeFemale.voiceName).toBe("te-IN-Chirp3-HD-Kore");

    const enFemaleReq: TTSRequest = {
      jobId: "test_job_en_f",
      text: "Hello",
      language: "en",
      gender: "FEMALE",
    };
    const resolvedEnFemale = (googleTextToSpeechService as any).resolveVoice(enFemaleReq);
    expect(resolvedEnFemale.voiceName).toBe("en-US-Chirp3-HD-Kore");
  });
});

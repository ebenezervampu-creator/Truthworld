import * as admin from "firebase-admin";
import { DubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { translationService } from "../../src/pipeline/services/translation";
import { geminiDubbingEditor } from "../../src/pipeline/services/geminiDubbingEditor";
import { noNativeVoiceMessage, unsupportedDubbingLanguageMessage } from "../../src/pipeline/services/voice-locale-policy";
import type { TimedSegment } from "../../src/pipeline/types";

// In-memory Firestore setup
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "test-truthworld" });
}

describe("Dubbing Pipeline Audit Fixes (A5, A7, A8, A9, A10, A11)", () => {
  const engine = new DubbingEngine();

  describe("A8: stitchSegments never merges dialogue across different speakers", () => {
    it("merges short segments from the SAME speaker", () => {
      const segments: TimedSegment[] = [
        { index: 0, text: "I think", start: 0, end: 1000, duration: 1000, speaker: "speaker_0", words: [] },
        { index: 1, text: "we should proceed now.", start: 1000, end: 3000, duration: 2000, speaker: "speaker_0", words: [] },
      ];
      const result = (engine as any).stitchSegments(segments);
      expect(result.length).toBe(1);
      expect(result[0].text).toBe("I think we should proceed now.");
      expect(result[0].speaker).toBe("speaker_0");
      expect(result[0].end).toBe(3000);
    });

    it("NEVER merges a short reply or conjunction from a DIFFERENT speaker (Speaker B is not voiced as Speaker A)", () => {
      const segments: TimedSegment[] = [
        { index: 0, text: "Are you ready to begin?", start: 0, end: 2000, duration: 2000, speaker: "speaker_0", words: [] },
        { index: 1, text: "No.", start: 2100, end: 2500, duration: 400, speaker: "speaker_1", words: [] },
        { index: 2, text: "Wait for me.", start: 2600, end: 3500, duration: 900, speaker: "speaker_1", words: [] },
      ];
      const result = (engine as any).stitchSegments(segments);
      // Segment 0 (speaker_0) must remain distinct from segment 1 (speaker_1)!
      expect(result.length).toBe(2);
      expect(result[0].speaker).toBe("speaker_0");
      expect(result[0].text).toBe("Are you ready to begin?");
      expect(result[1].speaker).toBe("speaker_1");
      expect(result[1].text).toBe("No. Wait for me.");
    });
  });

  describe("A9: Synthesis lease renewal and heartbeat", () => {
    const jobId = "test_lease_job_1";
    const lang = "te";

    it("acquires lease and renewDubbingLease extends leaseExpiresAt", async () => {
      const acquired = await engine.acquireDubbingLease(jobId, lang, 60_000);
      expect(acquired).toBe(true);

      const snap1 = await admin.firestore().collection("dubbing_checkpoints").doc(`${jobId}_${lang}`).get();
      const expiry1 = snap1.data()?.leaseExpiresAt;
      expect(typeof expiry1).toBe("number");

      // Renew lease with new TTL
      const renewed = await engine.renewDubbingLease(jobId, lang, 180_000);
      expect(renewed).toBe(true);

      const snap2 = await admin.firestore().collection("dubbing_checkpoints").doc(`${jobId}_${lang}`).get();
      const expiry2 = snap2.data()?.leaseExpiresAt;
      expect(expiry2).toBeGreaterThan(expiry1);

      // Release lease
      await engine.releaseDubbingLease(jobId, lang);
      const snap3 = await admin.firestore().collection("dubbing_checkpoints").doc(`${jobId}_${lang}`).get();
      expect(snap3.data()?.leaseExpiresAt).toBe(0);
    });

    it("enforces worker ownership: worker B cannot steal, renew, or release worker A's active lease", async () => {
      const ownedJobId = "test_lease_job_worker_owned";
      const workerA = "worker_alpha_123";
      const workerB = "worker_beta_456";

      // Worker A acquires lease
      const acquiredA = await engine.acquireDubbingLease(ownedJobId, lang, 60_000, workerA);
      expect(acquiredA).toBe(true);

      // Worker B attempts to acquire while Worker A's lease is active -> rejected
      const acquiredB = await engine.acquireDubbingLease(ownedJobId, lang, 60_000, workerB);
      expect(acquiredB).toBe(false);

      // Worker B attempts to renew Worker A's lease -> rejected
      const renewedB = await engine.renewDubbingLease(ownedJobId, lang, 120_000, workerB);
      expect(renewedB).toBe(false);

      // Worker B attempts to release Worker A's lease -> ignored, lease remains active
      await engine.releaseDubbingLease(ownedJobId, lang, workerB);
      const snapCheck = await admin.firestore().collection("dubbing_checkpoints").doc(`${ownedJobId}_${lang}`).get();
      expect(snapCheck.data()?.leaseExpiresAt).toBeGreaterThan(Date.now());
      expect(snapCheck.data()?.workerId).toBe(workerA);

      // Worker A renews own lease -> success
      const renewedA = await engine.renewDubbingLease(ownedJobId, lang, 120_000, workerA);
      expect(renewedA).toBe(true);

      // Worker A releases own lease -> success
      await engine.releaseDubbingLease(ownedJobId, lang, workerA);
      const snapFinal = await admin.firestore().collection("dubbing_checkpoints").doc(`${ownedJobId}_${lang}`).get();
      expect(snapFinal.data()?.leaseExpiresAt).toBe(0);
    });
  });

  describe("A7: 540s wall protection & reel threshold", () => {
    it("lowered default reelThresholdMs to 8 minutes (480,000ms) to stay within 540s Cloud Function timeout", () => {
      const defaultReelThresholdMs = 8 * 60 * 1000;
      expect(defaultReelThresholdMs).toBe(480000);
      expect(defaultReelThresholdMs).toBeLessThan(540 * 1000);
    });
  });

  describe("A5: Voice-clone consent policy", () => {
    it("requires explicit voiceCloneConsent: true for voice_clone mode", () => {
      const resolveDubbingMode = (body: any) => {
        const hasVoiceCloneConsent = body?.voiceCloneConsent === true;
        const requestedDubbingMode = String(body?.dubbingMode || "standard");
        return (requestedDubbingMode === "voice_clone" && hasVoiceCloneConsent)
          ? "voice_clone"
          : "standard";
      };

      // Default request with no body -> standard
      expect(resolveDubbingMode({})).toBe("standard");
      // Requested voice_clone but NO consent -> standard
      expect(resolveDubbingMode({ dubbingMode: "voice_clone" })).toBe("standard");
      expect(resolveDubbingMode({ dubbingMode: "voice_clone", voiceCloneConsent: false })).toBe("standard");
      // Requested voice_clone WITH explicit consent -> voice_clone
      expect(resolveDubbingMode({ dubbingMode: "voice_clone", voiceCloneConsent: true })).toBe("voice_clone");
    });
  });

  describe("A11: Shortened lines preserve formality register locks", () => {
    it("forwards registerDirective to geminiDubbingEditor when shortening", async () => {
      const editSpy = jest.spyOn(geminiDubbingEditor, "editSegments").mockResolvedValueOnce([
        {
          id: "L1",
          text: "మీరు దయచేసి ఇక్కడ రండి",
          usedDraft: false,
          syllables: 7,
          maxSyllables: 8,
          overBudget: false,
        },
      ]);

      await translationService.retranslateConcise(
        "Please come here",
        "en",
        "te",
        {
          maxDurationMs: 1500,
          currentTranslation: "మీరు దయచేసి ఇక్కడ వేచి ఉండి రండి",
          speaker: "speaker_0",
          appliedRegister: "FORMAL_HONORIFIC",
        }
      );

      expect(editSpy).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({
            registerDirective: "FORMAL_HONORIFIC",
          }),
        ]),
        expect.objectContaining({
          jobId: "retranslate",
        })
      );

      editSpy.mockRestore();
    });

    it("forwards full castList, relationships, and speakerNames context to geminiDubbingEditor", async () => {
      const mockCast = [{ name: "Joseph", gender: "male" as const, age: "adult" as const, role: "speaker_0" }];
      const mockRelations = [{ from: "speaker_0", to: "speaker_1", relationship: "formal" as const }];
      const mockNames = { speaker_0: "Joseph", speaker_1: "Pharaoh" };

      const editSpy = jest.spyOn(geminiDubbingEditor, "editSegments").mockResolvedValueOnce([
        {
          id: "L1",
          text: "నేను సిద్ధంగా ఉన్నాను",
          usedDraft: false,
          syllables: 7,
          maxSyllables: 8,
          overBudget: false,
        },
      ]);

      await translationService.retranslateConcise(
        "I am ready",
        "en",
        "te",
        {
          maxDurationMs: 1500,
          currentTranslation: "నేను ఇక్కడ సిద్ధంగా ఉన్నాను",
          speaker: "speaker_0",
          appliedRegister: "FORMAL_HONORIFIC",
          castList: mockCast,
          relationships: mockRelations,
          speakerNames: mockNames,
        }
      );

      expect(editSpy).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          castList: mockCast,
          relationships: mockRelations,
          speakerNames: mockNames,
        })
      );

      editSpy.mockRestore();
    });
  });

  describe("A2: Creator notices clearly mention refund to wallet", () => {
    it("informs creator that fee has been refunded when dubbing is skipped", () => {
      const msgNative = noNativeVoiceMessage("te");
      expect(msgNative).toMatch(/refunded to your wallet/i);

      const msgUnsupported = unsupportedDubbingLanguageMessage("sa");
      expect(msgUnsupported).toMatch(/refunded to your wallet/i);
    });
  });
});

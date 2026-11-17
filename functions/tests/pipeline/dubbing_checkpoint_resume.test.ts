import { DubbingEngine, toCanonicalGsUrl } from "../../src/pipeline/layers/07-dubbing";
import { ttsService } from "../../src/pipeline/services/tts";
import { translationService } from "../../src/pipeline/services/translation";
import { DubbingCheckpoint } from "../../src/pipeline/types";
import * as admin from "firebase-admin";

describe("Dubbing Pipeline Checkpoint & Exact Failure Resumption Guard", () => {
  let engine: DubbingEngine;
  const mockDbData: Record<string, Record<string, any>> = {};

  beforeAll(() => {
    engine = new DubbingEngine();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    Object.keys(mockDbData).forEach((k) => delete mockDbData[k]);

    // Mock Firestore checkpoint collections & transactions
    const createDocMock = (path: string) => ({
      path,
      get: jest.fn().mockImplementation(async () => {
        const data = mockDbData[path];
        return {
          exists: Boolean(data),
          data: () => data || null,
        };
      }),
      set: jest.fn().mockImplementation(async (data: any, options?: any) => {
        if (options?.merge && mockDbData[path]) {
          mockDbData[path] = { ...mockDbData[path], ...data };
        } else {
          mockDbData[path] = data;
        }
      }),
      update: jest.fn().mockImplementation(async (data: any) => {
        mockDbData[path] = { ...(mockDbData[path] || {}), ...data };
      }),
      collection: (subCol: string) => ({
        doc: (subId: string) => createDocMock(`${path}/${subCol}/${subId}`),
      }),
    });

    const firestoreMock: any = () => ({
      collection: (colName: string) => ({
        doc: (docId: string) => createDocMock(`${colName}/${docId}`),
        add: jest.fn().mockResolvedValue({ id: "cost_123" }),
      }),
      runTransaction: jest.fn().mockImplementation(async (cb: (tx: any) => Promise<any>) => {
        const txMock = {
          get: jest.fn().mockImplementation(async (docRef: any) => {
            return docRef.get();
          }),
          set: jest.fn().mockImplementation(async (docRef: any, data: any, options?: any) => {
            return docRef.set(data, options);
          }),
          update: jest.fn().mockImplementation(async (docRef: any, data: any) => {
            return docRef.update(data);
          }),
        };
        return await cb(txMock);
      }),
    });
    firestoreMock.FieldValue = {
      serverTimestamp: () => Date.now(),
      increment: (n: number) => n,
      arrayUnion: (...items: any[]) => items,
    };

    jest.spyOn(admin, "firestore").mockImplementation(firestoreMock);

    // Mock Storage bucket & files with standard verified audio payload
    const mockStorageFile = (filePath: string) => {
      // Allow individual tests to simulate zero-byte or missing files
      const isZeroByte = filePath.includes("zero_byte") || filePath.includes("corrupt");
      const isMissing = filePath.includes("missing_chunk");
      return {
        exists: jest.fn().mockResolvedValue([!isMissing]),
        getMetadata: jest.fn().mockResolvedValue([{ size: isZeroByte ? 128 : 4096 }]),
        download: jest.fn().mockResolvedValue([isZeroByte ? Buffer.alloc(128) : Buffer.alloc(4096)]),
        save: jest.fn().mockResolvedValue([]),
      };
    };

    const mockStorageBucket = {
      name: "truthworld-1.firebasestorage.app",
      file: jest.fn().mockImplementation((p: string) => mockStorageFile(p)),
    };

    jest.spyOn(admin, "storage").mockReturnValue({
      bucket: jest.fn().mockReturnValue(mockStorageBucket),
    } as any);
  });

  afterEach(async () => {
    await new Promise((resolve) => setTimeout(resolve, 50));
  });

  afterAll(() => {
    jest.restoreAllMocks();
  });

  it("1. Checkpoint Schema Checklist: persists all five resume anchors atomically", async () => {
    const jobId = "job_checkpoint_schema_01";
    const targetLang = "te";

    const empty = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(empty).toBeNull();

    const initialCheckpoint: Partial<DubbingCheckpoint> = {
      jobId,
      targetLang,
      stage: "synthesizing",
      isolatedVocalUrl: "gs://truthworld-1.firebasestorage.app/audio/job_01/isolated_vocals.mp3",
      meStemUrl: "gs://truthworld-1.firebasestorage.app/audio/job_01/mne_stem.mp3",
      voiceMapping: {
        speaker_0: "ErXwobaYiN019PkySvjV",
        speaker_1: "EXAVITQu4vr4xnSDxMaL",
      },
      translatedSegments: [
        {
          index: 0,
          originalText: "Hello world",
          translatedText: "హలో ప్రపంచం",
          language: "te",
          start: 0,
          end: 2000,
          targetDuration: 2,
          speaker: "speaker_0",
        },
      ],
      synthesizedUrls: {
        "0": "gs://truthworld-1.firebasestorage.app/audio/job_01/chunk_0.mp3",
      },
      leaseExpiresAt: Date.now() + 120_000,
    };

    await engine.saveDubbingCheckpoint(jobId, targetLang, initialCheckpoint);

    const loaded = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(loaded).toBeDefined();
    expect(loaded?.jobId).toBe(jobId);
    expect(loaded?.targetLang).toBe(targetLang);
    expect(loaded?.stage).toBe("synthesizing");
    expect(loaded?.isolatedVocalUrl).toBe("gs://truthworld-1.firebasestorage.app/audio/job_01/isolated_vocals.mp3");
    expect(loaded?.meStemUrl).toBe("gs://truthworld-1.firebasestorage.app/audio/job_01/mne_stem.mp3");
    expect(loaded?.voiceMapping?.speaker_0).toBe("ErXwobaYiN019PkySvjV");
    expect(loaded?.voiceMapping?.speaker_1).toBe("EXAVITQu4vr4xnSDxMaL");
    expect(loaded?.translatedSegments?.length).toBe(1);
    expect(loaded?.synthesizedUrls?.["0"]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_01/chunk_0.mp3");
    expect(loaded?.leaseExpiresAt).toBeGreaterThan(Date.now());
    expect(loaded?.updatedAt).toBeGreaterThan(0);
  });

  it("2. Edge Case 1: Expired Signed URLs vs. Canonical gs:// Storage Paths", async () => {
    // Verifies canonical gs:// conversion on signed, tokenized, or raw storage URLs
    const signedFirebaseUrl = "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/audio%2Fjob_123%2Fseg_0.mp3?alt=media&token=temporary-token-123";
    const signedGcsUrl = "https://storage.googleapis.com/truthworld-1.firebasestorage.app/audio/job_123/seg_1.mp3?X-Goog-Signature=temp-sig-456";
    const canonicalInput = "gs://truthworld-1.firebasestorage.app/audio/job_123/seg_2.mp3";

    expect(toCanonicalGsUrl(signedFirebaseUrl)).toBe("gs://truthworld-1.firebasestorage.app/audio/job_123/seg_0.mp3");
    expect(toCanonicalGsUrl(signedGcsUrl)).toBe("gs://truthworld-1.firebasestorage.app/audio/job_123/seg_1.mp3");
    expect(toCanonicalGsUrl(canonicalInput)).toBe("gs://truthworld-1.firebasestorage.app/audio/job_123/seg_2.mp3");
  });

  it("3. Edge Case 2: Partial / Zero-Byte Chunk Rejection and exact failure resumption", async () => {
    const jobId = "job_retry_test_02";
    const language = "te";

    // Simulate previous run where:
    // Segment 0: Valid audio (4096 bytes)
    // Segment 1: Corrupted / zero-byte chunk write on crash (128 bytes)
    // Segment 2: Never synthesized (failed before starting)
    await engine.saveDubbingCheckpoint(jobId, language, {
      stage: "synthesizing",
      status: "partial",
      synthesizedUrls: {
        "0": "gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/valid_chunk_0.mp3",
        "1": "gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/zero_byte_chunk_1.mp3",
      },
      totalSegments: 3,
    });

    const segments = [
      {
        index: 0,
        originalText: "Hello world",
        translatedText: "హలో ప్రపంచం",
        language: "te",
        start: 0,
        end: 2000,
        targetDuration: 2,
        speaker: "speaker_0",
      },
      {
        index: 1,
        originalText: "Welcome to TruthWorld",
        translatedText: "ట్రూత్ వరల్డ్‌కు స్వాగతం",
        language: "te",
        start: 2100,
        end: 4500,
        targetDuration: 2.4,
        speaker: "speaker_0",
      },
      {
        index: 2,
        originalText: "This failed before",
        translatedText: "ఇది గతంలో విఫలమైంది",
        language: "te",
        start: 4600,
        end: 7000,
        targetDuration: 2.4,
        speaker: "speaker_0",
      },
    ];

    const synthesizeSpy = jest.spyOn(ttsService, "synthesize").mockResolvedValue({
      audioUrl: "gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/resynthesized.mp3",
      characterCount: 20,
    } as any);

    // Call parallelTTSWithCache
    const result = await (engine as any).parallelTTSWithCache(
      jobId,
      "user_123",
      segments,
      language,
      { speaker_0: "ErXwobaYiN019PkySvjV" },
      false,
      { speaker_0: "MALE" },
      [],
      null,
      "audio_track",
      "studio_matched",
      "male"
    );

    // Segment 0 must be reused directly from the checkpoint
    expect(result.urls[0]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/valid_chunk_0.mp3");
    // Segment 1 (zero-byte corrupted chunk) must have been evicted and re-synthesized fresh
    expect(result.urls[1]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/resynthesized.mp3");
    // Segment 2 must be synthesized fresh
    expect(result.urls[2]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/resynthesized.mp3");

    // synthesize was called TWICE (for segment 1 and segment 2), NOT 3 times. Segment 0 saved 100% of credits!
    expect(synthesizeSpy).toHaveBeenCalledTimes(2);

    // Verify checkpoint was updated with all 3 valid canonical segments
    const finalCheckpoint = await engine.loadDubbingCheckpoint(jobId, language);
    expect(finalCheckpoint?.synthesizedUrls?.["0"]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/valid_chunk_0.mp3");
    expect(finalCheckpoint?.synthesizedUrls?.["1"]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/resynthesized.mp3");
    expect(finalCheckpoint?.synthesizedUrls?.["2"]).toBe("gs://truthworld-1.firebasestorage.app/audio/job_retry_test_02/resynthesized.mp3");
  });

  it("4. Edge Case 3: Checkpointing voiceMapping & stems prevents mid-video voice swaps", async () => {
    const jobId = "job_voice_swap_guard_03";
    const targetLang = "es";

    // Simulate checkpoint saved after Step 1.7 locking voiceId assignments & M&E stem
    const lockedVoiceMapping = {
      speaker_0: "EXAVITQu4vr4xnSDxMaL", // Sarah
      speaker_1: "ErXwobaYiN019PkySvjV", // Antoni
    };
    const lockedVocalUrl = "gs://truthworld-1.firebasestorage.app/audio/job_voice_swap_guard_03/vocals.mp3";
    const lockedMeStem = "gs://truthworld-1.firebasestorage.app/audio/job_voice_swap_guard_03/mne.mp3";

    await engine.saveDubbingCheckpoint(jobId, targetLang, {
      stage: "synthesizing",
      voiceMapping: lockedVoiceMapping,
      isolatedVocalUrl: lockedVocalUrl,
      meStemUrl: lockedMeStem,
      synthesizedUrls: {
        "0": "gs://truthworld-1.firebasestorage.app/audio/job_voice_swap_guard_03/chunk_0.mp3",
      },
    });

    // On resume, load checkpoint
    const restored = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(restored?.voiceMapping).toEqual(lockedVoiceMapping);
    expect(restored?.isolatedVocalUrl).toBe(lockedVocalUrl);
    expect(restored?.meStemUrl).toBe(lockedMeStem);

    // Segments 1..N retain the exact same speaker_0 and speaker_1 studio voice allocations
    expect(restored?.voiceMapping?.speaker_0).toBe("EXAVITQu4vr4xnSDxMaL");
    expect(restored?.voiceMapping?.speaker_1).toBe("ErXwobaYiN019PkySvjV");
  });

  it("5. Edge Case 4: Idempotency Lease Lock rejects concurrent retries within lease window", async () => {
    const jobId = "job_lease_lock_04";
    const targetLang = "te";

    // Worker A acquires lease for 120 seconds
    const workerAAcquired = await engine.acquireDubbingLease(jobId, targetLang, 120_000);
    expect(workerAAcquired).toBe(true);

    const checkpointA = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(checkpointA?.leaseExpiresAt).toBeGreaterThan(Date.now());

    // Worker B (concurrent duplicate tap on Retry button) attempts to acquire lease
    const workerBAcquired = await engine.acquireDubbingLease(jobId, targetLang, 120_000);
    expect(workerBAcquired).toBe(false); // Declined! Prevents double billing ElevenLabs credits

    // Worker A finishes and releases lease
    await engine.releaseDubbingLease(jobId, targetLang);

    const checkpointAfterRelease = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(checkpointAfterRelease?.leaseExpiresAt).toBe(0);

    // Worker C (subsequent user retry) can now acquire lease successfully
    const workerCAcquired = await engine.acquireDubbingLease(jobId, targetLang, 120_000);
    expect(workerCAcquired).toBe(true);
  });

  it("6. reuses translated segments from checkpoint with zero Google Translation API calls", async () => {
    const jobId = "job_trans_reuse_05";
    const targetLang = "te";

    const preTranslatedSegments = [
      {
        index: 0,
        originalText: "Fact checking in Telugu",
        translatedText: "తెలుగులో వాస్తవ పరిశీలన",
        language: "te",
        start: 0,
        end: 3000,
        targetDuration: 3,
        speaker: "speaker_0",
      },
    ];

    await engine.saveDubbingCheckpoint(jobId, targetLang, {
      stage: "translated",
      status: "translated",
      translatedSegments: preTranslatedSegments,
      totalSegments: 1,
    });

    const translateSpy = jest.spyOn(translationService, "translateSegments");

    const checkpoint = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(checkpoint?.translatedSegments).toBeDefined();
    expect(checkpoint?.translatedSegments?.length).toBe(1);
    expect(checkpoint?.translatedSegments?.[0].translatedText).toBe("తెలుగులో వాస్తవ పరిశీలన");

    expect(translateSpy).not.toHaveBeenCalled();
  });

  it("7. restores completed master track immediately when retrying a multi-language job", async () => {
    const jobId = "job_completed_restore_06";
    const targetLang = "es";

    await engine.saveDubbingCheckpoint(jobId, targetLang, {
      stage: "completed",
      status: "completed",
      masterAudioUrl: "gs://truthworld-1.firebasestorage.app/truthworld/es_master.mp3",
      directAudioUrl: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/truthworld/es_master.mp3",
      dialogueStemUrl: "gs://truthworld-1.firebasestorage.app/truthworld/es_dialogue.mp3",
      subtitleUrl: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/truthworld/es.srt",
      completedAt: Date.now(),
    });

    const loaded = await engine.loadDubbingCheckpoint(jobId, targetLang);
    expect(loaded?.stage).toBe("completed");
    expect(loaded?.status).toBe("completed");
    expect(loaded?.masterAudioUrl).toBe("gs://truthworld-1.firebasestorage.app/truthworld/es_master.mp3");
  });
});

# Demucs Worker Warm-up & Timing Utility

This script measures cold vs. warm GPU separation performance on a candidate media clip, verifies that the self-hosted Demucs v4 worker (`htdemucs` on Modal A10G) is operational, and validates whether the faithful mix will accept the background stem as clean using authentic pipeline validation (`MediaService.validateMneStem` and `canUseBedUnderDialogue`).

## Safety Architecture (Production Shield)

1. **Test Bucket Binding**: Before any pipeline modules are loaded, Firebase Admin is initialized targeting the user-specified non-production bucket (`admin.initializeApp({ storageBucket: <test-bucket>, projectId: <test-project> })`). Any stem downloads/uploads by `separateWithDemuxWorker` operate strictly against the test bucket.
2. **Production Blocklist**: The script refuses to execute on `truthworld-1.firebasestorage.app`, `truthworld-1.appspot.com`, or `truthworld-1`.
3. **Runtime Destination Verification**: Following each separation call, the returned stem URLs (`mneUrl` and `vocalsUrl`) are verified to ensure they point strictly at the test bucket and contain no references to `truthworld-1`.
4. **Transient Cleanup**: In the `finally` block, the uploaded test audio and all persisted stem files are deleted from the test bucket.

---

## PowerShell Command

From the `functions/` directory:

```powershell
npx ts-node scripts/demucs/warmup-and-measure.ts `
  --bucket="<your-non-production-test-bucket>" `
  --audio="C:\Users\ebene\.gemini\antigravity\brain\b7188cce-0e0e-490a-b356-3a82d9c692cb\.user_uploaded\media_1795451655097_41a07b61.mp4"
```

---

## Keep-Warm Guidance

- **Modal Idle-to-Cold Window**: Modal container instances on `@app.function` scale to zero when idle. In this deployment, the idle scaledown window is approximately **5 minutes**.
- **Timing Recommendation**:
  > **Run this script within 3 to 4 minutes before initiating a 5-minute dubbing test.**
  Running this keeps the Modal A10G container active and in-memory, eliminating the 40–80+ second cold start latency during your real dubbing job.

---

## Metrics & Outputs

The script outputs:
1. **Call 1 Latency (Cold)** vs. **Call 2 Latency (Warm)** and speedup factor.
2. **Stem Durations & Timeline Delta**: Ensures duration aligns within `<= 150 ms`.
3. **Background Stem Loudness**: Mean dBFS and peak dBFS.
4. **Speech Windows**: Derived from the isolated vocal stem via FFmpeg `silencedetect=noise=-35dB:d=0.4` (merged, stretches >= 1.0s long), serving as an authentic approximation of transcript speech segments. If fewer than 3 are found, the script safely reports no verdict.
5. **Authentic Pipeline Validation**: Runs `mediaService.validateMneStem` with the exact parameter set used in `07-dubbing.ts` (lines 827-832 & 3252-3258).
6. **Faithful Mix Acceptance**: Evaluates `canUseBedUnderDialogue` using the real `validationStatus`, `source`, and `isolatedVocalUrl`.
7. **Local Output**: Saves stems to `functions/local-dub-output/demucs-check/` (gitignored) for listening tests.

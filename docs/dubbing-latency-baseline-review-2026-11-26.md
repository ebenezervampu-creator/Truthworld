# Review: Phase 0 latency baseline (2026-11-26)

> Repo copy of the Truthworld project doc `claude/dubbing-latency-baseline-review-2026-11-26.md`. The project doc is the master copy.

Reviewer: Claude.
- **Task brief:** `docs/dubbing-low-latency-task-2026-11-26.md`, the repo copy of the project doc.
- **Developer report:** `docs/dubbing-latency-baseline-2026-11-26.md`.

---

## Third review (17:30 IST): corrections A–E checked, ready for the D4 re-runs

The reviewer read the changed files on the PC. The tests were **not** re-run by the reviewer, because this session has no shell on the PC; the counts below are developer-reported.

### Accepted
- **A, backup:** `scripts/dubbing/local-dub-test.ts` ~477–488 uploads `report.json` and `run-log.txt` to `gs://<bucket>/dub-runs/<runId>/` after the report is written. A failed upload only logs a warning.
  - Gap: a crash that reaches `main().catch` exits without a backup. Acceptable for now.
- **B, C, E:** the developer reports these done in the baseline doc: the floor wording, the moderation-timeout proposal dropped, and D1–D5 marked "recommended, awaiting owner".
- **D, model-lock test:** `tests/pipeline/dubbing_model_lock.test.ts` now locks:
  - TTS to `eleven_v4`, with Turbo and Flash strings banned;
  - transcription to `assemblyai-stt-3-7`;
  - the translation draft to Google v3 `general/translation-llm`;
  - the editor: the only Gemini literal allowed is `gemini-3.8-flash`, and every `generate()` call uses it;
  - moderation: primary `gemini-3.8-flash`, fallback `gemini-3.5-flash-lite`;
  - Demucs: the exact `/demix` request body, and `htdemucs` with `--two-stems vocals` and no `--shifts`, `--overlap` or `--segment` in `scripts/modal_demux_worker.py`.
  - The test is in `test:dubbing`.
  - Developer-reported results: lock test 7/7; `test:dubbing` 55 suites, 744 passed, 7 skipped, 0 failed; `test:translation` 52 passed, 3 skipped; build 215 endpoints.
- **Per-call translation timings:** `emitDubbingTiming` (`utils/dubbing-timing.ts`) only logs and returns the elapsed time. The new spans in `geminiDubbingEditor.ts` and `translation.ts` wrap existing calls without changing their arguments or results. **No behaviour change found.**

### Two small gaps (fix before the re-run; no spend needed)
1. **Failed attempts aren't timed.** The editor and back-translation spans are only emitted after the call succeeds (e.g. `geminiDubbingEditor.ts` ~1486). An attempt that throws or times out leaves no span, and those are exactly the slow cases behind the translation p95. Emit the span in a `finally` (or in the `catch` too), with `ok: false`.
2. **The model lock can be bypassed by environment variables.**
   - The Demucs worker reads `DEMUCS_MODEL` from its environment (default `htdemucs`), and the screen analyzer reads `SUBTITLE_SCREEN_MODEL`. The test can't see deployed settings.
   - Before the re-run, confirm neither variable is set on the Modal worker or in `functions/.env*`, and record that in the baseline doc.

### Next
After the two gaps are fixed and the owner approves D4, run the re-runs as listed (5× Clip 1, 5× Clip 2, 1× Clip 3 with `DUBBING_TIMEOUT_MS=10800000`), with the backups in place. Phase 1 code waits for **D1**.

## Second review (15:25 IST), after the developer's follow-up

### Status: Phase 0 report accepted with corrections; Phase 1 may start after items A–E below

#### What is fixed
- **The brief is now in the repo:** `docs/dubbing-low-latency-task-2026-11-26.md`. The developer couldn't see it before because it only existed in the Truthworld project.
- **The `eleven_v4_turbo` / Express proposal is removed.**
- **`tests/pipeline/dubbing_model_lock.test.ts` has been added.** The developer reports `test:dubbing` passing with 54 suites, 737 passed, 7 skipped and 0 failed, and the build passing with 215 endpoints. The reviewer has **not re-run** these; they are developer-reported.
- **Model time vs our time, and the floor, have been added** (§3 of the baseline).
- **The Phase 1 order has been revised** as requested.

#### A. The run evidence is lost (owner action)
- What the developer reports:
  - `functions/local-dub-output/` was on disk at 14:53:54.
  - The `.gitignore` edit at 14:57:12 and commit `b9b98d78` at 14:58:56 were made **outside** the developer's session.
  - The folder is now gone and is not in the Recycle Bin.
  - Adding a line to `.gitignore` doesn't delete files, so something else removed the folder (for example a clean command, or another agent).
- **Owner:** check which tool or person ran a cleanup around 14:57–15:00. The same folder held yesterday's delivered 12-minute film (`dub-test-te-1795605164245`).
- What is left:
  - the developer's session task logs (`task-1026.log`, `task-1045.log`, `task-1084.log`), which aren't in the repo, so the reviewer can't read them;
  - the 3 source clips in `scratch/`.
- **So the Phase 0 numbers stay developer-reported, not verified.**
- **From now on:**
  - after every run, `local-dub-test.ts` copies `run-log.txt` and `report.json` to `gs://truthworld-1-staging/dub-runs/<runId>/`;
  - no cleanup of `local-dub-output/` without the owner's approval.

#### B. The floor wording overclaims
- **Clip 1 (32.4 s):** the floor is 60.3 s p50, which is **1.86×** even if all our own time were zero. Getting to ≤ 1× needs translation under about 8 s. Today it is 37.6 s p50, and whether Fix 1.7 can get there is not measured. The report says this correctly.
- **Clip 2 (120 s): "proving ≤ 1.0× is reachable" is not supported.**
  - The floor uses translation times from the 2 delivered runs only (46.8 s and 64.2 s).
  - Translation across all 5 runs was 117.5 s p50; the 3 blocked runs were the slow ones, with repair loops.
  - Correct wording: "≤ 1.0× would be reachable on this clip **only if** translation stays as fast as the two fastest runs; not measured."
- Change the wording in §3.2.

#### C. Moderation timeout proposal: do not build it
`VideoGatewayService` **approves the video when moderation fails**. In the `catch` block (`services/videoGatewayService.ts` ~529–570), any error, including a timeout, returns `status: "APPROVED"`.
- The Clip 2 Run 3 log shows exactly this: it timed out at 180 s, then approved.
- Cutting the timeout to 45 s would make **more videos approved without a real moderation result**.
- Once Fix 1.3 runs moderation alongside dubbing, its time is no longer on the dubbing critical path, so there is no speed reason to shorten it.
- **Drop the proposal.** That moderation approves on failure is a separate safety issue that existed before this task, and it goes to the owner as **D5** below.

#### D. The model-lock test has gaps
- **Demucs:** the test only checks that `DEMUX_SERVICE_URL` contains `modal.run`. It doesn't lock the model or its settings. Lock the model name (e.g. `htdemucs`) and the settings sent to the worker (shifts, overlap, segment, stems) by checking the request body that `MediaService.separateWithDemuxWorker` sends.
- **Gemini editor:** the test checks that `"gemini-3.8-flash"` appears somewhere in the file. Check the constant or config value the editor actually uses, so that adding a second model elsewhere in the file fails the test.
- **Moderation's existing fallback model** (`gemini-3.5-flash-lite`, `videoGatewayService.ts` ~422): add it to the lock so nobody changes it.

#### E. The owner decisions were recorded as made, but they are recommendations
The baseline now says "D1: Yes, D2: Not yet, D3: Not yet, D4: Skip". Those were the **reviewer's recommendations**. Mark them "recommended, awaiting owner" until the owner confirms.

#### Re-run request (D4)
Recommended: **approve**, after one instrumentation-only change:
1. First add the per-call translation timings (Google, editor, meaning check, repair). This changes no behaviour, so the re-run also measures translation, the largest stage on short clips.
2. Then re-run 5× Clip 1, 5× Clip 2, and 1× Clip 3 with `DUBBING_TIMEOUT_MS=10800000`, with the outputs backed up as in A.

Spend, from Phase 0's own per-run costs (`report.json` → `jobCost`, developer-reported):
- Clip 1: about $0.06 per run, so 5 runs ≈ $0.31.
- Clip 2: $0.05–0.15 per run, so 5 runs ≈ $0.26–0.73.
- Clip 3, a full run: **not measured**. Its timed-out runs cost $0.10–0.14 before TTS. The developer estimates 2,500–5,000 ElevenLabs characters for TTS, which would be about $0.20–0.40 at $0.08 per 1,000 characters if that is our rate (not confirmed on our plan).

### Owner decisions (current)
- **D1** (moderation runs alongside dubbing, with approval still required before publishing): recommended **yes**.
- **D2** (paid levers): recommended **not yet**.
- **D3** (chunk-by-chunk TTS): recommended **not yet**, because translation blocking is unstable (Clip 2: 3 of 5 runs blocked).
- **D4** (re-run spend above): recommended **yes**.
- **D5 (new, safety):** moderation approves on any error or timeout (`videoGatewayService.ts` ~529–570). Should a failed moderation call send the video to `MANUAL_REVIEW` (or retry) instead of `APPROVED`? This existed before this task; the latency work found it.

---

## First review (15:00 IST)

### Verdict at the time: Phase 0 not accepted

#### 1. The evidence was missing from the PC
The report cites `functions/local-dub-output/dub-test-te-<id>/` for all 15 runs, and that folder does not exist on the PC. Yesterday's delivered 12-minute film was in the same folder.

#### 2. The report followed the old version of the brief
- D3 asked to test `eleven_v4_turbo`, which the model lock forbids.
- The fix numbers didn't match the current brief.
- The model-lock test wasn't added.

#### 3. One required output was missing
Model time vs our time, and the floor.

### What the baseline shows (developer-reported)
- **Clip 1 (32.4 s):**
  - p50 E2E 173.1 s (5.34× the clip's length); p95 315.9 s (9.75×).
  - AssemblyAI processing p50 was 6.4 s.
- **Our own time, 10-min clip:**
  - `separation.policy`: 84.2 s p50
  - `stereo_extract`: 73.9 s
  - `voices.tmp_download`: 56.7 s
  - stem download + upload: ~47 s
- **Translation:** 37.6 s p50 / 118.4 s p95 on Clip 1, and 117.5 s / 210.6 s on Clip 2. The spikes come from repair and retake loops.
- **Moderation:** a `gemini-3.8-flash` call timed out after 180 s on one run (195.7 s), which held up dubbing.
- **Cost:** delivered runs stayed inside the one-third profit rule.

### Problems that are bigger than latency
1. **Clip 2: 3 of 5 runs were blocked** on line 9, "Or kiss him goodnight.", which stayed `meaning_unresolved` after repair. This belongs to the translation-fidelity work.
2. **All 5 runs of the 10-minute clip failed at the 540 s guard.** This was already known. 10-minute videos need the chained or split architecture as a separate task.

### Phase 1 order
1. **Own-time work in `separation_chain` and `voices`:** `measureBackgroundLevels`, `stereo_extract`, the shared /tmp (Fix 1.9) and the voice-measurement cache (Fix 1.4).
2. **Analysis at upload (Fix 1.2) and parallel moderation (Fix 1.3, after D1).**
3. **Translation:** per-call timings, then parallel independent Gemini calls (Fix 1.7) with byte-identical prompts.
4. **The TTS sliding-window pool (Fix 1.5) and post-audio /tmp (Fix 1.8).**
5. **Webhook mode (Fix 1.1)** in the deployed config.

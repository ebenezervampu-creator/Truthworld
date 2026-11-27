# Task: Low-latency dubbing with the current models (no model changes)

> Repo copy of the Truthworld project doc `claude/dubbing-low-latency-task-assigned-2026-11-26.md` (saved here 2026-11-26 15:25 IST so the developer can read it). The project doc is the master copy.

Status: ASSIGNED. Assigned to: Senior Software Developer. Reviewer: Claude + owner.
Created: 2026-11-26 by Claude. Updated 2026-11-26: owner rule, **no model changes**.

Background:
- The measured run of the 32.4 s Telugu clip (`report.json` → `timingsSec`, `run-log.txt` → `[Dubbing:Timing]`), summarised below.
- Truthworld project docs: `claude/dubbing-speed-2026-11-21.md` (speed round 1: step cache, prewarm, parallel separation chain), `claude/dubbing-pricing-and-margin.md` (margin rule, must not be broken), `claude/dubbing-translation-fidelity-task-assigned-2026-11-25.md` (quality gates that must keep passing).

Repo: TruthWorld. Read `CLAUDE.md` at the repo root first and follow it. These rules matter most here:
- **Preserve working architecture**: make small, testable changes, and put every behaviour change behind a flag.
- **No unmeasured claims (rule 7)**: every speed, cost or quality number in your report must name its log, report file or `job_costs` document. A figure that hasn't been measured is written "not measured".
- **No mock data.** All runs use real clips and real APIs.

All paths are relative to `functions/`. Line numbers are from the 2026-11-26 files; re-check them before editing.

---

## 0. Model lock (owner rule, non-negotiable)

**Do not change, add, swap or fall back to any model or provider in the dubbing pipeline.** Every speed-up in this task must come from engineering: ordering, parallelism, caching, warm infrastructure, fewer file transfers, and configuration.

| Step | Model / provider that stays exactly as it is |
|---|---|
| Transcription + diarization | AssemblyAI `assemblyai-stt-3-7` (same request options) |
| Language probe, editor, meaning check, screen analysis | Same Gemini models and prompts as today (`gemini-3.8-flash` etc.) |
| Translation draft | Google Cloud Translation (same model) |
| Background separation | Demucs v4 on the self-hosted GPU worker (same model and settings) |
| Voice synthesis and cloning | ElevenLabs `eleven_v4` only; `tts.ts` stays "zero fallback models" |
| Moderation | VideoGateway (same checks) |

Not allowed in this task: `eleven_v4_turbo`, Flash or Turbo v2.5, any other TTS; streaming or different STT; Gemini audio transcription in place of AssemblyAI; DSP ducking in place of Demucs; lower Demucs quality settings (fewer shifts or overlap, a smaller model); changes to prompts or the order of quality checks.

Add a test, `tests/pipeline/dubbing_model_lock.test.ts`, that fails if the model IDs used by TTS, transcription, translation, the Gemini editor or Demucs differ from the values recorded at the start of this task. Add it to `test:dubbing`.

## 1. Where we are (measured)

32.4 s Telugu clip, en → te. Source: `report.json` `timingsSec` and `run-log.txt` `[Dubbing:Timing]` from that run.

| Phase | Measured | Notes |
|---|---|---|
| Clip prep + GCS upload | 5.2 s | |
| Transcription + moderation | 53.8 s | AssemblyAI 53,628 ms; ran in **polling** mode (5 attempts) |
| `separation_chain` / analysis | 38.4 s / 38.6 s | Demucs v4 GPU + ScreenContent + prosody; started only after transcription |
| `voices` | 16.8 s | `fromCache: 0`, 22 Telugu voices probed live |
| `translation` | 17.6 s | Google Translate + GeminiDubbingEditor + meaning check |
| `tts` | 30.0 s | `eleven_v4`, 8 segments, batch size 3 → 3 waves |
| `stitch` + `faithful_mix` | 3.8 s + 5.3 s | |
| `delivery_check` + upload | 4.0 s + 9.4 s | |
| **Total E2E** | **192.9 s** | 5.95× the clip's length |

Real-time factor (RTF) = processing time ÷ video length. This run: 192.9 ÷ 32.4 = **5.95**. The owner's goal is RTF ≤ 1.0, meaning the dub is ready no later than the video's own length.

**Be honest about the goal.** With the models fixed, the floor is set by how long AssemblyAI, Gemini, ElevenLabs `eleven_v4` and Demucs take to answer. Whether RTF ≤ 1.0 can be reached for a 30 s clip is **not measured**. Phase 0 measures the floor: the time spent inside the model calls alone. Report the best p50 and p95 RTF you actually reach, and how far it is from 1.0.

## 2. Findings in the code (checked 2026-11-26)

1. **TTS batch size 3 is a plan limit, not a bug.** `getAdaptiveTTSBatchSize` (`services/tts.ts` ~1483) returns `min(segments, ELEVENLABS_MAX_CONCURRENCY)`, and `DEFAULT_MAX_ELEVENLABS_CONCURRENCY = 3` (`services/elevenlabs-plan.ts`) is the ElevenLabs **Starter** limit. Setting it to 8–10 without upgrading the plan will produce 429s. ElevenLabs' TTS concurrency for non-Flash models is Starter 3 / Creator 5 / Pro 10 / Scale 15 ([ElevenLabs help: TTS concurrency](https://elevenlabs.io/docs/help-center/technical/how-many-text-to-speech-requests-can-i-make-and-can-i-increase-it)). A bigger plan keeps the same `eleven_v4` model, so it is allowed under the model lock, but it costs money (Phase 2).
   - **Free fix inside the limit:** the loop (`07-dubbing.ts` ~4990) runs in lock-step waves (`Promise.allSettled` per batch), so each wave waits for its slowest line. A sliding-window pool that starts the next line as soon as a slot frees up keeps all 3 slots busy.
2. **AssemblyAI webhook mode already exists.** `05-transcription.ts` ~413–465 submits with `webhook_url` when `ASSEMBLYAI_WEBHOOK_URL` is set, and only polls otherwise. The test run polled, so either the variable isn't set in that environment or the run used a local script. Same model, so this is allowed; check it first.
3. **Prewarm doesn't help a dub ordered at upload.** `prewarmDecision` (`services/dubbing-prewarm-policy.ts`) returns `"dubbing already ordered"` → no prewarm. So when dubbing is ordered at upload (the usual case), Demucs and screen analysis wait for transcription to finish: 53.8 + 38.6 = 92.4 s spent before translation even starts.
4. **Demucs compute is probably not the 38 s.** A published benchmark puts HDemucs at about 10.7× faster than real time on a single NVIDIA T4 ([arXiv 2310.11364, Table 3](https://arxiv.org/pdf/2310.11364)). That would mean roughly 3 s of GPU time for 32 s of audio. Our worker and GPU differ, so this is only a hint: most of the 38.4 s is likely cold start, transfer, fingerprint, prosody and ScreenContent. **Not measured**; Phase 0 will measure it.

## 3. Goal (what "done" means)

The same models, prompts and gates, with lower p50 and p95 RTF, measured on real clips.

Quality must be **identical**. For the same clips, these must match the Phase 0 baseline (or be better, with an explanation):
- `[Dubbing:SyncCheck]` violations
- meaning check `kept / fixed / unresolved` counts
- translation-blocked lines
- `delivery_check` loudness, bleed and quality gates (pass or fail)
- subtitle readability report
- the voice chosen for each speaker

Cost must stay inside the rule in `dubbing-pricing-and-margin.md`. TruthWorld keeps one third of every dub's price. Report the per-job cost from `job_costs/{jobId}` before and after. Phases 0–1 must add no per-job cost.

## 4. Engineering standards to follow

- **Measure before optimising.** Give each stage, and its sub-steps, a span. Report p50 and p95 over at least 5 runs per clip. A single run is not a result.
- **Shorten the critical path, then add parallelism.** Treat the pipeline as a dependency graph. Start every step as soon as its real inputs exist, not when the previous layer finishes.
- **Provider limits are about concurrency.** Use a bounded pool sized to the plan's limit. ElevenLabs returns `current-concurrent-requests` and `maximum-concurrent-requests` headers ([ElevenLabs: rate limiting for voice](https://elevenlabs.io/blog/ai-rate-limiting-for-voice)), so log them.
- **Use webhooks, not polling,** for async transcription ([AssemblyAI webhooks](https://www.assemblyai.com/docs/pre-recorded-audio/webhooks)). Keep polling as the fallback.
- **Keep GPUs and functions warm** only where cold starts show up in the critical path, and only after the cost is approved.
- **Every change has a rollback flag.** Copy the pattern in `services/translation-flags.ts` (default on; `"false"` restores the old behaviour). Add the new flags to a new `services/latency-flags.ts`.

---

## Phase 0: Instrument and record a baseline (no behaviour change)

1. Add sub-timings with the existing `recordTiming` (`07-dubbing.ts` ~347) and the same `[Dubbing:Timing]` log format:
   - **Transcription:** audio extraction, upload, Gemini language probe, AssemblyAI queue and processing (`submit → completed`), result fetch, VideoGateway moderation, and the Pub/Sub hop to `handleDubbing`.
   - **`separation_chain`:** separation-policy measurement, worker cold start vs warm (log whether the worker was already up), upload to worker, Demucs compute (worker-side timing in the response), stem download, fingerprint, prosody, and ScreenContent.
   - **`voices`:** catalog load, each live probe, and /tmp downloads.
   - **`translation`:** each Google Translate call, each Gemini editor call, each meaning-check call.
   - **`tts`:** per line: queue wait, ElevenLabs request time, ffprobe, upload; plus the ElevenLabs concurrency headers.
   - **Post-audio:** each FFmpeg pass and each GCS upload/download.
2. Clips (real files already on the PC, ask the owner if one is missing):
   - the 32.4 s Telugu clip from this run;
   - one ~2 min multi-speaker clip with background music;
   - one ~10 min clip.
3. Run each clip **5 times** for `te` (add `hi` if time allows) using `scripts/dubbing/local-dub-test.ts`, and once through the deployed function path so Pub/Sub and cold-start costs show up. **Before running, ask the owner to approve the ElevenLabs and GPU spend (D4), and include the estimated character count.**
4. Write `docs/dubbing-latency-baseline-2026-11-<dd>.md` containing:
   - a table per clip with p50 and p95 per stage and E2E, plus RTF;
   - **model time vs our time:** for each stage, how much was spent waiting on the model or provider and how much was our own work (transfers, FFmpeg, Firestore, queueing). Our own time is what this task can remove;
   - the **floor**: the shortest critical path made only of model calls, if every one of our own steps took zero time. This shows how close to RTF 1.0 the current models allow;
   - the quality counters from §3;
   - cost per job from `job_costs`;
   - the log file name for every number.

**Stop here and send the baseline to the reviewer** before Phase 1. The Phase 1 order depends on which sub-steps turn out to dominate.

## Phase 1: Faster with no quality change, no model change and no extra cost

| # | Change | Where | Flag |
|---|---|---|---|
| 1.1 | **Webhook mode on.** Confirm `ASSEMBLYAI_WEBHOOK_URL` and `ASSEMBLYAI_WEBHOOK_SECRET` are set wherever dubbing runs, and that the webhook function is deployed and verifies the secret. Leave polling as the fallback. The AssemblyAI model and request options don't change. | `05-transcription.ts` ~413 | config only |
| 1.2 | **Start language-independent analysis at upload, alongside transcription**, when dubbing is ordered. Run `runSeparationChain` (separation-policy, Demucs, fingerprint, prosody) and `getScreenContent` straight from the uploaded audio and video. The dubbing run then picks the results up from the step cache (`services/dubbing-step-cache.ts`), so nothing is computed twice. Steps that need speaker labels still wait for the transcript. Check the cache keys: the hash must not include transcript data for these steps. | `dubbing-prewarm-policy.ts` (new mode for ordered jobs), `07-dubbing.ts` `runSeparationChain` ~2245, `prepareDubbingAnalysis` ~2352 | `DUBBING_ANALYSIS_AT_UPLOAD` |
| 1.3 | **Run moderation alongside dubbing, and gate delivery on it.** Don't let VideoGateway hold up the dubbing trigger. Instead, delivery (publish, or making the dubbed track visible) waits until moderation passes, and a rejection cancels the job and refunds through the existing path. The VideoGateway checks themselves don't change. **Owner decision D1 is needed before coding.** | `05-transcription.ts` ~694, delivery step in `07-dubbing.ts` | `DUBBING_MODERATION_PARALLEL` |
| 1.4 | **Persist voice measurements.** Store each library voice's measured pitch and acoustics in Firestore, keyed by `voiceId` plus a preview-audio hash, and refresh them with a scheduled job. Probe live only on a cache miss or a changed hash. Matching results must be **identical**: test that the same speaker gets the same chosen voice with the cache on and off. | `services/library-voice-catalog.ts`, `voice-matcher.ts`, `voice-acoustics.ts` | `DUBBING_VOICE_MEASURE_CACHE` |
| 1.5 | **Sliding-window TTS pool.** Replace the lock-step batches with a bounded pool of size `readMaxElevenLabsConcurrency()`. Keep `eleven_v4`, the voice settings, checkpoint resume, retries and the order of results. Log the concurrency headers. | `07-dubbing.ts` ~4990 | `DUBBING_TTS_POOL` |
| 1.6 | **Overlap translation with voice matching**, where the real dependencies allow. Find out what the editor needs from voices or speaker profiling (e.g. `castGenderByLabel`). Start the Google Translate draft as soon as the transcript exists, and run the editor once its inputs are ready. The prompts and the inputs each call receives must be byte-identical to today: add a test that compares them. Report the dependency map under `## Plan`. | `07-dubbing.ts` translation step, `services/translation.ts` | `DUBBING_TRANSLATE_EARLY` |
| 1.7 | **Parallel Gemini calls inside translation**, where calls don't depend on each other (e.g. editor chunks, or meaning-check chunks that don't read each other's output). Results are applied in line order, and each call's prompt and inputs stay identical. Respect the Gemini quota, and log 429s. | `services/geminiDubbingEditor.ts`, `services/translation.ts` | `DUBBING_EDITOR_PARALLEL` |
| 1.8 | **Fewer post-audio round trips.** Keep intermediate files in /tmp across stitch, mix, check and remux; do one GCS upload at the end; use `-c:v copy -movflags +faststart`. Every `delivery_check` gate still runs on the final file, and the audio must be identical: compare loudness, bleed and a sample hash against the old path. | `07-dubbing.ts` post-audio, `MediaService` (`mergeAudioToVideo`, `enforceVideoLoudness`) | `DUBBING_LOCAL_POSTAUDIO` |
| 1.9 | **Remove repeat downloads.** Download the source audio and video to /tmp once per job and reuse them across voices, profiling, TTS probing and mixing. ffprobe TTS chunks from memory instead of re-downloading them (an open item from `dubbing-speed-2026-11-21.md`). | `07-dubbing.ts`, `voice-matcher.ts` | `DUBBING_SHARED_TMP` |

Upper bounds from the measured run (simple arithmetic, not predictions):
- 1.2 can take at most 38.6 s off the critical path, since that is the analysis stage's measured duration.
- 1.4 can take at most 16.8 s off.

Report what you actually measure.

## Phase 2: Paid levers, same models (each needs owner approval with a measured cost)

None of these change a model. For each one, give the measured latency gain from Phase 0/1 data, the added monthly cost, and the effect on the margin rule. Then **ask before switching it on (D2)**.

- **2.1 ElevenLabs plan upgrade (same `eleven_v4`).** Concurrency 5 (Creator) or 10 (Pro) means fewer or no TTS waves for short clips. Set `ELEVENLABS_MAX_CONCURRENCY` only after the plan changes. Check `maxInstances` on `handleDubbing` / `handleDubbingReel` (see the comment in `elevenlabs-plan.ts`).
- **2.2 Warm Demucs worker (same model and settings).** Keep a minimum instance running, possibly during peak IST hours only. Do this only if Phase 0 shows cold start is a large part of `separation_chain`. A faster GPU type is also allowed, as long as the output stems match (compare against the old ones).
- **2.3 `minInstances` on the dubbing functions,** only if Phase 0 shows function cold start on the critical path. Also check the memory and CPU settings: FFmpeg passes get faster with more vCPU, at the same output.

## Phase 3: Pipeline the stages for short clips (same models; only after Phases 0–1 are measured)

- **3.1 Start TTS per chunk.** Today all translation finishes before any TTS starts. Start `eleven_v4` synthesis for a chunk as soon as that chunk has passed every translation gate.
  - **This conflicts with the fidelity rule "block the language before any ElevenLabs spend"** (2026-11-25 task, Fix 2.3): if a later line is blocked, voice already paid for earlier chunks is wasted. **Owner decision D3 is needed before coding.** Without approval, leave this out.
- **3.2 Stitch as lines arrive.** Place each finished TTS line on the timeline as it completes, so only the final mix and delivery check run after the last line. The output must be identical to today's stitch.

Speed never skips a gate. Every translation and delivery gate from the 2026-11-25 fidelity task still runs.

---

## Owner decisions needed (ask; don't assume)

- **D1:** May dubbing run while moderation is still pending, as long as nothing is published before moderation passes (Fix 1.3)?
- **D2:** Budget for an ElevenLabs plan upgrade, a warm or faster GPU worker, and function `minInstances` (Phase 2), once the measured cost is presented.
- **D3:** May TTS start chunk by chunk (Phase 3.1), accepting that a late blocked line wastes voice already paid for on earlier chunks?
- **D4:** Spend approval for the Phase 0 and before/after runs (state the estimated characters and GPU minutes).

## Verify (after each phase; all must pass)
```bash
cd functions
npm run build
npm run test:dubbing
npm run test:pipeline
npm run test
```
- `npm run build` must report 0 errors and keep the number of functions in `functions.yaml`. Record that number before you start.
- New test files go into the `test:dubbing` script. At minimum, add tests for:
  - **the model lock** (`dubbing_model_lock.test.ts`, §0);
  - the TTS pool: never more than N requests in flight, results in input order, checkpoint resume still works;
  - the voice-measurement cache: same chosen voice with the cache on and off;
  - analysis at upload: the dubbing run hits the cache and doesn't recompute;
  - translating early and the parallel editor: prompts and inputs identical to today;
  - parallel moderation: a rejected video is never delivered and is refunded;
  - flags off: behaviour is identical to today.
- Don't weaken or delete a failing test. If you think a test is wrong, explain why under `## Result`.

## Out of scope
- **Any model or provider change** (§0).
- Changing translation prompts, the meaning check, quality gates, voice-matching logic, mixing or BGM, pricing or the 1.15× tempo cap.
- Removing any exported function or existing fallback.
- Committing, pushing or deploying without the owner's go-ahead.

## When done
Append `## Result` with:
1. Files changed, one line each.
2. Flags added and their defaults.
3. Before and after tables per clip: p50/p95 per stage, E2E and RTF; model time vs our time; the floor; the quality counters; cost per job. Name the log file for every number.
4. Confirmation that the model-lock test passes, and the list of model IDs it checks.
5. Test commands with how many tests ran, passed and failed.
6. The `functions.yaml` function count before and after.
7. What wasn't done, any place you departed from this task, and why.
8. Follow-ups.

Then set Status to `READY FOR REVIEW`.

## Plan
(Developer: write your plan in `docs/dubbing-latency-baseline-2026-11-26.md`.)

## Result
(Developer: fill in when done.)

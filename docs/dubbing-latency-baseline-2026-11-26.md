# TruthWorld Dubbing Latency Baseline (Phase 0)

- **Date:** 2026-11-26
- **Scope:** Phase 0 instrumentation only (`no behaviour change`). All measurements taken from `functions/scripts/dubbing/local-dub-test.ts` (Firestore emulator + live Cloud Storage `gs://truthworld-1-staging`, AssemblyAI `assemblyai-stt-3-7`, Modal A10G Demucs worker, Vertex AI Gemini, ElevenLabs `eleven_v4` with `ELEVENLABS_MAX_CONCURRENCY=3`).
- **Flag & env state verified during Phase 0:**
  - `ELEVENLABS_MAX_CONCURRENCY=3` in `functions/.env` (`elMaxConc=3` observed on `maximum-concurrent-requests` headers).
  - `ASSEMBLYAI_WEBHOOK_URL` and `ASSEMBLYAI_WEBHOOK_SECRET` are **not set** in `functions/.env` or `functions/.env.local`; all local baseline runs therefore ran AssemblyAI in polling mode (`"webhookMode":false`).
- **Not measured in Phase 0 (requires explicit go-ahead):**
  - **Deployed Cloud Function path (`1×` per clip):** not run because deploying functions requires explicit owner approval. Pub/Sub hop (`transcription.pubsub_hop`), webhook wake-up vs polling in production, and Cloud Run/Functions cold starts are therefore **not measured** here.
  - **Hindi (`hi`) baseline runs:** not run yet (all 15 baseline runs targeted Telugu `te`).

---

## 1. Run Index & Outcomes (15 real runs)

### Clip 1 — `32.4 s` Single-Speaker News Clip (`en → te`)
Source: `client_clip_32s.mp4` (`32.4s`, 8 dubbed segments, 333 ElevenLabs chars/run on baseline)

| Run | Folder / Log | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s) | Total E2E (s) | RTF (`E2E / 32.4`) | `jobCost` (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `functions/local-dub-output/dub-test-te-1795676966664/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 3.9 | 23.0 | 134.3 | 161.2 | 4.975 | \$0.057608 |
| 2 | `functions/local-dub-output/dub-test-te-1795677164668/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 3.0 | 23.4 | 135.2 | 161.6 | 4.988 | \$0.058113 |
| 3 | `functions/local-dub-output/dub-test-te-1795677354553/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 2.6 | 21.3 | 149.2 | 173.1 | 5.343 | \$0.062828 |
| 4 | `functions/local-dub-output/dub-test-te-1795677573199/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 4.8 | 24.3 | 163.0 | 192.1 | 5.929 | \$0.062727 |
| 5 | `functions/local-dub-output/dub-test-te-1795677799989/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 2.8 | 27.1 | 286.0 | 315.9 | 9.750 | \$0.078179 |

### Clip 2 — `120.0 s` Multi-Speaker Movie Clip w/ Background Music (`en → te`)
Source: `clip2_multi_195s.mp4` (`--seconds=120`, 27 segments, 816 ElevenLabs chars on Run 3 / 28 requests on Run 1)

| Run | Folder / Log | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s) | Total E2E (s) | RTF (`E2E / 120.0`) | `jobCost` (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `functions/local-dub-output/dub-test-te-1795678196840/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 7.7 | 34.6 | 379.2 | 421.5 | 3.513 | \$0.146769 |
| 2 | `functions/local-dub-output/dub-test-te-1795678672186/` (`run-log.txt`, `report.json`) | `NO_DUB_DELIVERED` (blocked pre-TTS) | 7.6 | 27.1 | 323.3 | 358.0 | 2.983 | \$0.052049 |
| 3 | `functions/local-dub-output/dub-test-te-1795679075196/` (`run-log.txt`, `report.json`) | `DUB_DELIVERED` | 10.2 | 216.2 | 350.7 | 577.1 | 4.809 | \$0.141418 |
| 4 | `functions/local-dub-output/dub-test-te-1795679737373/` (`run-log.txt`, `report.json`) | `NO_DUB_DELIVERED` (blocked pre-TTS) | 9.0 | 48.1 | 291.8 | 348.9 | 2.907 | \$0.051833 |
| 5 | `functions/local-dub-output/dub-test-te-1795680123348/` (`run-log.txt`, `report.json`) | `NO_DUB_DELIVERED` (blocked pre-TTS) | 10.3 | 55.8 | 237.7 | 303.8 | 2.532 | \$0.052787 |

> **Why Runs 2, 4, 5 stopped pre-TTS:** `[Dubbing:TranslationGate] Language blocked before TTS` (`DUBBING_BLOCK_ON_TRANSLATION_ERRORS`). Line 9 (`"Or kiss him goodnight."`) translated with an extra question/temporal clause (`"...ఇచ్చినప్పుడా?"` / `"...ముద్దిచ్చినప్పుడా?"`) and remained `meaning_unresolved` after repair, so the language was blocked and refunded before TTS spend.
>
> **Why Run 3 `transcription` spiked to `216.2 s`:** `VideoGatewayService` hit `[withAiRetry] Internal 180000ms timeout reached for model gemini-3.8-flash` (`transcription.moderation = 195,739 ms`) before falling back and approving.

### Clip 3 — `600.0 s` Long-Form Multi-Speaker Clip (`en → te`)
Source: `clip3_734s.mp4` (`--seconds=600`, ~81–82 turns, >8 min threshold -> enters `dispatchLongFormReels`)

| Run | Folder / Log | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s, cap) | Total Wall E2E (s) | RTF (`E2E / 600.0`) | Logged `CostEngine` Sum (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `functions/local-dub-output/dub-test-te-1795680571578/` (`run-log.txt`, `report.json`) | `ERROR` (`540s` guard) | 143.1 | 92.5 | 540.0 | 775.6 | 1.293 | \$0.096514 |
| 2 | `functions/local-dub-output/dub-test-te-1795681471721/` (`run-log.txt`, `report.json`) | `ERROR` (`540s` guard) | 102.2 | 84.3 | 540.0 | 726.5 | 1.211 | \$0.138213 |
| 3 | `functions/local-dub-output/dub-test-te-1795682327578/` (`run-log.txt`, `report.json`) | `ERROR` (`540s` guard) | 109.4 | 96.3 | 540.0 | 745.7 | 1.243 | \$0.139368 |
| 4 | `functions/local-dub-output/dub-test-te-1795683199361/` (`run-log.txt`, `report.json`) | `ERROR` (`540s` guard) | 85.8 | 81.1 | 540.0 | 706.9 | 1.178 | \$0.137811 |
| 5 | `functions/local-dub-output/dub-test-te-1795684039109/` (`run-log.txt`, `report.json`) | `ERROR` (`540s` guard) | 144.6 | 83.0 | 540.0 | 767.6 | 1.279 | \$0.138734 |

> **Why all 5 Clip 3 runs hit `540s`:** Pre-reel setup consumed **`analysis` p50 = `308.5 s` (`338.6 s` p95)** + **`voices` p50 = `95.0 s` (`133.3 s` p95)** = **`~403.5 s` p50 (`~471.9 s` p95)** *inside `07-dubbing.ts` before long-form translation/reels even began*. Runs 2–5 ran into `dispatchLongFormReels` translation (`~81–82` lines) and hit the `540s` `DUBBING_TIMEOUT_MS` guard before TTS (`Run 5` reached `[TranslationQualityGate]` segment #30 right before timeout). Run 5 also hit 1 Gemini `429 RESOURCE_EXHAUSTED` during `[GeminiDubbingEditor]` chunk edit (`attempt 1`).

---

## 2. Stage & Sub-Timing Breakdown (`p50` and `p95`)

Percentile definition across `n = 5` runs (`ceil(q * n)`): `p50` = sorted index `3` (median), `p95` = sorted index `5` (max). For Clip 2 post-translation stages (`n = 2` delivered runs), `p50` = Run 3 / Run 1 lower value and `p95` = higher value.

### 2.1 High-Level Stages (seconds) & RTF

| Stage | Clip 1 (`32.4 s`, `n=5`) p50 / p95 | Clip 2 (`120 s`, `n=5`) p50 / p95 | Clip 3 (`600 s`, `n=5`) p50 / p95 |
|---|---:|---:|---:|
| `cut` (test harness prep + upload) | 3.0 s / 4.8 s | 9.0 s / 10.3 s | 109.4 s / 144.6 s |
| `transcription` | 23.4 s / 27.1 s | 48.1 s / 216.2 s | 84.3 s / 96.3 s |
| `dubbing` (wall inside `07-dubbing.ts`) | 149.2 s / 286.0 s | 323.3 s / 379.2 s | 540.0 s* / 540.0 s* |
| **Total E2E** | **173.1 s / 315.9 s** | **358.0 s / 577.1 s** | **745.7 s* / 775.6 s*** |
| **RTF (`E2E / duration`)** | **5.343 / 9.750** | **2.983 / 4.809** | **1.243* / 1.293*** |

*\*All 5 Clip 3 runs aborted at `DUBBING_TIMEOUT_MS = 540s` before TTS / post-audio.*

### 2.2 Sub-Timings Across All Stages (milliseconds)

Unless marked **(per-call)**, values are job-level spans summed per job in `[Dubbing:Timing]`.

| Span (`[Dubbing:Timing]` `stage`) | Clip 1 (`32.4 s`) p50 / p95 | Clip 2 (`120 s`) p50 / p95 | Clip 3 (`600 s`) p50 / p95 |
|---|---:|---:|---:|
| `transcription.extract_download` | 2,453 / 3,028 | 5,641 / 7,673 | 51,648 / 56,136 |
| `transcription.extract_ffmpeg` | 340 / 524 | 894 / 1,092 | 6,156 / 12,797 |
| `transcription.audio_upload` | 530 / 730 | 608 / 1,083 | 1,133 / 2,195 |
| `transcription.extract_audio` | 3,377 / 4,181 | 7,441 / 9,188 | 59,420 / 71,213 |
| `transcription.url_resolve` | 280 / 483 | 300 / 440 | 310 / 350 |
| `transcription.language_probe` | 3,753 / 4,592 | 3,446 / 3,710 | 4,383 / 15,564 |
| `transcription.assemblyai_submit` | 1,015 / 1,375 | 1,120 / 1,498 | 1,123 / 1,319 |
| `transcription.assemblyai_queue` | 333 / 345 | 340 / 355 | 372 / 389 |
| `transcription.assemblyai_processing` | 6,422 / 6,467 | 7,980 / 8,029 | 11,084 / 11,232 |
| `transcription.result_fetch` | 1,179 / 1,253 | 460 / 569 | 481 / 665 |
| `transcription.moderation` | 6,604 / 10,780 | 26,377 / 195,739 | 6,582 / 7,071 |
| `transcription.publish` | 0 / 1 | 0 / 1 | 0 / 0 |
| `separation.policy` | 2,971 / 4,434 | 10,817 / 12,920 | 84,175 / 106,049 |
| `separation.screen_content` | 6,106 / 9,146 | 8,089 / 14,182 | 48,516 / 50,478 |
| `separation.stereo_extract` | 4,001 / 4,176 | 11,440 / 17,090 | 73,865 / 89,466 |
| `separation.worker_sign_url` | 175 / 262 | 209 / 230 | 179 / 228 |
| `separation.worker_request` (total) | 19,719 / 21,201 | 26,940 / 31,353 | 57,409 / 62,510 |
| `separation.worker_compute` (Modal A10G) | 12,673 / 14,734 | 19,784 / 22,112 | 49,078 / 55,273 |
| Demucs `workerOverheadMs` (`COLD` on all 15 runs) | 7,046 / 7,869 | 6,339 / 9,241 | 7,237 / 8,331 |
| `separation.stem_download` | 4,223 / 4,607 | 8,866 / 17,234 | 25,221 / 46,215 |
| `separation.stem_upload` | 1,182 / 1,395 | 3,139 / 3,992 | 22,397 / 24,986 |
| `separation.fingerprint` | 3,158 / 4,026 | 5,206 / 5,536 | 8,912 / 11,194 |
| `separation.prosody` | 6,259 / 15,658 | 18,353 / 39,898 | 36,968 / 43,695 |
| **`separation_chain`** | **38,113 / 46,622** | **85,857 / 98,957** | **308,219 / 338,101** |
| **`analysis`** | **38,239 / 46,755** | **86,010 / 99,183** | **308,514 / 338,584** |
| `voices.catalog_load` | 562 / 1,256 | 664 / 832 | 640 / 1,081 |
| `voices.tmp_download` | 2,511 / 2,687 | 6,687 / 7,118 | 56,662 / 63,662 |
| `voices.speaker_measure` | 3,139 / 3,661 | 8,257 / 8,920 | 21,415 / 44,431 |
| `voices.live_probe` (**per-call**, `fromCache: 0`) | 1,587 / 3,178 (`max 4,521`, 110 calls) | 1,490 / 3,372 (`max 5,256`, 200 calls) | 1,632 / 3,896 (`max 7,906`, 200 calls) |
| `voices.pitch_batch` | 9,944 / 11,020 | 15,545 / 22,252 | 16,148 / 31,300 |
| **`voices`** | **16,529 / 18,314** | **30,362 / 38,346** | **94,980 / 133,254** |
| **`translation`** | **37,566 / 118,360** | **117,544 / 210,567** | *timed out at 540s (`n=0` finished)* |
| `tts.queue_wait` (**per-call**) | 6,326 / 12,384 (`max 16,643`, 40 calls) | 17,552 / 47,231 (`max 47,232`, 54 calls, `n=2`) | — |
| `tts.elevenlabs_request` (**per-call**) | 1,946 / 2,975 (`max 3,087`, 40 calls) | 1,661 / 3,055 (`max 15,761`, 55 calls, `n=2`) | — |
| `tts.ffprobe` (**per-call**) | 45 / 749 (`max 2,960`, 40 calls) | 51 / 190 (`max 1,109`, 54 calls, `n=2`) | — |
| `tts.chunk_upload` (**per-call**) | 155 / 309 (`max 398`, 40 calls) | 135 / 198 (`max 488`, 55 calls, `n=2`) | — |
| **`tts`** (includes post-TTS concise retake!) | **14,674 / 44,065** | **41,954 / 123,059** (`n=2`) | — |
| `post.stitch_download` | 389 / 509 | 568 / 848 (`n=2`) | — |
| `post.stitch_ffmpeg_prep` | 423 / 468 | 1,334 / 3,511 (`n=2`) | — |
| `post.stitch_ffmpeg_mix` | 2,669 / 2,899 | 13,929 / 21,282 (`n=2`) | — |
| `post.stitch_upload` | 583 / 819 | 1,596 / 1,671 (`n=2`) | — |
| **`stitch`** | **4,062 / 4,438** | **17,812 / 27,009** (`n=2`) | — |
| `post.mix_download` | 2,103 / 2,481 | 5,234 / 5,302 (`n=2`) | — |
| `post.mix_pcm_analysis` | 1,152 / 1,197 | 3,796 / 6,162 (`n=2`) | — |
| `post.mix_ffmpeg_render` | 1,011 / 1,159 | 4,766 / 11,677 (`n=2`) | — |
| `post.mix_verify` | 249 / 269 | 750 / 1,737 (`n=2`) | — |
| `post.mix_upload` | 730 / 905 | 1,955 / 4,739 (`n=2`) | — |
| **`faithful_mix`** | **5,609 / 6,176** | **16,791 / 29,897** (`n=2`) | — |
| `post.delivery_download` | 943 / 3,106 | 2,875 / 2,973 (`n=2`) | — |
| `post.delivery_bleed_and_lufs` | 1,478 / 2,884 | 3,163 / 9,709 (`n=2`) | — |
| `post.delivery_loudness_ffmpeg` | 792 / 800 | skipped (`gainDb=0`, `n=2`) | — |
| `post.delivery_upload` | 502 / 686 | skipped (`n=2`) | — |
| **`delivery_check`** | **3,842 / 6,089** | **6,687 / 13,560** (`n=2`) | — |
| `post.remux_download` | 2,670 / 2,735 | 6,649 / 7,062 (`n=2`) | — |
| `post.remux_ffmpeg` | 1,489 / 1,809 | 3,729 / 6,557 (`n=2`) | — |
| `post.remux_upload` | 2,797 / 2,936 | 5,199 / 6,679 (`n=2`) | — |
| `post.video_loudness_download` | 2,155 / 3,061 | 4,779 / 5,438 (`n=2`) | — |
| `post.video_loudness_ffmpeg` | 161 / 251 | 573 / 2,266 (`n=2`) | — |
| **`upload`** (remux + loudness + GCS final) | **9,474 / 10,301** | **23,646 / 25,717** (`n=2`) | — |

---

## 3. Quality Gate Counters (§3 Baseline)

All values below come directly from `run-log.txt` and `report.json` in `functions/local-dub-output/dub-test-te-<id>/`. Note that a single job can emit multiple `[GeminiDubbingEditor] Meaning check` entries (initial 25-line chunk check plus per-line retake/repair checks); table counts sum every Meaning check event logged in that run.

| Clip / Run | Meaning Check (`kept / fixed / subtitle / unresolved`) | Translation-Blocked (`TranslationGate`) | Polarity Warnings (`TranslationQualityGate`) | `[Dubbing:SyncCheck]` (`missing / gender`) | `delivery_check` (`ok`, `lufsAfter`, `bleed`, `action`) | Subtitle Readability (`status`, `cues`, `avgCps`, `maxCps`) |
|---|---|---|---|---|---|---|
| **Clip 1** Run 1 (`1795676966664`) | `9 / 0 / 0 / 1` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `11.43`, `47.86` |
| **Clip 1** Run 2 (`1795677164668`) | `10 / 0 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.5 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `10`, `10.12`, `47.86` |
| **Clip 1** Run 3 (`1795677354553`) | `11 / 0 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `11.62`, `47.86` |
| **Clip 1** Run 4 (`1795677573199`) | `10 / 2 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `review`, `11`, `8.99`, `47.86` |
| **Clip 1** Run 5 (`1795677799989`) | `14 / 0 / 0 / 2` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `10.07`, `47.86` |
| **Clip 2** Run 1 (`1795678196840`) | `30 / 1 / 1 / 1` | `0` | `0` | `0 / 0` | `true`, `-15.6 LUFS`, `bleed=false` (`worstR=0.142`), `unchanged` | `pass`, `26`, `5.55`, `11.38` |
| **Clip 2** Run 2 (`1795678672186`) | `27 / 0 / 0 / 2` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 2** Run 3 (`1795679075196`) | `29 / 2 / 0 / 1` | `0` | `0` | `0 / 0` | `true`, `-14.7 LUFS`, **`bleed=true`** (`worstR=0.166`) -> **`dialogue_only`** (`worstR=0.041`) | `pass`, `26`, `5.43`, `11.38` |
| **Clip 2** Run 4 (`1795679737373`) | `27 / 0 / 0 / 2` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 2** Run 5 (`1795680123348`) | `28 / 0 / 0 / 3` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 3** Run 1 (`1795680571578`) | `0 / 0 / 0 / 0` (540s before edit) | `0` | `0` | n/a | n/a (timed out at 540s) | n/a |
| **Clip 3** Run 2 (`1795681471721`) | `80 / 0 / 1 / 1` | `0` | `0` | n/a | n/a (timed out at 540s) | n/a |
| **Clip 3** Run 3 (`1795682327578`) | `80 / 0 / 3 / 0` | `0` | `1` (seg #30) | n/a | n/a (timed out at 540s) | n/a |
| **Clip 3** Run 4 (`1795683199361`) | `82 / 0 / 0 / 2` | `0` | `1` (seg #30) | n/a | n/a (timed out at 540s) | n/a |
| **Clip 3** Run 5 (`1795684039109`) | `79 / 2 / 1 / 0` | `0` | `1` (seg #30) | n/a | n/a (timed out at 540s) | n/a |

---

## 4. Per-Job Cost & Margin (`job_costs/{jobId}` & `economics`)

Every completed run stayed well inside the 1/3 profit floor defined in `docs/dubbing-pricing-and-margin.md`.

| Clip | Metric | Measured Range | `p50` | `p95` | `priceUsd` | `profitFloorUsd` (1/3) | `costBudgetUsd` | Source |
|---|---|---|---:|---:|---:|---:|---:|---|
| **Clip 1** (`32.4s`, `n=5` delivered) | Actual `job_costs.totalUsd` | \$0.057608 – \$0.078179 | **\$0.062727** | **\$0.078179** | \$0.3000 | \$0.1000 | \$0.1482 | `report.json -> jobCost.totalUsd` |
| **Clip 2** (`120s`, `n=2` delivered) | Actual `job_costs.totalUsd` | \$0.141418 – \$0.146769 | — | — | \$0.6000 | \$0.2000 | \$0.2965 | `report.json -> jobCost.totalUsd` |
| **Clip 2** (`120s`, `n=3` blocked pre-TTS) | Sunk `job_costs.totalUsd` | \$0.051833 – \$0.052787 | \$0.052049 | \$0.052787 | (refunded) | — | — | `report.json -> jobCost.totalUsd` |
| **Clip 3** (`600s`, `n=5` timed out at 540s) | Sunk `[CostEngine]` sum | \$0.096514 – \$0.139368 | \$0.138213 | \$0.139368 | — | — | — | `run-log.txt` `[CostEngine] Recorded $...` |

Note on ElevenLabs concurrency headers during Phase 0: `maxConcurrentRequests: 3` confirmed in every live `tts.elevenlabs_request` log entry across delivered Clip 1 and Clip 2 runs, with **0** ElevenLabs HTTP `429` responses across all 95 TTS requests (`40` on Clip 1 + `55` on Clip 2).

---

## 5. Key Diagnostic Findings from Phase 0

1. **`separation.policy`, `stereo_extract`, `voices.tmp_download`, and `screen_content` kill 10-min (`600s`) jobs before translation can even run:**
   On Clip 3 (`600s`), `analysis` took **`308.5 s` p50 (`338.6 s` p95)** and `voices` took **`95.0 s` p50 (`133.3 s` p95)** — consuming **~75–87% of the `540 s` Cloud Function timeout** before long-form reel dispatch even started:
   - `separation.policy` (`measureBackgroundLevels` FFmpeg `aselect`) alone took **`84.2 s` p50 (`106.0 s` p95)** on 10 min audio!
   - `separation.stereo_extract` took **`73.9 s` p50**.
   - `voices.tmp_download` re-downloaded video/audio from GCS (`56.7 s` p50) even though `separation_chain` had already extracted/downloaded local files.
   - `voices.pitch_batch` took `9.9 s` (Clip 1), `15.5 s` (Clip 2), `16.1 s` (Clip 3) (`p95 31.3 s`) with **`fromCache: 0`** because the emulator cleared `voice_acoustics` and each run probed `22–40` voices live.
2. **`translation` is the #1 latency & variance driver on 32 s – 120 s clips:**
   - Clip 1: `37.6 s` p50 / **`118.4 s` p95** (when 2 unresolved Meaning Check lines triggered 4 iterative single-line Gemini edit/check loops, and post-TTS concise retake added another `~29 s` into `tts`).
   - Clip 2: `117.5 s` p50 / **`210.6 s` p95**, and 3/5 runs failed pre-TTS on line 9 (`"Or kiss him goodnight."`).
3. **`transcription.moderation` can stall the entire pipeline (`26.4 s` p50, `195.7 s` p95 on Clip 2):**
   Because `05-transcription.ts` awaits `videoGatewayService.evaluateVideo` (a `gemini-3.8-flash` call with `180s` internal timeout) *before* publishing `dubbing-processing`, even though AssemblyAI transcription itself only took **`6.4 s` (Clip 1) / `8.0 s` (Clip 2) / `11.1 s` (Clip 3)**!
4. **Lock-step TTS batches (`batchSize=3`) waste concurrency slots when one segment is slow:**
   On Clip 2 Run 1 (`1795678196840`), `segmentIndex: 15` (`15.76 s`) stalled two other slots, pushing `tts.queue_wait` max to `47.2 s`, and post-TTS `retranslateConcise` pushed total `tts` stage to **`123.1 s`** (`42.0 s` on Run 3).
5. **Post-audio performs redundant GCS roundtrips + serial passes:**
   `stitch` (`4.1 s` / `17.8 s`) + `faithful_mix` (`5.6 s` / `16.8 s`) + `delivery_check` (`3.8 s` / `6.7 s`) + `upload` (`9.5 s` / `23.6 s`) = **`23.0 s` p50 on Clip 1** and **`65–96 s` on Clip 2**, each separately downloading/uploading intermediate files from/to GCS instead of sharing `/tmp`.

---

## Plan — Phase 1 Execution Order (Zero Quality Drop, Zero Extra Cost)

Ranked strictly by Phase 0 measured impact on critical-path E2E latency and `540s` reliability (every code change placed behind a flag in `functions/src/pipeline/services/latency-flags.ts`, default `true` / rollback `"false"` following `translation-flags.ts`):

1. **P0 — Fix 10-min prep timeout & slash `analysis` + `voices` (`separation_chain`, `voices`):**
   - **(Fix 1.7 + 1.8) Voice preview disk/Firestore cache & pre-baked `voice_acoustics`:** reuse `voice_acoustics` pitch cache + `/tmp` voice cache across jobs (eliminating `10–31 s` `voices.pitch_batch` live probes and cutting `voices.tmp_download` by reusing stems/media already in `/tmp` from `separation_chain`). Expected impact from Phase 0 spans: eliminates up to `~10–31 s` of `voices.pitch_batch` + up to `~56 s` of duplicate GCS downloads on 10-min clips (exact gain to be measured after edit).
   - **(Fix 1.4) Parallelize independent work inside `separation_chain` + optimize `separation.policy`:** investigate & speed up `measureBackgroundLevels` (which took `84.2 s` p50 / `106.0 s` p95 on 600s, e.g. faster FFmpeg sampling or skipping redundant full-file decode) and avoid downloading stems twice (`stem_download` + `voices.tmp_download`).
2. **P0 — Unblock `dubbing` from `transcription.moderation` (`VideoGateway`) + start `runSeparationChain` at upload (`Fix 1.2` & `Fix 1.3`, pending `D1`):**
   - **(Fix 1.3, needs owner `D1`)** Run `VideoGateway` moderation concurrently with `handleDubbing` / translation, gating **publish/delivery** (and refunding cleanly if rejected) instead of blocking `transcription.publish` for `6.6 s – 195.7 s`.
   - **(Fix 1.2)** When dubbing is ordered at upload, trigger language-independent `runSeparationChain` immediately at upload alongside audio extraction + STT so the `38 s` (Clip 1) / `86 s` (Clip 2) / `308 s` (Clip 3) separation chain overlaps `transcription`.
3. **P1 — Enable AssemblyAI Webhook mode (`Fix 1.1`):**
   - Set `ASSEMBLYAI_WEBHOOK_URL` and `ASSEMBLYAI_WEBHOOK_SECRET` in deployed config and verify webhook secret handler in `05-transcription.ts` (keep polling as fallback when unset). Note: `audio_extraction` (`3.4 s` / `7.4 s` / `59.4 s`) + `language_probe` (`3.8 s`) + `assemblyai_processing` (`6.4–11.1 s`) shows polling overhead in local tests is small (`0.3–0.4 s` queue + polling interval) on 30–120s clips, so webhook mode matters most when removing polling wait + Function idle time in production.
4. **P1 — Replace lock-step TTS batches with a 3-slot sliding-window pool (`Fix 1.5`) + share `/tmp` across `stitch` → `faithful_mix` → `delivery_check` → `upload` (`Fix 1.6`):**
   - **(Fix 1.5)** Sliding-window `concurrency = ELEVENLABS_MAX_CONCURRENCY` (`3`) semaphore pool so slow segments (`10.8–15.8 s`) don't stall two idle slots.
   - **(Fix 1.6)** Pass local `/tmp` stems & mixed tracks directly between `stitch`, `faithful_mix`, `delivery_check`, and `remux/upload` to cut the post-audio GCS download/upload roundtrips measured in §2.2 (gain to be measured after edit).
5. **P1/P2 (post-baseline observation) — Reduce `translation` & retake latency (`37.6–118.4 s` Clip 1, `117.5–210.6 s` Clip 2) without changing quality gates:**
   - Profile internal sub-spans of `translation` (Google Translate v3 batch vs Gemini edit vs meaning check vs repair retries, and why Clip 2 line 9 `"Or kiss him goodnight."` failed 3/5 runs) and move/cache `post-TTS` concise retranslation + verify audio reuse before touching any quality gate or model.

---

## Owner Decisions Needed Before Proceeding

- **D1 (`Fix 1.3`):** May dubbing (`handleDubbing` + `runSeparationChain`) run concurrently while `VideoGateway` moderation (`6.6–195.7 s`) is in flight, with `APPROVED` still strictly gating final delivery/publish (and standard refund on rejection)? *(Recommended: **Yes**, since Phase 0 measured up to `195.7 s` blocking latency.)*
- **D2 (Phase 2 paid/warm budget):** Approve spend target for any Phase 2 paid levers (e.g., keeping Modal Demucs GPU warm to avoid `~7–8 s` cold overhead, upgrading ElevenLabs plan beyond `3` concurrent requests, or `latency-critical` Gemini tier) once Phase 1 Studio RTF is measured?
- **D3 (Phase 3 Express tier):** Confirm blind native-speaker listening test criteria and go/no-go for testing `eleven_v4_turbo` (`Express` mode target `p50 RTF ≤ 1.0`, pricing check on our ElevenLabs plan) after Phase 1–2 `Studio` completes.
- **D4 (Deployed Phase 0 spot check & `hi` runs):** Do you want us to run the `1×` per-clip deployed function baseline (requires your go-ahead to deploy the Phase 0 timing instrumentation + inspect/configure webhook env secrets) and/or `hi` baseline runs before starting Phase 1 edits, or proceed directly to Phase 1 after `D1`?

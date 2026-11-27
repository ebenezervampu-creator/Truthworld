# TruthWorld Dubbing Latency Baseline (Phase 0)

- **Date:** 2026-11-26 (revised 15:10 IST per review)
- **Scope:** Phase 0 instrumentation only (`no behaviour change`, **strict model lock**: `assemblyai-stt-3-7`, Modal Demucs v4 GPU worker, Google Translate v3 `general/translation-llm`, `gemini-3.8-flash` / `gemini-3.5-flash-lite`, ElevenLabs `eleven_v4` with `ELEVENLABS_MAX_CONCURRENCY=3`).
- **Evidence location & restoration status:**
  - All 15 runs were executed between `12:40` and `14:51 IST` on 2026-11-26 and verified directly on disk in `functions/local-dub-output/dub-test-te-<id>/` at `14:53:54 IST`.
  - At `14:57:12 IST`, `functions/.gitignore` was modified outside this session to add `local-dub-output/`, and at `14:58:56 IST` commit `b9b98d78` (`feat: dubbing studio, credibility pipeline, admin portal, and test suite updates`) was recorded; `functions/local-dub-output/` (including yesterday's `dub-test-te-1795605164245` and these 15 folders) is no longer present on `C:\` or in the Recycle Bin.
  - Full verbatim runner stdout/stderr logs (including every `[Dubbing:Timing]`, `[CostEngine]`, `[GeminiDubbingEditor]`, `[TranslationQualityGate]`, and `[Dubbing:SyncCheck]` event) remain saved under `<appDataDir>/brain/9e8ea77a-79b4-4307-8fbf-a8d6b4f5d309/.system_generated/tasks/` (`task-1026.log`, `task-1045.log`, `task-1084.log`) plus `scratch/baseline_summary.txt`.
  - **Pending verification on disk:** until `functions/local-dub-output/` is restored from backup or re-run (alongside `1×` Clip 3 with `DUBBING_TIMEOUT_MS` raised), the numbers below remain unverified against `functions/local-dub-output/`.
- **Flag & env state verified during Phase 0:**
  - `ELEVENLABS_MAX_CONCURRENCY=3` in `functions/.env` (`elMaxConc=3` observed on `maximum-concurrent-requests` headers).
  - `ASSEMBLYAI_WEBHOOK_URL` and `ASSEMBLYAI_WEBHOOK_SECRET` are **not set** in `functions/.env` or `functions/.env.local`; all local baseline runs ran AssemblyAI in polling mode (`"webhookMode":false`).
  - **Model-override env vars verified unset:** `DEMUCS_MODEL`, `SUBTITLE_SCREEN_MODEL`, `GEMINI_MODEL_DUBBING_TRANSLATION`, `GEMINI_MODERATION_MODEL`, and `TRANSLATION_MODEL` are **not set** in any `functions/.env*` file (checked `.env`, `.env.local`, `.env.test`, `.env.truthworld-1`), and `GET https://ebenezervampu--truthworld-demux-worker-fastapi-app.us-east.modal.run/health` returned `{"status":"healthy","service":"truthworld-demux-worker","engine":"demucs_v4_neural","model":"htdemucs","gpu":"A10G"}` on 2026-11-26 (`17:25 IST`).
- **Not measured in Phase 0 (deferred per D4):**
  - Deployed Cloud Function path (`1×` per clip) and Hindi (`hi`) baseline runs are deferred until Phase 1 is ready to deploy.

---

## 1. Run Index & Outcomes (15 real runs)

### Clip 1 — `32.4 s` Single-Speaker News Clip (`en → te`)
Source: `client_clip_32s.mp4` (`32.4s`, 8 dubbed segments, 333 ElevenLabs chars/run; raw task log: `task-1026.log`)

| Run | Original Folder (`functions/local-dub-output/`) | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s) | Total E2E (s) | RTF (`E2E / 32.4`) | `jobCost` (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `dub-test-te-1795676966664/` | `DUB_DELIVERED` | 3.9 | 23.0 | 134.3 | 161.2 | 4.975 | \$0.057608 |
| 2 | `dub-test-te-1795677164668/` | `DUB_DELIVERED` | 3.0 | 23.4 | 135.2 | 161.6 | 4.988 | \$0.058113 |
| 3 | `dub-test-te-1795677354553/` | `DUB_DELIVERED` | 2.6 | 21.3 | 149.2 | 173.1 | 5.343 | \$0.062828 |
| 4 | `dub-test-te-1795677573199/` | `DUB_DELIVERED` | 4.8 | 24.3 | 163.0 | 192.1 | 5.929 | \$0.062727 |
| 5 | `dub-test-te-1795677799989/` | `DUB_DELIVERED` | 2.8 | 27.1 | 286.0 | 315.9 | 9.750 | \$0.078179 |

### Clip 2 — `120.0 s` Multi-Speaker Movie Clip w/ Background Music (`en → te`)
Source: `clip2_multi_195s.mp4` (`--seconds=120`, 27 segments, 816 ElevenLabs chars on Run 3 / 28 requests on Run 1; raw task log: `task-1045.log`)

| Run | Original Folder (`functions/local-dub-output/`) | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s) | Total E2E (s) | RTF (`E2E / 120.0`) | `jobCost` (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `dub-test-te-1795678196840/` | `DUB_DELIVERED` | 7.7 | 34.6 | 379.2 | 421.5 | 3.513 | \$0.146769 |
| 2 | `dub-test-te-1795678672186/` | `NO_DUB_DELIVERED` (blocked pre-TTS) | 7.6 | 27.1 | 323.3 | 358.0 | 2.983 | \$0.052049 |
| 3 | `dub-test-te-1795679075196/` | `DUB_DELIVERED` | 10.2 | 216.2 | 350.7 | 577.1 | 4.809 | \$0.141418 |
| 4 | `dub-test-te-1795679737373/` | `NO_DUB_DELIVERED` (blocked pre-TTS) | 9.0 | 48.1 | 291.8 | 348.9 | 2.907 | \$0.051833 |
| 5 | `dub-test-te-1795680123348/` | `NO_DUB_DELIVERED` (blocked pre-TTS) | 10.3 | 55.8 | 237.7 | 303.8 | 2.532 | \$0.052787 |

> **Why Runs 2, 4, 5 stopped pre-TTS:** `[Dubbing:TranslationGate] Language blocked before TTS` (`DUBBING_BLOCK_ON_TRANSLATION_ERRORS`). Line 9 (`"Or kiss him goodnight."`) translated with an added question/temporal clause (`"...ఇచ్చినప్పుడా?"` / `"...ముద్దిచ్చినప్పుడా?"`) and stayed `meaning_unresolved` after repair, triggering pre-TTS block and refund (tracked under translation fidelity).
>
> **Why Run 3 `transcription` spiked to `216.2 s`:** `VideoGatewayService` hit `[withAiRetry] Internal 180000ms timeout reached for model gemini-3.8-flash` (`transcription.moderation = 195,739 ms`) before falling back and approving.

### Clip 3 — `600.0 s` Long-Form Multi-Speaker Clip (`en → te`)
Source: `clip3_734s.mp4` (`--seconds=600`, ~81–82 turns, >8 min threshold -> enters `dispatchLongFormReels`; raw task log: `task-1084.log`)

| Run | Original Folder (`functions/local-dub-output/`) | Verdict | `cut` (s) | `transcription` (s) | `dubbing` (s, cap) | Total Wall E2E (s) | RTF (`E2E / 600.0`) | Logged `CostEngine` Sum (USD) |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | `dub-test-te-1795680571578/` | `ERROR` (`540s` guard) | 143.1 | 92.5 | 540.0 | 775.6 | 1.293 | \$0.096514 |
| 2 | `dub-test-te-1795681471721/` | `ERROR` (`540s` guard) | 102.2 | 84.3 | 540.0 | 726.5 | 1.211 | \$0.138213 |
| 3 | `dub-test-te-1795682327578/` | `ERROR` (`540s` guard) | 109.4 | 96.3 | 540.0 | 745.7 | 1.243 | \$0.139368 |
| 4 | `dub-test-te-1795683199361/` | `ERROR` (`540s` guard) | 85.8 | 81.1 | 540.0 | 706.9 | 1.178 | \$0.137811 |
| 5 | `dub-test-te-1795684039109/` | `ERROR` (`540s` guard) | 144.6 | 83.0 | 540.0 | 767.6 | 1.279 | \$0.138734 |

> **Why all 5 Clip 3 runs hit `540s`:** Pre-reel setup consumed **`analysis` p50 = `308.5 s` (`338.6 s` p95)** + **`voices` p50 = `95.0 s` (`133.3 s` p95)** = **`~403.5 s` p50 (`~471.9 s` p95)** before long-form translation/reels began. Re-running `1×` Clip 3 with `DUBBING_TIMEOUT_MS` raised (e.g., `10800000`) is pending spend/re-run go-ahead to record Clip 3's translation, TTS, and post-audio spans.

---

## 2. Stage & Sub-Timing Breakdown (`p50` and `p95`)

Percentile definition across `n = 5` runs (`ceil(q * n)`): `p50` = sorted index `3`, `p95` = sorted index `5`. For Clip 2 post-translation stages (`n = 2` delivered runs), `p50` = lower value and `p95` = higher value.

### 2.1 High-Level Stages (seconds) & RTF

| Stage | Clip 1 (`32.4 s`, `n=5`) p50 / p95 | Clip 2 (`120 s`, `n=5`) p50 / p95 | Clip 3 (`600 s`, `n=5`) p50 / p95 |
|---|---:|---:|---:|
| `cut` (test harness prep + upload) | 3.0 s / 4.8 s | 9.0 s / 10.3 s | 109.4 s / 144.6 s |
| `transcription` | 23.4 s / 27.1 s | 48.1 s / 216.2 s | 84.3 s / 96.3 s |
| `dubbing` (wall inside `07-dubbing.ts`) | 149.2 s / 286.0 s | 323.3 s / 379.2 s | 540.0 s* / 540.0 s* |
| **Total E2E** | **173.1 s / 315.9 s** | **358.0 s / 577.1 s** | **745.7 s* / 775.6 s*** |
| **RTF (`E2E / duration`)** | **5.343 / 9.750** | **2.983 / 4.809** | **1.243* / 1.293*** |

### 2.2 Sub-Timings Across All Stages (milliseconds)

Unless marked **(per-call)**, values are summed per job in `[Dubbing:Timing]`.

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
| Demucs `workerOverheadMs` (`COLD` all 15 runs) | 7,046 / 7,869 | 6,339 / 9,241 | 7,237 / 8,331 |
| `separation.stem_download` | 4,223 / 4,607 | 8,866 / 17,234 | 25,221 / 46,215 |
| `separation.stem_upload` | 1,182 / 1,395 | 3,139 / 3,992 | 22,397 / 24,986 |
| `separation.fingerprint` | 3,158 / 4,026 | 5,206 / 5,536 | 8,912 / 11,194 |
| `separation.prosody` | 6,259 / 15,658 | 18,353 / 39,898 | 36,968 / 43,695 |
| **`separation_chain`** | **38,113 / 46,622** | **85,857 / 98,957** | **308,219 / 338,101** |
| **`analysis`** | **38,239 / 46,755** | **86,010 / 99,183** | **308,514 / 338,584** |
| `voices.catalog_load` | 562 / 1,256 | 664 / 832 | 640 / 1,081 |
| `voices.tmp_download` | 2,511 / 2,687 | 6,687 / 7,118 | 56,662 / 63,662 |
| `voices.speaker_measure` | 3,139 / 3,661 | 8,257 / 8,920 | 21,415 / 44,431 |
| `voices.live_probe` (**per-call**, `fromCache: 0`) | 1,587 / 3,178 (`max 4,521`) | 1,490 / 3,372 (`max 5,256`) | 1,632 / 3,896 (`max 7,906`) |
| `voices.pitch_batch` | 9,944 / 11,020 | 15,545 / 22,252 | 16,148 / 31,300 |
| **`voices`** | **16,529 / 18,314** | **30,362 / 38,346** | **94,980 / 133,254** |
| **`translation`** | **37,566 / 118,360** | **117,544 / 210,567** | *timed out at 540s* |
| `tts.queue_wait` (**per-call**) | 6,326 / 12,384 (`max 16,643`) | 17,552 / 47,231 (`max 47,232`, `n=2`) | — |
| `tts.elevenlabs_request` (**per-call**) | 1,946 / 2,975 (`max 3,087`) | 1,661 / 3,055 (`max 15,761`, `n=2`) | — |
| `tts.ffprobe` (**per-call**) | 45 / 749 (`max 2,960`) | 51 / 190 (`max 1,109`, `n=2`) | — |
| `tts.chunk_upload` (**per-call**) | 155 / 309 (`max 398`) | 135 / 198 (`max 488`, `n=2`) | — |
| **`tts`** (includes post-TTS concise retake) | **14,674 / 44,065** | **41,954 / 123,059** (`n=2`) | — |
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

## 3. Model Time vs Our Time & Critical-Path Floor (Clips 1 & 2)

Computed from `scratch/calc_floor.js` directly against `[Dubbing:Timing]` in `task-1026.log` and `task-1045.log`:

### 3.1 Per-Stage Decomposition (`p50 / p95` in seconds)

| Stage | Model Calls (locked providers/IDs) | Our Time (download/upload/FFmpeg/queues/orchestration) | Clip 1 (`32.4 s`, `n=5`) Model / Our (`p50`, `p95`) | Clip 2 (`120.0 s`, `n=5`; TTS/Post `n=2`) Model / Our (`p50`, `p95`) |
|---|---|---|---|---|
| **`cut`** | None | Local ffmpeg cut + GCS upload | `0.0 s` / `3.0 s` (`4.8 s`) | `0.0 s` / `9.0 s` (`10.3 s`) |
| **`transcription`** | `language_probe` (`gemini-3.5-flash-lite`) + `assemblyai_queue + processing` (`assemblyai-stt-3-7`) + `moderation` (`gemini-3.8-flash` -> fallback) | `extract_audio` + `url_resolve` + `assemblyai_submit` + `result_fetch` + `publish` | **Core STT+probe:** `10.5 s` (`11.4 s`)<br>**Moderation:** `6.6 s` (`10.8 s`)<br>**Our time:** `6.0 s` (`6.6 s`) | **Core STT+probe:** `11.8 s` (`12.1 s`)<br>**Moderation:** `26.4 s` (`195.7 s`)<br>**Our time:** `9.2 s` (`11.3 s`) |
| **`separation_chain` / `analysis`** | `worker_compute` (Demucs A10G) -> parallel(`fingerprint`, `prosody`* [`gemini-3.5-flash-lite`]); parallel `screen_content` [`gemini-3.5-flash-lite`] | `policy` (FFmpeg) + `stereo_extract` (FFmpeg) + Modal cold/transfer `workerOverheadMs` + `stem_download` + `stem_upload` + `sign_url` | **Demucs:** `12.7 s` (`14.7 s`)<br>**FP/Prosody*:** `6.3 s` (`15.7 s`)<br>**Screen (parallel):** `6.1 s` (`9.1 s`)<br>**Our time:** `19.5 s` (`22.1 s`) | **Demucs:** `19.8 s` (`22.1 s`)<br>**FP/Prosody*:** `18.4 s` (`39.9 s`)<br>**Screen (parallel):** `8.1 s` (`14.2 s`)<br>**Our time:** `44.6 s` (`49.2 s`) |
| **`voices`** | Gemini multimodal speaker gender/age inside `voices.speaker_measure`* | `catalog_load` + `tmp_download` + `pitch_batch` (HTTP preview + FFmpeg YIN; cacheable to `0` via Fix 1.4) + FFmpeg turn/frame slicing* | **Measure*:** `3.1 s` (`3.7 s`)<br>**Our (cacheable):** `13.3 s` (`14.7 s`) | **Measure*:** `8.3 s` (`8.9 s`)<br>**Our (cacheable):** `23.3 s` (`30.0 s`) |
| **`translation`** | Google Translate v3 + Localization Bible + `geminiDubbingEditor` (`gemini-3.8-flash`) + Meaning Check + repairs** | Prompt prep, chunking, JS validation (not yet split from model time; Phase 1 Step 3 instruments each call) | **`37.6 s` (`118.4 s`)** (combined**) | **`117.5 s` (`210.6 s`)** (combined**; Run 1=`46.8 s`, Run 3=`64.2 s`) |
| **`tts`** | `eleven_v4` across `3` slots (`sum(elevenlabs_request) / 3`) + any retake Gemini/TTS** | Lock-step `queue_wait` barrier + `ffprobe` + `chunk_upload` + retake orchestration | **3-slot TTS model:** `5.6 s` (`5.8 s`)<br>**Our + retake:** `9.1 s` (`38.3 s`) | **3-slot TTS model (`n=2`):** `18.3 s` – `19.7 s`<br>**Our + retake:** `23.7 s` – `103.4 s` |
| **`post-audio`** (`stitch`, `faithful_mix`, `delivery_check`, `upload`) | **None (`0 s`)** | All GCS downloads/uploads, FFmpeg mixes, PCM bleed check, loudnorm, remux | `0.0 s` / **`24.0 s` (`25.9 s`)** | `0.0 s` / **`64.9 s` – `96.2 s`** (`n=2`) |

*\*`prosody` (`separation.prosody`) includes audio download & FFmpeg RMS/WAV slicing alongside Gemini calls; `voices.speaker_measure` includes FFmpeg turn/frame extraction alongside Gemini gender/age. Not split in Phase 0; treating the whole span as model time is a conservative upper bound for the model floor.*
*\*\*`translation` is currently one combined span in Phase 0; per-call sub-timings (Google v3, Editor, Meaning check, Repair) are the first sub-task before `Fix 1.7`.*

### 3.2 Critical-Path Floor (Model Calls Only, `eleven_v4` + Current Models)

Assuming all **"Our Time"** drops toward 0 (`shared /tmp`, voice cache, zero GCS/lock-step overhead), `moderation` runs in parallel off the critical path (**Fix 1.3**), and `eleven_v4` uses `ELEVENLABS_MAX_CONCURRENCY=3`:

- **Formula A (Demucs starts at upload — Fix 1.2, overlapped with `language_probe + assemblyai`):**
  `Floor = (probe + aai) + max(0, Demucs + max(fp, prosody) − (probe + aai)) + translation + (sum(elevenlabs_request) / 3)`
- **Formula B (Sequential analysis after STT, no Fix 1.2 overlap):**
  `Floor = (probe + aai) + Demucs + max(fp, prosody) + translation + (sum(elevenlabs_request) / 3)`

| Clip | Metric | Formula A (Upload overlap, **current** sequential `translation`) | Formula B (No upload overlap, **current** sequential `translation`) | If `voices.speaker_measure` is added sequentially | Can `≤ 1.0×` (`32.4 s` / `120.0 s`) be reached with current models? |
|---|---|---:|---:|---:|---|
| **Clip 1** (`32.4 s`, `n=5`) | `p50` / `p95` | **`60.3 s`** (`1.86×`) / `142.4 s` (`4.40×`) | `70.8 s` (`2.19×`) / `152.7 s` (`4.71×`) | `+3.1 s` (`63.4 s`) | **Not with sequential `translation`** (`37.6 s` p50 alone > `32.4 s`). Removing `our time` (`~75 s` p50) + parallelizing `translation` (`Fix 1.7`, so `translation` drops from `37.6 s` toward `~10–15 s`) brings the non-translation model floor down to `19.0 s` (Demucs+prosody) + `5.6 s` (TTS) = **`24.6 s` (`0.76×`)** *before* translation, making `~1.0×` feasible only if `translation` parallelizes to `< ~8–10 s` (not yet measured). |
| **Clip 2** (`120.0 s`, `n=2` delivered) | Run 1 / Run 3 (`trans = 46.8 s / 64.2 s`) | **`103.1 s`** (`0.86×`) / **`122.9 s`** (`1.02×`) | `114.9 s` (`0.96×`) / `132.7 s` (`1.11×`) | `+5.6 s` / `+8.4 s` | **Only if translation stays as fast as the two fastest runs (`46.8 s` and `64.2 s`); not measured.** Non-translation model floor is **`56.5–57.9 s` (`0.47–0.48×`)**, while `translation` across all 5 runs was **`117.5 s` `p50`** (and 3/5 runs blocked after repair loops). |

---

## 4. Quality Gate Counters (§3 Baseline)

| Clip / Run | Meaning Check (`kept / fixed / subtitle / unresolved`) | Translation-Blocked (`TranslationGate`) | Polarity Warnings (`TranslationQualityGate`) | `[Dubbing:SyncCheck]` (`missing / gender`) | `delivery_check` (`ok`, `lufsAfter`, `bleed`, `action`) | Subtitle Readability (`status`, `cues`, `avgCps`, `maxCps`) |
|---|---|---|---|---|---|---|
| **Clip 1** Run 1 (`1795676966664`) | `9 / 0 / 0 / 1` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `11.43`, `47.86` |
| **Clip 1** Run 2 (`1795677164668`) | `10 / 0 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.5 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `10`, `10.12`, `47.86` |
| **Clip 1** Run 3 (`1795677354553`) | `11 / 0 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `11.62`, `47.86` |
| **Clip 1** Run 4 (`1795677573199`) | `10 / 2 / 0 / 0` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `review`, `11`, `8.99`, `47.86` |
| **Clip 1** Run 5 (`1795677799989`) | `14 / 0 / 0 / 2` | `0` | `0` | `0 / 0` | `true`, `-16.6 LUFS`, `bleed=false`, `loudness_corrected` | `warning`, `11`, `10.07`, `47.86` |
| **Clip 2** Run 1 (`1795678196840`) | `30 / 1 / 1 / 1` | `0` | `0` | `0 / 0` | `true`, `-15.6 LUFS`, `bleed=false` (`worstR=0.142`), `unchanged` | `pass`, `26`, `5.55`, `11.38` |
| **Clip 2** Run 2 (`1795678672186`) | `27 / 0 / 0 / 2` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 2** Run 3 (`1795679075196`) | `29 / 2 / 0 / 1` | `0` | `0` | `0 / 0` | `true`, `-14.7 LUFS`, **`bleed=true`** (`worstR=0.166`) -> `dialogue_only` (`worstR=0.041`) | `pass`, `26`, `5.43`, `11.38` |
| **Clip 2** Run 4 (`1795679737373`) | `27 / 0 / 0 / 2` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 2** Run 5 (`1795680123348`) | `28 / 0 / 0 / 3` | **`1`** (line 9) | `0` | n/a | n/a (refunded pre-TTS) | n/a |
| **Clip 3** Runs 1–5 | `0/0/0/0` to `79/2/1/0` | `0` | `1` (Runs 3–5, seg #30) | n/a | n/a (timed out at 540s) | n/a |

---

## 5. Per-Job Cost & Margin (`job_costs/{jobId}` & `economics`)

Every completed run stayed inside the 1/3 profit floor defined in `docs/dubbing-pricing-and-margin.md`.

| Clip | Metric | Measured Range | `p50` | `p95` | `priceUsd` | `profitFloorUsd` (1/3) | `costBudgetUsd` | Source |
|---|---|---|---:|---:|---:|---:|---:|---|
| **Clip 1** (`32.4s`, `n=5` delivered) | Actual `job_costs.totalUsd` | \$0.057608 – \$0.078179 | **\$0.062727** | **\$0.078179** | \$0.3000 | \$0.1000 | \$0.1482 | `report.json -> jobCost.totalUsd` (`task-1026.log`) |
| **Clip 2** (`120s`, `n=2` delivered) | Actual `job_costs.totalUsd` | \$0.141418 – \$0.146769 | — | — | \$0.6000 | \$0.2000 | \$0.2965 | `report.json -> jobCost.totalUsd` (`task-1045.log`) |
| **Clip 2** (`120s`, `n=3` blocked pre-TTS) | Sunk `job_costs.totalUsd` | \$0.051833 – \$0.052787 | \$0.052049 | \$0.052787 | (refunded) | — | — | `report.json -> jobCost.totalUsd` (`task-1045.log`) |
| **Clip 3** (`600s`, `n=5` timed out at 540s) | Sunk `[CostEngine]` sum | \$0.096514 – \$0.139368 | \$0.138213 | \$0.139368 | — | — | — | `[CostEngine] Recorded $...` (`task-1084.log`) |

---

## Plan — Phase 1 Execution Order (Strict Model Lock, Zero Quality Drop)

Every behavior change goes behind an env flag in `functions/src/pipeline/services/latency-flags.ts` (default `true`, `"false"` restores old behavior). Zero model or provider swaps (`docs/dubbing-low-latency-task-2026-11-26.md` §0).

0. **Gate — `functions/tests/pipeline/dubbing_model_lock.test.ts` (added before any Phase 1 code):**
   - Added to `test:dubbing` in `functions/package.json`; locks `eleven_v4`, `assemblyai-stt-3-7`, Google Translate v3 `general/translation-llm`, `gemini-3.8-flash` / `gemini-3.5-flash-lite` (including `VideoGatewayService` moderation primary & fallback and `GeminiDubbingEditor` `DEFAULT_MODEL`), and Modal Demucs (`htdemucs`, `--two-stems vocals`, payload `{ jobId, audioUrl }`).
1. **Step 1 — Remove our own time in `separation_chain` and `voices` (`Fix 1.4`, `Fix 1.9`):**
   - Optimize `measureBackgroundLevels` (`separation.policy`: `84.2 s` p50 / `106.0 s` p95 on 600s) and `stereo_extract` (`73.9 s` p50 on 600s).
   - **Fix 1.9 (Shared `/tmp`):** reuse already-downloaded source audio/video across `voices`, profiling, TTS probing, and mixing (`voices.tmp_download`: `56.7 s` p50 on 600s) and `ffprobe` TTS chunks from memory.
   - **Fix 1.4 (Voice-measurement cache):** persist voice measurements in Firestore keyed by `voiceId` + preview-audio hash; probe live only on cache miss (`9.9–16.1 s` p50 / `31.3 s` p95 with `fromCache: 0`).
2. **Step 2 — Analysis at upload (`Fix 1.2`) + parallel moderation (`Fix 1.3`, awaiting D1):**
   - **Fix 1.2:** Start language-independent `runSeparationChain` + `getScreenContent` at upload alongside audio extraction + STT; pick up results from `dubbing-step-cache.ts`.
   - **Fix 1.3 (awaiting D1):** Run `VideoGateway` moderation concurrently with dubbing; keep `APPROVED` as a hard gate before final delivery/publish (refund on rejection). Per Review C, the `45,000 ms` moderation timeout proposal was dropped because `VideoGatewayService` (`videoGatewayService.ts:529-570`) returns `APPROVED` on error/timeout (tracked as safety decision `D5`); parallel moderation removes moderation from the dubbing critical path.
3. **Step 3 — Translation instrumentation + overlap with voices (`Fix 1.6`) + parallel independent Gemini calls (`Fix 1.7`):**
   - Per-call `[Dubbing:Timing]` spans added in `translation.ts` and `geminiDubbingEditor.ts` (`translation.google_draft`, `translation.localization_bible`, `translation.editor_edit`, `translation.editor_tighten`, `translation.meaning_check`, `translation.google_back_translate`, `translation.repair_numeric`, `translation.repair_meaning`, `translation.concise_retranslate`) with zero behavior change prior to the `D4` re-run.
   - **Fix 1.6:** Overlap Google Translate draft (`translation.google_draft`) with voice matching; run Gemini editor once `castGenderByLabel` / voice inputs are ready, keeping prompts and inputs byte-identical.
   - **Fix 1.7:** Run independent Gemini editor / meaning-check chunks in parallel with byte-identical prompts while respecting quota and logging 429s.
4. **Step 4 — TTS sliding-window pool (`Fix 1.5`) + post-audio shared `/tmp` (`Fix 1.8`):**
   - **Fix 1.5:** Replace lock-step `Promise.allSettled` batches (`batchSize=3`) with a 3-slot sliding-window pool (`ELEVENLABS_MAX_CONCURRENCY=3`).
   - **Fix 1.8:** Share `/tmp` intermediate tracks across `stitch → faithful_mix → delivery_check → remux` (`-c:v copy -movflags +faststart`), doing one GCS upload at the end.
5. **Step 5 — Webhook mode (`Fix 1.1`):**
   - Configure `ASSEMBLYAI_WEBHOOK_URL` and `ASSEMBLYAI_WEBHOOK_SECRET` in deployed environments (keep polling fallback).

---

## Owner Decisions (Recommended — Awaiting Owner Confirmation)

- **D1 (`Fix 1.3`):** Recommended **Yes** (awaiting owner) — run moderation alongside dubbing, with `APPROVED` still gating delivery/publish and refund on rejection.
- **D2 (Phase 2 paid warm/tier levers):** Recommended **Not yet** (awaiting owner) — decide after Phase 1 is measured.
- **D3 (`eleven_v4` chunk-by-chunk TTS):** Recommended **Not yet** (awaiting owner) — hold until translation blocking (`3/5` Clip 2 runs) is stabilized.
- **D4 (Re-run `5×` Clip 1, `5×` Clip 2, `1×` Clip 3 w/ `DUBBING_TIMEOUT_MS=10800000`):** Recommended **Yes** (awaiting owner spend approval; outputs backed up via `local-dub-test.ts` to `gs://truthworld-1-staging/dub-runs/<runId>/`). Estimated spend from Phase 0 `jobCost`: Clip 1 `~$0.31` (`5 × ~$0.06`, `~1,665` ElevenLabs chars), Clip 2 `~$0.26–$0.73` (`5 × $0.05–$0.15`, up to `~4,080` chars), Clip 3 `1×` full run `not measured` (`~$0.10–$0.14` pre-TTS + estimated `2,500–5,000` ElevenLabs chars). Deployed/Hindi baseline stays deferred until Phase 1 deploy.
- **D5 (New safety finding):** Moderation currently returns `APPROVED` on any error or `180 s` timeout (`videoGatewayService.ts:529-570`). Should a failed moderation call route to `MANUAL_REVIEW` (or retry) instead of `APPROVED`? (Awaiting owner decision; separate from the latency task.)

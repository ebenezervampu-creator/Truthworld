# TruthWorld Credibility End-to-End Hardening Implementation Plan

> **For agentic workers:** Execute via parallel `/teamwork` subagents (`superpowers:dispatching-parallel-agents` + verification gates) across strictly disjoint file scopes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an industry-standard, cost-effective end-to-end Credibility System implementing **1A** (evergreen settled/historical facts + short-TTL mutable claims), **2A** (forward BigQuery wiring + env flag unification + backfill script), **Option 1** (BigQuery primary store + slim `<1ms` RAM Tier 2 guard fed `original` + `englishCanonical`), real Tier 4 redirect unwrapping / ccTLD domain inference / Option A single-claim retry, Ask AI Chat GCS fallback + App Check + honest synthesis, accurate telemetry, and Flutter UI fixes.

**Architecture:** Claims run a single upfront `gemini-3.5-flash-lite` multilingual canonicalization (`englishCanonical`) and check **Tier 1** (`L1 LRU -> L2 Firestore claim_cache [evergreen/short-TTL] -> 1 batched BigQuery raw_claims_verified SQL lookup [<=2500ms] + warm backfill`), gating aged links (`>30d`) with a `$0`-AI HTTP check. Truly new/dead/volatile claims flow through slim **Tier 2** (`original` + `englishCanonical`), **Tier 3** opinion filter, `$0` domain-wide open pre-retrieval (Wikipedia, Wikidata, PubMed, Crossref, FRED, World Bank), **Tier 4** batch-5 grounding + real `UrlVerificationService` unwrapping + `classifySourceStances` + **Option A** isolated 1-claim retry on misses, persisting newly verified Tier 2/4 results back to Cache + BigQuery. Ask AI adds Zero-Trust GCS `factCheckUrl` fallback, App Check auth, mobile context passing, and Flutter fixes ccTLD favicons and millisecond timestamp scaling.

**Tech Stack:** TypeScript (Node/Cloud Functions v2, `@google-cloud/bigquery`, `@google/genai`, Firebase Admin/Firestore/Storage, Jest), Flutter / Dart (GetX, `firebase_app_check`, `flutter_test`).

**Spec:** [docs/superpowers/specs/2026-11-27-credibility-end-to-end-fix-design.md](file:///c:/company/truthworld/docs/superpowers/specs/2026-11-27-credibility-end-to-end-fix-design.md)

## Global Constraints
- **Zero Mock Data & Zero Fabricated Verification:** Never synthesize `httpStatus: 200` / `VERIFIED` on unresolved redirects or invent citations (`verdictGate` remains strict, `C1`).
- **Zero Cost Blowup:** Keep `gemini-4-hydrogen` out of routine paths; run at most **1 batched BigQuery SQL lookup per video** (`<=2500ms`, fail-open); Option A retry uses `claims = [missedClaim]` with `thinkingBudget: 512` (`C2`).
- **BigQuery Flag Unification (`2A`):** Reconcile `functions/src/config/env.ts` and `functions/src/analytics/bigqueryService.ts` (`ENABLE_BIGQUERY_ANALYTICS` default enabled in runtime when not `"false"`, disabled in `NODE_ENV === "test"` unless injected/mocked).
- **1A + Option 1 Policy:** Past years `< current UTC year` (`2014`, `1969`, etc.) must **never** be marked volatile; Tier 2 stays slim (`<1ms` RAM math/guard) while BigQuery + Cache own growing knowledge.
- **Zero-Trust Chat Security:** `aiCredibilityChat` must never trust client-supplied claim verdicts or sources; only read Firestore / GCS (`factCheckUrl`).
- **Flutter & Project Rules:** Zero `setState()` (GetX only); Zero Raw Developer Errors; Zero Charm Pricing; WCAG AA verified by `flutter test test/core/ui_contrast_guard_test.dart`; preserve all existing unrelated uncommitted dubbing edits in the working tree (`git checkout` / `reset` forbidden; verify via builds/tests before committing).

## Review Focus
1. **Past-Year vs Volatile Boundary:** Claims containing settled past years (`"Modi elected PM in 2014"`, `"Apollo 11 in 1969"`) vs live markers (`"currently"`, `"today"`, current year) being either falsely invalidated or over-cached across mutable updates — pinned in Task 1 & Task 2 tests.
2. **BigQuery Failure / Timeout / Schema Drift:** BigQuery timeout (`>2500ms`), network failure, or legacy `raw_claims_verified` tables missing new columns must fail-open smoothly (`no pipeline crash`) — pinned in Task 1 tests.
3. **Unresolved Grounding Redirects & File Extension False Positives:** `vertexaisearch.cloud.google.com` redirects failing HTTP check (`dead/soft-404`) must never become `VERIFIED`; `spacecentre.nz` / `.gov.uk` must resolve while `photo.png` / `report.pdf` / `video.mp4` must never be treated as domains — pinned in Task 3 & Task 6 tests.
4. **Zero-Trust Chat Under Partial Firestore State + Client App Check:** `chatWithCredibilityAi` / `streamCredibilityAiChat` falling back to GCS `factCheckUrl` without trusting client payloads, client SSE sending `X-Firebase-AppCheck`, and non-financial fallback when offline — pinned in Task 4 & Task 6 tests.
5. **Millisecond Double-Scaling & Audit Skew:** `startMs: 6000` (and numeric `"6000"`) formatting as `00:06` instead of `1:40:00`, plus `UNPROVEN` claims not inflating `CAUTION_HEAVY` and setting `lastEvidenceCheckAt: 0` on `FAIL` audit — pinned in Task 5 & Task 6 tests.

---

### Agent Partitioning (100% Disjoint File Ownership)
- **Agent 1 (Tasks 1–3):** `env.ts`, `bigqueryService.ts`, `claim-normalization.ts`, `claimCacheService.ts`, `deterministicRegistry.ts`, `tier0Knowledge.ts`, `multilingualPreRetrievalService.ts` (new), `verificationCascadeService.ts`, `sourceTrustService.ts`, `fusedGroundingService.ts`, `verdictGate.ts`, `backfill-claims-bigquery.ts` (new), `tier1_bigquery_cache.test.ts` (new), `multilingual_cascade_grounding.test.ts` (new).
- **Agent 2 (Tasks 4–5):** `reportQualityAudit.ts`, `06-credibility.ts`, `pipelineTriggers.ts`, `aiCredibilityChat.ts`, `credibility_audit_fixes.test.ts`, `report_audit_and_chat_fallback.test.ts` (new).
- **Agent 3 (Task 6):** `ai_credibility_chat_service.dart`, `video_analysis_screen.dart`, `video_analysis_helpers.dart`, `fact_check_models_helper.dart`, `video_analysis_claim_card.dart`, `video_analysis_chapters_section.dart`, `claim_detail_screen.dart`, `credibility_report.dart`, `source_url_sanitizer.dart`, `source_avatar_service.dart`, `credibility_ui_fixes_test.dart` (new).

---

## Agent 1 Tasks — Knowledge Store (`1A + 2A + Option 1`), Cascade & Tier 4

### Task 1: Flag Unification, BigQuery Ledger Schema & Evergreen Tier 1 Lookup (`1A + 2A`)

**Files:**
- Modify: `functions/src/config/env.ts`
- Modify: `functions/src/analytics/bigqueryService.ts`
- Modify: `functions/src/pipeline/utils/claim-normalization.ts`
- Modify: `functions/src/pipeline/services/claimCacheService.ts`
- Create: `functions/scripts/backfill-claims-bigquery.ts`
- Test: `functions/tests/pipeline/tier1_bigquery_cache.test.ts`

**Interfaces:**
- Produces in `functions/src/config/env.ts`: `resolveBigQueryAnalyticsEnabled(override?: boolean): boolean` (used identically by `env.ts` and `BigQueryAnalyticsService`).
- Produces in `functions/src/pipeline/utils/claim-normalization.ts`: `isSettledPastYearClaim(claimText: string, now?: Date): boolean` and exported normalization helpers.
- Produces in `functions/src/analytics/bigqueryService.ts`:
  - Extended `BigQueryVerifiedClaim` (`english_claim_hash?: string`, `semantic_hash?: string`, `evidence_schema_version?: number`, `rich_sources_json?: string`).
  - `lookupVerifiedClaimsBatch(params: { exactHashes: string[]; semanticHashes: string[]; schemaVersion: number; timeoutMs?: number }): Promise<BigQueryVerifiedClaim[]>`
  - Idempotent schema migration adding missing columns to `raw_claims_verified`.
- Produces in `functions/src/pipeline/services/claimCacheService.ts`:
  - `getBatch(claims: Array<{ claimId: string; text: string; englishCanonical?: string }>, options?: { enableBigQuery?: boolean }): Promise<Map<string, CachedClaimHit>>`
  - `set(claimText: string, entry: ..., englishCanonical?: string): Promise<void>`

- [ ] **Step 1: Write failing tests in `functions/tests/pipeline/tier1_bigquery_cache.test.ts`**
  - Test cases covering:
    1. Settled past-year claim `"Narendra Modi was elected PM in 2014"` (`isTimeSensitiveClaim(...) === false`, `isSettledPastYearClaim(...) === true`), whereas `"The RBI repo rate today is currently 6.5%"` and current/future years stay volatile (`true`).
    2. L1 + L2 miss -> hits mocked `BigQueryAnalyticsService.lookupVerifiedClaimsBatch` once for multiple claims (`QUALIFY ROW_NUMBER()`), reconstructs `richSources` with `claimStance` + `sourceKind`, warms L1 + L2 Firestore `claim_cache`, and returns hits (`0` LLM/Search calls).
    3. BigQuery lookup error or `>2500ms` timeout fails open cleanly returning empty BigQuery hits without throwing.
    4. Evergreen cache hit (`isEvergreen: true`, created 2 years ago): `ageSinceLastUrlCheck <= 30d` returns immediately (`0` HTTP checks); `ageSinceLastUrlCheck > 30d` runs `$0`-AI HTTP `verifyBatch` (rejects only when `isLiveVerificationRecord` is false or `isRetracted` is true; bumps `lastUrlCheckAt` and returns hit when `HTTP 200`).
    5. Cross-language Telugu + English phrasing sharing `englishExactHash` / `englishSemanticHash` hits same Tier 1 entry.
    6. `resolveBigQueryAnalyticsEnabled` matches across `env.ts` and `BigQueryAnalyticsService`.
    7. Backfill script helper (`buildBackfillRowsFromRecords` exported from `backfill-claims-bigquery.ts`) maps sample Firestore `claim_cache` & GCS `full.json` claims into deduplicated `BigQueryVerifiedClaim[]` with `stripEvidenceText` applied and respects dry-run vs `--apply`.
- [ ] **Step 2: Run Jest on new test file to confirm initial failure**
  - Run: `cd functions && npx jest tests/pipeline/tier1_bigquery_cache.test.ts` (Expected: FAIL).
- [ ] **Step 3: Implement `resolveBigQueryAnalyticsEnabled` in `env.ts` & extend `BigQueryAnalyticsService`**
  - Align `env.enableBigQueryAnalytics` and `BigQueryAnalyticsService` default (`false` in `NODE_ENV === "test"` unless `config.enabled` / override set; enabled when `ENABLE_BIGQUERY_ANALYTICS !== "false"` in runtime).
  - Add `english_claim_hash`, `semantic_hash`, `evidence_schema_version`, `rich_sources_json` to `raw_claims_verified` schema & table-upgrade migration (`getMetadata` / `ALTER TABLE ADD COLUMN IF NOT EXISTS`).
  - Implement single batched `lookupVerifiedClaimsBatch(...)` with `2500ms` race timeout, `QUALIFY ROW_NUMBER() OVER (PARTITION BY ... ORDER BY timestamp DESC) = 1`, parameterized `UNNEST(@hashes)` / `UNNEST(@semHashes)`, `is_grounded = TRUE`, and fail-open catch/logging.
- [ ] **Step 4: Implement `isSettledPastYearClaim` & Evergreen `1A` Tier 1A -> 1B -> 1C flow in `claimCacheService.ts`**
  - Fix `isTimeSensitiveClaim` so years strictly `< new Date().getUTCFullYear()` are not volatile unless paired with live present markers.
  - Store `isEvergreen`, `ttlMode: "evergreen_url_checked"`, `lastUrlCheckAt`, `englishExactHash`, `englishSemanticHash`, `richSources` (with `stripEvidenceText`).
  - Implement strict `L1 -> L2 Firestore (batches of 30 + bounded semanticHash) -> Tier 1C BigQuery 1-query lookup -> warm backfill -> 0-AI HTTP check on age > 30d & retraction check`.
- [ ] **Step 5: Implement `functions/scripts/backfill-claims-bigquery.ts`**
  - Dry-run by default (`--apply` required to write, `--limit`, `--source=cache|gcs|both`), paginated iteration over `claim_cache` & GCS `factChecks/*/full.json`, deduplicating by `normalized_claim_hash`, exporting testable transformation helper.
- [ ] **Step 6: Run Jest & confirm Task 1 passes**
  - Run: `cd functions && npx jest tests/pipeline/tier1_bigquery_cache.test.ts` (Expected: PASS, 0 failures).

---

### Task 2: Option 1 Slim Multilingual Tier 2 + Domain-Wide `$0` Pre-Retrieval + BigQuery Writeback

**Files:**
- Modify: `functions/src/pipeline/services/deterministicRegistry.ts`
- Modify: `functions/src/pipeline/services/tier0Knowledge.ts`
- Create: `functions/src/pipeline/services/multilingualPreRetrievalService.ts`
- Modify: `functions/src/pipeline/services/verificationCascadeService.ts`
- Test: `functions/tests/pipeline/multilingual_cascade_grounding.test.ts`

**Interfaces:**
- Consumes from Task 1: `ClaimCacheService.getBatch/set`, `BigQueryAnalyticsService.enqueueVerifiedClaim`, `isSettledPastYearClaim`.
- Produces in `functions/src/pipeline/services/multilingualPreRetrievalService.ts`:
  - `batchResolveMultilingualCanonical(claims): Promise<Map<string, string>>` (extracts bracketed English + 1x `gemini-3.5-flash-lite` batch translation, safe in `NODE_ENV === "test"` & fails open).
  - `gatherDomainWidePreRetrieval(claims, preResolvedEnglishMap?: Map<string, string>): Promise<VerifiedSource[]>` (runs across all factual domains: Wikipedia EN+native, Wikidata, conditional PubMed/Crossref/WorldBank/FRED with `800ms` timeout).
- Consumes in Task 3: `FusedGroundingService.verifyBatchFused(claims, domain, options)` accepting `preRetrievedEvidence` and single-claim `[missedClaim]` retry flag.

- [ ] **Step 1: Add failing tests for Task 2 in `functions/tests/pipeline/multilingual_cascade_grounding.test.ts`**
  - Cases:
    1. Bilingual Telugu claim `"[అపోలో 11 / Apollo 11] రాకెట్ 1969 జూలై 16న చంద్రుడి మీదకి బయలుదేరింది"` & `"Apollo 11 landed on the moon in 1969"` resolve via normalized English in Tier 2 (`deterministicRegistry.ts` / `tier0Knowledge.ts`), include `claimStance: "SUPPORTS"`, `sourceKind: "REFERENCE"` / `"PRIMARY_RECORD"`, and pass `applyVerdictGateToClaim`.
    2. Anti-poisoning check preserved: `"Apollo 11 was faked in 1969"` and `"Apollo 11 landed on Mars in July 1969"` return `null` from Tier 2.
    3. `analyzeClaimForTierRouting` does NOT bypass Tier 1 for settled past years (`2014`, `1969`), while current year/live market figures retain volatile routing.
    4. `gatherDomainWidePreRetrieval` runs Wikipedia/Wikidata pre-retrieval for `History` / `General` / `Space` claims (not gated solely to `HEALTH_MEDICAL`/`Science`) and reuses `preResolvedEnglishMap` without a duplicate translation LLM call.
    5. `executeCascade` enqueues newly verified Tier 2 and Tier 4 claims into `BigQueryAnalyticsService.enqueueVerifiedClaim` and skips Tiers 2–4 completely on Tier 1 hits (`0` LLM/Search calls).
- [ ] **Step 2: Run Jest to verify initial failures**
  - Run: `cd functions && npx jest tests/pipeline/multilingual_cascade_grounding.test.ts` (Expected: FAIL).
- [ ] **Step 3: Expand `resolveApollo11` carefully in `deterministicRegistry.ts` & stamp `claimStance`/`sourceKind` in `deterministicRegistry.ts` & `tier0Knowledge.ts`**
  - Keep strict whole-sentence/value comparison rules; add launch date (`July 16, 1969`), landing date (`July 20, 1969`), ~8-day duration, and ~384,400 km / ~400,000 km lunar distance checks. Stamp explicit `claimStance` and `sourceKind: "REFERENCE"` / `"PRIMARY_RECORD"` + verified `urlVerification`.
- [ ] **Step 4: Create `multilingualPreRetrievalService.ts` & wire `verificationCascadeService.ts`**
  - Run `batchResolveMultilingualCanonical` once upfront; feed both `claim.text` and `englishCanonical` to `ClaimCacheService.getBatch` and slim Tier 2; fix `analyzeClaimForTierRouting` (`year < current UTC year` not volatile); pass `gatherDomainWidePreRetrieval` across all empirical domains into Tier 4; wire Option A single-claim retry on sourceless/unproven factual claims; enqueue verified Tier 2 & Tier 4 results to BigQuery + Firestore `claim_cache`.
- [ ] **Step 5: Run Task 2 unit tests to confirm pass**
  - Run: `cd functions && npx jest tests/pipeline/multilingual_cascade_grounding.test.ts`.

---

### Task 3: ccTLD Domain Inference, Real Redirect Unwrapping, Real Pre-Retrieval Tiers, Stance Match & Option A Retry

**Files:**
- Modify: `functions/src/pipeline/services/sourceTrustService.ts`
- Modify: `functions/src/pipeline/services/fusedGroundingService.ts`
- Modify: `functions/src/pipeline/services/verdictGate.ts`
- Test: `functions/tests/pipeline/multilingual_cascade_grounding.test.ts` (append Task 3 assertions)

**Interfaces:**
- Consumes: `urlVerificationService.verifyBatch`, `isLiveVerificationRecord`, `classifySourceStances` (`functions/src/pipeline/services/stanceClassifier.ts`), `sourceTrustService.resolveSourceTrust/resolvePublisher/inferDomainFromTitle`.
- Produces: Hardened `FusedGroundingService.verifyBatchFused` (strict `C1` + `C2`).

- [ ] **Step 1: Add failing tests for Task 3 in `functions/tests/pipeline/multilingual_cascade_grounding.test.ts`**
  - Cases:
    1. `sourceTrustService.inferDomainFromTitle` extracts `"spacecentre.nz"`, `"bbc.co.uk"`, `"csiro.au"` while ignoring `"photo.png"`, `"doc.pdf"`, `"clip.mp4"`, `"data.json"`, `"index.html"`.
    2. `FusedGroundingService` never stamps synthetic `{ status: "VERIFIED", httpStatus: 200, verifierMethod: "grounding_resolved" }` on unresolved `vertexaisearch.cloud.google.com` redirects; unwraps via `UrlVerificationService.verifyBatch`, preserves real `uv.excerpt` / passage snippets instead of `v.summary`, and quarantines dead/unverified links.
    3. `preRetrievedEvidence` uses real `sourceTrustService.resolveSourceTrust(...)` tiers (`wikipedia.org` is NOT hardcoded `"A"`; PubMed/NASA keeps Tier `"A"`).
    4. `disputed`/`misleading` claims or `contradictingChunkIndices` do NOT force `SUPPORTS`; batched `classifySourceStances` runs over already-fetched passages/`uv.evidenceText`.
    5. Micro-batch claim returning `richSources.length === 0` or `unproven` triggers Option A single-claim retry (`claims = [missedClaim]`, `thinkingBudget: 512`), bounded by budget.
    6. `verdictGate.ts` allows genuine `.gov` archival/mission paths (`/mission/apollo-11/`) as `"PRIMARY_RECORD"` / `"REFERENCE"` while keeping `/press-release/`, `/news/`, `/speeches/` as `"OFFICIAL_STATEMENT"` (`C1`).
- [ ] **Step 2: Run Jest to see Task 3 tests fail**
- [ ] **Step 3: Implement `sourceTrustService.ts`, `fusedGroundingService.ts`, `verdictGate.ts`**
- [ ] **Step 4: Re-run `tier1_bigquery_cache.test.ts` + `multilingual_cascade_grounding.test.ts`**
  - Run: `cd functions && npx jest tests/pipeline/tier1_bigquery_cache.test.ts tests/pipeline/multilingual_cascade_grounding.test.ts && npx tsc --noEmit`.

---

## Agent 2 Tasks — Credibility Engine Orchestration, Chat GCS Fallback, Quality Audit (`C3`) & Existing Tests

### Task 4: Fix `reportQualityAudit`, Stage 10 Deduplication, Priority Heal (`C3`) & BigQuery Flush

**Files:**
- Modify: `functions/src/pipeline/services/reportQualityAudit.ts`
- Modify: `functions/src/pipeline/layers/06-credibility.ts`
- Modify: `functions/src/pipeline/pipelineTriggers.ts`
- Create: `functions/tests/pipeline/report_audit_and_chat_fallback.test.ts`

**Interfaces:**
- Consumes from Agent 1 (only runtime import): `BigQueryAnalyticsService` (`bigqueryAnalyticsService.flush()`).
- Produces: Clean `auditCredibilityReport` (`unprovenClaims` / `unprovenRatio`), URL-deduped `aggregatedSources` keeping distinct excerpts, `lastEvidenceCheckAt: 0` marker on `FAIL` audit (`C3`), explicit BigQuery buffer flush before `handleCredibility` exit.

- [ ] **Step 1: Write failing tests in `functions/tests/pipeline/report_audit_and_chat_fallback.test.ts`**
  - Cases covering:
    1. Report with 26 `unproven`, 2 `caution`, 1 `verified_true`, 1 `false_claim` reports `unprovenClaims === 26`, does NOT inflate `caution` to `28`, and does NOT trigger `CAUTION_HEAVY`.
    2. `recordReportQualityAudit` on `grade === "FAIL"` with `ZERO_SOURCE_FACTS` or `UNVERIFIED_SOURCE` updates audit/freshness marker with `lastEvidenceCheckAt: 0` without emitting recursive Pub/Sub events (`C3`).
    3. Canonical URL deduplication merges duplicate `nasa.gov` entries by URL/path cleanly without dropping distinct titles/excerpts from separate NASA mission pages.
- [ ] **Step 2: Run Jest to verify failure**
- [ ] **Step 3: Implement fixes in `reportQualityAudit.ts`, `06-credibility.ts`, and `pipelineTriggers.ts` (`flush()` guard)**
- [ ] **Step 4: Run Jest to verify Task 4 passes**

---

### Task 5: Zero-Trust GCS `factCheckUrl` Chat Fallback & Repair `credibility_audit_fixes.test.ts`

**Files:**
- Modify: `functions/src/pipeline/aiCredibilityChat.ts`
- Modify: `functions/tests/pipeline/credibility_audit_fixes.test.ts`
- Modify: `functions/tests/pipeline/report_audit_and_chat_fallback.test.ts`

**Interfaces:**
- Produces: Zero-Trust GCS `factCheckUrl` fallback loader shared cleanly between `chatWithCredibilityAi` and `streamCredibilityAiChat` (reusing one helper function; ignores any client-tampered claims/sources).

- [ ] **Step 1: Add failing tests in `functions/tests/pipeline/report_audit_and_chat_fallback.test.ts`**
  - Cases:
    1. When Firestore `credDoc` / `uiReport` / `StreamingClaimProcessor.getLiveClaims` have `0` claims/sources, backend resolves `factCheckUrl` (`vData.factCheckUrl || credDoc.data()?.factCheckUrl || video_jobs/{id}.outputs?.factCheckUrl`), loads GCS JSON report, and populates authoritative claims/sources/summary into the Zero-Trust chat prompt while ignoring tampered client payloads.
    2. Update `credibility_audit_fixes.test.ts` `#2` (`vid_gate_1..3` -> valid UUID v4 + mock `videos/{uuid}`) and `#5` (`allow write: if videoExists(videoId) && isVideoOwner(videoId) && docId != 'credibility';`).
- [ ] **Step 2: Run Jest on both files to verify `#2`/`#5` and new fallback test fail**
- [ ] **Step 3: Implement shared GCS `factCheckUrl` loader in `aiCredibilityChat.ts` & fix `credibility_audit_fixes.test.ts`**
  - Note: Preserve all unrelated existing changes already in `aiCredibilityChat.ts`!
- [ ] **Step 4: Run all backend credibility tests & TypeScript check**
  - Run: `cd functions && npx jest tests/pipeline/credibility_audit_fixes.test.ts tests/pipeline/report_audit_and_chat_fallback.test.ts && npx tsc --noEmit`.

---

## Agent 3 Tasks — Flutter Client Fixes & Regression Tests

### Task 6: App Check Header, Mobile Chat Context, Honest Fallback, ccTLD Domain/Favicon & Millisecond Timestamps

**Files:**
- Modify: `lib/features/video/data/services/ai_credibility_chat_service.dart`
- Modify: `lib/features/video/presentation/views/video_analysis_screen.dart`
- Modify: `lib/features/video/presentation/widgets/analysis/video_analysis_helpers.dart`
- Modify: `lib/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart`
- Modify: `lib/features/video/presentation/widgets/analysis/video_analysis_claim_card.dart`
- Modify: `lib/features/video/presentation/widgets/analysis/video_analysis_chapters_section.dart`
- Modify: `lib/features/video/presentation/views/claim_detail_screen.dart`
- Modify: `lib/features/video/data/models/credibility_report.dart`
- Modify: `lib/core/utils/source_url_sanitizer.dart`
- Modify: `lib/core/services/source_avatar_service.dart`
- Create: `test/features/video/credibility_ui_fixes_test.dart`

**Interfaces:**
- Produces in `video_analysis_helpers.dart` & `fact_check_models_helper.dart`:
  - `normalizeTimestampToMs(dynamic raw, {bool assumeSecondsForSmallNumbers = false})` + explicit `resolveClaimTimestampMs(Map claim, {bool isEnd = false})` so `startMs: 6000` / `start: 6000` -> `6000` (`00:06`), never `1:40:00`, while `startSeconds` converts seconds `* 1000`.
- Produces in `source_url_sanitizer.dart` & `source_avatar_service.dart`:
  - Domain extraction supporting multi-part ccTLDs (`.nz`, `.uk`, `.au`, etc.) from `title`/`publisher` when `url` is `vertexaisearch.cloud.google.com` or Google host, blocking file extensions, before falling back to `'Verified Source'` or Google `G` favicon.
- Produces in `ai_credibility_chat_service.dart`:
  - `streamCredibilityAi` sends `'X-Firebase-AppCheck': appCheckToken` when `StorageUtils.getAppCheckToken()` is non-empty; `_synthesizeLocalHeuristicMessage` synthesizes strictly from real `cachedClaims`/`cachedSources` or honest unavailability copy (zero Jio/IPO financial copy).

- [ ] **Step 1: Write failing Flutter tests in `test/features/video/credibility_ui_fixes_test.dart`**
  - Cases:
    1. `VideoAnalysisHelpers.normalizeTimestampToMs(6000)` == `6000` (`00:06`), `"01:40"` == `100000`, `resolveClaimTimestampMs({'startMs': 6000})` == `6000`, `resolveClaimTimestampMs({'startSeconds': 6})` == `6000`, and `fact_check_models_helper.dart` `normalizeTimestampToMs(6000)` == `6000`.
    2. `SourceUrlSanitizer` resolves `"spacecentre.nz"` from title/publisher when `url` is `"https://vertexaisearch.cloud.google.com/grounding-api-redirect/..."` (does not return `'Verified Source'`), and ignores `"image.png"` / `"document.pdf"`.
    3. `SourceAvatarService.resolveAvatarUrl` skips `vertexaisearch.cloud.google.com` / `google.com` when `title` or `publisher` contains `"spacecentre.nz"`, returning a favicon URL for `spacecentre.nz`.
    4. `_synthesizeLocalHeuristicMessage` (or extracted `@visibleForTesting` `buildLocalHeuristicFallback`) contains real claim count metrics (`verified`, `caution`, `false`, `no evidence yet`) without `"Forward-looking financial forecasts"` / corporate milestones boilerplate, and SSE request builder helper attaches `X-Firebase-AppCheck` when token provided.
- [ ] **Step 2: Run `flutter test test/features/video/credibility_ui_fixes_test.dart` to confirm failure**
- [ ] **Step 3: Implement all Flutter fixes cleanly (GetX only, zero `setState`, preserve unrelated working-tree changes)**
- [ ] **Step 4: Run `flutter analyze`, `flutter test test/features/video/credibility_ui_fixes_test.dart`, and `flutter test test/core/ui_contrast_guard_test.dart`**

---

## Final Integration & Verification Tasks (Coordinator After Parallel Workers Return)

- [ ] **Step 1:** Review diffs across all 3 agents (`git diff` on all touched files) to confirm zero conflicts, zero mock data, zero raw error leaks, and adherence to `.agents/rules`.
- [ ] **Step 2:** Run full backend build (`cd functions && npm run build`) and full credibility Jest suites (`credibility_audit_fixes.test.ts`, `tier1_bigquery_cache.test.ts`, `multilingual_cascade_grounding.test.ts`, `report_audit_and_chat_fallback.test.ts`, plus existing credibility test files).
- [ ] **Step 3:** Run full Flutter static analysis & tests (`flutter analyze`, `flutter test test/features/video/credibility_ui_fixes_test.dart`, `flutter test test/core/ui_contrast_guard_test.dart`, `flutter test test/video_timestamp_test.dart`, `flutter test test/topic_timestamp_test.dart`).
- [ ] **Step 4:** Dispatch a fresh final whole-branch code reviewer subagent (`superpowers:requesting-code-review`) over the complete diff and address any Critical/Important findings before presenting the verified report.

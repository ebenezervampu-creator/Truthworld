# Task: Translation accuracy + dub sync fixes (07-dubbing translation path)

Date: 2026-11-25. Read `CLAUDE.md` first. Its rules apply, especially #6 (keep working architecture, make small testable changes) and #7 (no unmeasured claims).

**About "100% accuracy":** no test can show a translation is 100% accurate, and CLAUDE.md rule 7 forbids claiming it. This task sets something you can check instead. Every spoken and subtitle line must pass the same checks before it is voiced or published: numbers, negation, meaning, glossary and timing. Any line that still fails after repair stops the language; it is never voiced as-is. Report results as counts from real runs, e.g. "0 of 214 lines unresolved (log X)".

---

## 0. Audit verification (done by Claude, 2026-11-25, reading the code on the PC)

The audit you were given is **mostly correct**. Every claim below was checked against the current files. Line numbers are from today's files.

| # | Audit claim | Verdict | Evidence |
|---|---|---|---|
| 1a | Subtitles re-translate from scratch and ignore the dub's dual-track `subtitleText` | **True** | `multilingual_subtitle_localizer.ts:171` builds sentences from `sourceWords` (fallbackSegments only used when there are no words). Line 195: `isContextualDubbingEditEnabled()` → `translateSubtitleSentences` (new v3 draft + new Gemini edit). |
| 1b | No cast/relationships/speakerNames/castGenderByLabel reach the subtitle pass | **True** | `07-dubbing.ts:2849` `subtitleExtras` has none of them; `localizeTrack` (localizer:151) has no params for them; `translateSubtitleSentences` (translation.ts:1208) accepts them but is never given them. |
| 1c | Subtitle pass skips `TranslationQualityGate` and the Telugu lexicon guard | **True** | translation.ts:1208–1258: no quality gate, no `applyTeluguTheologicalLexiconGuard`. |
| 1d | "Subtitles diverge from the dub" | **Partly true: some divergence is intended.** | The comment at localizer:196 says subtitles are deliberately a *faithful* translation, not the shortened dub text. Wording may differ. **Honorifics, names, terms and numbers must not differ.** Today they can. |
| 2a | Polarity flip / low semantic score only set `reviewRecommended`; nothing blocks | **True** | translationQualityGate.ts:118–131 only warns. `polarityFlipped` is just copied through (07-dubbing.ts:5178, 5250, 6134). `quality-gate.ts:77` `BLOCKING_VIOLATION_PREFIXES` has no translation entry. |
| 2b | Numeric repair is a no-op without Adaptive MT, and subtitles are never repaired | **True** | translation.ts:1696: repair only `if (this.adaptiveMtClient)`, otherwise it returns the input. translation.ts:991–995 updates `translatedTexts` only, never `subtitleTexts`. |
| 3a | Back-translation is always to `"en"`; English-only negation regex and ASCII tokenizer | **True** | translation.ts:983, 985 (`"en"`); translationQualityGate.ts:44 (regex) and :165 (`[^a-z0-9]`). |
| 3b | Glossary is empty for non-English sources | **True** | translation.ts:1305. |
| 3c | `checkEditedLine` "untranslated" test compares the target to `"en"` | **True** | geminiDubbingEditor.ts:337. |
| 4a | Two different speech-rate models | **True** (already listed as open in project doc `dubbing-pipeline-audit-2026-11-21` A3) | Editor: `countSourceSyllables` ÷ table (te 4.8 × 1.1), geminiDubbingEditor.ts:147–203. Pre-TTS filter: `estimateSpeechDurationMs`, Indic code points ÷ 2.4 at 5.5/s plus pauses, 07-dubbing.ts:195. On one Telugu sample line Claude ran, the editor counts 23 syllables (~4.8 s at 4.8/s) and the filter estimates 3.5 s. That is one line, not a measurement of the gap across a film. |
| 4b | Measured voice rate is logged but never used | **True** | 07-dubbing.ts:3308–3331 is telemetry only. The post-TTS `retranslateConcise` (3386) uses the static table. |
| 4c | Concise retakes accepted on `.length` (characters) | **True** | 07-dubbing.ts:3232 and 3414. |
| 4d | A rejected edit falls back to the over-budget draft | **True** | geminiDubbingEditor.ts:1223 `text = check.ok ? candidate : seg.draft`. The tighten pass then `continue`s on a failed check (~1256), so the line stays over budget. |
| 4e | Concise dub rewrites don't update subtitles | **True, but intended.** Subtitles should stay faithful, not follow the shortened dub. **No change; lock it with a test.** | |
| 5a | `retranslateConcise` triggers a new localization bible | **Partly true** | It never passes `bible` or `inferBible:false` (translation.ts:742–765). With a cast list it re-infers a bible (an extra Gemini call). Without one it falls back to a default register (geminiDubbingEditor.ts:915–934), which can flip address forms. Both are wrong. |
| 5b | `creatorDNA`, `targetPlatform`, `enableABHooks` unused | **True** | Only declared at translation.ts:831–833; never read. |
| 5c | `isSong` ignored by the editor | **True, and worse:** `isSong` is never set at all. `translateWithCache` (07-dubbing.ts:5141–5157) doesn't forward it, and dubbing segments never get it from `songIntervalsMs`. |
| 5d | `visualSceneNotes` never supplied | **True** | Field exists (geminiDubbingEditor.ts:84). `applyContextualDubbingEdit` (translation.ts:1175) never sets it, though `getScreenContent` already starts at 07-dubbing.ts:588. |
| 5e | Dubbing window ignores `shotChangesMs` | **True** | `permissibleWindowMs` (geminiDubbingEditor.ts:210) and the inline copies (07-dubbing.ts:3162–3178, 3343–3355) take no shot changes. |

**Issues the audit missed (also verified):**
- **M1:** `editChunk` uses Gemini's `subtitleText` **without checking it**, even when the spoken line from the same reply was rejected (geminiDubbingEditor.ts:1224–1226). The subtitle can then carry a number or drift error that the dub line was rejected for.
- **M2:** The polarity check only runs on ~10% of lines plus claim, hook and number lines (`sampleRate: 0.10`, translation.ts:973). The Gemini meaning check does cover every spoken line, but an `"unresolved"` result is only logged and then voiced (geminiDubbingEditor.ts:708, 1160–1196).
- **M3:** `checkNegationPolarityFlip` decides negation by whether the count of negation words is odd or even, so "not … never" counts as positive. Even for English it is a weak check.
- **M4:** On the legacy (non-hybrid) cache path, cache hits get fixed perfect quality flags (`numericalParityVerified: true`, `semanticParityScore: 1.0`) and `subtitleText = dub text` (07-dubbing.ts:5198). This only applies when the hybrid flag is off.
- **M5:** The pre-TTS and post-TTS loops each re-implement `permissibleWindowMs` inline instead of calling the exported function. Three copies can drift apart.

---

## Decisions already made for you (change them only if the owner says so)
- **D1:** Subtitles stay *faithful* (not dub-shortened). Dubbed languages get them from the **same** contextual pass as the dub (dual-track `subtitleText`). A second translation pass runs only for languages that have subtitles but no dub.
- **D2:** A line still failing after repair (polarity flip, number mismatch, or meaning `unresolved`) is a **blocking** violation for that language. Add flag `DUBBING_BLOCK_ON_TRANSLATION_ERRORS` (default `true`) so it can be rolled back. A blocked language goes through the existing failed-language and refund path.
- **D3:** Sung lines (`isSong`) are translated faithfully, with **no syllable compression**, and marked in the segment. Before changing anything, read how `faithful-mix.ts` handles `songIntervalsMs` and report it. Do not change mixing behaviour for songs in this task.
- **D4:** If `enableABHooks` has no defined behaviour anywhere, remove it from the translation options; don't invent one. `creatorDNA` and `targetPlatform` get wired in (Phase 4).

---

## Phase 1: one source of truth for dub and subtitles
1. **Reuse dual-track subtitles for dubbed languages.**
   - Add an optional `preTranslatedSentences` input to `MultilingualSubtitleLocalizer.localizeTrack`: `{ startMs, endMs, speaker, sourceText, text }[]` built from `dubbingSegs` (source timing + `subtitleText`).
   - When it is given, skip `extractSourceSentences` + `translateSubtitleSentences`. Still run phrase splitting, reading-speed condensing (`condenseSubtitleLines`), shot-change snapping, `conformCues`, the readability validator and the existing 80% coverage guard.
   - Pass it from `generateSubtitles` (07-dubbing.ts:5288) on both the normal path and the long-video path (~6288).
   - The source-language track and subtitle-only languages keep today's path.
2. **Subtitle-only languages.** Pass `castList`, `relationships`, `speakerNames` and `castGenderByLabel` through `subtitleExtras` → `localizeTrack` → `translateSubtitleSentences`. Run the quality gate (Phase 2) and the Telugu lexicon guard on the result.
3. **Fix M1.** In `editChunk` and the tighten pass, validate `subtitleText` with `checkEditedLine` against the draft. If it fails, use the checked spoken text, or else the draft.
4. **Fix M4** on the legacy cache path: cached lines get quality flags `undefined` (not "passed") and go through the gate.
5. **Tests:** `subtitleText` reaches the cues unchanged apart from splitting. There is no second `batchTranslateV3`/Gemini call for a dubbed language (count calls via an injected generate fn). A concise dub retake does **not** change the subtitle text (locks 4e). M1 is covered with a rejected-spoken/bad-subtitle reply.

## Phase 2: gates that repair, then block
1. **Language-agnostic verification.**
   - Back-translate into `sourceLanguage`, not `"en"` (translation.ts:983/985).
   - Keep the regex polarity and Dice checks **only when the source is English**, and fix M3: decide negation per clause, not by an odd/even count.
   - For every other language, treat the Gemini meaning check (already covering every spoken line) as the semantic and polarity verifier. Extend its schema with `polarityFlipped: boolean` and `numbersChanged: boolean`.
   - Run the meaning check on the **subtitle** lines too (one call per 25 lines, as today).
2. **Repair without Adaptive MT.**
   - In `repairNumericalDrift`, if Adaptive MT is unavailable or its result fails the recheck, call `geminiDubbingEditor.editSegments` on that line with the drift details. The line must pass `NumericalEntityGuard` and `checkEditedLine`.
   - Add `repairMeaning(line, problem)`, which uses the same validator, for polarity and meaning failures.
   - Apply repairs to **both** `translatedTexts[i]` and `subtitleTexts[i]`.
3. **Block what can't be repaired.**
   - Add a segment field `translationBlockReason`.
   - Add the prefix `"Translation meaning error"` to `BLOCKING_VIOLATION_PREFIXES` (behind D2's flag).
   - `DubbingQualityGate.evaluate` lists each blocked line (index + reason).
   - **Order:** this check runs **before TTS**, so nothing is paid to ElevenLabs for a blocked language.
4. **Glossary for non-English sources** (translation.ts:1305). Match source text against `entry.translations[srcLang]` terms when the source isn't English. Return the target term as today.
5. **`checkEditedLine`:** `untranslated` when `baseLanguage(target) !== baseLanguage(source)` and the text equals the source.
6. **Tests:** the Gemini repair path when `adaptiveMtClient` is null; a repair updates the subtitle; a polarity flip that can't be repaired produces a blocking violation and no TTS call; a Hindi-source glossary hit; `untranslated` for a non-English target.

## Phase 3: close the timing loop
1. **One speech-rate model.**
   - Create `services/speech-rate.ts` holding the per-language rate table, the syllable counter (`countSourceSyllables`) and the pause allowance.
   - Base `estimateSpeechDurationMs` and `syllableBudgetForDuration` on it, and delete the duplicate.
   - Seed rates from measured logs where they exist (te 4.85, dub-test-te-1795516992008). Mark every other rate "not measured" in a comment.
2. **One window function.** Replace the inline copies (07-dubbing.ts:3162–3178, 3343–3355) with `permissibleWindowMs` (fixes M5).
3. **Per-voice rate.**
   - After first TTS, compute the median syllables/sec **per speaker**, using lines of 800 ms or more and 4 or more syllables (the same filter as the existing telemetry), and only when a speaker has at least 3 such lines.
   - Pass it as a new `syllablesPerSecond` option into `retranslateConcise` → `syllableBudgetForDuration(window, lang, rate)`.
   - Fall back to the table rate when there aren't enough lines.
4. **Accept retakes on duration, not characters** (07-dubbing.ts:3232, 3414).
   - Accept only if the estimated duration (at the measured rate when known) is lower **and** ≤ window × 1.15.
   - Otherwise don't pay for the retake.
5. **No silent over-budget draft** (fixes 4d).
   - When an edit is rejected and the result is > `maxSyllables × 1.15`, run one constrained tighten from the draft: preserve facts; the drift threshold may relax **only** for shortening.
   - If that also fails, keep the shortest candidate that passed the checks.
   - Log `overBudgetAfterEdit` per line.
6. **Shot changes.** Await `getScreenContent` (already started at 07-dubbing.ts:588) with a timeout before translation.
   - In `permissibleWindowMs`, a shot change may cap the **extra buffer after the source line ends**. It must never shorten the line's own source window, because dialogue legitimately runs across cuts.
   - Use the same value for the editor budget and the pre/post-TTS checks.
7. **Tests:** both estimators give the same number for the same text and language; the measured rate is used in the post-TTS budget; a retake that is shorter in characters but longer in duration is rejected; a shot change caps only the buffer.
8. **Out of scope for this task:** mapping AssemblyAI mid-sentence pauses to target-text pauses. Write it up as a follow-up.

## Phase 4: give the editor the context it is missing
1. **`creatorDNA` and `targetPlatform`** → `EditorOptions` → `buildSystemInstruction` and `generateLocalizationBible` (vibe, slang tolerance, vocabulary preference, custom instructions). Check field names in `creatorStyleService.ts`.
2. **`isSong`.** Set it on dubbing segments that overlap `songIntervalsMs` by 50% or more, forward it in `translateWithCache` → `translateSegments` → editor, and add a prompt rule (per D3).
3. **`visualSceneNotes`:** pass `onScreenText` events that overlap the chunk's time range (text + time). Also cross-check spoken references to on-screen text against its translated form.
4. **`retranslateConcise`:** keep the job's bible and `RollingHonorificCache` from the first `translateSegments` call (return it on `TranslationResult`, store it per language with the checkpoint) and pass `bible` + `inferBible: false` in both pre- and post-TTS calls. Also pass `castGenderByLabel`.
5. **Tests:** retakes make zero `generateLocalizationBible` calls; the creatorDNA text appears in the system instruction; song lines get no syllable budget.

## Phase 5: measure before and after on real videos (no dry runs, no mocks)
- Use real clips already on this PC, e.g. `local-dub-output` runs and the 12-min film (project docs `dubbing-12min-film-*`). Cover at least one multi-speaker, one non-English source and one fast-speech clip. Ask the owner if none of these exist for a case.
- Run each **before** your changes (current `main`) and **after**, same clips and languages. Record from the logs:
  - meaning check `kept/fixed/subtitle/unresolved`
  - gate numeric/polarity flags and blocked lines
  - pre-TTS and post-TTS retake counts
  - lines over budget after the edit
  - `[Dubbing:SyncCheck]` violations
  - subtitle readability report
  - v3 + Gemini calls per language (for the cost claim in 1a)
  - measured syl/s per voice
- Write the results to `functions/docs/translation-fidelity-results-<date>.md` as a table with the log file name for every number. Where something wasn't measured, write "not measured".

---

## Rules for this task
- One phase per change set. Run `npm run build` and `npm run test:dubbing` after each and report the counts of tests run and passed.
- Every behaviour change goes behind an env flag that defaults on, with a rollback value (follow `DUBBING_MEANING_CHECK`).
- Don't rewrite `07-dubbing.ts` wholesale. Extract only what you touch.
- Don't commit or deploy unless the owner asks. Report what you changed file by file, and say it is your own work, not independent verification.

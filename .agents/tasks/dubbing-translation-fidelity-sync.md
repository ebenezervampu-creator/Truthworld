# Task: Make dubbing translation faithful and in sync (subtitles, quality gates, timing, editor context)

Status: CHANGES REQUESTED (review 2026-11-26 01:05 IST). Assigned to: Gemini (Antigravity). Reviewer: Claude.
Created: 2026-11-25 by Claude.
Background:
- `functions/docs/translation-fidelity-sync-task-2026-11-25.md` (the audit check, with evidence for every finding)
- Truthworld project docs: `claude/dubbing-translation-audit-verification-2026-11-25.md`, `claude/dubbing-meaning-check-2026-11-24.md`, `claude/dubbing-pipeline-audit-2026-11-21.md` (A3)

Repo: TruthWorld. Read `CLAUDE.md` at the repo root and `.agents/rules/engineering.md` first, and follow them, in particular:
- preserve working architecture and make small, testable changes;
- no mock data;
- **no unmeasured claims**: never write "100% accurate", "verified" or "production-ready". Report counts from real runs and name the log file.

All paths below are relative to `functions/`. Line numbers are from the 2026-11-25 files; re-check them before editing, since files may have moved.

---

## Goal (what "done" means)
Every spoken line and every subtitle line passes the same checks before it is voiced or published: numbers, negation (polarity), meaning, glossary and timing.
- A line that fails is **repaired**.
- If repair also fails, the language is **stopped before any ElevenLabs spend** and goes through the existing failed-language and refund path. The line is never voiced as-is.
- Dub and subtitles for a language come from **one** contextual translation pass, so names, honorifics, terms and numbers always match.
- Subtitle wording may still be fuller than the dub. That is intended (Netflix-style faithful subtitles).

## Decisions already made (don't change them without asking the owner)
- **D1: one pass.** Subtitles for every non-source language reuse the dual-track `subtitleText` from `translateSegments(..., { enableDualTrack: true })`. Subtitles stay faithful: a concise dub retake never rewrites a subtitle.
- **D2: block on errors.** A line still failing after repair is a blocking violation. Rollback flag: `DUBBING_BLOCK_ON_TRANSLATION_ERRORS=false`.
- **D3: songs.** Sung lines are translated faithfully, with **no syllable compression**. Do not change song mixing in this task. Before coding Fix 4.2, report how `src/pipeline/services/faithful-mix.ts` treats sung passages.
- **D4: `enableABHooks`.** If nothing in the repo defines what it does, remove it from the translation option types and the call sites. Don't invent behaviour.

## Rollback flags
Every behaviour change goes behind an env flag. Default is on; `"false"` restores the old behaviour. Copy the pattern of `meaningCheckEnabled()` in `geminiDubbingEditor.ts:572`. Put the flags in one place, a new `src/pipeline/services/translation-flags.ts`:

| Flag | Covers |
|---|---|
| `DUBBING_SUBTITLES_FROM_DUB_PASS` | Fix 1.1 |
| `DUBBING_BLOCK_ON_TRANSLATION_ERRORS` | Fix 2.3 |
| `DUBBING_UNIFIED_SPEECH_RATE` | Fix 3.1 |
| `DUBBING_VOICE_RATE_CALIBRATION` | Fix 3.3 |
| `DUBBING_SHOT_CHANGE_WINDOW` | Fix 3.6 |
| `DUBBING_EDITOR_CONTEXT` | Fix 4.1–4.3 |

Fixes 1.3, 2.1, 2.2, 2.4, 2.5, 3.2, 3.4, 3.5 and 4.4 are bug fixes and need no flag.

## Before you code
1. Read every file named in Fixes 1–4 (`07-dubbing.ts` only around the lines given; it is 7,000 lines).
2. Write a short plan for each fix in this file, under `## Plan`: the functions you will change, new functions, the test file you will add, and the risks.
3. Then implement **one phase at a time**. After each phase run the Verify commands and append the counts to `## Result`.

---

## Phase 1: one source of truth for dub and subtitles

### Fix 1.1: Subtitles reuse the dual-track `subtitleText`
**Where:**
- `src/pipeline/services/multilingual_subtitle_localizer.ts`: `localizeTrack` (~151), `extractSourceSentences` (~64)
- `src/pipeline/layers/07-dubbing.ts`: `generateSubtitles` (~5288) and both callers: the normal path (~2867/2871) and the long-video path (~6288)

**Bug:**
- `localizeTrack` builds sentences from the source words and, because `isContextualDubbingEditEnabled()` is on by default, calls `translationService.translateSubtitleSentences` (~199). That is a second Translation LLM draft plus a second Gemini edit, with no cast, gender or bible and no quality gate.
- `fallbackSegments` (the dub's `subtitleText`) is ignored whenever words exist.
- Every non-source language already goes through `translateWithCache` with `enableDualTrack: true`, including subtitle-only languages (07-dubbing.ts ~2786 and ~6244). So `subtitleText` is always available for non-source languages.

**Change:**
1. Add an optional parameter to `localizeTrack`:
   ```ts
   preTranslatedSentences?: Array<{ startMs: number; endMs: number; speaker?: string; sourceText: string; text: string }>;
   ```
2. When it is given (and the flag is on):
   - Build `SourceSentence[]` from it: `startMs`, `endMs` and `speaker` come from the item.
   - Set `words` to the source words whose `start >= startMs - 50 && end <= endMs + 50`, so `anchorCuesToSpeech` still anchors to real speech.
   - Set `followingPauseMs` from the next item.
   - Use `item.text` as the translated text.
   - Skip `extractSourceSentences` and every translation call.
   - Everything after translation must still run unchanged: `SubtitleGuardrails.sanitize`, `segmentTranslatedSentence`, `retimeTargetPhrasesForSentence`, `anchorCuesToSpeech`, `conformCues` with shot changes, `condenseSubtitleLines` for cues too fast to read, the second `conformCues`, and `SubtitleReadabilityValidator`.
3. In `generateSubtitles`, when `language !== sourceLanguage` and every segment has a non-empty `subtitleText`, build `preTranslatedSentences` from `segments`:
   - `startMs: s.start`
   - `endMs: s.end`, the **source** end, not `actualSynthesizedDurationMs`: subtitles follow the original speech
   - `speaker: s.speaker`
   - `sourceText: s.originalText`
   - `text: stripAudioTagsForSubtitles(s.subtitleText)`

   Pass it in. Keep `fallbackSegments` as it is.
4. If any segment lacks `subtitleText` (e.g. an old checkpoint from before dual-track), use today's path (`translateSubtitleSentences`) and log `[MultilingualLocalizer] Dual-track subtitle text missing — translating subtitles separately` with `jobId`, `targetLanguage` and the missing count.
5. Keep `translateSubtitleSentences`; don't delete it. It remains that fallback.
6. Keep the coverage guard (`subtitleLineCoverage`, `MIN_SUBTITLE_LINE_COVERAGE`).

**Tests:** new file `tests/pipeline/dubbing_subtitles_from_dub_pass.test.ts`. Inject translation and Gemini through the existing seams; follow `tests/pipeline/gemini_dubbing_editor.test.ts` and `tests/unit/multilingualSubtitleLocalizer.test.ts`.
- With `preTranslatedSentences`, `batchTranslateV3` and `geminiDubbingEditor.editSegments` are called **0 times**. Spy on both.
- The cue text joined per sentence equals the given `text`, apart from line breaks and splitting.
- Cue times stay inside the sentence window plus the conformer's allowed extension, and no cue crosses a shot change in `shotChangesMs`.
- With one segment missing `subtitleText`, the old path is used and the warning is logged.
- With the flag `false`, behaviour is identical to today.
- Use real text from `tests/fixtures/stage4_joseph_request.json` or an existing real run in `local-dub-output`. No invented lines.

### Fix 1.2: Cast context for the fallback subtitle path
**Where:**
- 07-dubbing.ts `subtitleExtras` (~2849) and the long-path extras (~6288)
- `generateSubtitles` → `localizeTrack` → `translateSubtitleSentences`

**Change:**
- Pass `castList`, `relationships`, `speakerNames` and `castGenderByLabel` (from `castContext` / `loadCastContext`) all the way through.
- In `translateSubtitleSentences` (translation.ts ~1208):
  - pass `speakerNames` to the editor (it already accepts it);
  - run `TranslationQualityGate.evaluateQualityGate` on the results, as `translateSegments` does (Checkpoint B), and apply Phase 2's repair and block logic;
  - for `te`, apply `applyTeluguTheologicalLexiconGuard`.

**Tests:** the fallback path receives the cast fields (spy on `editSegments` opts), and a Telugu result has the lexicon guard applied.

### Fix 1.3: An unchecked subtitle line can ship (bug the audit missed)
**Where:** `src/pipeline/services/geminiDubbingEditor.ts`, `editChunk` (~1214–1268): lines ~1224–1226 and the tighten loop (~1250–1263).

**Bug:** `subText = candidateItem.subtitleText` is used **even when `checkEditedLine` rejected the spoken line from the same reply**. The subtitle line itself is never checked, so a subtitle can carry a lost number or drift that the dub was rejected for.

**Change:**
- Validate `candidateItem.subtitleText` with `checkEditedLine(seg, subtitleText, opts, candidateItem)`.
- If it passes, use it. Otherwise use the accepted spoken `text` if the spoken check passed, else `seg.draft`.
- Same rule in the tighten loop.
- Log the rejection reason as `subtitleRejectReason` in the result (add an optional field to `EditorLineResult`).

**Tests:** add to `tests/pipeline/gemini_dubbing_editor.test.ts`:
- a reply where the spoken line passes but the subtitle drops a number → the subtitle falls back to the spoken text;
- a reply where both fail → both fall back to the draft.

### Fix 1.4: Legacy cache path fakes perfect quality flags
**Where:** 07-dubbing.ts `translateWithCache` (~5196–5199). This only applies when the hybrid edit is off.

**Bug:** Cache hits get `numericalParityVerified: true`, `semanticParityScore: 1.0`, `reviewRecommended: false`, `polarityFlipped: false`, and `subtitleText = dub text`.

**Change:**
- Set those quality fields to `undefined`, meaning "not checked".
- Make sure Phase 2's pre-TTS block check (Fix 2.3) treats `undefined` as "not checked", not "failed".
- Add a comment explaining why.

**Test:** a cache hit has `undefined` quality fields and isn't blocked.

### Fix 1.5: Lock the intended behaviour
**Test:** after a pre-TTS or post-TTS concise retake (07-dubbing.ts ~3233 and ~3422), `normalised[i].subtitleText` is unchanged. Concise retakes only change the spoken text.

---

## Phase 2: gates that repair, then block

### Fix 2.1: Language-agnostic verification
**Where:**
- `src/pipeline/services/translation.ts` Checkpoint B (~965–995)
- `src/pipeline/services/translationQualityGate.ts`
- `src/pipeline/services/geminiDubbingEditor.ts` meaning check (`checkMeaning` ~1157, `resolveMeaning` ~685, `MEANING_CHECK` ~576)

**Bugs:**
- Back-translation always goes to `"en"` (translation.ts ~983, ~985).
- `NEGATION_REGEX` (gate ~44) and the ASCII tokenizer (gate ~165) only work for English.
- `checkNegationPolarityFlip` decides negation by an odd/even count of negation words, so "not … never" reads as positive.
- The back-translation spot check runs on only ~10% of lines plus claim, hook and number lines (`sampleRate: 0.10`, translation.ts ~973).

**Change:**
1. `backTranslateCallback` translates into `normSourceLang`, not `"en"`.
2. In `evaluateQualityGate`, run the regex polarity check and the Dice score **only when `baseLanguage(sourceLang) === "en"`**. For other sources, skip them and let the meaning check (point 3) decide.
3. Make the Gemini meaning check the semantic and polarity verifier for every language:
   - Extend its reply schema with `polarityFlipped: boolean` and `numbersChanged: boolean` per line.
   - Add both to the prompt's list of problems to look for. It already covers negation, so make it explicit and per line.
   - Return them on `EditorLineResult` as `meaningPolarityFlipped`, `meaningNumbersChanged`, and `meaningAction` (`kept | fixed | subtitle | unresolved`; today this is only counted in the log).
4. Run the meaning check on **subtitle** lines too. Today it is skipped when `opts.purpose === "subtitle"` (~1136). For subtitles, a `fixed` line is used only if it passes `checkEditedLine` and stays within `maxCharacters × 1.3`.
5. Fix `checkNegationPolarityFlip` for English: count negations per clause (split on `[,;:]|\b(but|and|or|because|so)\b`) and compare clause by clause, not by overall parity.
   - Keep the method signature.
   - Add cases to `tests/pipeline/translation_quality_gate.test.ts`: "not … never" (double negative), "isn't", and "nothing", using real lines from an existing run.
6. Pass `segments[i].isClaim` from 07-dubbing's segments into the gate input if it isn't already; check it.

### Fix 2.2: Repair without Adaptive MT, and repair subtitles too
**Where:**
- translation.ts `repairNumericalDrift` (~1685–1725)
- translation.ts Checkpoint B result loop (~991–995)

**Bugs:**
- Repair only happens when `this.adaptiveMtClient` exists; otherwise it returns the input unchanged.
- Repairs update `translatedTexts[i]` but never `subtitleTexts[i]`.

**Change:**
1. Keep the Adaptive MT attempt. If it is unavailable or its result fails the parity recheck, call `geminiDubbingEditor.editSegments` on that one line:
   - `draft: currentTranslation`;
   - a new optional `repairInstruction` on `EditorSegment`, used in `buildUserPrompt` as "Fix only this problem: <details>. Keep every number, unit and name from SOURCE.";
   - `bible` + `inferBible: false` (Fix 4.4);
   - a `maxSyllables` budget equal to the line's existing budget × `MEANING_CHECK.maxOverBudget` (accuracy wins over the budget, within the existing limit).

   Accept the result only if `NumericalEntityGuard.verifyNumericalParity` passes and `checkEditedLine` is ok.
2. Add `repairMeaning(source, current, problem, ctx)` with the same validator, for lines with polarity flipped, numbers changed or meaning `unresolved`.
3. Run the same repair on the subtitle text, and write repaired text to **both** `translatedTexts[i]` and `subtitleTexts[i]`.
4. Record per line: `repairAttempted`, `repairOutcome` (`repaired | failed`) and `translationBlockReason` (`"number_mismatch" | "polarity_flip" | "meaning_unresolved"`, or `undefined`). Carry these through `translateWithCache` onto `DubbingSegment` (types in `src/pipeline/types.ts`).

**Tests:** extend `tests/pipeline/translation_quality_gate.test.ts` and `tests/pipeline/google_translation_v3.test.ts`:
- `adaptiveMtClient === null` with a number drift → the Gemini repair is called and the repaired text is in both tracks;
- a repair that fails the recheck → the original is kept and `translationBlockReason: "number_mismatch"` is set.

### Fix 2.3: Block before paying for voices
**Where:**
- `src/pipeline/layers/quality-gate.ts`: `BLOCKING_VIOLATION_PREFIXES` (~77), `DubbingQualityGateParams`, `evaluate`
- 07-dubbing.ts, after translation and **before** the pre-TTS budget filter (~3150) on the normal path, and at the equivalent point on the long-video path (~6278)

**Change:**
1. Add `"Translation meaning error"` to `BLOCKING_VIOLATION_PREFIXES`, but only when `DUBBING_BLOCK_ON_TRANSLATION_ERRORS` is on. Make the list a function (or filter at check time) so the flag is read at runtime.
2. Add `translationBlockedLines?: Array<{ index: number; reason: string; source: string; text: string }>` to `DubbingQualityGateParams`. Each one becomes the violation `Translation meaning error: line <index+1> (<reason>): "<source>" → "<text>"`.
3. In 07-dubbing, before TTS: if any segment has `translationBlockReason` and the flag is on:
   - **Don't call TTS for that language.**
   - Fail it through the existing failed-language and refund path, the same one used for other blocking violations (find how `isBlockingViolation` results are handled after stitching and reuse that path; don't build a new one).
   - Log `[Dubbing:TranslationGate] Language blocked before TTS` with `jobId`, `targetLang`, `blockedCount` and the first 10 lines.
   - Subtitles for the language follow the same rule: don't publish a subtitle track that contains a blocked line. Use the line-based fallback only if the blocked line can be excluded; otherwise fail subtitles for that language too and say so in the notice.
4. Write the creator-facing notice with `addDubbingNotice` in plain, polite English, e.g.: "We couldn't produce a reliable <language> translation for a few lines, so this language wasn't dubbed and you won't be charged for it." No raw errors (CLAUDE.md rule 3). Put the code (`DUB_BLOCKED_TRANSLATION`) in `src/pipeline/services/dubbing-user-messages.ts`, following the existing messages.

**Tests:** extend `tests/pipeline/dubbing_quality_gate.test.ts` and add `tests/pipeline/dubbing_translation_block.test.ts`:
- a blocked line produces the violation, and `isBlockingViolation` is true with the flag on and false with it off;
- with a blocked segment, the TTS service is **never called** (spy) and the refund path is called.

### Fix 2.4: Glossary for non-English sources
**Where:** translation.ts `buildGlossaryTermsForEditor` (~1298–1320).

**Bug:** `if (!sourceLanguage.toLowerCase().startsWith("en")) return [];`

**Change:**
- When the source isn't English, match the source text against `entry.translations[srcBase]` terms (`preferred` plus any listed alternatives; check the `DOMAIN_GLOSSARY` entry shape in `terminology_glossary.ts`).
- When matched, emit `{ source: <the matched source-language term>, target: <target term as today>, sense }`.
- If an entry has no data for the source language, skip it.
- English behaviour stays the same.

**Test:** a Hindi-source line containing a Hindi glossary term returns the Telugu target term. Take a real term from `terminology_glossary.ts`.

### Fix 2.5: "Untranslated" check compares against English
**Where:** geminiDubbingEditor.ts `checkEditedLine` (~337).

**Change:** `untranslated` when `text === seg.source.trim() && baseLanguage(opts.targetLanguage) !== baseLanguage(opts.sourceLanguage)`.
- Add `sourceLanguage` to the `Pick<EditorOptions, ...>` type and to every call site (`resolveMeaning` included).
- For the same-language condense call (`condenseSubtitleLines`), source equals target, so this check won't fire there; that's correct.

**Test:** a Hindi→Telugu edit equal to the Hindi source is rejected, and a Telugu→Telugu condense equal to its input is accepted.

---

## Phase 3: close the timing loop

### Fix 3.1: One speech-rate model
**Where:**
- 07-dubbing.ts `estimateSpeechDurationMs` (~195)
- geminiDubbingEditor.ts `SYLLABLES_PER_SECOND` (~147), `syllableBudgetForDuration` (~199), `configuredSyllablesPerSecond` (~194)
- translation.ts `countSourceSyllables` (~459)

**Bug:** The two models count different units and use different rates.
- On one Telugu line, the editor counted 23 syllables (≈4.8 s at 4.8/s) and the pre-TTS filter estimated 3.5 s. This is one line, not a measured average.
- So the pre-TTS filter misses lines the editor considers too long, and they overflow after TTS and get paid for twice.
- This was already open as A3 in `claude/dubbing-pipeline-audit-2026-11-21.md`.

**Change:**
1. New file `src/pipeline/services/speech-rate.ts` exporting:
   - `SYLLABLES_PER_SECOND` (moved from the editor, same values);
   - `syllablesPerSecond(lang, measuredRate?)`;
   - `estimateSpeechDurationMs(text, lang, measuredRate?)` = `countSourceSyllables(stripTags(text), lang) / rate × 1000` + the existing punctuation pause allowance (commas 120 ms, stops 300 ms);
   - `syllableBudgetForDuration(windowMs, lang, measuredRate?)` with the same formula as today, including `TEMPO_HEADROOM`.
2. Move `countSourceSyllables` into `speech-rate.ts` and re-export it from translation.ts so existing imports keep working. Make sure this creates no import cycle (speech-rate must not import translation.ts or the editor).
3. Make 07-dubbing's `estimateSpeechDurationMs` and the editor's `syllableBudgetForDuration` / `configuredSyllablesPerSecond` delegate to `speech-rate.ts`. Keep the exported names (tests import them).
4. Rates:
   - Keep today's editor values.
   - For `te`, the comment must cite the measurement (4.85 syl/s, run `dub-test-te-1795516992008`).
   - Mark every other language `// not measured` and leave its value unchanged.
   - Collect more measurements from `"[Dubbing:Pacing] Measured speaking rate"` lines in `console-film*.txt` / `local-dub-output` logs. Only update a rate when there are at least 20 lines of evidence, and cite the file.
5. Flag off → the old `estimateSpeechDurationMs` body is used. Keep it as `estimateSpeechDurationMsLegacy`.

**Tests:** new `tests/pipeline/speech_rate_unified.test.ts`:
- for each of `te`, `hi`, `ta`, `en`, `es`, `zh`, the pre-TTS estimate and the editor budget agree: a line exactly at budget estimates within ±5% of the window ÷ `TEMPO_HEADROOM`;
- `countSourceSyllables` results are unchanged (snapshot on 10 real lines).
- Add the file to `test:dubbing`.

### Fix 3.2: One window function (bug the audit missed)
**Where:** 07-dubbing.ts pre-TTS (~3162–3178) and post-TTS (~3343–3355) re-implement `permissibleWindowMs` inline.

**Change:** replace both copies with `permissibleWindowMs(seg.start, seg.end, nextStartMs, totalVideoDurationMs || undefined)` from the editor (or move it to `speech-rate.ts` / `segment-timing.ts` and import it from there).

**Test:** for 50 consecutive real segments from a run, the inline result and the function result are equal before the change (write this test first and commit nothing until it passes).

### Fix 3.3: Use each voice's measured speed
**Where:**
- 07-dubbing.ts telemetry (~3308–3331)
- the post-TTS overflow loop (~3333–3430)
- `retranslateConcise` (translation.ts ~695)

**Bug:** The measured syllables/sec is only logged. The post-TTS concise retake budgets with the static table, so a slower cloned voice overflows again on the retake.

**Change:**
1. Compute the median rate **per speaker**, using lines with `ms >= 800 && syl >= 4` (the existing filter), only for speakers with at least 3 such lines. Keep the existing language-wide log line and add `bySpeaker`.
2. Add an option `syllablesPerSecond?: number` to `retranslateConcise`. Use it in `syllableBudgetForDuration(maxDurationMs, tgt, syllablesPerSecond)`.
3. In the post-TTS loop, pass the speaker's measured rate, falling back to the language-wide median, then to the table.
4. Store the measured rate per voice ID in the language checkpoint (`saveDubbingCheckpoint`) so a resume reuses it. Don't add a new Firestore collection.

**Tests:** in `tests/pipeline/dubbing_real_line_lengths.test.ts`:
- a speaker with a measured 3.8 syl/s gets a smaller `maxSyllables` than with the table rate 4.8;
- a speaker with only 2 measurable lines uses the language median.

### Fix 3.4: Accept retakes on duration, not characters
**Where:** 07-dubbing.ts ~3232 (pre-TTS) and ~3414 (post-TTS): `conciseTagged.length < seg.translatedText.length`.

**Change:**
- Accept only if `estimateSpeechDurationMs(concise, lang, rate) < estimateSpeechDurationMs(current, lang, rate)` **and** `estimateSpeechDurationMs(concise, lang, rate) <= window × 1.15`.
- Post-TTS uses the measured rate.
- If the new line is shorter but still over `window × 1.15`, don't pay for a retake. Keep the first take (the 1.15× stitch handles what it can) and log `[Dubbing:Pacing] Retake skipped — still too long` with the index and both estimates.
- Keep the `retryBudget.tryConsume` call, and only consume after deciding to retake. Today it consumes before calling Gemini; keep that order for the Gemini call, but don't count the TTS characters unless the retake is accepted. Check how `retryBudget` is used and don't break the margin rule in `dubbing-economics.ts`.

**Tests:**
- a concise line that is shorter in characters but longer in syllables is rejected;
- a line that is shorter but still over the window → no TTS call.

### Fix 3.5: Never fall back silently to an over-budget draft
**Where:** geminiDubbingEditor.ts `editChunk` (~1223: `text = check.ok ? candidate : seg.draft`) and the tighten loop (~1256: `continue` on a failed check).

**Change:**
1. After the edit and tighten passes, for each line where `maxSyllables` is set and `syllables > maxSyllables × TIGHTEN_TRIGGER`, run **one** constrained call with the existing `tightenOnly=true` prompt plus:
   - `draft` = the shortest text that has passed `checkEditedLine` so far (the draft if none);
   - a relaxed drift check **for this call only**: `MIN_DRAFT_SIMILARITY × 0.6`, while numbers, glossary, `label_leak` and `untranslated` checks stay strict;
   - the meaning check (Phase 2) runs on the result as usual, so meaning still wins.
2. Accept the result only if it passed the checks and is shorter in syllables.
3. Otherwise keep the shortest checked candidate.
4. Mark `overBudgetAfterEdit: true` on the result and log the count per job in the `[GeminiDubbingEditor] Edit complete` log.

**Tests:** in `tests/pipeline/gemini_dubbing_editor.test.ts`:
- an over-budget draft with a rejected edit triggers the constrained call;
- a constrained result that drops a number is rejected and the line is marked `overBudgetAfterEdit`.

### Fix 3.6: Respect hard scene cuts in the dub window
**Where:**
- `permissibleWindowMs` (geminiDubbingEditor.ts ~210)
- its callers: `applyContextualDubbingEdit` (translation.ts ~1135) and the 07-dubbing pre/post-TTS loops after Fix 3.2
- `getScreenContent` (`src/pipeline/services/screenContentAnalyzer.ts`), already started at 07-dubbing.ts ~588

**Change:**
1. Add an optional `shotChangesMs?: number[]` to `permissibleWindowMs`.
   - A shot change at time `t` with `endMs < t < hardCeiling` caps **only the extra buffer** after the source line ends: `maxEnd = min(maxEnd, max(endMs, t - 80))`.
   - It must **never** shorten the line's own window (`startMs` to `endMs`), because dialogue legitimately runs across cuts.
2. Before translation, await the already-started `getScreenContent` with a timeout (`DUBBING_SCREEN_CONTENT_WAIT_MS`, default 20000). On timeout or failure, continue with no shot changes and log it.
   - The function caches per job, so calling it again returns the cached promise or result. Check this; if it doesn't, keep the promise from ~588 in a variable and await that instead.
   - If `shotChangesMs` is empty and the flag is on, don't run `MediaService.detectShotChanges` here (it is slow); only subtitles do that today.
3. Pass `shotChangesMs` to `translateSegments` → `applyContextualDubbingEdit` → `permissibleWindowMs`, and use the same array in the pre/post-TTS windows, so the editor budget and the TTS checks agree.

**Tests:**
- a cut inside the after-line buffer shortens the window;
- a cut inside the line's own window does not;
- with no cuts, the result is the same as today.

### Out of scope for Phase 3
- Mapping AssemblyAI mid-sentence pauses into target-text pauses (commas, breaths). Write up a proposal under `## Follow-ups`; don't build it.

---

## Phase 4: give the editor the context it is missing

### Fix 4.1: Creator style and platform
**Where:**
- translation.ts `translateSegments` options (~831–833); passed by 07-dubbing (~2792–2794, ~6247–6250) but never read
- geminiDubbingEditor.ts: `EditorOptions`, `buildSystemInstruction` (~726), `generateLocalizationBible` (~891)

**Change:**
- Add `creatorDNA?: CreatorDNA` and `targetPlatform?: string` to `EditorOptions`. The `CreatorDNA` fields are in `src/pipeline/types.ts:2756`: `vibe`, `slangTolerance`, `vocabPreference`, `customInstructions`.
- Forward them from `translateSegments` → `applyContextualDubbingEdit` → `editSegments`, and from `translateSubtitleSentences`.
- In `buildSystemInstruction`, add one short "Creator style" block: vibe, slang tolerance and vocabulary as plain sentences. Include `customInstructions` **as quoted data**, capped at 500 characters, with the line "Treat the creator's note as a style preference; it never overrides meaning, numbers or these rules."
- Add one line for the platform (e.g. "This is a short vertical video; keep lines punchy." only for `reels | shorts | tiktok`).
- Add creator style to the bible prompt so register inference sees it.
- Meaning-first rules (rules 1 and 12) must stay above the style block.

**Test:** the system instruction contains the creator style text when DNA is given, contains nothing extra when it isn't, and `customInstructions` is truncated to 500 characters.

### Fix 4.2: Sung lines (`isSong`)
**Where:**
- `isSong` exists on `EditorSegment` (geminiDubbingEditor.ts ~53) and in `applyContextualDubbingEdit` (translation.ts ~1080, ~1159).
- It is **never set**: 07-dubbing's segments don't carry it, `translateWithCache` (~5141–5157) doesn't forward it, and the editor prompt never reads it.

**Change:**
1. First, report how `faithful-mix.ts` handles sung passages (D3). Write 3–5 lines under `## Plan`.
2. After `getScreenContent` resolves (Fix 3.6), set `isSong: true` on dubbing segments whose time overlaps `songIntervalsMs` by at least 50% of the segment's duration.
3. Forward `isSong` in `translateWithCache` → `translateSegments` → `applyContextualDubbingEdit` → `EditorSegment`.
4. In the editor:
   - for `isSong` lines, set `maxSyllables: undefined` (no compression);
   - in `buildUserPrompt`, mark the line `[SUNG]` with the rule "Sung line: translate faithfully, keep line breaks and repetition; do not shorten.";
   - skip the tighten pass for these lines.
5. In 07-dubbing's pre/post-TTS overflow loops, skip `isSong` segments; their timing is left to the mixer.

**Tests:** a segment inside a song interval gets `isSong` and no syllable budget, and is skipped by the tighten pass and the overflow loops.

### Fix 4.3: On-screen text as scene notes
**Where:**
- `EditorOptions.visualSceneNotes` (geminiDubbingEditor.ts ~84) is never set by `applyContextualDubbingEdit`
- `getScreenContent` returns `onScreenText` events (screenContentAnalyzer.ts ~93)

**Change:**
- Pass `onScreenText` events into `translateSegments`.
- In `applyContextualDubbingEdit`, build `visualSceneNotes` as one note per event: `"<mm:ss> on screen: \"<text>\""`, capped at 30 notes and 2000 characters total, plus the translated form if the analyzer provides it.
- Note: a non-empty `visualSceneNotes` makes `shouldInfer` true (~926–930), so the bible will be inferred for single-speaker videos with on-screen text. That is intended (one call per language).
- Add the prompt rule: "When a line refers to text on screen, use the same wording as the on-screen text's translation."

**Test:** `visualSceneNotes` is built and capped, and the editor receives it.

### Fix 4.4: Reuse the bible and honorific cache in retakes
**Where:**
- translation.ts `retranslateConcise` (~695–800): never passes `bible`, `inferBible: false` or `honorificCache`
- 07-dubbing.ts callers (~3198, ~3386)

**Bug:**
- With a cast list, every retake re-infers a localization bible: an extra Gemini call per overflowing line.
- Without one, the single-line call gets the default register (`tone`-based), which can flip an address form that the first pass chose.

**Change:**
1. Return the bible from `editSegments`. Add `lastBible` to the editor result, or return `{ results, bible }` from a new method and keep the old signature as a wrapper so tests keep passing.
2. Store it on `TranslationResult` as `localizationBible`, carry it through `translateWithCache`, and save it in the language checkpoint (`saveDubbingCheckpoint`, `stage: "translated"`) so resumes have it.
3. In both `retranslateConcise` call sites, pass `bible: <stored bible>`, `inferBible: false` and `castGenderByLabel`. Add `honorificCache` support to `retranslateConcise` options and pass a cache seeded from the bible.
4. Also pass `bible` + `inferBible: false` to the Fix 2.2 repair calls.

**Tests:**
- retakes make **0** `generateLocalizationBible` Gemini calls (spy on the generate fn);
- the retake's register equals the first pass's register for the same speaker pair. Use `tests/pipeline/localization_bible_register.test.ts` as the pattern.

### Fix 4.5: `enableABHooks` (D4)
Search the whole repo (including `lib/` and `admin-portal/`) for `enableABHooks` and `ABHook`.
- If nothing defines behaviour, remove it from the `translateSegments` / `translateWithCache` option types and the 07-dubbing call sites.
- If something does, stop and report what you found under `## Plan`. Don't wire it in.

---

## Phase 5: measure before and after on real videos
No dry runs and no mocks.

1. **Clips:** use real clips already on the PC. You need:
   - one multi-speaker clip;
   - one fast-speech clip;
   - the 12-minute film used in the 2026-11-25 run (see project docs `dubbing-12min-film-*`), **if** the owner agrees to the ElevenLabs spend. Ask first; write the estimated character count in your question;
   - **one non-English source clip.** If none exists, stop and ask the owner for one. Don't make one up.

   Use `scripts/dubbing/local-dub-test.ts` for `te` and `hi` (and `ta` if time allows).
2. **Before:** run on the current code first: either a git worktree at `HEAD` before your changes, or all the new flags set to `false`. Save the logs as `local-dub-output/fidelity-before-<lang>-<clip>.txt`.
3. **After:** run with all flags on. Save as `fidelity-after-...`.
4. Write `docs/translation-fidelity-results-2026-11-<dd>.md` with one table per clip and language. Each number gets its log file name:
   - lines; meaning check `kept / fixed / subtitle / unresolved`;
   - number-mismatch lines and polarity-flip lines, both before and after repair; blocked lines;
   - pre-TTS retakes, post-TTS retakes, retakes skipped (Fix 3.4); lines `overBudgetAfterEdit`;
   - `[Dubbing:SyncCheck]` violations;
   - subtitle readability report (from the localizer log);
   - Translation LLM calls and Gemini calls per language (count log lines or add a counter log; this checks the cost claim in Fix 1.1);
   - measured syl/s per speaker.

   Where something wasn't measured, write "not measured" and say why.
5. Don't summarise the results as a percentage of "accuracy". Report the counts.

---

## Verify (after each phase; all must pass)
```bash
cd functions
npm run build
npm run test:dubbing
npx jest tests/pipeline/gemini_dubbing_editor.test.ts tests/pipeline/translation_quality_gate.test.ts tests/pipeline/netflix_subtitles.test.ts tests/unit/multilingualSubtitleLocalizer.test.ts tests/unit/subtitlesRegressionAudit.test.ts tests/pipeline/world_class_translation.test.ts --runInBand --forceExit
npm run test
```
- `npm run build` must report 0 errors and keep the same number of functions in `functions.yaml` as before you started; record that number first.
- Add every new test file to the `test:dubbing` script in `package.json`. `gemini_dubbing_editor.test.ts` and `translation_quality_gate.test.ts` are **not** in that list today; add them too.
- If a test that passed before your change now fails, fix the cause. Don't weaken or delete the test. If you believe a test is wrong, explain why under `## Result` and leave it failing for review.

## Out of scope
- Don't change voice matching, cloning, gender logic, mixing/BGM, pricing or the 1.15× tempo cap.
- Don't change the Gemini model names or the Translation LLM model.
- Don't remove `translateSubtitleSentences`, `retranslateConcise` or any exported function. Rule: no removing functionality without approval; `enableABHooks` (D4) is the only exception.
- Don't commit, push or deploy.

## When done
Append a `## Result` section to this file with:
1. Files changed, each with one line on what changed.
2. Flags added and their defaults.
3. Test output per phase: the command, how many tests ran and how many passed or failed. Paste the summary lines.
4. The `functions.yaml` function count before and after.
5. A link to the Phase 5 results doc, or why it isn't done.
6. What you couldn't do, and any place where you departed from this task and why.
7. A list of follow-ups.

Then set Status to `READY FOR REVIEW`.

## Plan
(Gemini: write your plan here before coding.)

## Result
(Gemini: fill in when done.)

(Gemini posted its Plan and Result in chat instead of this file. Paste them above before the next review.)

## Review (Claude, 2026-11-26 01:05 IST)

**How this was checked:** I read the changed source files on the PC and diffed them against copies taken before the work. I did **not** re-run your test suite (it needs the full `node_modules`). The test counts below are yours (Result §3), not mine.

### Accepted (checked in the code)
- **Fix 1.1:** `generateSubtitles` passes `preTranslatedSentences` built from `s.start` / `s.end` (the source timing) and `stripAudioTagsForSubtitles(s.subtitleText)`. `localizeTrack` skips translation and still runs sanitize → segment → retime → anchor → conform → condense → validate. The fallback warning is logged when `subtitleText` is missing.
- **Fix 2.3 (normal path):** the block is evaluated before TTS (07-dubbing.ts ~2906). `isDubbingSupportedForTarget` is false for a blocked language, `dubOutcome = "failed"`, so the language lands in `failedLangs` → `refundDubbingFeeOnFailure` (~1605). The notice is plain English.
- **Fix 3.1:** `countSourceSyllables` in `speech-rate.ts` gives **identical** counts to the old translation.ts version. I compared 13 real lines (en, te, hi, ta, zh, es): 13 of 13 equal. Your "snapshot update" only corrected the test's expected values.
- **Fix 3.4 (post-TTS):** acceptance uses `estimateSpeechDurationMs` with the speaker's measured rate (falling back to the voice's rate, then the language median). Speakers need at least 3 lines with ms ≥ 800 and syl ≥ 4.
- **Fix 3.5:** the constrained call only runs on rejected edits that are still over `maxSyllables × TIGHTEN_TRIGGER`. Only the drift threshold is relaxed; songs are skipped.
- **Fix 3.6 (normal path):** `permissibleWindowMs` caps only the buffer after `endMs`. The screen-content wait reuses the in-flight analysis (`inFlight` in screenContentAnalyzer.ts), so there's no second Gemini video call.
- **D4 (`enableABHooks` removal) and the D3 report on faithful-mix:** fine.
- **Meaning check on subtitles:** it now runs whenever source and target languages differ, and is skipped for same-language condensing. That is the right scope. Accepted.

### Real data on the new block (not a test)
The three 12-minute film runs on this PC logged these meaning-check results:

| Log | Lines | Kept | Subtitle | Unresolved |
|---|---|---|---|---|
| `console-film.txt` | 76 | 76 | 0 | 0 |
| `console-film-all-cloned.txt` | 72 | 71 | 1 | 0 |
| `console-film-3.txt` | 82 | 82 | 0 | 0 |

So the `meaning_unresolved` block would not have stopped any of those Telugu runs. The new polarity and number flags didn't exist then, so their rates are not measured yet.

### Changes requested
**Must fix**
1. **R1. `dubbing_translation_block.test.ts` doesn't test the real code.**
   - The test rebuilds the block filter inline and asserts a spy it never wires to anything, so it passes whatever 07-dubbing does.
   - Extract the decision into one exported function used by **both** paths (e.g. `findBlockedTranslationLines(segs, enabled)` in `translation-flags.ts` or a new small module).
   - Test that function directly, and add a test that drives the normal-path decision: a blocked segment → `isDubbingSupportedForTarget === false` and `dubOutcome === "failed"`. If `processLanguage` can't be driven in a test, extract the outcome decision into a pure function too, and test that.
2. **R2. Long-form path (films) misses Fixes 3.6, 4.2 and 4.3.**
   - `dispatchLongFormReels` (07-dubbing.ts ~6476) calls `translateWithCache` without `shotChangesMs`, `onScreenText` or `isSong` marking, and never awaits `getScreenContent`.
   - The 12-minute film goes through this path.
   - Do the same wait-with-timeout, song marking and pass-through there as on the normal path (~2764–2854).
3. **R3. Prove refunds for a blocked long-form language.**
   - On the long path, a blocked language only gets a notice and is left out of `dubLanguages`.
   - Show, with file and line, where a language that was ordered but isn't in `dubLanguages` is refunded (follow how `DUB_SKIPPED_UNSUPPORTED_LANGUAGE` is handled).
   - If it isn't refunded, mark it failed so the existing refund runs, and add a test.
4. **R4. A repaired line is accepted without re-checking the meaning.**
   - `repairLineWithEditor` (translation.ts ~2015) only checks numbers and `checkEditedLine`. In Checkpoint B, any changed text counts as "repaired".
   - `editSegments` already runs the meaning check on the repair, but its verdict is ignored.
   - Treat the repair as **failed** when the returned line has `meaningAction === "unresolved"`, `meaningPolarityFlipped === true` or `meaningNumbersChanged === true`.
   - Add a test with a repair reply that still flips polarity → the line stays blocked.

**Should fix**

5. **R5. Pre-TTS keeps a longer line when the shorter one is still over 1.15× the window** (07-dubbing.ts ~3354).
   - Before TTS, nothing has been paid yet, so a shorter line that passed the editor's checks is always better.
   - Accept any shorter line pre-TTS. Keep the "skip, still too long" rule only post-TTS, where it saves a paid retake.
   - (My task text was ambiguous here; this is not your mistake.)
6. **R6. Update `tests/pipeline/dubbing_meaning_check.test.ts:213`** to the accepted behaviour: meaning-checked when languages differ, skipped for same-language condense. Then `test:dubbing` should be fully green.
7. **R7. Timeout timer.** Clear or `unref()` the 20 s timer in the screen-content `Promise.race` (~2770) so it doesn't hold the event loop after the analysis returns.

### Follow-ups (record them in the `## Follow-ups` section; don't build them now)
- **Numbers aren't counted as speech.**
  - `countSourceSyllables("2024లో ధరలు 12% పెరిగాయి.", "te")` = 8, but "2024" and "12%" are spoken as many syllables, so lines with numbers are under-estimated and are more likely to overflow.
  - Measure how often this happens in Phase 5 (overflow lines that contain digits) before changing it.
- **Pauses are counted twice for measured rates.** The measured rate comes from whole-take durations, which already include pauses, and `estimateSpeechDurationMs` adds punctuation pauses on top. That makes the estimate conservative (more retakes). Check it in Phase 5.

### Phase 5
- `functions/local-dub-output` exists but is **empty**, and no source clips are in the repo. The owner's film and test clips are elsewhere on the PC; the owner will give the paths.
- Don't spend ElevenLabs credits until the owner approves the character count.

When R1–R7 are done: run the Verify block, paste the counts into `## Result`, and set Status to `READY FOR REVIEW`.

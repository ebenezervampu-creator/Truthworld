# Tamil (`ta`) Dubbing & Subtitle Prompt Rules — Native Review

**Reviewer Instructions:**
Please review each rule and example below taken directly from the TruthWorld translation and dubbing engine code. For each row, indicate your verdict:
- ✅ **Correct** — Accurately reflects natural, spoken Tamil as spoken today.
- ✏️ **Fix: [Your correction]** — Natural suggestion to improve phrasing or grammar.
- ❌ **Wrong** — Culturally or grammatically inaccurate; should not be used in production.

All line references point directly to the codebase:
- `functions/src/pipeline/services/geminiDubbingEditor.ts`
- `functions/src/pipeline/services/cast-list.ts`

---

## 1. Addressing an Audience or Group

These rules instruct the AI on how to address viewers, an auditorium, or multiple people collectively.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | When addressing an audience or group, always use polite plural forms 'நீங்கள் / உங்களை / உங்களுக்கு' with polite '-ங்கள்' or spoken '-ங்க' verb endings. | `"Tamil: நீங்கள் / உங்களை / உங்களுக்கு with -ங்கள் / -ங்க verb endings"` | `geminiDubbingEditor.ts:439` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 2 | For subtitles, use 'நீங்கள் / உங்களை / உங்களுக்கு' for elders, professionals, and audience; reserve 'நீ' for children or intimate peers. | `"In Tamil, use நீங்கள் / உங்களை / உங்களுக்கு for elders, professionals and audience; reserve நீ for children or intimate peers."` | `geminiDubbingEditor.ts:440` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 3 | For voice dubbing, use polite 'நீங்கள் / உங்களை / உங்களுக்கு' (spoken: 'நீங்க / உங்கள / உங்களுக்கு') with polite '-ங்கள் / -ங்க' verb endings for elders, parents, teachers, guests, professionals, strangers, or audience. | `"In Tamil: Use நீங்கள் / உங்களை / உங்களுக்கு (spoken: நீங்க / உங்கள / உங்களுக்கு) with polite -ங்கள் / -ங்க verb endings for elders, parents, teachers, guests, professionals, strangers, or audience."` | `geminiDubbingEditor.ts:441` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 4 | When a character's relationship to an audience or elder is deferential, use 'நீங்கள் / தாங்கள்' with respectful '-ங்கள்' verb endings. | `"Use 'நீங்கள் / தாங்கள்' with respectful '-ங்கள்' verb endings."` | `cast-list.ts:97` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 2. Addressing One Person (Formal vs. Informal "You")

Tamil distinguishes between formal/plural address and intimate singular address.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 5 | **Formal Address**: Use polite 'நீங்கள் / உங்களை / உங்களுக்கு' with polite '-ங்கள்' endings for professionals, elders, and colleagues. | `"Use 'நீங்கள் / உங்களை / உங்களுக்கு' with polite '-ங்கள்' endings."` | `cast-list.ts:98` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 6 | **Informal Address**: Use familiar 'நீ / உன்னை / உனக்கு' with familiar verb endings. | `"Use 'நீ / உன்னை / உனக்கு' with familiar verb endings."` | `cast-list.ts:99` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 7 | **Strict Boundary on Singular Address**: Restrict 'நீ / உன்னை / உனக்கு' strictly to a child, younger sibling, or intimate close friend; never default singular English 'you' to 'நீ'. | `"Use நீ / உன்னை / உனக்கு ONLY for a child, younger sibling, or intimate close friend."` | `geminiDubbingEditor.ts:441` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 3. Sounding Spoken, Not Written

Tamil dubbing must use standard standard spoken Tamil (as heard in modern Tamil cinema and digital media) rather than formal textbook literary Tamil (Sen-Tamil).

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 8 | Use standard spoken Tamil auxiliary 'இருக்கு' instead of formal written 'இருக்கிறது'. | `"'இருக்கு' instead of 'இருக்கிறது'"` | `geminiDubbingEditor.ts:442` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 9 | Use natural conversational first-person 'சொல்றேன்' instead of formal written 'சொல்கிறேன்'. | `"'சொல்றேன்' instead of 'சொல்கிறேன்'"` | `geminiDubbingEditor.ts:442` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 10 | Use spoken plural progressive 'போறோம்' instead of formal written 'போகிறோம்'. | `"'போறோம்' instead of 'போகிறோம்'"` | `geminiDubbingEditor.ts:442` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 11 | Use conversational interrogative 'என்ன பண்றீங்க' instead of textbook 'என்ன செய்கிறீர்கள்'. | `"'என்ன பண்றீங்க' instead of 'என்ன செய்கிறீர்கள்'"` | `geminiDubbingEditor.ts:442` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 12 | **Dialect Boundary**: Avoid heavy regional slang (e.g. extreme localized dialects) in favor of clear standard spoken Tamil. | `"use clear standard spoken Tamil as heard in Tamil films and YouTube rather than formal written Tamil... Avoid heavy regional slang"` | `geminiDubbingEditor.ts:442` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 4. Words the System Treats as the Same "You" (Honorific Normalizer Set)

Source: `functions/src/pipeline/services/geminiDubbingEditor.ts:271-276` (`TAMIL_HONORIFIC_NORM`)

When comparing edited lines against drafts to detect drift, the engine treats variations within each category as equivalent:

| Internal Category Token | Quoted Words in Code (`geminiDubbingEditor.ts:271-276`) | Plain English Explanation | Is Any Form Missing or Wrong? |
| :--- | :--- | :--- | :--- |
| `__YOU_DAT__` | `"உங்களுக்கு"`, `"உனக்கு"` | Dative "to you" in polite ('உங்களுக்கு') and informal ('உனக்கு') registers. | |
| `__YOU_OBJ__` | `"உங்களை"`, `"உங்கள"`, `"உன்னை"` | Accusative object "you" in polite written ('உங்களை'), polite spoken ('உங்கள'), and informal ('உன்னை') forms. | |
| `__YOUR__` | `"உங்கள்"`, `"உங்க"`, `"உன்"` | Possessive "your / yours" in polite written ('உங்கள்'), polite spoken ('உங்க'), and informal ('உன்') forms. | |
| `__YOU__` | `"நீங்கள்"`, `"நீங்க"`, `"தாங்கள்"`, `"நீ"` | Subject pronoun "you" in polite written ('நீங்கள்'), polite spoken ('நீங்க'), honorific ('தாங்கள்'), and informal ('நீ') forms. | |

**Question for Reviewer:** Are there any spoken possessive or oblique forms missing (e.g. `'உங்களுடைய'`, `'உன்னுடைய'`, or spoken dative/locative `'உங்கிட்ட'`)?

---

## 5. Open Questions for the Tamil Native Reviewer

1. **Colloquial Spoken Universality**: Are cinema/YouTube progressive forms like `'பண்றீங்க'`, `'சொல்றேன்'`, and `'போறோம்'` recognized and appreciated across all Tamil Nadu regions (Chennai, Kongu, Madurai, Tirunelveli) as natural neutral spoken Tamil, or do they sound tied to a specific region?
2. **Spoken vs. Written Subtitles**: In the dual-track pipeline, dubbed speech uses spoken contractions (`'இருக்கு'`, `'நீங்க'`), but subtitles often default to standard written Tamil (`'இருக்கிறது'`, `'நீங்கள்'`). Do Tamil viewers prefer subtitles to match spoken audio verbatim, or should subtitles follow formal orthography?
3. **Usage of 'தாங்கள்'**: The deferential register lists `'தாங்கள்'`. In contemporary Tamil dialogue, does `'தாங்கள்'` sound too formal/archaic for YouTube interviews, or is it appropriate when interviewing dignitaries, scholars, and spiritual leaders?

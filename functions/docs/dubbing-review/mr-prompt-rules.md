# Marathi (`mr`) Dubbing & Subtitle Prompt Rules — Native Review

**Reviewer Instructions:**
Please review each rule and example below taken directly from the TruthWorld translation and dubbing engine code. For each row, indicate your verdict:
- ✅ **Correct** — Accurately reflects natural, spoken Marathi as spoken today.
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
| 1 | When addressing an audience, group, or multiple people, use respectful plural forms 'तुम्ही / तुम्हाला / तुमचा' with plural verb forms, or 'आपण' for very formal address. | `"Marathi: तुम्ही / तुम्हाला / तुमचा with plural verb forms, or आपण for very formal address"` | `geminiDubbingEditor.ts:433` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 2 | For subtitles, use 'तुम्ही / तुम्हाला' for elders, professionals, and audience; reserve 'तू' for children or intimate peers. Never use Hindi words or Hindi grammar. | `"In Marathi, use तुम्ही / तुम्हाला for elders, professionals and audience; reserve तू for children or intimate peers. Write Marathi, never Hindi words or grammar."` | `geminiDubbingEditor.ts:434` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 3 | For voice dubbing, use 'तुम्ही / तुम्हाला / तुमचा' with plural verb agreement for elders, parents, teachers, guests, professionals, strangers, or audience ('आपण' for very formal address). | `"In Marathi: Use तुम्ही / तुम्हाला / तुमचा with plural verb agreement for elders, parents, teachers, guests, professionals, strangers, or audience (आपण for very formal address)."` | `geminiDubbingEditor.ts:435` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 4 | When a character's relationship to an audience or elder is deferential, use respectful 'आपण / आपल्याला' or 'तुम्ही' with '-आ / -ता' plural verb forms. | `"Use respectful 'आपण / आपल्याला' or 'तुम्ही' with '-आ / -ता' plural verb forms."` | `cast-list.ts:112` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 2. Addressing One Person (Formal vs. Informal "You")

Marathi is a two-level language in the engine: the prompt enforces either polite plural agreement or intimate singular agreement without confusing ambiguity.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 5 | **Formal Address**: Use polite 'तुम्ही / तुम्हाला / तुमचा' with plural verb agreement for all professional interactions, strangers, and elders. | `"Use polite 'तुम्ही / तुम्हाला / तुमचा' with plural verb agreement."` | `cast-list.ts:113` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 6 | **Informal Address**: Use familiar 'तू / तुला / तुझा' with singular verb agreement ONLY for a child, younger sibling, or intimate close friend. | `"Use familiar 'तू / तुला / तुझा' with singular verb agreement."` | `cast-list.ts:114` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 7 | **Strict Boundary on Singular Address**: Restricts 'तू / तुला / तुझा' with singular verb agreement strictly to intimate close relationships or younger children; never default singular English 'you' to 'तू'. | `"Use तू / तुला / तुझा with singular verb agreement ONLY for a child, younger sibling, or intimate close friend."` | `geminiDubbingEditor.ts:435` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 3. Sounding Spoken, Not Written

Spoken dubbing must feel like living speech rather than translated text.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 8 | Use contracted spoken progressive verb forms like 'करतोय' (male speaker) / 'करतेय' (female speaker) matching the speaker's gender instead of textbook 'करत आहे'. | `"use contracted spoken progressive forms such as 'करतोय' / 'करतेय' (matching the speaker's gender) instead of 'करत आहे'"` | `geminiDubbingEditor.ts:436` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 9 | Use natural spoken vocabulary 'मदत' instead of formal Sanskritized 'सहाय्य'. | `"'मदत' instead of 'सहाय्य'"` | `geminiDubbingEditor.ts:436` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 10 | Use natural spoken word 'सुरू' instead of formal bookish 'प्रारंभ'. | `"'सुरू' instead of 'प्रारंभ'"` | `geminiDubbingEditor.ts:436` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 11 | **Strict Anti-Hindi Contamination Rule**: Machine translation frequently bleeds Hindi words into Marathi. Explicitly forbids Hindi vocabulary and grammatical particles: 'है', 'नहीं', 'क्या', 'और'. | `"Never mix in Hindi words or grammar ('है', 'नहीं', 'क्या', 'और')"` | `geminiDubbingEditor.ts:436` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 4. Words the System Treats as the Same "You" (Honorific Normalizer Set)

Source: `functions/src/pipeline/services/geminiDubbingEditor.ts:265-269` (`MARATHI_HONORIFIC_NORM`)

When calculating similarity to detect translation drift, the engine normalizes the following Marathi pronouns into neutral tokens:

| Internal Category Token | Quoted Words in Code (`geminiDubbingEditor.ts:265-269`) | Plain English Explanation | Is Any Form Missing or Wrong? |
| :--- | :--- | :--- | :--- |
| `__YOU_DAT__` | `"तुम्हाला"`, `"तुला"`, `"आपल्याला"` | Dative "to you" / "for you" in formal ('तुम्हाला'), informal ('तुला'), and inclusive/honorific ('आपल्याला') forms. | |
| `__YOUR__` | `"तुमचा"`, `"तुमची"`, `"तुमचे"`, `"तुझा"`, `"तुझी"`, `"तुझे"`, `"आपला"`, `"आपली"`, `"आपले"` | Masculine, feminine, and plural possessives ("your / yours"). | |
| `__YOU__` | `"तुम्ही"`, `"तू"`, `"आपण"` | Subject pronouns "you" (formal 'तुम्ही', informal 'तू', high-honorific 'आपण'). | |

**Question for Reviewer:** Notice that neuter possessive forms ending in anusvara — **'तुमचं'**, **'तुझं'**, and **'आपलं'** (e.g. "तुमचं नाव काय?") — are currently not listed in the code. Should these neuter forms be added to the code's normalizer list?

---

## 5. Open Questions for the Marathi Native Reviewer

1. **Progressive Contraction Balance**: Is `'करतोय' / 'करतेय'` the right spoken standard for casual and lifestyle YouTube dubs, or does it sound overly informal in news analysis and educational documentary voiceovers where `'करत आहे'` might sound more authoritative?
2. **Deference with 'आपण'**: The prompt specifies `'आपण'` for very formal address. In modern spoken Marathi, does addressing an individual guest as `'आपण'` feel natural and respectful, or does it occasionally sound ambiguous with the first-person plural ("we")?
3. **Prevention of Hindi Infiltration**: The prompt strictly bans `'है', 'नहीं', 'क्या', 'और'`. Are there other persistent Hindi loan words or sentence connectors (such as `'लेकिन'`, `'क्यूंकी'`, `'ज्यादा'`) that AI translation engines commonly inject into Marathi dubs which we should explicitly add to the banned list?

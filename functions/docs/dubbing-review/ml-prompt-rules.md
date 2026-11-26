# Malayalam (`ml`) Dubbing & Subtitle Prompt Rules — Native Review

**Reviewer Instructions:**
Please review each rule and example below taken directly from the TruthWorld translation and dubbing engine code. For each row, indicate your verdict:
- ✅ **Correct** — Accurately reflects natural, spoken Malayalam as spoken today.
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
| 1 | When addressing an audience or group, use polite plural forms 'നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്', or 'താങ്കൾ' for very formal address. | `"Malayalam: നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്, or താങ്കൾ for very formal address"` | `geminiDubbingEditor.ts:445` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 2 | For subtitles, use 'നിങ്ങൾ' (or 'താങ്കൾ', or a title such as 'സാർ / ചേട്ടൻ / ചേച്ചി') for elders, professionals, and audience; reserve 'നീ' for children or intimate peers. | `"In Malayalam, use നിങ്ങൾ (or താങ്കൾ, or a title such as സാർ / ചേട്ടൻ / ചേച്ചി) for elders, professionals and audience; reserve നീ for children or intimate peers."` | `geminiDubbingEditor.ts:446` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 3 | For voice dubbing, use 'നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്' ('താങ്കൾ' for very formal address), or address the person by title ('സാർ, ചേട്ടൻ, ചേച്ചി') where culturally natural. | `"In Malayalam: For elders, parents, teachers, guests, professionals, strangers, or audience, use നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക് (താങ്കൾ for very formal address), or address them by a title (സാർ, ചേട്ടൻ, ചേച്ചി) where a Malayali would."` | `geminiDubbingEditor.ts:447` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 4 | When a character's relationship to an audience or elder is deferential, use respectful 'താങ്കൾ / താങ്കളെ / താങ്കൾക്ക്' (or 'സാർ / ചേട്ടാ' vocative address where natural). | `"Use respectful 'താങ്കൾ / താങ്കളെ / താങ്കൾക്ക്' (or 'സാർ / ചേട്ടാ' style address where natural)."` | `cast-list.ts:107` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 2. Addressing One Person (Formal vs. Informal "You")

Malayalam distinguishes between polite address and intimate singular address.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 5 | **Formal Address**: Use polite 'നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്' for professionals, elders, and colleagues. | `"Use polite 'നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്'."` | `cast-list.ts:108` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 6 | **Informal Address**: Use familiar 'നീ / നിന്നെ / നിനക്ക്'. | `"Use familiar 'നീ / നിന്നെ / നിനക്ക്'."` | `cast-list.ts:109` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 7 | **Strict Boundary on Singular Address**: Restrict 'നീ / നിന്നെ / നിനക്ക്' strictly to a child, younger sibling, or intimate close friend; never default singular English 'you' to 'നീ'. | `"Use നീ / നിന്നെ / നിനക്ക് ONLY for a child, younger sibling, or intimate close friend."` | `geminiDubbingEditor.ts:447` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 3. Sounding Spoken, Not Written

Spoken Malayalam dubbing must sound natural and conversational rather than formal written bookish Malayalam.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 8 | Use natural spoken interrogative 'എന്താ' instead of formal written 'എന്താണ്'. | `"'എന്താ' instead of 'എന്താണ്'"` | `geminiDubbingEditor.ts:448` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 9 | Use natural spoken vocabulary instead of heavy Sanskritized Malayalam terms. | `"and everyday words instead of Sanskritised ones"` | `geminiDubbingEditor.ts:448` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 10 | **Dialect Boundary**: Avoid heavy regional dialects in favor of standard spoken Malayalam understandable across all districts of Kerala. | `"use natural spoken Malayalam rather than formal written Malayalam... Avoid heavy regional dialect"` | `geminiDubbingEditor.ts:448` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 11 | **Culturally Natural Titles**: Use vocative titles ('സാർ', 'ചേട്ടൻ' / 'ചേട്ടാ', 'ചേച്ചി') in place of bare second-person pronouns where a native speaker would naturally use a title. | `"or address them by a title (സാർ, ചേട്ടൻ, ചേച്ചി) where a Malayali would"` | `geminiDubbingEditor.ts:447` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 4. Words the System Treats as the Same "You" (Honorific Normalizer Set)

Source: `functions/src/pipeline/services/geminiDubbingEditor.ts:278-283` (`MALAYALAM_HONORIFIC_NORM`)

When evaluating translation drift, the engine treats variations within each category as equivalent:

| Internal Category Token | Quoted Words in Code (`geminiDubbingEditor.ts:278-283`) | Plain English Explanation | Is Any Form Missing or Wrong? |
| :--- | :--- | :--- | :--- |
| `__YOU_DAT__` | `"നിങ്ങൾക്ക്"`, `"നിനക്ക്"`, `"താങ്കൾക്ക്"` | Dative "to you" in polite ('നിങ്ങൾക്ക്'), informal ('നിനക്ക്'), and high-formal ('താങ്കൾക്ക്') forms. | |
| `__YOU_OBJ__` | `"നിങ്ങളെ"`, `"നിന്നെ"`, `"താങ്കളെ"` | Accusative object "you" in polite ('നിങ്ങളെ'), informal ('നിന്നെ'), and high-formal ('താങ്കളെ') forms. | |
| `__YOUR__` | `"നിങ്ങളുടെ"`, `"നിന്റെ"`, `"താങ്കളുടെ"` | Possessive "your / yours" in polite ('നിങ്ങളുടെ'), informal ('നിന്റെ'), and high-formal ('താങ്കളുടെ') forms. | |
| `__YOU__` | `"നിങ്ങൾ"`, `"താങ്കൾ"`, `"നീ"` | Subject pronoun "you" in polite ('നിങ്ങൾ'), high-formal ('താങ്കൾ'), and informal ('നീ') forms. | |

**Question for Reviewer:** Are there any spoken pronoun forms missing from this set (e.g. conversational dative `'തനിക്ക്'` or familiar peer address `'താൻ'`)?

---

## 5. Open Questions for the Malayalam Native Reviewer

1. **Spoken Contraction Extent**: The prompt recommends `'എന്താ'` instead of `'എന്താണ്'`. Are there other common spoken contractions (e.g. `'അല്ലേ'` vs `'അല്ലയോ'`, `'ഉണ്ടോ'` vs `'ഉണ്ടാകുമോ'`, or `'ചെയ്യുന്നുണ്ട്'` vs `'ചെയ്യുകയാണ്'`) that must be encouraged to make voice dubs sound authentic rather than read from news scripts?
2. **Title Replacement ('ചേട്ടൻ' / 'ചേച്ചി')**: Malayalam culture frequently replaces direct pronouns ("you") with relational titles like `'ചേട്ടൻ'` or `'ചേച്ചി'`. Does directing an AI to inject these titles risk sounding overly presumptuous if the age or familial relationship between speakers isn't explicitly known?
3. **Naturalness of 'താങ്കൾ'**: While `'താങ്കൾ'` is grammatically deferential, does it sound somewhat stiff or overly formal for modern digital video dubbing, or is it still the preferred form when dubbing respected professionals, ministers, or senior guests?

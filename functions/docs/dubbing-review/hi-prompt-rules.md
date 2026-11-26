# Hindi (`hi`) Dubbing & Subtitle Prompt Rules — Native Review

**Reviewer Instructions:**
Please review each rule and example below taken directly from the TruthWorld translation and dubbing engine code. For each row, indicate your verdict:
- ✅ **Correct** — Accurately reflects natural, spoken Hindi as spoken today.
- ✏️ **Fix: [Your correction]** — Natural suggestion to improve phrasing or grammar.
- ❌ **Wrong** — Culturally or grammatically inaccurate; should not be used in production.

All line references point directly to the codebase:
- `functions/src/pipeline/services/geminiDubbingEditor.ts`
- `functions/src/pipeline/services/cast-list.ts`

---

## 1. Addressing an Audience or Group

These rules instruct the AI on how to speak when a video creator or speaker addresses viewers, an auditorium, or multiple people collectively.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | Always address an audience or group using the respectful plural pronoun 'आप' with polite '-इए' or plural 'हैं' verb endings. | `"Hindi: आप with -इए / हैं"` | `geminiDubbingEditor.ts:427` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 2 | For video subtitles, use 'आप' for elders and audience members, and use 'तुम' for social peers. | `"In Hindi, use आप for elders/audience and तुम for peers."` | `geminiDubbingEditor.ts:428` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 3 | For voice dubbing, address an audience, elders, guests, or professionals with 'आप' and polite verb agreement ('-इए / हैं'). | `"In Hindi: Use आप with -इए / हैं for elders, guests, professionals, or audience."` | `geminiDubbingEditor.ts:429` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 4 | When a speaker's social register is formal, address elders, guests, professionals, colleagues, and audiences with polite 'आप' and '-इए / हैं' verb agreement. | `"Use polite 'आप' with '-इए / हैं' agreement (elders, guests, professionals, colleagues, audience)."` | `cast-list.ts:92` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 2. Addressing One Person (Formal vs. Informal "You")

English "you" does not distinguish between social status or intimacy. The engine directs the AI to select the correct register based on character relationship tags.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 5 | **Highest Deference / Reverence**: Use honorific pronouns 'आप / आपको / आपका' with polite verb forms ('-इए / हैं / जी'). Never accidentally slip into 'तुम' or 'तू'. | `"Use honorific 'आप / आपको / आपका' with '-इए / हैं / जी' verb forms. Never slip into 'तुम' or 'तू'."` | `cast-list.ts:91` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 6 | **Peer / Equal Address**: When two speakers are colleagues, siblings, or close social peers, use friendly 'तुम' with '-ओ / हो' verb agreement. | `"Use friendly 'तुम' with '-ओ / हो' agreement (friends, siblings, close peers)."` | `cast-list.ts:93` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 7 | **Familiar / Informal Address**: Use 'तुम' for friends/family; reserve 'तू' strictly for young children or very intimate family members when culturally natural. | `"Use 'तुम'; reserve 'तू' for young children or very intimate family when culturally natural."` | `cast-list.ts:94` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 8 | **Comprehensive Dubbing Register Breakdown**: Directs the editor to use 'आप' with '-इए / हैं' for elders, guests, professionals, or audience; use 'तुम' with '-ओ' for colleagues/peers; and reserve 'तू' strictly for intimate family or young children. | `"In Hindi: Use आप with -इए / हैं for elders, guests, professionals, or audience. Use तुम with -ओ for colleagues/peers. Reserve तू strictly for intimate family or young children."` | `geminiDubbingEditor.ts:429` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 3. Sounding Spoken, Not Written

Spoken dubbing must sound like living conversation rather than formal textbook translation.

| # | What the rule tells the AI (plain English) | Example in the language, exactly as in the code | Code Reference | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- |
| 9 | Use natural spoken everyday Hindustani vocabulary instead of heavy Sanskritized bookish Hindi (e.g. 'मदद' instead of 'सहायता'). | `"'मदद' instead of 'सहायता'"` | `geminiDubbingEditor.ts:430` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 10 | Use spoken everyday Hindustani 'शुरू' instead of bookish 'प्रारंभ'. | `"'शुरू' instead of 'प्रारंभ'"` | `geminiDubbingEditor.ts:430` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 11 | Use natural conversational connector 'लेकिन' instead of textbook 'किंतु'. | `"'लेकिन' instead of 'किंतु'"` | `geminiDubbingEditor.ts:430` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 12 | Use everyday spoken adjective 'ज़रूरी' instead of formal 'आवश्यक'. | `"'ज़रूरी' instead of 'आवश्यक'"` | `geminiDubbingEditor.ts:430` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 13 | Use conversational noun 'सवाल' instead of textbook 'प्रश्न'. | `"'सवाल' instead of 'प्रश्न'"` | `geminiDubbingEditor.ts:430` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 4. Words the System Treats as the Same "You" (Honorific Normalizer Set)

When evaluating whether an AI edit changed the fundamental meaning of a line (drift detection), the engine treats all variations within each grammatical category below as interchangeable versions of "you", "come", and "do".

Source: `functions/src/pipeline/services/geminiDubbingEditor.ts:257-263` (`HINDI_HONORIFIC_NORM`)

| Internal Category Token | Quoted Words in Code (`geminiDubbingEditor.ts:257-263`) | Plain English Explanation | Is Any Form Missing or Wrong? |
| :--- | :--- | :--- | :--- |
| `__YOU_DAT__` | `"आपको"`, `"तुमको"`, `"तुम्हें"`, `"तुझे"`, `"तुझको"` | Dative "to you" across formal ('आप'), peer ('तुम'), and intimate ('तू') registers. | |
| `__YOUR__` | `"आपका"`, `"आपकी"`, `"आपके"`, `"तुम्हारा"`, `"तुम्हारी"`, `"तुम्हारे"`, `"तेरा"`, `"तेरी"`, `"तेरे"` | Possessive "your / yours" across all genders and social registers. | |
| `__YOU__` | `"आप"`, `"तुम"`, `"तू"` | Subject pronoun "you" (formal, peer, intimate). | |
| `__COME__` | `"आइए"`, `"आइये"`, `"आओ"`, `"आ"` | Imperative forms of "come" across formal, peer, and informal registers. | |
| `__DO__` | `"कीजिए"`, `"कीजिये"`, `"करिए"`, `"करो"`, `"कर"` | Imperative forms of "do" across formal, peer, and informal registers. | |

**Question for Reviewer:** Are there any common spoken pronoun forms missing from this set (e.g., regional or conversational variants such as `अपने को`) or any form that shouldn't be grouped together?

---

## 5. Open Questions for the Hindi Native Reviewer

1. **Peer Form Suitability**: Is 'तुम' with '-ओ / हो' verb agreement the right default tone for conversational YouTube dialogue between adults/peers, or does modern urban digital content prefer polite 'आप' to avoid sounding overly blunt?
2. **Boundary of 'तू'**: The prompt reserves 'तू' strictly for young children or intimate family. In dramatic dialogue, does this prohibition prevent natural dialogue during intense arguments, or is this restriction essential to keep branded video dubs clean and polite?
3. **Everyday Vocabulary Balance**: Rule 4 recommends 'मदद' over 'सहायता' and 'सवाल' over 'प्रश्न'. Does this everyday Hindustani register sound natural across news/documentary contexts as well as entertainment, or should formal journalism retain words like 'सहायता' and 'प्रश्न'?

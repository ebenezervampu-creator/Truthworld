# Dubbing Launch Review Pack (v1 Launch Coordinator Sheet)

This review pack coordinates the native speaker verification for TruthWorld's Dubbing v1 launch from English into **Telugu (te)**, **Hindi (hi)**, **Marathi (mr)**, **Tamil (ta)**, and **Malayalam (ml)**.

The backend pipeline and code are feature-complete. Before opening dubbing to production users, native language reviewers must sign off on:
1. **Prompt & Register Rules** (`hi`, `mr`, `ta`, `ml`): ensuring the AI uses authentic social registers, natural spoken phrasing, and proper honorifics. (*Telugu rules unchanged; Telugu is included in the listening test.*)
2. **Terminology Glossary** (`mr` only): validating Marathi translations for 29 domain terms across fact-checking, energy, science, theology, and monetization.
3. **Listening Tests** (all 5 languages: `te`, `hi`, `mr`, `ta`, `ml`): evaluating end-to-end dubbed audio tracks using Full Test videos (with optional Quick Check clips for smoke testing).

Each reviewer's assignment is isolated into a standalone document and is designed to be completed in **under 45–60 minutes** without reading any codebase files or technical scripts.

---

## 📋 What Each Reviewer Receives & Sends Back

| Reviewer Role | Document Provided | Target Time | What Reviewer Must Send Back |
| :--- | :--- | :--- | :--- |
| **Hindi Reviewer** | [`hi-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/hi-prompt-rules.md) & [`listening-test.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/listening-test.md) (Hindi section) | 45 min | Marked verdict table + answers to 3 open questions + filled listening test score sheets for Full Tests A & B. |
| **Marathi Reviewer** | [`mr-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/mr-prompt-rules.md), [`mr-glossary-proposal.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/mr-glossary-proposal.md), & [`listening-test.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/listening-test.md) (Marathi section) | 60 min | Approved prompt rules + 29 glossary term verdicts + filled listening test score sheets for Full Tests A & B. |
| **Tamil Reviewer** | [`ta-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/ta-prompt-rules.md) & [`listening-test.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/listening-test.md) (Tamil section) | 45 min | Marked verdict table + answers to 3 open questions + filled listening test score sheets for Full Tests A & B. |
| **Malayalam Reviewer** | [`ml-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/ml-prompt-rules.md) & [`listening-test.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/listening-test.md) (Malayalam section) | 45 min | Marked verdict table + answers to 3 open questions + filled listening test score sheets for Full Tests A & B. |
| **Telugu Reviewer** | [`listening-test.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/listening-test.md) (Telugu section) | 30 min | Filled listening test score sheets for Full Tests A & B (Telugu rules unchanged; Telugu is included in the listening test). |

---

## 🚦 Language Launch Status Table

| Language | Reviewer Name | Prompt Rules (Code Verified) | Glossary Status | Listening Test (Full Tests A & B) | Overall Launch Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Telugu (`te`)** | `____________________` | 🟢 Unchanged (*Telugu rules unchanged; Telugu is included in the listening test*) | 🟢 Complete (29/29 locked in code) | ⚪ Pending Review | ⏳ Awaiting Listening Test |
| **Hindi (`hi`)** | `____________________` | ⚪ Pending Review ([`hi-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/hi-prompt-rules.md)) | 🟢 Complete (29/29 locked in code) | ⚪ Pending Review | ⏳ Pending Sign-off |
| **Marathi (`mr`)** | `____________________` | ⚪ Pending Review ([`mr-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/mr-prompt-rules.md)) | ⚪ Pending Review ([`mr-glossary-proposal.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/mr-glossary-proposal.md)) | ⚪ Pending Review | ⏳ Pending Sign-off |
| **Tamil (`ta`)** | `____________________` | ⚪ Pending Review ([`ta-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/ta-prompt-rules.md)) | 🟢 Complete (29/29 locked in code) | ⚪ Pending Review | ⏳ Pending Sign-off |
| **Malayalam (`ml`)** | `____________________` | ⚪ Pending Review ([`ml-prompt-rules.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/ml-prompt-rules.md)) | 🟢 Complete (29/29 locked in code) | ⚪ Pending Review | ⏳ Pending Sign-off |

---

## 🎯 Mandatory Pass Rules for Launch

A target language is cleared for production release **only** when all the following conditions are met:

1. **Prompt Rules Approval**:
   - The native reviewer approves or provides final corrections for all prompt guidance entries, cast directives, and honorific normalization sets.
   - Any required edits are updated in `functions/src/pipeline/services/geminiDubbingEditor.ts` and `functions/src/pipeline/services/cast-list.ts`.
2. **Glossary Approval (Marathi Only)**:
   - All 29 Marathi terminology proposals in [`mr-glossary-proposal.md`](file:///c:/company/truthworld/functions/docs/dubbing-review/mr-glossary-proposal.md) receive a positive verdict (✅ Correct or ✏️ Fix with verified correction).
   - Christian theological terms (e.g. Scripture, Gospel, Prophet, Resurrection, Crucifixion, Salvation) are verified against the Marathi Bible (मराठी बायबल).
3. **Listening Test Thresholds (All 5 Languages)**:
   - The launch pass rule strictly uses the **Full Tests** (**Full Test A** and **Full Test B**).
   - Both Full Test videos must score **at least 4 out of 5 on every criterion** (C1 through C6).
   - **Zero Tolerance Policy**: **No line** may be logged as `"Wrong meaning"` (epistemic distortion, factual corruption, or dropped negation disqualifies a release).

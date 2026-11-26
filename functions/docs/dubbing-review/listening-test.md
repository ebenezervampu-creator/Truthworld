# TruthWorld Dubbing Listening Test Protocol (All 5 Launch Languages)

This document provides the standard end-to-end listening test protocol for TruthWorld's Dubbing v1 launch:
**English → Telugu (`te`), Hindi (`hi`), Marathi (`mr`), Tamil (`ta`), and Malayalam (`ml`)**.

---

## 📦 What to Send Back

> [!IMPORTANT]
> **Reviewer Return Package:**
> 1. Completed **Score Sheets** (Scores 1 to 5 across all 6 criteria) for both **Full Test A** and **Full Test B**.
> 2. Completed **Per-Line Defect Log** with precise timestamps for any line that has an issue.
> 3. Confirmation that **no line** is logged as `"Wrong meaning"` (factual or semantic corruption).
>
> *Screen recordings or audio snippets of problem segments are optional but helpful.*

---

## 🎯 Launch Pass Rule

The official launch clearance rule uses the **Full Tests** (**Full Test A** and **Full Test B**):
- **Every criterion must score at least 4 out of 5** (Scores 4 or 5 on C1 through C6).
- **Zero Tolerance Policy**: **No line may be logged as `"Wrong meaning"`** (any factual alteration, dropped negation, hallucination, or corrupted claim disqualifies the release).
- *(Quick Check A & B are quick 30-second smoke tests to verify pipeline connectivity before running the longer Full Tests).*

---

## 🎬 1. Test Videos

To ensure rigorous validation of speech naturalness, social honorifics, timing, and multi-speaker separation, the listening test specifies two tiers of benchmark videos:

### Tier 1: Full Tests (Mandatory for Launch Clearance)

The owner must select or record authentic, un-dubbed English video clips fitting these exact specifications (do not use third-party branded logos or copyrighted commercial film clips):

#### Full Test A: Direct-to-Camera Journalistic Monologue (1–2 minutes)
- **Length**: 1 to 2 minutes.
- **Visual & Audio Setup**: Exactly one person on screen speaking continuously to the camera/audience in clear English; no background music; clean spoken audio.
- **Content**: Explaining a real-world, factual topic (e.g. science, public policy, economics, or news analysis) containing facts, proper nouns, and numbers.
- **Evaluation Objective**:
  - Validates audience honorific agreement (verifying the speaker consistently uses respectful/plural "you": Telugu `మీరు`, Hindi `आप`, Marathi `तुम्ही`, Tamil `நீங்கள்` / `நீங்க`, Malayalam `നിങ്ങൾ`).
  - Verifies spoken fluency, clear phrase cadence, and lack of archaic or textbook Sanskritized vocabulary.

#### Full Test B: Multi-Speaker Conversational Dialogue (2–4 minutes)
- **Length**: 2 to 4 minutes.
- **Visual & Audio Setup**: 2 to 3 distinct speakers conversing naturally, with ambient room acoustics and continuous background music/soundtrack throughout the conversation.
- **Social Dynamic**: Must feature at least one formal relationship (e.g. a younger person talking respectfully to an elder, or an interviewer addressing an expert guest) and at least one informal relationship (e.g. colleagues, friends, or family peers conversing).
- **Evaluation Objective**:
  - Validates character register consistency (formal vs informal "you" maintained across turns without flipping).
  - Validates register splitting: proper nouns and titles retained respectfully, while spoken verbs and pronouns use natural colloquial contractions.
  - Validates acoustic separation: background music and ambient sounds must remain 100% intact without muffling, volume dipping, or speech leakage.
  - Validates voice casting: different speakers get distinct, appropriate voices.

---

### Tier 2: Quick Checks (Smoke Testing Pre-Flight)

The two uploaded 31-second sample clips serve as instant sanity-check benchmarks:

#### Quick Check A: Solo Monologue Clip (~32s)
- **Format**: Single speaker talking to the camera without background music.
- **Purpose**: Rapid 30-second check to verify audience register (`आप` / `మీరు` / `तुम्ही` / `நீங்கள்` / `നിങ്ങൾ`), syllable timing, and basic acoustic clarity before launching the Full Test.

#### Quick Check B: Dramatic Dialogue Clip (~31s)
- **Format**: Two animated characters conversing over food in a shared room, with ambient sound and background score.
- **Purpose**: Rapid 30-second check to verify peer register between close equals, conversational contractions, and background music preservation.

---

## 🛠️ 2. Owner's Guide: How to Order and Play a Test Dub

*(All screen labels below are quoted directly from the live application code in `lib/features/dashboard` and `lib/features/video`.)*

### Step 1: Upload the Test Video
1. In TruthWorld Creator Studio, upload the test video (**Full Test A** or **Full Test B**) with original language set to **English**.
2. Wait for initial transcription and diarization to finish.

### Step 2: Order Dubbing from the AI Features Dialog
1. Navigate to **Creator Studio Dashboard** → **Content** (`lib/features/dashboard/presentation/views/dashboard/video_management.dart`).
2. On the video row, click the AI action icon (`Icons.auto_awesome_rounded` or `Icons.record_voice_over_rounded`).
3. This opens the modal dialog:
   - Literal Title Expression in Code (`content_ai_features_dialog.dart:54-62`):
     ```dart
     isDubbingPreselected ? 'Multilingual Audio Dubbing Studio' : 'AI Features & Advanced Settings'
     ```
     Renders on screen as: **`Multilingual Audio Dubbing Studio`** (or **`AI Features & Advanced Settings`**).
4. Filter and select the target languages:
   - Region filter chip literal expression (`content_ai_features_dialog.dart:366`):
     ```dart
     _buildLanguageRegionChip('ElevenLabs Dubbing (${kElevenLabsDubbingLanguages.length})', 'dubbing', regionFilter, applyFilter)
     ```
     Because `kElevenLabsDubbingLanguages` is filtered by `kDubbingLaunchTargetCodes` (`lib/core/constants/ai_languages.dart:12, 1037`), the chip displays exactly:
     **`ElevenLabs Dubbing (5)`**
   - Click the chip to show only the launch languages, or select each language chip:
     - **`Telugu (తెలుగు)`**
     - **`Hindi (हिन्दी)`** *(note: code uses `हिन्दी`, `ai_languages.dart:94`)*
     - **`Marathi (मराठी)`**
     - **`Tamil (தமிழ்)`**
     - **`Malayalam (മലയാളം)`**
5. In the section titled **`Select AI Features to Generate`** (`content_ai_features_dialog.dart:420`):
   - Check the checkbox for AI dubbing (`line 442-445`):
     Literal expression in code:
     ```dart
     'AI Audio Dubbing (${DubbingProductionTier.fromId(selectedDubbingTier.value).name} • \$${currentTierPerLangRate.toStringAsFixed(2)}/lang)'
     ```
     With the default `audio_track` tier selected, this displays:
     **`AI Audio Dubbing (Audio Track • $.../lang)`**
6. Click the primary action button at the bottom right (`content_ai_features_dialog.dart:972-980`):
   - Literal expression in code:
     ```dart
     isQuoteLoading.value
         ? 'Getting your price…'
         : isAwaitingTranscript
             ? 'Price ready after transcript'
             : isLanguageUnavailable
                 ? 'Dubbing not available yet'
                 : totalEstimatedCost > 0
                     ? 'Generate & Pay \$${totalEstimatedCost.toStringAsFixed(2)}'
                     : 'Generate AI Features (Free)'
     ```
     Shows: **`Generate & Pay $...`** (or **`Generate AI Features (Free)`**).

### Step 3: Listen to the Dubbed Track in the Player
1. Open the video in the TruthWorld video player (`lib/features/video/presentation/widgets/video_player_settings_sheet.dart`).
2. Tap the settings gear icon (`Icons.settings_rounded`) on the player controls.
3. This opens the bottom sheet with title:
   - **`Player Settings`** (`video_player_settings_sheet.dart:31`).
4. Tap the settings row titled:
   - **`Audio Track`** (`video_player_settings_sheet.dart:51`, icon: `Icons.audiotrack_rounded`).
5. This opens the audio track selection bottom sheet:
   - Sheet Title: **`Audio Tracks`** (`video_player_settings_sheet.dart:99`).
6. Select the target language track to switch audio:
   - **`Original`** (default)
   - **`Telugu`**
   - **`Hindi`**
   - **`Marathi`**
   - **`Tamil`**
   - **`Malayalam`**

---

## 📊 3. Evaluation Criteria (Score 1 to 5)

Every dubbed track is evaluated against **six criteria** on a scale from 1 (Unacceptable) to 5 (Flawless):

| # | Criterion | Score 1 (Fail) | Score 3 (Acceptable) | Score 5 (Flawless) |
| :- | :--- | :--- | :--- | :--- |
| **C1** | **Meaning Kept** | Facts, names, or claims omitted, altered, or hallucinated. | Meaning preserved; minor nuance lost without factual drift. | 100% faithful to English original; all facts, numbers, and names intact. |
| **C2** | **Correct Formality ("You")** | Wrong honorific level used (e.g. addressing audience with intimate singular "you"). | Correct general register, with minor inconsistency across rapid lines. | Perfect honorific and social register agreement throughout the video. |
| **C3** | **Sounds Spoken, Not Read** | Stiff, bookish textbook translation; sounds like a robot reading a dictionary. | Comprehensible and mostly natural, with a few stiff literary suffixes. | Sounds like an authentic native speaker conversing naturally on camera. |
| **C4** | **Timing & Lip Feel** | Severe rushing, unnatural speed-up (>1.25x), or cut-off words at chunk boundaries. | Slight tempo variation to fit time slot, but stays clear and intelligible. | Natural speech cadence; pauses and phrase boundaries align with the visuals. |
| **C5** | **Voice Suits Speaker** | Voice mismatched in gender, age, or emotional energy. | Acceptable voice match, but sounds somewhat synthetic or emotionally flat. | Gender, age and energy match the speaker, and the voice sounds natural. *(Standard voices are default; voice cloning is not required.)* |
| **C6** | **Background Sound Preservation** | Background music erased, muffled, phased, or harsh speech bleed. | Background score present, with slight volume ducking artifacts. | 100% pristine background score and ambient sound; speech sits cleanly in mix. |

### Defect Classifications (for per-line logging):
- **`Wrong meaning`**: Factual alteration, hallucination, or mistranslation (*DISQUALIFYING*).
- **`Wrong formality`**: Inappropriate social register (e.g. using `तू` / `నువ్వు` / `നീ` for an audience or elder).
- **`Unnatural`**: Textbook phrasing, awkward syntax, or archaic vocabulary.
- **`Timing`**: Rushed speech, unnatural pause, or truncated audio syllable.
- **`Voice`**: Inappropriate pitch, synthetic artifact, or emotion mismatch.
- **`Sound`**: Distortion, background music phasing, or ducking glitch.

---

## 📝 4. Listening Test Score Sheets

---

### Language 1: Telugu (`te`)

#### Full Test A: Direct-to-Camera Monologue (1–2 min)
- **Reviewer**: `____________________` | **Date**: `____________`
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality ("You" = `మీరు`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Sound Preservation | `[   ]` / 5 | |

#### Full Test B: Multi-Speaker Dialogue (2–4 min)
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality (Elder = `మీరు`, Peer = `నువ్వు`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (Spoken contractions) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Music Preservation | `[   ]` / 5 | |

#### Telugu Per-Line Defect Log
| Video (A/B) | Timestamp | What Was Said (Telugu) | Problem Description | Defect Type |
| :--- | :--- | :--- | :--- | :--- |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |

---

### Language 2: Hindi (`hi`)

#### Full Test A: Direct-to-Camera Monologue (1–2 min)
- **Reviewer**: `____________________` | **Date**: `____________`
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality ("You" = `आप`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Sound Preservation | `[   ]` / 5 | |

#### Full Test B: Multi-Speaker Dialogue (2–4 min)
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality (Elder = `आप`, Peer = `तुम`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (Everyday Hindustani) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Music Preservation | `[   ]` / 5 | |

#### Hindi Per-Line Defect Log
| Video (A/B) | Timestamp | What Was Said (Hindi) | Problem Description | Defect Type |
| :--- | :--- | :--- | :--- | :--- |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |

---

### Language 3: Marathi (`mr`)

#### Full Test A: Direct-to-Camera Monologue (1–2 min)
- **Reviewer**: `____________________` | **Date**: `____________`
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality ("You" = `तुम्ही`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (No Hindi words) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Sound Preservation | `[   ]` / 5 | |

#### Full Test B: Multi-Speaker Dialogue (2–4 min)
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality (Elder = `तुम्ही` / `आपण`, Peer = `तू`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (`करतोय` vs `करत आहे`) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Music Preservation | `[   ]` / 5 | |

#### Marathi Per-Line Defect Log
| Video (A/B) | Timestamp | What Was Said (Marathi) | Problem Description | Defect Type |
| :--- | :--- | :--- | :--- | :--- |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |

---

### Language 4: Tamil (`ta`)

#### Full Test A: Direct-to-Camera Monologue (1–2 min)
- **Reviewer**: `____________________` | **Date**: `____________`
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality ("You" = `நீங்கள்` / `நீங்க`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Sound Preservation | `[   ]` / 5 | |

#### Full Test B: Multi-Speaker Dialogue (2–4 min)
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality (Elder = `நீங்கள்`, Peer = `நீ`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (`இருக்கு`, `பண்றீங்க`) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Music Preservation | `[   ]` / 5 | |

#### Tamil Per-Line Defect Log
| Video (A/B) | Timestamp | What Was Said (Tamil) | Problem Description | Defect Type |
| :--- | :--- | :--- | :--- | :--- |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |

---

### Language 5: Malayalam (`ml`)

#### Full Test A: Direct-to-Camera Monologue (1–2 min)
- **Reviewer**: `____________________` | **Date**: `____________`
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality ("You" = `നിങ്ങൾ`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Sound Preservation | `[   ]` / 5 | |

#### Full Test B: Multi-Speaker Dialogue (2–4 min)
- **Pass Requirement**: Every criterion ≥ 4, and no line logged as Wrong meaning.

| Criterion | Score (1–5) | Reviewer Notes |
| :--- | :---: | :--- |
| C1. Meaning Kept | `[   ]` / 5 | |
| C2. Correct Formality (Elder = `നിങ്ങൾ` / `താങ്കൾ`, Peer = `നീ`) | `[   ]` / 5 | |
| C3. Sounds Spoken, Not Read (`എന്താ` vs `എന്താണ്`) | `[   ]` / 5 | |
| C4. Timing & Lip Feel | `[   ]` / 5 | |
| C5. Voice Suits Speaker | `[   ]` / 5 | |
| C6. Background Music Preservation | `[   ]` / 5 | |

#### Malayalam Per-Line Defect Log
| Video (A/B) | Timestamp | What Was Said (Malayalam) | Problem Description | Defect Type |
| :--- | :--- | :--- | :--- | :--- |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |
| | | | | `[ ] Wrong meaning [ ] Wrong formality [ ] Unnatural [ ] Timing [ ] Voice [ ] Sound` |

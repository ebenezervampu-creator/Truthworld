# Subtitle Architecture Diagram

## Data Flow: From Firestore to UI

```
┌─────────────────────────────────────────────────────────────────┐
│                      Firestore Database                         │
│                                                                 │
│  videos/{videoId}                                               │
│  ├─ media.subtitles                                             │
│  │  ├─ en: "gs://bucket/subtitles/job_id/en.srt"              │
│  │  ├─ hi: "gs://bucket/subtitles/job_id/hi.srt"              │
│  │  └─ te: "gs://bucket/subtitles/job_id/te.srt"              │
│  ├─ media.variants                                              │
│  │  ├─ 144p: "gs://bucket/resolutions/...144p.mp4"            │
│  │  ├─ 720p: "gs://bucket/resolutions/...720p.mp4"            │
│  └─ language: "en"                                              │
│     sourceLanguage: "en"                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
         ┌──────────────────┐  ┌──────────────────┐
         │ Video.fromMap()  │  │ _parseSubtitles()│
         │                  │  │                  │
         │ Extracts:        │  │ Converts:        │
         │ • subtitles[]    │  │ • Map → List     │
         │ • variants[]     │  │ • gs:// URLs     │
         │ • language       │  │                  │
         └──────────────────┘  └──────────────────┘
                    ↓                   ↓
         ┌─────────────────────────────────────┐
         │    VideoController                  │
         │                                     │
         │  availableSubtitles: RxList[]       │
         │  availableResolutions: RxList[]     │
         │  currentResolution: Rx?             │
         └─────────────────────────────────────┘
                    ↓
         ┌─────────────────────────────────────┐
         │  fetchAvailableSubtitles()          │
         │                                     │
         │  1. Load from video.subtitles       │
         │  2. Fallback: subtitle_jobs coll.   │
         │  3. Resolve gs:// URLs              │
         │  4. Sort by user language           │
         │  5. Convert to SubtitleTrack        │
         │  6. Sync to TowerPlayerController   │
         └─────────────────────────────────────┘
                    ↓
    ┌────────────────────────────────────┐
    │   TowerPlayerController            │
    │                                    │
    │   subtitleTracks: RxList[]         │
    │   subtitleSegments: RxList[]       │
    │   currentSubtitle: RxString        │
    │   subtitlesEnabled: RxBool         │
    │   activeSubLang: RxString          │
    └────────────────────────────────────┘
                    ↓
    ┌────────────────────────────────────┐
    │  TowerCustomPlayer (UI Layer)      │
    │                                    │
    │  ├─ Settings Panel                 │
    │  │  ├─ Toggle subtitles            │
    │  │  └─ Select language              │
    │  │                                  │
    │  └─ Subtitle Overlay                │
    │     └─ Display currentSubtitle      │
    └────────────────────────────────────┘
```

---

## Component Hierarchy

```
TowerCustomPlayer (StatelessWidget)
│
├─ GetBuilder<TowerPlayerController>
│  │
│  └─ Stack
│     ├─ _AudioOnlyOverlay
│     ├─ _DoubleTapRipple
│     ├─ _StateOverlay
│     ├─ _SeekPreviewTooltip
│     ├─ _Toast
│     ├─ _MainControls
│     │  ├─ _ProgressBar
│     │  ├─ _VolumeControl
│     │  ├─ _TimeDisplay
│     │  └─ _AbrBadge
│     ├─ _SettingsPanel ← SUBTITLES HERE
│     │  ├─ _MainSettingsMenu
│     │  ├─ _SpeedPanel
│     │  ├─ _QualityPanel
│     │  ├─ _SubtitlesPanel ← SELECT LANGUAGE
│     │  ├─ _LanguagePanel
│     │  └─ _RatingPanel
│     └─ _SubtitleOverlay ← DISPLAY SUBTITLES
```

---

## Subtitle Selection Flow (User Interaction)

```
User opens Settings
        ↓
_MainSettingsMenu shown
        ↓
User taps "Subtitles / CC"
        ↓
activePanel.value = 'subtitles'
        ↓
_SubtitlesPanel displayed
        ↓
┌────────────────────────────────┐
│  Master Toggle (On/Off)        │
└────────────────────────────────┘
        ↓
┌────────────────────────────────┐
│ Available Languages:           │
│ • English (selected)           │
│ • हिंदी (Hindi)                 │
│ • తెలుగు (Telugu)               │
└────────────────────────────────┘
        ↓
User selects language
        ↓
ctrl.setSubtitles(enabled: true, track: selectedTrack)
        ↓
┌──────────────────────────────────────┐
│ 1. activeSubLang = track.label       │
│ 2. fetchAndParseSubtitles(url)       │
│ 3. _parseSubtitles(content)          │
│ 4. subtitleSegments = parsed[]       │
│ 5. UI re-renders                     │
└──────────────────────────────────────┘
        ↓
Subtitles display in real-time
during video playback
```

---

## Real-Time Subtitle Display During Playback

```
┌─────────────────────────────────────┐
│  _onVpcUpdate() called every frame   │
│  (from VideoPlayerController)        │
└─────────────────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │ if subtitlesEnabled &&    │
    │    subtitleSegments[] not empty
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │ Find segment where:       │
    │ position >= segment.start │
    │ position <= segment.end   │
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │ currentSubtitle.value =   │
    │ foundSegment?.text ?? ''  │
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │ Obx() listens to          │
    │ currentSubtitle.value     │
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │ _SubtitleOverlay          │
    │ re-renders with new text  │
    └───────────────────────────┘
                ↓
    User sees subtitle update
    in real-time on screen
```

---

## Subtitle Parsing (SRT Format Example)

```
┌────────────────────────────────────────┐
│  Raw SRT File Content                  │
│                                        │
│  1                                     │
│  00:00:05,000 --> 00:00:10,000        │
│  First subtitle line                   │
│                                        │
│  2                                     │
│  00:00:10,000 --> 00:00:15,000        │
│  Second subtitle line                  │
└────────────────────────────────────────┘
                ↓
    _parseSubtitles(content)
                ↓
    ┌───────────────────────────────────────┐
    │ Split by '\n'                         │
    │ Match timestamps with Regex:          │
    │ (\d{2}:\d{2}:\d{2})[.,](\d{3})      │
    │ --> (\d{2}:\d{2}:\d{2})[.,](\d{3})   │
    └───────────────────────────────────────┘
                ↓
    ┌───────────────────────────────────────┐
    │ Parse duration parts:                 │
    │ 00 = hours                            │
    │ 00 = minutes                          │
    │ 05 = seconds                          │
    │ 000 = milliseconds                    │
    └───────────────────────────────────────┘
                ↓
    ┌────────────────────────────────────────┐
    │ SubtitleSegment(                       │
    │   start: Duration(seconds: 5),         │
    │   end: Duration(seconds: 10),          │
    │   text: 'First subtitle line'          │
    │ )                                      │
    └────────────────────────────────────────┘
```

---

## State Management Flow

```
                    Video Starts
                        ↓
            _startPlaybackFlow()
                        ↓
        ┌───────────────┬───────────────┐
        ↓               ↓               ↓
  Resolutions    Subtitles      Audio Tracks
  (Parallel)     (Parallel)      (Parallel)
        ↓               ↓               ↓
        └───────────────┴───────────────┘
                        ↓
        availableSubtitles.assignAll(tracks)
                        ↓
        ┌─────────────────────────────────┐
        │ Auto-enable default subtitle:   │
        │ • Preferred: video.language     │
        │ • Fallback: 'en'                │
        └─────────────────────────────────┘
                        ↓
        tower.setSubtitles(
          enabled: true,
          track: defaultTrack
        )
                        ↓
        ┌──────────────────────────────────┐
        │ fetchAndParseSubtitles(url)      │
        │                                  │
        │ 1. http.get(url)                 │
        │ 2. _parseSubtitles(content)      │
        │ 3. subtitleSegments = segments[] │
        └──────────────────────────────────┘
                        ↓
        Video plays with subtitles
        _onVpcUpdate() runs every frame
        Subtitles update in real-time
```

---

## Error Recovery Chain

```
User selects Subtitle
        ↓
fetchAndParseSubtitles(url)
        ↓
    ┌─────────────────────────────┐
    │ try                         │
    │   Get subtitle file         │
    │   Parse SRT/VTT             │
    │   Display on UI             │
    └─────────────────────────────┘
        ↓
    ┌─────────────────────────────┐
    │ catch (error)               │
    │                             │
    │ if gs:// && unauthorized    │
    │   Skip (silent)             │
    │                             │
    │ else                        │
    │   Log error                 │
    │   Show "No subtitles found" │
    │                             │
    │ Finally:                    │
    │   Playback continues!       │
    └─────────────────────────────┘
```

---

## Language Priority Sorting

```
Available Subtitles:
  • English (en)
  • Hindi (hi)
  • Telugu (te)

Video Configuration:
  • language: "en"
  • sourceLanguage: "en"

Sort Algorithm:
  1. if lang == video.language     → Priority 1 (← Default)
  2. if lang == video.sourceLanguage → Priority 2
  3. if lang == 'en'               → Priority 3
  4. All others                     → Priority 4

Result (Auto-enabled):
  English (Default)
  ↓
  Hindi
  ↓
  Telugu
```

---

## Performance Timeline

```
Video Load Start
├─ T+0ms: Video document fetched
├─ T+50ms: subtitles[] parsed from media.subtitles
├─ T+100ms: Firebase Storage URLs start resolving (parallel)
│           ├─ en URL: gs:// → https:// ✓
│           ├─ hi URL: gs:// → https:// ✓
│           └─ te URL: gs:// → https:// ✓
├─ T+200ms: All URLs resolved
├─ T+250ms: Subtitles sorted by preference
├─ T+300ms: Default subtitle fetched
├─ T+400ms: SRT/VTT parsed (500+ lines typically <10ms)
├─ T+450ms: TowerPlayerController synced
├─ T+500ms: UI re-rendered
└─ T+600ms: Playback starts, subtitles ready

Total: ~600ms from start to first subtitle
(Usually hidden by video buffering)
```

---

## Quality Assurance Checkpoints

```
Subtitle Loading
├─ ✓ Firebase Storage access check
├─ ✓ URL resolution (gs:// → https://)
├─ ✓ Network request (http.get)
├─ ✓ Content parsing (SRT/VTT)
└─ ✓ UI sync (Rx updates)

Subtitle Rendering
├─ ✓ Position matching (current ≥ start && ≤ end)
├─ ✓ Text update (per frame)
├─ ✓ Empty state handling
├─ ✓ Multi-line text wrapping
└─ ✓ Seek synchronization

User Interactions
├─ ✓ Enable/disable toggle
├─ ✓ Language selection
├─ ✓ Settings menu navigation
├─ ✓ Concurrent quality/subtitle switches
└─ ✓ State persistence across seeks
```

---

## Integration Points

### With VideoController
- Receives subtitle URLs from Firestore
- Manages lifecycle: fetch → parse → display
- Syncs with `TowerPlayerController`

### With TowerPlayerController  
- Receives `SubtitleTrack[]` list
- Manages UI state: enabled/disabled
- Handles user language selection
- Updates subtitles every frame

### With Video Model
- Parses `media.subtitles` map
- Maps language codes → URLs
- Provides language/sourceLanguage context

### With Firebase
- Reads video document
- Retrieves SRT/VTT files
- Resolves gs:// URLs to download URLs

---

## Future Extensibility

```
Current Architecture:
  Video → VideoController → TowerPlayerController → UI

Can extend to:
  ├─ Custom subtitle styling
  │  └─ Font size, color, background
  │
  ├─ Multiple parsers
  │  ├─ SRT (current)
  │  ├─ VTT (current)
  │  ├─ ASS/SSA
  │  └─ Custom formats
  │
  ├─ Advanced features
  │  ├─ Subtitle offset/sync
  │  ├─ Search within subtitles
  │  ├─ Auto-generated captions
  │  └─ User-uploaded subtitles
  │
  └─ Analytics
     ├─ Subtitle language usage
     ├─ Engagement metrics
     └─ Quality feedback
```


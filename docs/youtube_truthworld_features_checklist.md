# 📋 YouTube vs. TruthWorld: Feature Implementation Checklist

This checklist contains all the standard video platform features (inspired by YouTube) and advanced integrity features (specific to TruthWorld). Use this document to track your development progress, check off completed features, or delete/mark features you choose not to implement.

---

## 🎥 1. Core Video Playback & Player UX

### Standard Playback Features (YouTube-inspired)
- [x] **Custom Video Player Controls:** Play, pause, volume, quality switcher, playback speed, and native fullscreen mode.
- [x] **Double-Tap / Hotkeys:** Skip forward/backward 10 seconds.
- [/] **Picture-in-Picture (PiP) / Mini-Player:** Keep playing video in a small corner window while browsing other pages (implemented but has viewport/routing issues).
- [x] **Auto-Play:** Automatically queue and start the next recommended video.
- [/] **Interactive Progress Bar (Scrubber):** Hover thumbnail previews over the timeline (partially complete: chapters and scrubbing work, hover previews are missing).
- [x] **Offline Downloads:** Download videos for local/offline viewing (app cache).

### Advanced Integrity & Translation Player Features (TruthWorld-specific)
- [ ] **Interactive Claims Timeline:** A synchronized marker timeline highlighting factual claims during playback.
- [ ] **Real-Time Fact Overlay:** Clickable popup cards on the video frame showing claims, sources, and credibility ratings.
- [x] **Interactive Citation Panel:** Sidebar displaying source details, domain trust tiers (Tier A-E), and evidence logs.
- [x] **AI Audio Dubbing Track Switcher:** Instantly toggle between translated cloned voice-tracks and original audio.

---

## 🔍 2. Search & Discovery

### Standard Search & Discovery (YouTube-inspired)
- [x] **Search Bar with Auto-Complete:** Search suggestions as you type.
- [x] **Search Filters:** Filter by upload date, duration, video quality, and type (video, channel, playlist).
- [x] **Infinite Scroll Recommendations:** Infinite scroll list of recommended videos.
- [x] **Interest Category Chips:** Quick filter tags at the top of the homepage (e.g., Music, Gaming, Tech).

### Advanced Search & Discovery (TruthWorld-specific)
- [ ] **Grounded Search Mode:** Toggled search that prioritizes videos with high fact-checking verification scores.
- [ ] **Category Bias Warnings:** In-feed notices for highly polarized categories (Finance, Medicine) indicating high misinformation risk.
- [ ] **Trust Score Badge Overlays:** Displaying 0-100 composite Trust Scores on video card thumbnails in all feeds.

---

## 📁 3. Playlists & Library Management

### Standard Library Features (YouTube-inspired)
- [x] **Custom Playlists:** Create, edit (title/description), and delete user playlists.
- [x] **Watch Later:** Default private playlist for bookmarking videos.
- [x] **Watch History:** Chronological list of previously watched videos with clear/pause controls.
- [x] **Liked Videos:** Default playlist collecting videos the user has liked.
- [x] **Library Tab Overview:** Merged dashboard summarizing history, playlists, and watch later.

### Advanced Library Features (TruthWorld-specific)
- [ ] **Playlist Collective Trust Rating:** Aggregated average trust score displayed at the header of every playlist.
- [ ] **Misinformation Warnings inside Playlists:** Visual badges highlighting videos within a playlist that have been flagged as false or misleading.
- [ ] **Epistemic Footprint Dashboard:** An interactive chart in the Library showing the user's consumption breakdown (factual vs. opinion vs. biased media).

---

## 🔔 4. Subscriptions & Notification Feed

### Standard Subscription Features (YouTube-inspired)
- [x] **Channel Subscriptions:** Follow creators to build a personalized feed.
- [x] **Subscription Feed:** Chronological grid of videos exclusively from subscribed channels.
- [x] **Notification Bell:** Toggle subscription notifications (All, Personalized, None).
- [x] **Creator Subscriptions (Memberships):** Paid tier for supporting creators directly.

### Advanced Subscription Features (TruthWorld-specific)
- [ ] **Reputation-Tiered Feeds:** Sorting subscribed channels by high-trust badges or institutional credibility levels.
- [ ] **Monetization Plan Indicators:** Subscription models indicating standard vs. custom billing setups (buyout vs. infrastructure support).
- [ ] **AI-Dubbing Subscriptions:** Opt-in notification alerts when a creator releases a video translated into the user's default locale.

---

## 🛠️ 5. Creator Hub & Studio (Content Management)

### Standard Creator Studio Features (YouTube-inspired)
- [x] **Video Upload Wizard:** Steps to select file, set title, description, thumbnail, and visibility (public/unlisted/private).
- [x] **Custom Thumbnails:** Upload static image overlays for videos.
- [x] **Video Manager / Content List:** Table of uploaded videos with options to edit details or delete.
- [x] **Standard Analytics Panel:** Charts for views, watch time, subscriber growth, and estimated revenue.

### Advanced Creator Studio Features (TruthWorld-specific)
- [/] **AI Pipeline Progress Tracker:** High-fidelity visual workflow showing upload processing states (Ingestion → Transcription → Fact-Checking → Dubbing → Complete) (partially complete: data structures and widgets exist but are unintegrated).
- [ ] **Manual Dubbing Studio:** Creator editor to adjust cloned voice TTS, align waveforms, and modify translated transcripts.
- [x] **Verification Report Dashboard:** Deep dive into fact-checking outcomes, detailing claim accuracy, disputable tags, and suggested repairs.
- [ ] **Economic Settings Panel:** Configure Standard vs. Custom plan parameters, track real-time hosting/CDN costs, and handle buyout packages.

---

## 💬 6. Social & Community Engagement

### Standard Social Features (YouTube-inspired)
- [x] **Comments Section:** Threaded replies, likes, dislikes, and creator hearts under videos.
- [x] **Community Posts:** Image, text, and poll updates published directly to subscriber feeds.
- [x] **Live Chat:** Real-time messaging feed during live broadcasts or premieres.

### Advanced Social Features (TruthWorld-specific)
- [ ] **Community Verification / Crowdsourcing:** Users can submit evidence logs, consensus articles, or disputes to flag claims.
- [ ] **Credibility Badges in Comments:** Commenters have their reputation score or expert category badges displayed next to their names.
- [ ] **Dynamic Fact Debates:** Special comment sections dedicated entirely to debating individual video claims, moderated by consensus algorithms.

---

## 🔒 7. Settings, Localization & Admin Controls

### Standard Admin Features (YouTube-inspired)
- [x] **Account settings:** Manage username, avatar, and linked email.
- [x] **System Theme Selector:** Light Mode / Dark Mode toggles.
- [x] **Playback Settings:** Default quality, speed, and caption defaults.

### Advanced Admin Features (TruthWorld-specific)
- [ ] **Category-Specific Weighting Rules:** Admin controls to adjust how strictly different categories are verified (e.g., political commentary vs. humor).
- [x] **Branding Configuration:** Customize CSS palettes, typography tokens, and banner styles for premium custom channels.
- [ ] **Trust Engine Thresholds:** Global toggles for AI models, consensus criteria, and search filtering parameters.

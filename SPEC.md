# Guitar Learning App — Product & Technical Spec

> Status: Draft v1 · 2026-06-14
> Platform: Native mobile (iOS + Android) · Audience: All levels (beginner → intermediate)

---

## 1. Vision

A mobile app that teaches guitar by **listening to you play**. It hears each note
and chord through the phone's mic, gives instant visual feedback, and walks every
user along a personalized path from "never held a guitar" to "playing real songs."

The core bet: people learn an instrument fastest with **immediate, honest feedback
on every attempt** — not video lectures. We build the listening engine first;
everything else is presentation on top of it.

### Design principles
- **Play in 30 seconds.** Tune in-app, then straight into making sound. No signup wall.
- **Show, don't tell.** Animated fretboard + a falling-note "highway" instead of theory.
- **Per-note feedback.** Green/red as you play, not a score at the end.
- **Small daily wins.** 3–5 min lessons, streaks, "you can now play your first song."
- **Respect the dropout points.** Most quit at sore fingertips and barre chords —
  pace the curriculum around real friction, not music-theory order.

---

## 2. Audience & levels

The single biggest engineering challenge of "all levels" is the curriculum, not the
code. We structure content as a **skill graph**, not a linear course, so the app can
place a returning player and let advanced users skip ahead.

| Tier | Entry state | Target outcome |
|------|-------------|----------------|
| **0 — First contact** | Never held a guitar | Hold it, tune it, play single open strings cleanly |
| **1 — First chords** | Can fret a note | A, E, D, G, C open chords; clean transitions |
| **2 — First songs** | Knows ~4 chords | Strumming patterns, play a real 3–4 chord song in time |
| **3 — Rhythm & barre** | Plays simple songs | Barre chords, 16th strumming, palm muting |
| **4 — Lead basics** | Solid rhythm | Scales (pentatonic), riffs, bends, hammer-ons/pull-offs |
| **5 — Intermediate** | Plays leads | Improvisation, theory, ear training, full songs |

An onboarding **placement check** (play a few things, the app listens) routes users
to the right entry node instead of forcing tier 0.

---

## 3. Core features

### 3.1 Listening engine (the heart)
- **Chromatic tuner** — always available, the simplest use of the engine; also the
  best way to validate detection accuracy before anything else.
- **Single-note detection** — pitch + onset (when a note starts) for melody/lead.
- **Chord detection** — recognize strummed chords (harder; multiple simultaneous
  pitches). Start with a "is this the right chord?" yes/no rather than full
  polyphonic transcription.
- **Timing/rhythm scoring** — was the note on the beat? (V2 — needs onset timing.)

### 3.2 Learning surfaces
- **Tab highway** — notes scroll toward a strike line; hit them in time (Rocksmith-style).
- **Chord diagrams** — finger-position charts with animated transitions.
- **Interactive fretboard** — highlights where to put fingers; lights up what you played.
- **Tuner & metronome** — utilities available everywhere.

### 3.3 Progression & motivation
- Skill graph with unlockable nodes, daily streaks, XP, practice reminders.
- Per-skill mastery tracking (e.g. "G→C transition: 78% clean").
- Spaced repetition: resurface shaky skills automatically.

### 3.4 Content
- Structured lessons per skill-graph node.
- Song library with play-along (licensing is a real concern — see §8).
- Practice tools: loop a section, slow it down, isolate a chord change.

---

## 4. Technical architecture

### 4.1 Framework recommendation
**React Native (with a custom dev build, not pure Expo Go).**

Rationale:
- Real-time audio + DSP requires native modules; we'll write/bind some native code
  either way, so the JS/TS ecosystem + fast iteration of RN wins.
- TypeScript end-to-end matches the web-tooling many devs already know.
- Reanimated + Skia give us 60fps fretboard/highway animation without native UI code.

*Alternative:* **Flutter** — arguably smoother custom-canvas performance and a single
codebase, but a smaller audio/DSP package ecosystem and Dart instead of TS. Pick
Flutter only if the team already knows Dart.

### 4.2 Audio pipeline (the hard part)
```
Mic ──▶ Native audio capture (low latency) ──▶ ring buffer
      ──▶ DSP: pitch detection (YIN / McLeod / pYIN)
      ──▶ onset detection (spectral flux)
      ──▶ note/chord classifier
      ──▶ JS bridge (throttled) ──▶ UI feedback
```
- **Capture:** native modules — iOS AVAudioEngine, Android Oboe/AudioRecord — for the
  lowest latency. Target end-to-end latency < ~50 ms so feedback feels instant.
- **Pitch detection:** YIN or McLeod Pitch Method for monophonic; both are robust on
  guitar. Run DSP in native (C++ via JSI) for performance; the JS bridge only carries
  results, not raw audio.
- **Chord recognition:** start with template matching against expected chord (we know
  what the lesson asked for, so it's a *verification* problem, not open transcription).
  Upgrade to a chroma-feature + small ML classifier later.
- **Latency budget** is the make-or-break metric. Build a test harness early that
  measures detected-note latency and pitch accuracy against known recordings.

### 4.3 Suggested stack
| Concern | Choice |
|---------|--------|
| Framework | React Native + TypeScript |
| Animation/canvas | React Native Skia + Reanimated |
| Audio capture | Custom native module (AVAudioEngine / Oboe) |
| DSP | C++ (YIN/MPM) via JSI; prototype in JS with `pitchy` |
| State | Zustand or Redux Toolkit |
| Local data | SQLite (WatermelonDB or op-sqlite) for offline-first progress |
| Backend | Supabase or Firebase (auth, sync, content delivery) |
| Music notation | Custom Skia rendering (tab/fretboard); VexFlow if standard notation needed |

### 4.4 Offline-first
Practice happens anywhere, including without signal. Lessons and progress live locally
(SQLite); sync to backend when online. Audio processing is always 100% on-device.

---

## 5. Data model (first cut)

- **User** — profile, settings, current skill-graph position.
- **Skill** — node in the graph; prerequisites, tier, lesson refs.
- **Lesson** — ordered steps; each step has a target (note/chord/pattern) + audio criteria.
- **Attempt** — per-practice result: accuracy, timing, timestamp (feeds mastery + SRS).
- **Song** — metadata, difficulty, tab/chord chart, backing track ref, license info.
- **Progress** — per-skill mastery score, streak, XP, SRS schedule.

---

## 6. Build phases

### Phase 0 — Spike (validate the risky part)
- Native mic capture + YIN pitch detection on one platform.
- A working **tuner** + a latency/accuracy test harness.
- Decision gate: is on-device detection accurate and fast enough? *Everything depends
  on this — do it before building any UI.*

### Phase 1 — MVP
- Onboarding + placement check.
- Tuner, metronome.
- Tier 0–2 curriculum (open chords → first real song).
- Tab highway + chord diagrams + per-note feedback.
- Local progress tracking, streaks.

### Phase 2
- Chord detection, timing/rhythm scoring.
- Song library with play-along, loop/slow-down practice tools.
- Backend sync, accounts, spaced repetition.

### Phase 3
- Tiers 3–5 (barre, lead, theory, ear training).
- Custom song import, social/sharing, leaderboards.

---

## 7. Key risks & open questions
- **Detection accuracy** is existential — bad mic, acoustic vs electric, background
  noise all hurt. Mitigate: on-device DSP, mic calibration step, electric-guitar input
  via interface as a "pro" path. *Validate in Phase 0.*
- **Audio latency** on Android is historically worse than iOS — Oboe helps; budget time.
- **Song licensing** — covering popular songs requires publishing licenses (mechanical/
  sync) or a service like a music-rights aggregator. Start with public-domain / original
  practice pieces and license incrementally.
- **Battery/thermal** — continuous DSP + mic + animation is heavy; profile early.
- **Monetization** — freemium (free tuner + first tier, subscription for full path) is
  the proven model in this category. Decide before building paywalls.

---

## 8. What to decide next
1. React Native vs Flutter (recommend RN unless team knows Dart).
2. iOS-first or both platforms in Phase 0 (recommend iOS-first — better audio latency
   for validating the engine).
3. Build vs license initial song content.
4. Backend: Supabase vs Firebase.
5. Confirm: should I start scaffolding Phase 0 (the audio spike)?

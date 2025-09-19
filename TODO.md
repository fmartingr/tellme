```markdown
# TODO — Menu-Whisper (macOS, Swift, Offline STT)

This file tracks the tasks needed to deliver the app in **phases** with clear acceptance checks.
Conventions:
- `[ ]` = to do, `[x]` = done
- **AC** = Acceptance Criteria
- All features must work **offline** after models are installed.

---

## Global / Project-Wide

- [x] Set project license to **MIT** and add `LICENSE` file.
- [x] Add `README.md` with high-level summary, build requirements (Xcode, macOS 13+), Apple Silicon-only note.
- [x] Add `Docs/ARCHITECTURE.md` skeleton (to be filled in Phase 0).
- [x] Create base **localization** scaffolding (`en.lproj`, `es.lproj`) with `Localizable.strings`.
- [x] Add SwiftPM structure with separate targets for `App`, `Core/*` modules.
- [x] Prepare optional tooling:
  - [x] SwiftFormat / SwiftLint config (opt-in).
  - [x] GitHub Actions macOS runner for **build-only** CI (optional).

---

## Phase 0 — Scaffolding (MVP-0)

**Goal:** Base project + menu bar item; structure and docs.

### Tasks
- [x] Create SwiftUI macOS app (macOS 13+) with `MenuBarExtra` / `NSStatusItem`.
- [x] Add placeholder mic icon (template asset).
- [x] Create module targets:
  - [x] `Core/Audio`
  - [x] `Core/STT` (with subfolders `WhisperCPP` and `CoreML` (stub))
  - [x] `Core/Models`
  - [x] `Core/Injection`
  - [x] `Core/Permissions`
  - [x] `Core/Settings`
  - [x] `Core/Utils`
- [x] Wire a minimal state machine: `Idle` state shown in menubar menu.
- [x] Add scripts:
  - [x] `Scripts/build.sh` (SPM/Xcodebuild)
  - [x] `Scripts/notarize.sh` (stub with placeholders for later)
- [x] Write `Docs/ARCHITECTURE.md` (modules, data flow, FSM diagram).

### AC
- [x] Project compiles and shows a **menu bar** icon with a basic menu.
- [x] Repo has clear structure and architecture doc.

---

## Phase 1 — Hotkey + HUD + Audio (MVP-1)

**Goal:** Listening UX without real STT.

### Tasks
- [x] Implement **global hotkey** manager:
  - [x] Default **⌘⇧V** (configurable later).
  - [x] Support **push-to-talk** (start on key down, stop on key up).
  - [x] Support **toggle** (press to start, press to stop).
- [x] Create **HUD** as non-activating centered `NSPanel`:
  - [x] State **Listening** with **RMS/peak bars** animation (SwiftUI view).
  - [x] State **Processing** with spinner/label.
  - [x] Dismiss/cancel with **Esc**.
- [x] Implement **AVAudioEngine** capture:
  - [x] Tap on input bus; compute RMS/peak for visualization.
  - [x] Resample path ready for 16 kHz mono PCM (no STT yet).
- [x] Add dictation **time limit** (default **10 min**, configurable later).
- [x] Optional **sounds** for start/stop (toggle in settings later).
- [x] Permissions onboarding:
  - [x] Request **Microphone** permission with Info.plist string.
  - [x] Show guide for **Accessibility** and **Input Monitoring** (no hard gating yet).

### AC
- [x] Hotkey works in both modes (push/toggle) across desktop & full-screen apps.
- [x] HUD appears centered; **Listening** shows live bars; **Processing** shows spinner.
- [x] Cancel (Esc) reliably stops listening and hides HUD.

---

## Phase 2 — STT via whisper.cpp (MVP-2)

**Goal:** Real offline transcription (Apple Silicon + Metal).

### Tasks
- [x] Add **whisper.cpp** integration:
  - [x] Vendor/SwiftPM/Wrapper target for C/C++ (via SwiftWhisper).
  - [x] Build with **Metal** path enabled on Apple Silicon.
  - [x] Define `STTEngine` protocol and `WhisperCPPSTTEngine` implementation.
- [x] Audio pipeline:
  - [x] Convert captured audio to **16 kHz mono** 16-bit PCM.
  - [x] Chunking/streaming into STT worker; end-of-dictation triggers transcription.
- [x] **Model Manager** (backend + minimal UI):
  - [x] Bundle a **curated JSON catalog** (name, size, languages, license, URL, SHA256).
  - [x] Download via `URLSession` with progress + resume support.
  - [x] Validate **SHA256**; store under `~/Library/Application Support/MenuWhisper/Models`.
  - [x] Allow **select active model**; persist selection.
  - [x] Language: **auto** or **forced** (persist).
- [x] Text normalization pass (basic replacements; punctuation from model).
- [x] Error handling (network failures, disk full, missing model).
- [x] Performance knobs (threads, GPU toggle if exposed by backend).

### AC
- [x] A **10 s** clip produces coherent **ES/EN** text **offline**.
- [x] Latency target: **< 4 s** additional for 10 s clip on M1 with **small** model.
- [x] Memory: ~**1.5–2.5 GB** with small model without leaks.
- [x] Model download: progress UI + SHA256 verification + selection works.

**Current Status:** Phase 2 **COMPLETE**.

**What works:**
- Real whisper.cpp integration (SwiftWhisper with Metal)
- STT transcription (verified offline ES/EN, ~2.2s for 10s audio)
- Model Manager with 3 curated models (tiny/base/small)
- Real model downloads (verified whisper-base 142MB download works)
- Preferences window with model management UI
- NSStatusItem menu bar with model status
- Hotkey protection (shows alert if no model loaded)
- Proper model path handling (`~/Library/Application Support/MenuWhisper/Models`)

**User Experience:**
1. Launch MenuWhisper → Menu shows "No model - click Preferences"
2. Open Preferences → See available models, download options
3. Download model → Progress tracking, SHA256 verification
4. Select model → Loads automatically
5. Press ⌘⇧V → Real speech-to-text transcription

No automatic downloads - users must download and select models first.

---

## Phase 3 — Robust Text Insertion (MVP-3)

**Goal:** Insert text into focused app safely; handle Secure Input.

### Tasks
- [ ] Implement **Paste** method:
  - [ ] Put text on **NSPasteboard** (general).
  - [ ] Send **⌘V** via CGEvent to focused app.
- [ ] Implement **Typing** fallback:
  - [ ] Generate per-character **CGEvent**; respect active keyboard layout.
  - [ ] Handle `\n`, `\t`, and common unicode safely.
- [ ] Detect **Secure Input**:
  - [ ] Use `IsSecureEventInputEnabled()` (or accepted API) check before injection.
  - [ ] If enabled: **do not inject**; keep text on clipboard; show non-blocking notice.
- [ ] Add preference for **insertion method** (Paste preferred) + fallback strategy.
- [ ] Add **Permissions** helpers for Accessibility/Input Monitoring (deep links).
- [ ] Compatibility tests: Safari, Chrome, Notes, VS Code, Terminal, iTerm2, Mail.

### AC
- [ ] Text reliably appears in the currently focused app via Paste.
- [ ] If Paste is blocked, Typing fallback works (except in Secure Input).
- [ ] When **Secure Input** is active: no injection occurs; clipboard contains the text; user is informed.

---

## Phase 4 — Preferences + UX Polish (MVP-4)

**Goal:** Complete options, localization, and stability.

### Tasks
- [ ] Full **Preferences** window:
  - [ ] Hotkey recorder (change ⌘⇧V if needed).
  - [ ] Mode: Push-to-talk / Toggle.
  - [ ] Model picker: list, **download**, **delete**, **set active**, show size/language/license.
  - [ ] Language: Auto / Forced (dropdown).
  - [ ] Insertion: **Direct** (default) vs **Preview**; Paste vs Typing preference.
  - [ ] HUD: opacity/size, show/hide sounds toggles.
  - [ ] Dictation limit: editable (default 10 min).
  - [ ] Advanced: threads/batch; **local logs opt-in**.
  - [ ] **Export/Import** settings (JSON).
- [ ] Implement **Preview** dialog (off by default): shows transcribed text with **Insert** / **Cancel**.
- [ ] Expand **localization** (ES/EN) for all UI strings.
- [ ] Onboarding & help views (permissions, Secure Input explanation).
- [ ] Persist all settings in `UserDefaults`; validate on load; migrate if needed.
- [ ] UX polish: icons, animation timing, keyboard navigation, VoiceOver labels.
- [ ] Optional: internal **timing instrumentation** (guarded by logs opt-in).

### AC
- [ ] All preferences persist and take effect without relaunch.
- [ ] Preview (when enabled) allows quick edit & insertion.
- [ ] ES/EN localization passes a manual spot-check.

---

## Phase 5 — Distribution (MVP-5)

**Goal:** Shippable, signed/notarized .dmg, user docs.

### Tasks
- [ ] Hardened runtime, entitlements, Info.plist:
  - [ ] `NSMicrophoneUsageDescription`
  - [ ] Review for any additional required entitlements.
- [ ] **Code signing** with Developer ID; set team identifiers.
- [ ] **Notarization** using `notarytool`; **staple** on success.
- [ ] Build **.app** and create **.dmg**:
  - [ ] DMG background, /Applications symlink, icon.
- [ ] Write **Docs/USER_GUIDE.md** (first run, downloading models, dictation flow).
- [ ] Write **Docs/TROUBLESHOOTING.md** (permissions, Secure Input, model space/RAM issues).
- [ ] QA matrix:
  - [ ] macOS **13/14/15**, Apple Silicon **M1/M2/M3**.
  - [ ] Target apps list (insertion works).
  - [ ] Offline check (network disabled).
- [ ] Prepare **VERSIONING** notes and changelog (semantic-ish).

### AC
- [ ] Signed & **notarized** .dmg installs cleanly.
- [ ] App functions **entirely offline** post-model download.
- [ ] Guides are complete and reference all common pitfalls.

---

## Phase 6 — Core ML Backend (Post-MVP)

**Goal:** Second STT backend and selector.

### Tasks
- [ ] Evaluate **Core ML** path (e.g., WhisperKit or custom Core ML models).
- [ ] Implement `STTEngineCoreML` conforming to `STTEngine` protocol.
- [ ] Backend **selector** in Preferences; runtime switching.
- [ ] Ensure **feature parity** (language settings, output normalization).
- [ ] **Benchmarks**: produce local latency/memory table across small/base/medium.
- [ ] Errors & fallbacks (if model missing, surface helpful guidance).

### AC
- [ ] Both backends run on Apple Silicon; user can switch backends.
- [ ] Comparable outputs; documented pros/cons and performance data.

---

## Backlog / Post-MVP Options

- [ ] **VAD (WebRTC)**: auto-stop on silence with thresholds.
- [ ] **Continuous dictation** with smart segmentation.
- [ ] **Noise suppression** and AGC in the audio pipeline.
- [ ] **Login item** (auto-launch at login).
- [ ] **Sparkle** or custom updater (if desirable outside App Store).
- [ ] **Settings profiles** (per-language/model presets).
- [ ] **In-app model catalog refresh** (remote JSON update).
- [ ] **Advanced insertion rules** (per-app behavior).
- [ ] **Analytics viewer** for local logs (no telemetry).

---
```

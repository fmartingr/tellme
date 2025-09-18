# Technical Definition — “Menu-Whisper” (macOS, Swift, Offline STT)

## 0) Owner Decisions (Locked)
- **Platform:** Apple Silicon only (M1/M2/M3), macOS 13+.
- **STT backends:** Start with **whisper.cpp (Metal)** for simplicity; add **Core ML** backend later.
- **Models:** Do **not** auto-download. On first run, user **chooses & downloads** a model.
- **VAD:** Post-MVP.
- **Insertion behavior:** Configurable; **direct insertion** is default (no preview).
- **Default hotkey:** **⌘⇧V** (user-configurable).
- **Punctuation:** Let the model handle punctuation automatically (no spoken commands).
- **Privacy/Connectivity:** 100% local at runtime; model downloads only when the user explicitly requests. **No telemetry**.
- **Distribution:** **.app/.dmg** (signed + notarized), outside the Mac App Store initially.
- **UI languages:** **ES/EN**.
- **Low-power mode:** Still allow downloads if the user starts them.
- **License:** **MIT**.
- **Per-dictation limit:** **10 minutes** by default (configurable).

---

## 1) Goal
A **menu bar** app for macOS that performs **offline speech-to-text** using Whisper-family models and **inserts the transcribed text** into whichever app currently has focus. Shows a minimal **HUD** while listening and processing. No internet required during normal operation.

---

## 2) MVP Scope
- Persistent **menu bar** item (NSStatusItem / `MenuBarExtra`).
- **Global hotkey** (push-to-talk and toggle modes).
- **HUD** (centered NSPanel + SwiftUI):
  - “Listening” with audio-level animation (RMS/peak).
  - “Processing” with a spinner/animation.
- **Offline STT** with **whisper.cpp** (GGUF models; Metal acceleration on Apple Silicon).
- **Model Manager**: curated list, manual download with progress + SHA256 check, user selection.
- **Text injection**:
  - Preferred: **Clipboard + ⌘V** paste.
  - Fallback: **simulated typing** via CGEvent.
  - If **Secure Input** is active, **do not inject**; show notice and keep text on clipboard.
- **Preferences**: hotkey & mode, model & language, insertion method, HUD styling, sounds, dictation limit.
- **Permissions onboarding**: Microphone, Accessibility, Input Monitoring.

---

## 3) Functional Requirements

### 3.1 Capture
- Prompt for permissions on first use.
- Global hotkey (default ⌘⇧V).
- **Push-to-talk**: start on key down, stop on key up.
- **Toggle**: press to start, press again to stop.
- Per-dictation limit (default 10 min, range 10 s–30 min).

### 3.2 HUD / UX
- Non-activating, centered **NSPanel** (~320×160), no focus stealing.
- **Listening**: bar-style audio visualization driven by live RMS/peak.
- **Processing**: spinner + “Transcribing…” label.
- **Esc** to cancel.
- Optional start/stop sounds (user-toggleable).

### 3.3 STT
- Backend A (MVP): **whisper.cpp** with **GGUF** and **Metal**.
- Language: auto-detect or forced (persisted).
- Basic text normalization; punctuation from the model.
- UTF-8 output; standard replacements (quotes, dashes, etc.).

### 3.4 Injection
- Preferred method: **NSPasteboard** + **CGEvent** to send ⌘V.
- Fallback: **CGEventCreateKeyboardEvent** (character-by-character), respecting active keyboard layout.
- **Secure Input**: detect with `IsSecureEventInputEnabled()`; if enabled, **do not inject**. Show a non-intrusive notice and leave the text on the clipboard.

### 3.5 Preferences
- **General:** hotkey + mode (push/toggle), sounds, HUD options.
- **Models:** catalog, download, select active model, language, local storage path.
- **Insertion:** direct vs preview (preview **off** by default), paste vs type.
- **Advanced:** limits, performance knobs (threads/batch), **local** logs opt-in.

---

## 4) Non-Functional Requirements
- **Offline** execution after models are installed.
- **Latency target** (M1 + “small” model): < 4 s for 10 s of audio.
- **Memory target:** ~1.5–2.5 GB with “small”.
- **Privacy:** audio and text never leave the device.
- **Accessibility:** sufficient contrast; VoiceOver labels; focus never stolen by HUD.

---

## 5) Architecture (High-Level)
- **App (SwiftUI)** with AppKit bridges for NSStatusItem and NSPanel.
- **Shortcut Manager** (Carbon `RegisterEventHotKey` or HotKey/MASShortcut).
- **Audio**: AVAudioEngine (downsample to 16 kHz mono, 16-bit PCM).
- **STT Engine**:
  - **whisper.cpp** (C/C++ via SPM/CMake) with Metal.
  - **Core ML backend** (e.g., WhisperKit / custom) in a later phase.
- **Model Manager**: curated catalog, downloads (progress + SHA256), selection, caching.
- **Text Injection**: pasteboard + CGEvent; typing fallback; Secure Input detection.
- **Permissions Manager**: guided flows to System Settings panes.
- **Settings**: UserDefaults + JSON export/import.
- **Packaging**: .app + .dmg (signed & notarized).

---

## 6) Main Flow
1. User presses global hotkey.
2. Check permissions; guide if missing.
3. Show HUD → **Listening**; start capture.
4. Stop (key up/toggle/timeout).
5. HUD → **Processing**; run STT in background.
6. On result → (optional preview) → **insert** (paste) or **fallback** (type). If Secure Input, **do not inject**; keep in clipboard + show notice.
7. Close HUD → **Idle**.

---

## 7) Finite State Machine (FSM)
- **Idle** → (Hotkey) → **Listening**
- **Listening** → (Stop/Timeout) → **Processing**
- **Processing** → (Done) → **Injecting**
- **Injecting** → (Done) → **Idle**
- Any → (Error) → **ErrorModal** → **Idle**

---

## 8) Model Management (Manual Downloads)
**Goal:** Offer a clear list of **free** Whisper-family models (names, sizes, languages, recommended backend) with one-click downloads. No automatic downloads.

### 8.1 OpenAI Whisper (official weights)
- Families: **tiny**, **base**, **small**, **medium**, **large-v2**, **large-v3** (multilingual; some `.en` variants).
- Usable with **whisper.cpp** via **GGUF** (community conversions widely available).

### 8.2 Whisper for whisper.cpp (converted GGUF)
- Community-maintained conversions for whisper.cpp (GGUF), optimized for CPU/GPU Metal on macOS.

### 8.3 Faster-Whisper (CTranslate2)
- Optimized variants (tiny/base/small/medium/large-v2/large-v3). Useful if a CT2-based or Core-ML-assisted backend is added later.

### 8.4 Distil-Whisper (distilled)
- Distilled models (e.g., **distil-large-v2/v3/v3.5**, **distil-small.en**), significantly smaller/faster with near-large accuracy.

> **UI must show:** model file size, languages, license, **RAM estimate**, and a warning if a large model is selected on lower-memory machines.

**Optional JSON Schema for catalog entries (for the app’s first-run picker):**

```json
{
  "name": "whisper-small",
  "family": "OpenAI-Whisper",
  "format": "gguf",
  "size_mb": 466,
  "languages": ["multilingual"],
  "recommended_backend": "whisper.cpp",
  "quality_tier": "small",
  "license": "MIT",
  "sha256": "…",
  "download_url": "…",
  "notes": "Good balance of speed/accuracy on M1/M2."
}
```

---

## 9) Security & Permissions

* **Info.plist:** `NSMicrophoneUsageDescription`.
* **Accessibility & Input Monitoring:** required for CGEvent; provide clear step-by-step guidance and deep-links.
* **Secure Input:** check `IsSecureEventInputEnabled()`; **never** attempt to bypass. Provide help text to identify apps that enable it (password fields, 2FA prompts, etc.).

---

## 10) Performance

* Lazy-load and reuse model (warm cache).
* Real-time downsampling to 16 kHz mono; chunked streaming into backend.
* Configurable threads; prefer **Metal** path on Apple Silicon.
* “Fast path” tweaks for short clips (<15 s).

---

## 11) Logging & Privacy

* **No remote telemetry.**
* Local logs **opt-in** (timings, errors only). Never store audio/text unless user explicitly enables a debug flag.
* “Wipe local data” button (models remain unless the user removes them).

---

## 12) Internationalization

* UI in **Spanish** and **English** (Localizable.strings).
* STT multilingual; language auto or forced per user preference.

---

## 13) Testing (Minimum)

* macOS 13/14/15 on M1/M2/M3.
* Injection works in Safari, Chrome, Notes, VS Code, Terminal, iTerm2, Mail.
* **Secure Input**: correctly detected; no injection; clipboard + notice.
* Meet latency target with **small** model on M1.
* Model download & selection flows (simulate network errors).

---

## 14) Phased Plan (AI-Deliverables)

### Phase 0 — Scaffolding (MVP-0)

**Goal:** Base project + menubar.
**Deliverables:**

* SwiftUI app with `MenuBarExtra`, microphone icon, “Idle” state.
* `ARCHITECTURE.md` describing modules (Audio/STT/Injection/Models/Permissions/Settings).
* Build scripts and signing/notarization templates.
  **DoD:** Compiles; menu bar item visible; SPM structure ready.

---

### Phase 1 — Hotkey + HUD + Audio (MVP-1)

**Goal:** Listening UX without real STT.
**Deliverables:**

* Global hotkey (default ⌘⇧V) with **push** and **toggle**.
* NSPanel HUD (Listening/Processing) + **real** RMS bars from AVAudioEngine.
* Per-dictation limit (default 10 min).
  **DoD:** Live meter responds to mic; correct state transitions.

---

### Phase 2 — STT via whisper.cpp (MVP-2)

**Goal:** Real offline transcription.
**Deliverables:**

* **whisper.cpp** module (C/C++), background inference with **Metal**.
* **Model Manager** (curated list, download with SHA256, selection).
* Language auto/forced; basic normalization.
  **DoD:** 10-second clip → coherent ES/EN text offline; meets timing targets.

---

### Phase 3 — Robust Insertion (MVP-3)

**Goal:** Reliable insertion into focused app.
**Deliverables:**

* Paste (clipboard + ⌘V) and typing fallback.
* **Secure Input** detection; safe behavior (no injection, clipboard + notice).
  **DoD:** Works across target apps; correct Secure Input handling.

---

### Phase 4 — Preferences + UX Polish (MVP-4)

**Goal:** Complete options & stability.
**Deliverables:**

* Full Preferences (hotkey, modes, model, language, insertion, HUD, sounds).
* Optional preview dialog (off by default).
* Config export/import (JSON).
  **DoD:** All settings persist and are honored.

---

### Phase 5 — Distribution (MVP-5)

**Goal:** Installable package.
**Deliverables:**

* Error handling; permission prompts & help (incl. Secure Input troubleshooting).
* **.dmg** (signed + notarized) and install guide.
* **USER\_GUIDE.md** + **TROUBLESHOOTING.md**.
  **DoD:** Clean install on test machines; distribution checklist passed.

---

### Phase 6 — Core ML Backend (Post-MVP)

**Goal:** Second backend.
**Deliverables:**

* **Core ML** integration (e.g., WhisperKit or custom conversion).
* Backend selector (whisper.cpp/Core ML) in Preferences; local benchmarks table.
  **DoD:** Feature parity and stability; documented pros/cons.

---

## 15) Mini-Prompts for the Builder AI (per Phase)

* **P0:** “Create macOS 13+ SwiftUI menubar app (`MenuBarExtra`), microphone icon, SPM layout with modules in `ARCHITECTURE.md`.”
* **P1:** “Add global hotkey (push & toggle) with `RegisterEventHotKey`; NSPanel HUD with RMS bars from AVAudioEngine; 10-minute dictation limit.”
* **P2:** “Integrate **whisper.cpp** (Metal); add Model Manager (curated list, SHA256-verified downloads, selection); language auto/forced; transcribe WAV 16 kHz mono.”
* **P3:** “Implement insertion: pasteboard+⌘V and CGEvent typing fallback; detect `IsSecureEventInputEnabled()` and avoid injection.”
* **P4:** “Implement full Preferences, optional preview, JSON export/import; UX polish and messages.”
* **P5:** “Signing + notarization; produce .dmg; write USER\_GUIDE and TROUBLESHOOTING (with Secure Input section).”
* **P6:** “Add Core ML backend (WhisperKit/custom), backend selector, and local benchmarks.”

---

## 16) Suggested Repo Layout

```
MenuWhisper/
  Sources/
    App/                 # SwiftUI + AppKit bridges
    Core/
      Audio/             # AVAudioEngine capture + meters
      STT/
        WhisperCPP/      # C/C++ wrapper + Metal path
        CoreML/          # post-MVP
      Models/            # catalog, downloads, hashes
      Injection/         # clipboard, CGEvent typing, secure input checks
      Permissions/
      Settings/
      Utils/
  Resources/             # icons, sounds, localizations
  Docs/                  # ARCHITECTURE.md, USER_GUIDE.md, TROUBLESHOOTING.md
  Scripts/               # build, sign, notarize
  Tests/                 # unit + integration
```

---

## 17) Risks & Mitigations

* **Hotkey collision (⌘⇧V)** with “Paste and Match Style” in some apps → make it discoverable & easily rebindable; warn on conflict.
* **Secure Input** blocks injection → inform the user, keep text on clipboard, provide help to identify the app enabling it.
* **RAM/latency** with large models → recommend **small/base** by default; show RAM/latency hints in the model picker.
* **Keyboard layouts** → prefer paste; if typing, map using the active layout.

---

## 18) Global MVP Definition of Done

* A 30–90 s dictation yields accurate ES/EN text **offline** and inserts correctly in common apps.
* Secure Input is correctly detected and handled.
* Model download/selection is robust and user-driven.
* Shippable **.dmg** (signed + notarized) and clear docs included.

# Architecture — Menu-Whisper

This document describes the high-level architecture and module organization for Menu-Whisper, a macOS offline speech-to-text application.

## Overview

Menu-Whisper follows a modular architecture with clear separation of concerns between UI, audio processing, speech recognition, text injection, and system integration components.

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       App Layer                         │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │   MenuBarExtra  │ │    HUD Panel    │ │ Preferences │ │
│  │   (SwiftUI)     │ │   (SwiftUI)     │ │  (SwiftUI)  │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────┐
│                      Core Modules                       │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │     Audio       │ │      STT        │ │  Injection  │ │
│  │  AVAudioEngine  │ │  whisper.cpp    │ │  Clipboard  │ │
│  │   RMS/Peak      │ │   Core ML       │ │   Typing    │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │     Models      │ │  Permissions    │ │  Settings   │ │
│  │   Management    │ │   Microphone    │ │ UserDefaults│ │
│  │   Downloads     │ │  Accessibility  │ │ JSON Export │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────┐
│                  System Integration                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │ Global Hotkeys  │ │  Secure Input   │ │   Utils     │ │
│  │    Carbon       │ │   Detection     │ │  Helpers    │ │
│  │  RegisterHotKey │ │   CGEvent API   │ │             │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Module Descriptions

### App Layer
- **MenuBarExtra**: SwiftUI-based menu bar interface using `MenuBarExtra` for macOS 13+
- **HUD Panel**: Non-activating NSPanel for "Listening" and "Processing" states
- **Preferences**: Settings window with model management, hotkey configuration, etc.

### Core Modules

#### Core/Audio
**Purpose**: Audio capture and real-time processing
- AVAudioEngine integration for microphone input
- Real-time RMS/peak computation for visual feedback
- Audio format conversion (16kHz mono PCM for STT)
- Dictation time limits and session management

#### Core/STT
**Purpose**: Speech-to-text processing with multiple backends
- **WhisperCPP**: Primary backend using whisper.cpp with Metal acceleration
- **CoreML**: Future backend for Core ML models (Phase 6)
- `STTEngine` protocol for backend abstraction
- Language detection and text normalization

#### Core/Models
**Purpose**: Model catalog, downloads, and management
- Curated model catalog (JSON-based)
- Download management with progress tracking
- SHA256 verification and integrity checks
- Local storage in `~/Library/Application Support/TellMe/Models`
- Model selection and metadata management

#### Core/Injection
**Purpose**: Text insertion into focused applications
- Clipboard-based insertion (preferred method)
- Character-by-character typing fallback
- Secure Input detection and handling
- Cross-application compatibility layer

#### Core/Permissions
**Purpose**: System permission management and onboarding
- Microphone access (AVAudioSession)
- Accessibility permissions for text injection
- Input Monitoring permissions for global hotkeys
- Permission status checking and guidance flows

#### Core/Settings
**Purpose**: User preferences and configuration persistence
- UserDefaults-based storage
- JSON export/import functionality
- Settings validation and migration
- Configuration change notifications

### System Integration

#### Global Hotkeys
- Carbon framework integration (`RegisterEventHotKey`)
- Push-to-talk and toggle modes
- Hotkey conflict detection and user guidance
- Cross-application hotkey handling

#### Secure Input Detection
- `IsSecureEventInputEnabled()` monitoring
- Safe fallback behavior (clipboard-only)
- User notification for secure contexts

#### Utils
- Shared utilities and helper functions
- Logging infrastructure (opt-in local logs)
- Error handling and user feedback

## Data Flow

### Main Operational Flow
```
User Hotkey → Audio Capture → STT Processing → Text Injection
     ▲              │              │              │
     │              ▼              ▼              ▼
 Hotkey Mgr    Audio Buffer   Model Engine   Injection Mgr
     │          RMS/Peak      whisper.cpp    Clipboard/Type
     │              │              │              │
     ▼              ▼              ▼              ▼
   HUD UI      Visual Feedback  Processing UI  Target App
```

### State Management
The application follows a finite state machine pattern:
- **Idle**: Waiting for user input
- **Listening**: Capturing audio with visual feedback
- **Processing**: Running STT inference
- **Injecting**: Inserting text into target application
- **Error**: Handling and displaying errors

## Finite State Machine

```
    ┌─────────────┐
    │    Idle     │◄─────────────┐
    └─────────────┘              │
           │                     │
           │ Hotkey Press        │ Success/Error
           ▼                     │
    ┌─────────────┐              │
    │  Listening  │              │
    └─────────────┘              │
           │                     │
           │ Stop/Timeout        │
           ▼                     │
    ┌─────────────┐              │
    │ Processing  │              │
    └─────────────┘              │
           │                     │
           │ STT Complete        │
           ▼                     │
    ┌─────────────┐              │
    │  Injecting  │──────────────┘
    └─────────────┘
```

## Technology Stack

### Core Technologies
- **Swift 5.9+**: Primary development language
- **SwiftUI**: User interface framework
- **AppKit**: macOS-specific UI components (NSStatusItem, NSPanel)
- **AVFoundation**: Audio capture and processing
- **Carbon**: Global hotkey registration

### External Dependencies
- **whisper.cpp**: C/C++ speech recognition engine with Metal support
- **Swift Package Manager**: Dependency management and build system

### Platform Integration
- **UserDefaults**: Settings persistence
- **NSPasteboard**: Clipboard operations
- **CGEvent**: Low-level input simulation
- **URLSession**: Model downloads

## Build System

The project uses Swift Package Manager with modular targets:

```
TellMe/
├── Package.swift                    # SPM configuration
├── Sources/
│   ├── App/                        # Main application target
│   ├── CoreAudio/                  # Audio processing module
│   ├── CoreSTT/                    # Speech-to-text engines
│   ├── CoreModels/                 # Model management
│   ├── CoreInjection/              # Text insertion
│   ├── CorePermissions/            # System permissions
│   ├── CoreSettings/               # User preferences
│   └── CoreUtils/                  # Shared utilities
├── Resources/                      # Assets, localizations
└── Tests/                         # Unit and integration tests
```

## Security Considerations

### Privacy
- All audio processing occurs locally
- No telemetry or data collection
- Optional local logging with user consent

### System Security
- Respects Secure Input contexts
- Requires explicit user permission grants
- Code signing and notarization for distribution

### Input Safety
- Validates all user inputs
- Safe handling of special characters in typing mode
- Proper escaping for different keyboard layouts

## Performance Characteristics

### Target Metrics
- **Latency**: <4s additional processing time for 10s audio (M1 + small model)
- **Memory**: ~1.5-2.5GB with small model
- **Model Loading**: Lazy loading with warm cache
- **UI Responsiveness**: Non-blocking background processing

### Optimization Strategies
- Metal acceleration for STT inference
- Efficient audio buffering and streaming
- Model reuse across dictation sessions
- Configurable threading for CPU-intensive operations

## Future Extensibility

The modular architecture supports future enhancements:
- Additional STT backends (Core ML, cloud services)
- Voice Activity Detection (VAD)
- Advanced audio preprocessing
- Custom insertion rules per application
- Plugin architecture for text processing

This architecture provides a solid foundation for the MVP while maintaining flexibility for future feature additions and platform evolution.
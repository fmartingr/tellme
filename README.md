# Menu-Whisper

A macOS menu bar application that provides offline speech-to-text transcription using Whisper-family models and automatically inserts the transcribed text into the currently focused application.

## Overview

Menu-Whisper is designed to be a privacy-focused, offline-first speech recognition tool for macOS. It runs entirely locally on Apple Silicon machines, requiring no internet connection during normal operation (only for initial model downloads).

### Key Features

- **100% Offline Operation**: Audio and text never leave your device
- **Apple Silicon Optimized**: Built specifically for M1/M2/M3 processors with Metal acceleration
- **Global Hotkey Support**: Default ⌘⇧V (configurable)
- **Smart Text Insertion**: Clipboard paste with typing fallback
- **Secure Input Detection**: Respects password fields and secure contexts
- **Multiple Models**: Support for various Whisper model sizes and variants
- **Multilingual**: Spanish and English interface and recognition

## Requirements

- **macOS**: 13.0 (Ventura) or later
- **Hardware**: Apple Silicon (M1, M2, or M3 processor) - Intel Macs are not supported
- **Xcode**: 15.0+ for building from source
- **Permissions**: Microphone, Accessibility, and Input Monitoring access

## Build Requirements

### Development Environment
- macOS 13+ with Xcode 15.0+
- Swift 5.9+
- Swift Package Manager (included with Xcode)

### System Dependencies
- AVFoundation framework (audio capture)
- Carbon framework (global hotkeys)
- AppKit/SwiftUI (UI components)

### Third-party Dependencies
- whisper.cpp (C/C++ library for speech recognition with Metal support)

## Installation

**Note**: This project is currently in development. Pre-built binaries will be available as signed and notarized .dmg files once complete.

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd tellme
   ```

2. Open the project in Xcode or use Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. For development, open `Package.swift` in Xcode.

## Architecture

The application is structured with modular components:
- **App**: SwiftUI interface with AppKit bridges
- **Core/Audio**: AVAudioEngine capture and processing
- **Core/STT**: Speech-to-text engines (whisper.cpp, future Core ML)
- **Core/Models**: Model management and downloads
- **Core/Injection**: Text insertion with secure input handling
- **Core/Permissions**: System permission management
- **Core/Settings**: User preferences and configuration

## Privacy & Security

- **No Telemetry**: Zero data collection or remote analytics
- **Local Processing**: All audio processing happens on-device
- **Secure Input Respect**: Automatically detects and respects secure input contexts
- **Permission-Based**: Requires explicit user consent for system access

## Development Status

This project is currently in active development following a phased approach:
- Phase 0: Project scaffolding ⬅️ **Current**
- Phase 1: Hotkey + HUD + Audio capture
- Phase 2: STT integration with whisper.cpp
- Phase 3: Text insertion system
- Phase 4: Preferences and UX polish
- Phase 5: Distribution and packaging

See `TODO.md` for detailed development progress and `TECHSPEC.md` for complete technical specifications.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

This project follows a structured development approach with clear phases and acceptance criteria. Please refer to the technical specification and TODO list before contributing.
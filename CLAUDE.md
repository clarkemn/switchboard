# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build               # Debug build
swift build -c release    # Release build
./build.sh release        # Release build with .app bundle

# Test
swift test                                          # All tests
swift test --filter INIParserTests                  # Single test class
swift test --filter INIParserTests.testParseSimple  # Single test method

# CI validates: swift test && swift build && ./build.sh release
```

## Architecture

**Switchboard** is a native macOS menu bar app (SwiftUI/MVVM) for managing AWS CLI profiles and launching terminals with assumed credentials.

**Stack:** SwiftUI + Swift Package Manager, no external dependencies, macOS 13+.

### Layers

- **Models** (`Models/AWSProfile.swift`) — Core data model. Supports four profile types: static credentials, AWS SSO, assume-role, and environment.

- **Services** (`Services/`) — Business logic, each independently testable:
  - `AWSConfigService` — Parses `~/.aws/config` and `~/.aws/credentials` via `INIParser`; watches files with `DispatchSourceFileSystemObject` (0.5s debounce).
  - `TerminalService` — Launches Terminal.app, iTerm2, Warp, or Ghostty via AppleScript (`Utilities/AppleScriptTemplates.swift`). Requires Accessibility permissions.
  - `GrantedService` — Detects Granted CLI via PATH for credential assumption.
  - `ProfileHistoryService` — Persists favorites and recents to `UserDefaults` as JSON.

- **ViewModel** (`ViewModels/ProfileViewModel.swift`) — Single `@MainActor` class coordinating all services; owns filtered/favorite profile state.

- **Views** (`Views/`) — `SwitchboardApp` registers a `MenuBarExtra` + `WindowGroup` + `Settings` scene. `MainWindowView` is the primary window with search and profile list. `PreferencesView` handles terminal selection and file-watching toggle.

- **Utilities** (`Utilities/INIParser.swift`) — Custom INI parser (no external libs); `AppleScriptTemplates.swift` contains per-terminal AppleScript strings.

### Key Patterns

- Services use constructor injection for testability.
- All UI state flows through `ProfileViewModel`; views are read-only consumers.
- Terminal launching uses `NSAppleScript` (synchronous); errors surface as `TerminalLaunchError`.
- Tests live in `tests/` and cover `INIParser`, `AWSProfile` parsing, and AppleScript string escaping.

### Release

Releases are triggered by `v*` tags. The `release.yml` workflow runs tests, builds the `.app`, creates a tarball + SHA256, uploads artifacts, creates a GitHub release, and updates the Homebrew tap. The current version is tracked in `VERSION`.

# Accessibility Permission Fixes for Ghostty and Warp

## Problem

Ghostty and Warp terminals use System Events keystrokes via AppleScript, which requires Accessibility permissions. Terminal.app and iTerm2 work fine because they have native AppleScript dictionaries. The Accessibility requirement is bad UX: it resets on debug rebuilds, requires manual System Settings navigation, and users are wary of granting it.

## Design

### Ghostty: CLI-based launching

Replace the System Events AppleScript with a `Process`-based launch using Ghostty's `-e` flag:

```
ghostty -e bash -c 'assume '\''profile'\''; exec bash'
```

Changes:
- Remove `ghostty()` and `ghosttyConsole()` from `AppleScriptTemplates`
- Add a `launchViaProcess` path in `TerminalService` for Ghostty
- Set `requiresSystemEventsAccess = false` for Ghostty
- Warning banner automatically stops showing for Ghostty users

### Warp: `AXIsProcessTrustedWithOptions` prompt

Replace the passive "go to System Settings" flow with an active system prompt:

- Call `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true` to trigger the native macOS permission dialog
- Trigger proactively in `checkAccessibilityPermissions()` when Warp is selected and permissions aren't granted (fires on first launch attempt)
- Existing warning banner remains as fallback if user dismisses the dialog

### Unchanged

- Terminal.app and iTerm2 (native AppleScript, no permissions needed)
- Warning banner UI (stays as Warp fallback)
- Error handling patterns (`TerminalLaunchError` types)

### Testing

- Update escaping tests if shell escaping differs from AppleScript escaping
- Update `TerminalServiceTests` for new Ghostty path
- Manual: Ghostty launches without accessibility, Warp shows system dialog

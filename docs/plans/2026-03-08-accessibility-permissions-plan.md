# Accessibility Permission Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate Accessibility permission requirement for Ghostty (CLI launch) and improve permission UX for Warp (`AXIsProcessTrustedWithOptions` prompt).

**Architecture:** Ghostty switches from AppleScript System Events keystrokes to `Process`-based CLI launch via `ghostty -e`. Warp keeps AppleScript but replaces passive "go to Settings" with the native macOS accessibility prompt dialog. Shell escaping added for Ghostty's `Process` path.

**Tech Stack:** Swift, AppKit, ApplicationServices (`AXIsProcessTrustedWithOptions`), `Process` (Foundation)

---

### Task 1: Add shell escaping for Ghostty CLI launch

**Files:**
- Modify: `switchboard/Utilities/AppleScriptTemplates.swift:176-184` (add `escapedForShell` extension)
- Test: `tests/StringEscapingTests.swift`

**Step 1: Write the failing test**

Add to `tests/StringEscapingTests.swift`:

```swift
// MARK: - Shell Escaping Tests

func testShellEscaping_SimpleString() {
    let input = "my-profile"
    XCTAssertEqual(input.escapedForShell, "my-profile")
}

func testShellEscaping_SingleQuote() {
    let input = "it's-my-profile"
    XCTAssertEqual(input.escapedForShell, "it'\\''s-my-profile")
}

func testShellEscaping_MultipleQuotes() {
    let input = "it's a 'quoted' profile"
    XCTAssertEqual(input.escapedForShell, "it'\\''s a '\\''quoted'\\'' profile")
}

func testShellEscaping_Backslash() {
    let input = "path\\to\\profile"
    XCTAssertEqual(input.escapedForShell, "path\\to\\profile")
}

func testShellEscaping_EmptyString() {
    let input = ""
    XCTAssertEqual(input.escapedForShell, "")
}

func testShellEscaping_SpecialCharacters() {
    let input = "profile-with_special.chars@123"
    XCTAssertEqual(input.escapedForShell, "profile-with_special.chars@123")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter StringEscapingTests.testShellEscaping_SimpleString`
Expected: FAIL — `escapedForShell` does not exist

**Step 3: Write minimal implementation**

Add to `switchboard/Utilities/AppleScriptTemplates.swift` in the `String` extension:

```swift
/// Escape string for use in single-quoted shell arguments
/// Uses the '\'' pattern to break out of single quotes safely
var escapedForShell: String {
    self.replacingOccurrences(of: "'", with: "'\\''")
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StringEscapingTests`
Expected: All PASS

**Step 5: Commit**

```bash
git add switchboard/Utilities/AppleScriptTemplates.swift tests/StringEscapingTests.swift
git commit -m "feat: add shell escaping for Ghostty CLI launch"
```

---

### Task 2: Add Ghostty CLI launch command builder

**Files:**
- Modify: `switchboard/Utilities/AppleScriptTemplates.swift` (add `GhosttyCommands` enum)
- Test: `tests/StringEscapingTests.swift`

**Step 1: Write the failing tests**

Add to `tests/StringEscapingTests.swift`, replacing the existing Ghostty template tests:

```swift
// MARK: - Ghostty CLI Command Tests

func testGhosttyCommand_Assume() {
    let args = GhosttyCommands.ghosttyArgs(profileName: "test-profile", forConsole: false)
    XCTAssertEqual(args, ["-e", "bash", "-c", "assume 'test-profile'; exec bash"])
}

func testGhosttyCommand_AssumeConsole() {
    let args = GhosttyCommands.ghosttyArgs(profileName: "test-profile", forConsole: true)
    XCTAssertEqual(args, ["-e", "bash", "-c", "assume -c 'test-profile'; exec bash"])
}

func testGhosttyCommand_WithQuotesInProfile() {
    let args = GhosttyCommands.ghosttyArgs(profileName: "it's-my-profile", forConsole: false)
    XCTAssertEqual(args, ["-e", "bash", "-c", "assume 'it'\\''s-my-profile'; exec bash"])
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter StringEscapingTests.testGhosttyCommand_Assume`
Expected: FAIL — `GhosttyCommands` does not exist

**Step 3: Write minimal implementation**

Add to `switchboard/Utilities/AppleScriptTemplates.swift`:

```swift
// MARK: - Ghostty CLI Commands

/// Command arguments for launching Ghostty via CLI (no AppleScript/Accessibility needed)
enum GhosttyCommands {

    /// Build arguments for `ghostty` CLI to run assume command
    /// - Parameters:
    ///   - profileName: AWS profile name to assume
    ///   - forConsole: Whether to use assume -c (console mode)
    /// - Returns: Array of arguments to pass to the ghostty process
    static func ghosttyArgs(profileName: String, forConsole: Bool) -> [String] {
        let escapedProfile = profileName.escapedForShell
        let assumeCmd = forConsole ? "assume -c" : "assume"
        return ["-e", "bash", "-c", "\(assumeCmd) '\(escapedProfile)'; exec bash"]
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StringEscapingTests`
Expected: All PASS

**Step 5: Commit**

```bash
git add switchboard/Utilities/AppleScriptTemplates.swift tests/StringEscapingTests.swift
git commit -m "feat: add GhosttyCommands for CLI-based launching"
```

---

### Task 3: Switch Ghostty launching from AppleScript to Process

**Files:**
- Modify: `switchboard/Services/TerminalService.swift:79-84,143-163`
- Modify: `switchboard/Utilities/AppleScriptTemplates.swift` (remove Ghostty AppleScript templates)
- Test: `tests/TerminalServiceTests.swift`

**Step 1: Update tests — Ghostty no longer requires System Events**

In `tests/TerminalServiceTests.swift`:

- Change `testRequiresSystemEventsAccess_Ghostty_IsTrue` to assert **false**
- Change `testRequiresAccessibilityPermissions_Ghostty_IsTrue` to assert **false**
- Remove `testGhosttyScript_UsesSystemEvents` (no more AppleScript for Ghostty)

Updated tests:

```swift
func testRequiresSystemEventsAccess_Ghostty_IsFalse() {
    XCTAssertFalse(TerminalService.Terminal.ghostty.requiresSystemEventsAccess)
}

func testRequiresAccessibilityPermissions_Ghostty_IsFalse() {
    let service = TerminalService()
    XCTAssertFalse(service.requiresAccessibilityPermissions(.ghostty))
}
```

Also remove `testAppleScriptTemplate_Ghostty` and `testAppleScriptTemplate_GhosttyConsole` from `tests/StringEscapingTests.swift` (replaced by `testGhosttyCommand_*` tests from Task 2).

**Step 2: Run tests to verify they fail**

Run: `swift test --filter TerminalServiceTests`
Expected: FAIL — Ghostty still returns `true` for `requiresSystemEventsAccess`

**Step 3: Update TerminalService**

In `switchboard/Services/TerminalService.swift`:

a) Change `requiresSystemEventsAccess` for Ghostty to `false`:

```swift
var requiresSystemEventsAccess: Bool {
    switch self {
    case .terminal, .iTerm2, .ghostty: return false
    case .warp: return true
    }
}
```

b) Add `launchViaProcess` method and update `launchViaAppleScript` to route Ghostty to it:

```swift
/// Launch Ghostty using CLI Process (no Accessibility permissions needed)
private func launchViaProcess(terminal: Terminal, profileName: String, forConsole: Bool) throws {
    let ghosttyURL: URL
    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) {
        ghosttyURL = appURL.appendingPathComponent("Contents/MacOS/ghostty")
    } else {
        throw TerminalLaunchError.terminalNotInstalled(name: terminal.displayName)
    }

    let args = GhosttyCommands.ghosttyArgs(profileName: profileName, forConsole: forConsole)

    let process = Process()
    process.executableURL = ghosttyURL
    process.arguments = args

    do {
        try process.run()
    } catch {
        throw TerminalLaunchError.launchFailed(terminal: terminal.displayName, reason: error.localizedDescription)
    }
}
```

c) Update `launchViaAppleScript` to route Ghostty to the new method. Replace the Ghostty case in the switch and add routing at the top:

```swift
private func launchViaAppleScript(terminal: Terminal, profileName: String, forConsole: Bool) throws {
    // Ghostty uses CLI-based launching (no Accessibility permissions needed)
    if terminal == .ghostty {
        try launchViaProcess(terminal: terminal, profileName: profileName, forConsole: forConsole)
        return
    }

    let script: String
    // ... rest of existing switch (remove .ghostty case)
```

d) Remove the `.ghostty` case from the switch statement in `launchViaAppleScript`.

**Step 4: Remove Ghostty AppleScript templates**

Delete `ghostty()` and `ghosttyConsole()` from `switchboard/Utilities/AppleScriptTemplates.swift`.

**Step 5: Run tests to verify they pass**

Run: `swift test`
Expected: All PASS

**Step 6: Commit**

```bash
git add switchboard/Services/TerminalService.swift switchboard/Utilities/AppleScriptTemplates.swift tests/TerminalServiceTests.swift tests/StringEscapingTests.swift
git commit -m "feat: switch Ghostty to CLI-based launching, no accessibility needed"
```

---

### Task 4: Add `AXIsProcessTrustedWithOptions` prompt for Warp

**Files:**
- Modify: `switchboard/Services/TerminalService.swift:91-93,103-106`

**Step 1: Update `hasAccessibilityPermissions` to accept a prompt parameter**

Replace the existing method and add a prompting variant:

```swift
/// Check if the app has Accessibility permissions
/// - Parameter prompt: If true, shows the system dialog to request permissions
/// - Returns: True if Accessibility permissions are granted
func hasAccessibilityPermissions(prompt: Bool = false) -> Bool {
    if prompt {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    return AXIsProcessTrusted()
}
```

**Step 2: Update `openAccessibilitySettings` to use the prompt**

```swift
/// Request Accessibility permissions via system prompt, with fallback to System Settings
func openAccessibilitySettings() {
    // Try the system prompt first
    let granted = hasAccessibilityPermissions(prompt: true)
    if !granted {
        // Also open System Settings as fallback
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

**Step 3: Run tests to verify nothing broke**

Run: `swift test`
Expected: All PASS

**Step 4: Commit**

```bash
git add switchboard/Services/TerminalService.swift
git commit -m "feat: use AXIsProcessTrustedWithOptions prompt for Warp permissions"
```

---

### Task 5: Trigger accessibility prompt on first Warp launch attempt

**Files:**
- Modify: `switchboard/ViewModels/ProfileViewModel.swift:193-209`

**Step 1: Update `checkAccessibilityPermissions` to prompt when Warp is selected**

```swift
/// Check accessibility permissions and update warning status
func checkAccessibilityPermissions() {
    let needsPermissions = terminalService.requiresAccessibilityPermissions(selectedTerminal)

    if needsPermissions {
        // Use prompt: true to trigger the system dialog on first check
        hasAccessibilityPermissions = terminalService.hasAccessibilityPermissions(prompt: true)
    } else {
        hasAccessibilityPermissions = true
    }

    showAccessibilityWarning = needsPermissions && !hasAccessibilityPermissions

    // Auto-clear error message if permissions are now granted or if terminal doesn't need them
    if let error = errorMessage,
       (error.contains("Accessibility permissions") || error.contains("accessibility")) {
        if hasAccessibilityPermissions || !needsPermissions {
            errorMessage = nil
        }
    }

    logger.info("Accessibility check: hasPermissions=\(self.hasAccessibilityPermissions), needsPermissions=\(needsPermissions), showWarning=\(self.showAccessibilityWarning)")
}
```

**Step 2: Run tests to verify nothing broke**

Run: `swift test`
Expected: All PASS

**Step 3: Commit**

```bash
git add switchboard/ViewModels/ProfileViewModel.swift
git commit -m "feat: trigger accessibility prompt on first Warp launch attempt"
```

---

### Task 6: Final verification

**Step 1: Run full test suite**

Run: `swift test`
Expected: All PASS

**Step 2: Build release**

Run: `swift build -c release`
Expected: Build succeeds

**Step 3: Manual testing checklist**

- [ ] Select Ghostty as terminal — no accessibility warning banner
- [ ] Click "Open in Terminal" with Ghostty — launches without permission error
- [ ] Select Warp as terminal — system accessibility dialog appears
- [ ] Dismiss dialog — warning banner shows as fallback
- [ ] Terminal.app and iTerm2 still work as before

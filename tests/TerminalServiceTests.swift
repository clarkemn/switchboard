//
//  TerminalServiceTests.swift
//  SwitchboardTests
//
//  Unit tests for TerminalService terminal type properties and accessibility permission logic
//

import XCTest
@testable import Switchboard

final class TerminalServiceTests: XCTestCase {

    // MARK: - requiresSystemEventsAccess

    // Terminal.app and iTerm2 have native AppleScript scripting dictionaries and
    // do not drive input via System Events keystrokes, so they do not need
    // Accessibility permissions.

    func testRequiresSystemEventsAccess_TerminalApp_IsFalse() {
        XCTAssertFalse(TerminalService.Terminal.terminal.requiresSystemEventsAccess)
    }

    func testRequiresSystemEventsAccess_iTerm2_IsFalse() {
        XCTAssertFalse(TerminalService.Terminal.iTerm2.requiresSystemEventsAccess)
    }

    // Warp and Ghostty have no AppleScript dictionary, so the scripts use
    // System Events keystrokes — which requires Accessibility permissions.

    func testRequiresSystemEventsAccess_Warp_IsTrue() {
        XCTAssertTrue(TerminalService.Terminal.warp.requiresSystemEventsAccess)
    }

    func testRequiresSystemEventsAccess_Ghostty_IsTrue() {
        XCTAssertTrue(TerminalService.Terminal.ghostty.requiresSystemEventsAccess)
    }

    // MARK: - requiresAccessibilityPermissions

    func testRequiresAccessibilityPermissions_TerminalApp_IsFalse() {
        let service = TerminalService()
        XCTAssertFalse(service.requiresAccessibilityPermissions(.terminal))
    }

    func testRequiresAccessibilityPermissions_iTerm2_IsFalse() {
        let service = TerminalService()
        XCTAssertFalse(service.requiresAccessibilityPermissions(.iTerm2))
    }

    func testRequiresAccessibilityPermissions_Warp_IsTrue() {
        let service = TerminalService()
        XCTAssertTrue(service.requiresAccessibilityPermissions(.warp))
    }

    func testRequiresAccessibilityPermissions_Ghostty_IsTrue() {
        let service = TerminalService()
        XCTAssertTrue(service.requiresAccessibilityPermissions(.ghostty))
    }

    // MARK: - Warp and Ghostty AppleScript templates use System Events

    // These templates must use System Events keystrokes (the reason they need
    // Accessibility permissions in the first place).

    func testWarpScript_UsesSystemEvents() {
        let script = AppleScriptTemplates.warp(profileName: "test")
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("keystroke"))
    }

    func testGhosttyScript_UsesSystemEvents() {
        let script = AppleScriptTemplates.ghostty(profileName: "test")
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("keystroke"))
    }

    // MARK: - Terminal.app and iTerm2 do NOT use System Events

    func testTerminalAppScript_DoesNotUseSystemEvents() {
        let script = AppleScriptTemplates.terminalApp(profileName: "test")
        XCTAssertFalse(script.contains("System Events"))
        XCTAssertFalse(script.contains("keystroke"))
    }

    func testITerm2Script_DoesNotUseSystemEvents() {
        let script = AppleScriptTemplates.iTerm2(profileName: "test")
        XCTAssertFalse(script.contains("System Events"))
        XCTAssertFalse(script.contains("keystroke"))
    }
}

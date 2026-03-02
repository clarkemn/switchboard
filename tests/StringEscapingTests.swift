//
//  StringEscapingTests.swift
//  SwitchboardTests
//
//  Unit tests for string escaping extensions used in AppleScript and shell commands
//

import XCTest
@testable import Switchboard

final class StringEscapingTests: XCTestCase {

    // MARK: - AppleScript Escaping Tests

    func testAppleScriptEscaping_SimpleString() {
        let input = "my-profile"
        XCTAssertEqual(input.escapedForAppleScript, "my-profile")
    }

    func testAppleScriptEscaping_SingleQuote() {
        let input = "it's-my-profile"
        XCTAssertEqual(input.escapedForAppleScript, "it\\'s-my-profile")
    }

    func testAppleScriptEscaping_MultipleQuotes() {
        let input = "it's a 'quoted' profile"
        XCTAssertEqual(input.escapedForAppleScript, "it\\'s a \\'quoted\\' profile")
    }

    func testAppleScriptEscaping_Backslash() {
        let input = "path\\to\\profile"
        XCTAssertEqual(input.escapedForAppleScript, "path\\\\to\\\\profile")
    }

    func testAppleScriptEscaping_BackslashAndQuote() {
        let input = "it's\\weird"
        // Backslashes are escaped first, then quotes
        XCTAssertEqual(input.escapedForAppleScript, "it\\'s\\\\weird")
    }

    func testAppleScriptEscaping_EmptyString() {
        let input = ""
        XCTAssertEqual(input.escapedForAppleScript, "")
    }

    func testAppleScriptEscaping_SpecialCharacters() {
        // These should not be affected by AppleScript escaping
        let input = "profile-with_special.chars@123"
        XCTAssertEqual(input.escapedForAppleScript, "profile-with_special.chars@123")
    }

    // MARK: - AppleScript Template Integration Tests (Granted)

    func testAppleScriptTemplate_TerminalApp() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.terminalApp(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"Terminal\""))
        XCTAssertTrue(script.contains("assume 'test-profile'"))
        XCTAssertTrue(script.contains("activate"))
    }

    func testAppleScriptTemplate_TerminalApp_WithQuotes() {
        let profileName = "it's-my-profile"
        let script = AppleScriptTemplates.terminalApp(profileName: profileName)

        // The escaped version should be in the script
        XCTAssertTrue(script.contains("it\\'s-my-profile"))
    }

    func testAppleScriptTemplate_TerminalAppConsole() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.terminalAppConsole(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"Terminal\""))
        XCTAssertTrue(script.contains("assume -c 'test-profile'"))
    }

    func testAppleScriptTemplate_iTerm2() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.iTerm2(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"iTerm\""))
        XCTAssertTrue(script.contains("create window with default profile"))
        XCTAssertTrue(script.contains("assume 'test-profile'"))
    }

    func testAppleScriptTemplate_iTerm2Console() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.iTerm2Console(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"iTerm\""))
        XCTAssertTrue(script.contains("assume -c 'test-profile'"))
    }

    func testAppleScriptTemplate_Warp() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.warp(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"Warp\""))
        XCTAssertTrue(script.contains("assume 'test-profile'"))
    }

    func testAppleScriptTemplate_WarpConsole() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.warpConsole(profileName: profileName)

        XCTAssertTrue(script.contains("tell application \"Warp\""))
        XCTAssertTrue(script.contains("assume -c 'test-profile'"))
    }

    func testAppleScriptTemplate_Ghostty() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.ghostty(profileName: profileName)

        XCTAssertTrue(script.contains("com.mitchellh.ghostty"))
        XCTAssertTrue(script.contains("keystroke \"n\" using command down"))
        XCTAssertTrue(script.contains("assume 'test-profile'"))
        XCTAssertTrue(script.contains("keystroke return"))
    }

    func testAppleScriptTemplate_GhosttyConsole() {
        let profileName = "test-profile"
        let script = AppleScriptTemplates.ghosttyConsole(profileName: profileName)

        XCTAssertTrue(script.contains("com.mitchellh.ghostty"))
        XCTAssertTrue(script.contains("keystroke \"n\" using command down"))
        XCTAssertTrue(script.contains("assume -c 'test-profile'"))
        XCTAssertTrue(script.contains("keystroke return"))
    }

    // MARK: - Edge Cases

    func testEscaping_UnicodeCharacters() {
        let input = "profile-with-emoji-"

        // Unicode should pass through unchanged for AppleScript escaping
        XCTAssertEqual(input.escapedForAppleScript, "profile-with-emoji-")
    }

    func testEscaping_Newlines() {
        let input = "profile\nwith\nnewlines"

        // Newlines aren't specifically escaped, but shouldn't cause crashes
        XCTAssertNotNil(input.escapedForAppleScript)
    }

    func testEscaping_Tabs() {
        let input = "profile\twith\ttabs"

        // Tabs should pass through
        XCTAssertEqual(input.escapedForAppleScript, "profile\twith\ttabs")
    }
}

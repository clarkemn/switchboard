//
//  AppleScriptTemplates.swift
//  Switchboard
//
//  AppleScript templates for launching terminals with Granted assume command
//

import Foundation

/// Templates for AppleScript commands to launch various terminal applications with Granted
enum AppleScriptTemplates {

    // MARK: - Terminal.app

    /// Generate AppleScript for Terminal.app with Granted assume
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func terminalApp(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "Terminal"
            activate
            do script "assume '\(escapedProfile)'"
        end tell
        """
    }

    /// Generate AppleScript for Terminal.app with Granted assume -c (console)
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func terminalAppConsole(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "Terminal"
            activate
            do script "assume -c '\(escapedProfile)'"
        end tell
        """
    }

    // MARK: - iTerm2

    /// Generate AppleScript for iTerm2 with Granted assume
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func iTerm2(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "iTerm"
            activate
            create window with default profile
            tell current session of current window
                write text "assume '\(escapedProfile)'"
            end tell
        end tell
        """
    }

    /// Generate AppleScript for iTerm2 with Granted assume -c (console)
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func iTerm2Console(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "iTerm"
            activate
            create window with default profile
            tell current session of current window
                write text "assume -c '\(escapedProfile)'"
            end tell
        end tell
        """
    }

    // MARK: - Warp

    /// Generate AppleScript for Warp terminal with Granted assume
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func warp(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "Warp"
            activate
        end tell

        delay 0.5

        tell application "System Events"
            tell process "Warp"
                keystroke "n" using command down
                delay 0.3
                keystroke "assume '\(escapedProfile)'"
                keystroke return
            end tell
        end tell
        """
    }

    /// Generate AppleScript for Warp terminal with Granted assume -c (console)
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func warpConsole(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application "Warp"
            activate
        end tell

        delay 0.5

        tell application "System Events"
            tell process "Warp"
                keystroke "n" using command down
                delay 0.3
                keystroke "assume -c '\(escapedProfile)'"
                keystroke return
            end tell
        end tell
        """
    }


    // MARK: - Ghostty

    /// Generate AppleScript for Ghostty terminal with Granted assume
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func ghostty(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application id "com.mitchellh.ghostty"
            activate
        end tell

        delay 0.5

        tell application "System Events"
            tell process "Ghostty"
                keystroke "n" using command down
                delay 0.3
                keystroke "assume '\(escapedProfile)'"
                keystroke return
            end tell
        end tell
        """
    }

    /// Generate AppleScript for Ghostty terminal with Granted assume -c (console)
    /// - Parameter profileName: AWS profile name to assume
    /// - Returns: AppleScript string
    static func ghosttyConsole(profileName: String) -> String {
        let escapedProfile = profileName.escapedForAppleScript
        return """
        tell application id "com.mitchellh.ghostty"
            activate
        end tell

        delay 0.5

        tell application "System Events"
            tell process "Ghostty"
                keystroke "n" using command down
                delay 0.3
                keystroke "assume -c '\(escapedProfile)'"
                keystroke return
            end tell
        end tell
        """
    }

}

// MARK: - String Escaping Extensions

extension String {
    /// Escape string for use in AppleScript
    /// Escapes single quotes and backslashes
    var escapedForAppleScript: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}

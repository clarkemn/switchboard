//
//  TerminalService.swift
//  Switchboard
//
//  Service for launching terminal applications with Granted assume command
//

import Foundation
import AppKit
import ApplicationServices
import os.log

/// Logger for TerminalService
private let logger = Logger(subsystem: "com.switchboard.app", category: "TerminalService")

/// Errors that can occur when launching terminals
enum TerminalLaunchError: LocalizedError {
    case terminalNotInstalled(name: String)
    case appleScriptFailed(error: String)
    case accessibilityPermissionRequired(terminal: String)
    case launchFailed(terminal: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .terminalNotInstalled(let name):
            return "\(name) is not installed on this system"
        case .appleScriptFailed(let error):
            return "AppleScript execution failed: \(error)"
        case .accessibilityPermissionRequired(let terminal):
            return "\(terminal) requires Accessibility permissions. Go to System Settings > Privacy & Security > Accessibility and add Switchboard."
        case .launchFailed(let terminal, let reason):
            return "Failed to launch \(terminal): \(reason)"
        }
    }
}

/// Service for managing terminal application launching with Granted
class TerminalService {

    // MARK: - Terminal App Enum

    /// Supported terminal applications
    enum Terminal: String, CaseIterable, Identifiable {
        case terminal = "Terminal"
        case iTerm2 = "iTerm"
        case warp = "Warp"
        case ghostty = "Ghostty"

        var id: String { rawValue }

        /// Display name for the terminal
        var displayName: String {
            switch self {
            case .terminal: return "Terminal.app"
            case .iTerm2: return "iTerm2"
            case .warp: return "Warp"
            case .ghostty: return "Ghostty"
            }
        }

        /// Bundle identifier for the terminal application
        var bundleIdentifier: String {
            switch self {
            case .terminal: return "com.apple.Terminal"
            case .iTerm2: return "com.googlecode.iterm2"
            case .warp: return "dev.warp.Warp-Stable"
            case .ghostty: return "com.mitchellh.ghostty"
            }
        }

        /// Check if this terminal is installed
        var isInstalled: Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        }

        /// Whether this terminal requires Accessibility permissions (System Events keystroke access)
        /// Terminal.app and iTerm2 have native AppleScript dictionaries and don't need this.
        /// Warp and Ghostty rely on System Events keystrokes, which require Accessibility access.
        var requiresSystemEventsAccess: Bool {
            switch self {
            case .terminal, .iTerm2, .ghostty: return false
            case .warp: return true
            }
        }
    }

    // MARK: - Public Methods

    /// Check if the app has Accessibility permissions
    /// - Returns: True if Accessibility permissions are granted
    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Check if a specific terminal requires Accessibility permissions
    /// - Parameter terminal: Terminal to check
    /// - Returns: True if the terminal requires Accessibility permissions
    func requiresAccessibilityPermissions(_ terminal: Terminal) -> Bool {
        return terminal.requiresSystemEventsAccess
    }

    /// Open System Settings to the Accessibility privacy pane
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Detect all installed terminal applications
    /// - Returns: Array of installed terminals
    func detectInstalledTerminals() -> [Terminal] {
        Terminal.allCases.filter { $0.isInstalled }
    }

    /// Launch a terminal with Granted assume command
    /// - Parameters:
    ///   - terminal: Terminal application to launch
    ///   - profile: AWS profile to assume
    /// - Throws: TerminalLaunchError if launch fails
    func launch(terminal: Terminal, profile: AWSProfile) throws {
        guard terminal.isInstalled else {
            throw TerminalLaunchError.terminalNotInstalled(name: terminal.displayName)
        }

        try launchViaAppleScript(terminal: terminal, profileName: profile.name, forConsole: false)
    }

    /// Launch a terminal with Granted assume -c command (opens AWS Console)
    /// - Parameters:
    ///   - terminal: Terminal application to launch
    ///   - profile: AWS profile to assume for console
    /// - Throws: TerminalLaunchError if launch fails
    func launchForConsole(terminal: Terminal, profile: AWSProfile) throws {
        guard terminal.isInstalled else {
            throw TerminalLaunchError.terminalNotInstalled(name: terminal.displayName)
        }

        try launchViaAppleScript(terminal: terminal, profileName: profile.name, forConsole: true)
    }

    // MARK: - Private Methods

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

    /// Launch terminal using AppleScript
    private func launchViaAppleScript(terminal: Terminal, profileName: String, forConsole: Bool) throws {
        // Ghostty uses CLI-based launching (no Accessibility permissions needed)
        if terminal == .ghostty {
            try launchViaProcess(terminal: terminal, profileName: profileName, forConsole: forConsole)
            return
        }

        let script: String

        switch terminal {
        case .terminal:
            script = forConsole
                ? AppleScriptTemplates.terminalAppConsole(profileName: profileName)
                : AppleScriptTemplates.terminalApp(profileName: profileName)
        case .iTerm2:
            script = forConsole
                ? AppleScriptTemplates.iTerm2Console(profileName: profileName)
                : AppleScriptTemplates.iTerm2(profileName: profileName)
        case .warp:
            script = forConsole
                ? AppleScriptTemplates.warpConsole(profileName: profileName)
                : AppleScriptTemplates.warp(profileName: profileName)
        case .ghostty:
            fatalError("Ghostty should be handled by launchViaProcess")
        }

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error.description
            // Check for accessibility permission errors (error 1002 or "not allowed to send keystrokes")
            if errorMessage.contains("not allowed to send keystrokes") ||
               errorMessage.contains("assistive access") ||
               errorMessage.contains("1002") {
                throw TerminalLaunchError.accessibilityPermissionRequired(terminal: terminal.displayName)
            }
            throw TerminalLaunchError.appleScriptFailed(error: errorMessage)
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Key for storing the preferred terminal
    private static let preferredTerminalKey = "preferredTerminal"

    /// Get the preferred terminal from UserDefaults
    var preferredTerminal: TerminalService.Terminal {
        get {
            guard let rawValue = string(forKey: Self.preferredTerminalKey),
                  let terminal = TerminalService.Terminal(rawValue: rawValue) else {
                return .terminal
            }
            return terminal
        }
        set {
            set(newValue.rawValue, forKey: Self.preferredTerminalKey)
        }
    }
}

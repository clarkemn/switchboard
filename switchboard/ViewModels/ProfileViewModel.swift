//
//  ProfileViewModel.swift
//  Switchboard
//
//  ViewModel for managing application state and profile operations
//

import Foundation
import SwiftUI
import os.log

/// Logger for ProfileViewModel
private let logger = Logger(subsystem: "com.switchboard.app", category: "ProfileViewModel")

/// Main view model for the Switchboard application
@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All loaded AWS profiles
    @Published private(set) var profiles: [AWSProfile] = []

    /// Search text for filtering profiles
    @Published var searchText: String = ""

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Granted installation status
    @Published private(set) var grantedStatus: GrantedStatus = .notInstalled

    /// Whether Accessibility permissions are granted
    @Published private(set) var hasAccessibilityPermissions: Bool = true

    /// Whether to show Accessibility warning
    @Published private(set) var showAccessibilityWarning: Bool = false

    // MARK: - App Storage (Preferences)

    /// Preferred terminal application
    @AppStorage("preferredTerminal") var preferredTerminal: String = TerminalService.Terminal.terminal.rawValue

    /// Whether to show account IDs in the menu
    @AppStorage("showAccountId") var showAccountId: Bool = true

    /// Whether to show profile type icons
    @AppStorage("showProfileTypeIcon") var showProfileTypeIcon: Bool = true

    /// Whether to launch app at login
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    /// Whether to enable file watching
    @AppStorage("enableFileWatching") var enableFileWatching: Bool = true

    /// AWS directory path (default: ~/.aws)
    @AppStorage("awsDirectory") var awsDirectory: String = "~/.aws"

    // MARK: - Services

    private var configService: AWSConfigService
    private let terminalService: TerminalService
    private let grantedService: GrantedService
    private lazy var historyService = ProfileHistoryService()

    // MARK: - Computed Properties

    /// Whether Granted is installed
    var isGrantedInstalled: Bool {
        grantedStatus.isInstalled
    }

    /// Favorite profiles (sorted alphabetically)
    var favoriteProfiles: [AWSProfile] {
        let favoriteNames = Set(historyService.getFavorites())
        return profiles.filter { favoriteNames.contains($0.name) }
            .sorted { $0.name < $1.name }
    }

    /// Recent profiles (most recent first)
    var recentProfiles: [AWSProfile] {
        let recentNames = historyService.getRecents(limit: 10)
        var result: [AWSProfile] = []
        for name in recentNames {
            if let profile = profiles.first(where: { $0.name == name }) {
                result.append(profile)
            }
        }
        return result
    }

    /// Profiles filtered by search text
    var filteredProfiles: [AWSProfile] {
        if searchText.isEmpty {
            return profiles
        }

        return profiles.filter { profile in
            profile.name.localizedCaseInsensitiveContains(searchText) ||
            (profile.accountId?.contains(searchText) ?? false) ||
            (profile.region?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Available terminal applications
    var availableTerminals: [TerminalService.Terminal] {
        terminalService.detectInstalledTerminals()
    }

    /// Currently selected terminal
    var selectedTerminal: TerminalService.Terminal {
        TerminalService.Terminal(rawValue: preferredTerminal) ?? .terminal
    }

    // MARK: - Initialization

    /// Initialize the view model with optional service injection
    init(
        configService: AWSConfigService? = nil,
        terminalService: TerminalService? = nil,
        grantedService: GrantedService? = nil
    ) {
        // Note: awsDirectory @AppStorage property is initialized by SwiftUI before init
        // If configService is provided (testing), use it; otherwise create with stored path
        if let configService = configService {
            self.configService = configService
        } else {
            // Will use default "~/.aws" on first launch, then stored value
            let storedPath = UserDefaults.standard.string(forKey: "awsDirectory") ?? "~/.aws"
            self.configService = AWSConfigService(awsDirectory: storedPath)
        }

        self.terminalService = terminalService ?? TerminalService()
        self.grantedService = grantedService ?? GrantedService()

        // Check Granted installation and load profiles
        Task {
            await checkGrantedInstallation()
            if isGrantedInstalled {
                await loadProfiles()
            }
            // Check accessibility permissions on startup
            checkAccessibilityPermissions()
        }
    }

    // MARK: - Public Methods

    /// Check if Granted is installed
    func checkGrantedInstallation() async {
        let status = grantedService.detectGranted()
        await MainActor.run {
            grantedStatus = status
            logger.info("Granted status: \(status.isInstalled ? "installed" : "not installed")")
        }
    }

    /// Refresh Granted status
    func refreshGrantedStatus() {
        grantedService.refreshStatus()
        Task {
            await checkGrantedInstallation()
            if isGrantedInstalled && profiles.isEmpty {
                await loadProfiles()
            }
        }
    }

    /// Update AWS directory path and reinitialize config service
    func updateAWSDirectory(_ newPath: String) async {
        // Stop watching old files
        configService.stopWatching()

        // Reinitialize service with new path
        configService = AWSConfigService(awsDirectory: newPath)

        // Reload profiles from new location
        if isGrantedInstalled {
            await loadProfiles()
        }
    }

    /// Reset AWS directory to default
    func resetAWSDirectory() async {
        awsDirectory = "~/.aws"
        await updateAWSDirectory(awsDirectory)
    }

    /// Check accessibility permissions and update warning status
    func checkAccessibilityPermissions() {
        hasAccessibilityPermissions = terminalService.hasAccessibilityPermissions()

        // Show warning if selected terminal needs Accessibility permissions but they're not granted
        let needsPermissions = terminalService.requiresAccessibilityPermissions(selectedTerminal)
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

    /// Open System Settings to Accessibility privacy pane
    func openAccessibilitySettings() {
        terminalService.openAccessibilitySettings()
    }

    /// Dismiss accessibility warning
    func dismissAccessibilityWarning() {
        showAccessibilityWarning = false
    }

    /// Load AWS profiles from configuration files
    func loadProfiles() async {
        isLoading = true
        errorMessage = nil

        do {
            profiles = try await configService.loadProfiles()

            // Start watching for changes if enabled
            if enableFileWatching {
                startWatchingConfigFiles()
            }
        } catch {
            errorMessage = error.localizedDescription
            profiles = []
        }

        isLoading = false
    }

    /// Refresh profiles (reload from files)
    func refreshProfiles() async {
        await loadProfiles()
    }

    /// Open a terminal with Granted assume command
    /// - Parameter profile: AWS profile to activate
    func openTerminal(with profile: AWSProfile) {
        do {
            try terminalService.launch(terminal: selectedTerminal, profile: profile)
            historyService.recordUsage(profile.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Open AWS Console for the specified profile (via Granted assume -c)
    /// - Parameter profile: AWS profile to use
    func openConsole(with profile: AWSProfile) {
        do {
            try terminalService.launchForConsole(terminal: selectedTerminal, profile: profile)
            historyService.recordUsage(profile.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Copy profile name to clipboard
    func copyProfileName(_ profile: AWSProfile) {
        copyToClipboard(profile.name)
    }

    /// Copy account ID to clipboard
    func copyAccountId(_ profile: AWSProfile) {
        guard let accountId = profile.accountId else { return }
        copyToClipboard(accountId)
    }

    /// Copy export command to clipboard
    func copyExportCommand(_ profile: AWSProfile) {
        let command = "assume '\(profile.name)'"
        copyToClipboard(command)
    }

    /// Toggle favorite status for a profile
    func toggleFavorite(_ profile: AWSProfile) {
        historyService.toggleFavorite(profile.name)
        objectWillChange.send()
    }

    /// Check if a profile is favorited
    func isFavorite(_ profile: AWSProfile) -> Bool {
        return historyService.isFavorite(profile.name)
    }

    // MARK: - Private Methods

    /// Copy a string to the system clipboard
    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Start watching configuration files for changes
    private func startWatchingConfigFiles() {
        configService.startWatching { [weak self] newProfiles in
            Task { @MainActor in
                self?.profiles = newProfiles
            }
        }
    }
}

// MARK: - Helper Extensions

extension ProfileViewModel {
    /// Check if AWS CLI is installed
    var isAWSCLIInstalled: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["aws"]
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Get configuration file paths for display
    var configPaths: (config: String, credentials: String) {
        configService.configurationPaths
    }

    /// Check if AWS directory exists
    var awsDirectoryExists: Bool {
        configService.directoryExists
    }

    /// Check if any AWS config files exist
    var awsConfigFilesExist: Bool {
        configService.configFilesExist
    }
}

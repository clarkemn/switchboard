//
//  AWSConfigService.swift
//  Switchboard
//
//  Service for parsing and watching AWS configuration files
//

import Foundation
import os.log

/// Logger for AWSConfigService
private let logger = Logger(subsystem: "com.switchboard.app", category: "AWSConfigService")

/// Errors that can occur while working with AWS configuration
enum AWSConfigError: LocalizedError {
    case noConfigFiles(directory: String)
    case parsingFailed(underlying: Error)
    case invalidConfiguration(message: String)

    var errorDescription: String? {
        switch self {
        case .noConfigFiles(let directory):
            return "No AWS configuration files found at \(directory)"
        case .parsingFailed(let error):
            return "Failed to parse AWS configuration: \(error.localizedDescription)"
        case .invalidConfiguration(let message):
            return "Invalid AWS configuration: \(message)"
        }
    }
}

/// Service for managing AWS configuration files
@MainActor
class AWSConfigService: ObservableObject {

    // MARK: - Properties

    /// AWS config file path
    private let configPath: URL
    /// AWS credentials file path
    private let credentialsPath: URL
    /// AWS directory path (for display)
    private let awsDirectory: String

    /// File system monitor for config changes
    private var configMonitor: DispatchSourceFileSystemObject?
    private var credentialsMonitor: DispatchSourceFileSystemObject?

    /// Debounce timer for file changes
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5

    /// Callback for when profiles change
    private var onChangeCallback: (([AWSProfile]) -> Void)?

    // MARK: - Initialization

    init(awsDirectory: String = "~/.aws") {
        self.awsDirectory = awsDirectory
        let expandedPath = NSString(string: awsDirectory).expandingTildeInPath
        let awsDir = URL(fileURLWithPath: expandedPath)

        self.configPath = awsDir.appendingPathComponent("config")
        self.credentialsPath = awsDir.appendingPathComponent("credentials")
    }

    // MARK: - Public Methods

    /// Load AWS profiles from configuration files
    /// - Returns: Array of parsed AWS profiles
    /// - Throws: AWSConfigError if files cannot be parsed
    func loadProfiles() async throws -> [AWSProfile] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AWSConfigError.noConfigFiles(directory: "~/.aws"))
                    return
                }

                do {
                    let profiles = try self.parseProfiles()
                    continuation.resume(returning: profiles)
                } catch {
                    continuation.resume(throwing: AWSConfigError.parsingFailed(underlying: error))
                }
            }
        }
    }

    /// Start watching configuration files for changes
    /// - Parameter onChange: Callback invoked when files change (debounced)
    func startWatching(onChange: @escaping ([AWSProfile]) -> Void) {
        self.onChangeCallback = onChange

        // Watch config file
        if FileManager.default.fileExists(atPath: configPath.path) {
            startMonitoring(file: configPath, monitor: &configMonitor)
        }

        // Watch credentials file
        if FileManager.default.fileExists(atPath: credentialsPath.path) {
            startMonitoring(file: credentialsPath, monitor: &credentialsMonitor)
        }
    }

    /// Stop watching configuration files
    func stopWatching() {
        configMonitor?.cancel()
        credentialsMonitor?.cancel()
        configMonitor = nil
        credentialsMonitor = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    // MARK: - Private Methods

    /// Parse AWS configuration files and merge into profiles
    private nonisolated func parseProfiles() throws -> [AWSProfile] {
        // Parse both files (credentials file is optional)
        var config: [String: [String: String]] = [:]
        var credentials: [String: [String: String]] = [:]

        // Parse config file (required)
        if FileManager.default.fileExists(atPath: configPath.path) {
            config = try INIParser.parse(fileAt: configPath)
        }

        // Parse credentials file (optional)
        if FileManager.default.fileExists(atPath: credentialsPath.path) {
            credentials = try INIParser.parse(fileAt: credentialsPath)
        }

        // Merge into profiles
        return mergeIntoProfiles(config: config, credentials: credentials)
    }

    /// Merge config and credentials data into AWSProfile objects
    private nonisolated func mergeIntoProfiles(
        config: [String: [String: String]],
        credentials: [String: [String: String]]
    ) -> [AWSProfile] {
        // Collect all unique profile names
        var profileNames = Set<String>()
        profileNames.formUnion(config.keys)
        profileNames.formUnion(credentials.keys)

        // Create profile objects
        var profiles: [AWSProfile] = []

        for name in profileNames.sorted() {
            let configData = config[name] ?? [:]
            let credentialsData = credentials[name]

            let profile = AWSProfile(
                name: name,
                configData: configData,
                credentialsData: credentialsData
            )

            profiles.append(profile)
        }

        return profiles
    }

    /// Start monitoring a file for changes
    private func startMonitoring(
        file: URL,
        monitor: inout DispatchSourceFileSystemObject?
    ) {
        let fileDescriptor = open(file.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChange()
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        monitor = source
    }

    /// Handle file system change events (debounced)
    private func handleFileChange() {
        Task { @MainActor in
            // Cancel existing timer
            debounceTimer?.invalidate()

            // Create new debounce timer
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: debounceInterval,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.reloadAndNotify()
                }
            }
        }
    }

    /// Reload profiles and notify callback
    private func reloadAndNotify() async {
        do {
            let profiles = try await loadProfiles()
            onChangeCallback?(profiles)
        } catch {
            logger.error("Error reloading profiles: \(error.localizedDescription)")
        }
    }
}

// MARK: - Utility Extensions

extension AWSConfigService {
    /// Check if AWS configuration files exist
    var configFilesExist: Bool {
        FileManager.default.fileExists(atPath: configPath.path) ||
        FileManager.default.fileExists(atPath: credentialsPath.path)
    }

    /// Get paths for debugging
    var configurationPaths: (config: String, credentials: String) {
        (configPath.path, credentialsPath.path)
    }

    /// Get the AWS directory path
    var directoryPath: String {
        awsDirectory
    }

    /// Check if the AWS directory exists
    var directoryExists: Bool {
        let expandedPath = NSString(string: awsDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

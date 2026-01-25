//
//  GrantedService.swift
//  Switchboard
//
//  Service for detecting Granted CLI installation
//

import Foundation
import os.log

/// Logger for GrantedService
private let logger = Logger(subsystem: "com.switchboard.app", category: "GrantedService")

/// Status of Granted installation
enum GrantedStatus: Equatable {
    case installed(path: String, version: String)
    case notInstalled

    var isInstalled: Bool {
        if case .installed = self {
            return true
        }
        return false
    }

    var path: String? {
        if case .installed(let path, _) = self {
            return path
        }
        return nil
    }

    var version: String? {
        if case .installed(_, let version) = self {
            return version
        }
        return nil
    }
}

/// Service for detecting Granted CLI installation
class GrantedService {

    // MARK: - Properties

    /// Cached status of Granted installation
    private var cachedStatus: GrantedStatus?

    // MARK: - Detection

    /// Detect Granted installation
    /// - Returns: GrantedStatus indicating whether Granted is installed
    func detectGranted() -> GrantedStatus {
        if let cached = cachedStatus {
            return cached
        }

        // Check common installation paths
        let paths = [
            "/opt/homebrew/bin/granted",  // Apple Silicon Homebrew
            "/usr/local/bin/granted"       // Intel Homebrew
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                let status = getGrantedVersion(at: path)
                cachedStatus = status
                return status
            }
        }

        // Fallback: use `which` to find granted
        if let whichPath = findGrantedViaWhich() {
            let status = getGrantedVersion(at: whichPath)
            cachedStatus = status
            return status
        }

        cachedStatus = .notInstalled
        return .notInstalled
    }

    /// Check if the `assume` binary is available
    /// - Returns: Path to assume binary if found
    func findAssumeBinary() -> String? {
        let paths = [
            "/opt/homebrew/bin/assume",  // Apple Silicon Homebrew
            "/usr/local/bin/assume"       // Intel Homebrew
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: use `which` to find assume
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["assume"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            logger.error("Failed to run 'which assume': \(error.localizedDescription)")
            return nil
        }
    }

    /// Refresh the cached status
    func refreshStatus() {
        cachedStatus = nil
        _ = detectGranted()
    }

    // MARK: - Private Methods

    /// Find Granted using `which` command
    private func findGrantedViaWhich() -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["granted"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            logger.error("Failed to run 'which granted': \(error.localizedDescription)")
            return nil
        }
    }

    /// Get Granted version from binary
    private func getGrantedVersion(at path: String) -> GrantedStatus {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return .installed(path: path, version: "unknown")
            }

            // Parse version from output (format: "granted version x.y.z")
            let version = output
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "granted version ", with: "")
                .replacingOccurrences(of: "granted ", with: "")

            return .installed(path: path, version: version)
        } catch {
            logger.error("Failed to get Granted version: \(error.localizedDescription)")
            return .installed(path: path, version: "unknown")
        }
    }
}

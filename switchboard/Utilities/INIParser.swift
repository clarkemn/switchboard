//
//  INIParser.swift
//  Switchboard
//
//  Generic INI file parser for AWS configuration files
//

import Foundation

/// Errors that can occur during INI parsing
enum INIParserError: LocalizedError {
    case fileNotFound(path: String)
    case fileNotReadable(path: String)
    case invalidFormat(line: Int, content: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "INI file not found at: \(path)"
        case .fileNotReadable(let path):
            return "Cannot read INI file at: \(path)"
        case .invalidFormat(let line, let content):
            return "Invalid INI format at line \(line): \(content)"
        }
    }
}

/// Parser for INI configuration files
/// Supports sections, key-value pairs, comments, and whitespace handling
class INIParser {

    /// Parse an INI file at the given URL
    /// - Parameter url: URL of the INI file to parse
    /// - Returns: Dictionary mapping section names to their key-value pairs
    /// - Throws: INIParserError if file cannot be read or parsed
    static func parse(fileAt url: URL) throws -> [String: [String: String]] {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw INIParserError.fileNotFound(path: url.path)
        }

        // Read file contents
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            throw INIParserError.fileNotReadable(path: url.path)
        }

        return try parse(string: contents)
    }

    /// Parse INI content from a string
    /// - Parameter string: INI file content as a string
    /// - Returns: Dictionary mapping section names to their key-value pairs
    /// - Throws: INIParserError if content is invalid
    static func parse(string: String) throws -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection: String?
        var lineNumber = 0

        for line in string.components(separatedBy: .newlines) {
            lineNumber += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            // Check for section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let sectionName = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)

                // Handle AWS CLI profile naming (strip "profile " prefix from section names)
                let cleanedSection: String
                if sectionName.hasPrefix("profile ") {
                    cleanedSection = String(sectionName.dropFirst(8))
                } else {
                    cleanedSection = sectionName
                }

                currentSection = cleanedSection
                if result[cleanedSection] == nil {
                    result[cleanedSection] = [:]
                }
                continue
            }

            // Parse key-value pair
            if let equalsIndex = trimmed.firstIndex(of: "=") {
                guard let section = currentSection else {
                    // Key-value pair outside of a section - skip or use default section
                    continue
                }

                let key = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)

                // Remove quotes if present
                let cleanedValue = removeQuotes(from: String(value))

                result[section]?[key] = cleanedValue
            }
        }

        return result
    }

    /// Remove surrounding quotes from a string value
    private static func removeQuotes(from string: String) -> String {
        var result = string

        // Remove double quotes
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count > 1 {
            result = String(result.dropFirst().dropLast())
        }

        // Remove single quotes
        if result.hasPrefix("'") && result.hasSuffix("'") && result.count > 1 {
            result = String(result.dropFirst().dropLast())
        }

        return result
    }
}

// MARK: - Convenience Extensions

extension INIParser {
    /// Parse multiple INI files and merge the results
    /// Later files override earlier files for the same section/key
    static func parseAndMerge(files: [URL]) throws -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]

        for file in files {
            // Skip files that don't exist (allow optional config files)
            guard FileManager.default.fileExists(atPath: file.path) else {
                continue
            }

            let parsed = try parse(fileAt: file)

            // Merge sections
            for (section, keyValues) in parsed {
                if result[section] == nil {
                    result[section] = keyValues
                } else {
                    // Merge key-value pairs, later values override earlier ones
                    result[section]?.merge(keyValues) { _, new in new }
                }
            }
        }

        return result
    }
}

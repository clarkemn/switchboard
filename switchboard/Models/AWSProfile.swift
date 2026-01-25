//
//  AWSProfile.swift
//  Switchboard
//
//  AWS profile data model with support for multiple profile types
//

import Foundation

/// Represents an AWS CLI profile with its configuration
struct AWSProfile: Identifiable, Hashable {
    /// Unique identifier (profile name)
    let id: String

    /// Display name for the profile
    let name: String

    /// AWS region (e.g., "us-east-1")
    let region: String?

    /// AWS account ID (extracted from role ARN or SSO config)
    let accountId: String?

    /// Type of profile (credentials, SSO, assume role, etc.)
    let type: ProfileType

    /// Type of AWS profile
    enum ProfileType: String, CaseIterable {
        case staticCredentials = "key.fill"
        case sso = "person.badge.key.fill"
        case assumeRole = "arrow.triangle.2.circlepath"
        case environment = "globe"

        /// SF Symbol icon name for this profile type
        var icon: String { rawValue }

        /// Human-readable description
        var description: String {
            switch self {
            case .staticCredentials: return "Static Credentials"
            case .sso: return "AWS SSO"
            case .assumeRole: return "Assume Role"
            case .environment: return "Environment"
            }
        }
    }
}

// MARK: - Convenience Initializers

extension AWSProfile {
    /// Create a profile from merged config and credentials data
    init(
        name: String,
        configData: [String: String],
        credentialsData: [String: String]?
    ) {
        self.id = name
        self.name = name
        self.region = configData["region"]

        // Determine profile type
        if configData["sso_start_url"] != nil {
            self.type = .sso
            self.accountId = configData["sso_account_id"]
        } else if let roleArn = configData["role_arn"] {
            self.type = .assumeRole
            self.accountId = Self.extractAccountId(from: roleArn)
        } else if credentialsData?["aws_access_key_id"] != nil {
            self.type = .staticCredentials
            self.accountId = nil
        } else {
            self.type = .environment
            self.accountId = nil
        }
    }

    /// Extract AWS account ID from a role ARN
    /// Format: arn:aws:iam::123456789012:role/RoleName
    private static func extractAccountId(from arn: String) -> String? {
        let pattern = #"arn:aws:iam::(\d{12}):"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: arn,
                range: NSRange(arn.startIndex..., in: arn)
              ),
              let accountRange = Range(match.range(at: 1), in: arn) else {
            return nil
        }
        return String(arn[accountRange])
    }
}

// MARK: - Capability Helpers

extension AWSProfile {
    /// Whether this profile type supports opening AWS Console
    /// With Granted, all profile types can open console via `assume -c`
    var supportsConsole: Bool {
        true
    }
}

// MARK: - Display Helpers

extension AWSProfile {
    /// Formatted display text for the profile
    var displayText: String {
        var components = [name]

        if let accountId = accountId {
            components.append("(\(accountId))")
        }

        if let region = region {
            components.append("[\(region)]")
        }

        return components.joined(separator: " ")
    }

    /// Short display text (name and account only)
    var shortDisplayText: String {
        if let accountId = accountId {
            return "\(name) (\(accountId))"
        }
        return name
    }
}

//
//  AWSProfileTests.swift
//  SwitchboardTests
//
//  Unit tests for AWSProfile model
//

import XCTest
@testable import Switchboard

final class AWSProfileTests: XCTestCase {

    // MARK: - Profile Type Detection Tests

    func testProfileTypeDetection_SSO() {
        let configData: [String: String] = [
            "sso_start_url": "https://my-sso.awsapps.com/start",
            "sso_account_id": "123456789012",
            "sso_role_name": "AdminRole",
            "region": "us-east-1"
        ]

        let profile = AWSProfile(name: "sso-profile", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.type, .sso)
        XCTAssertEqual(profile.accountId, "123456789012")
        XCTAssertEqual(profile.region, "us-east-1")
    }

    func testProfileTypeDetection_AssumeRole() {
        let configData: [String: String] = [
            "role_arn": "arn:aws:iam::987654321098:role/CrossAccountRole",
            "source_profile": "default",
            "region": "us-west-2"
        ]

        let profile = AWSProfile(name: "assume-role-profile", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.type, .assumeRole)
        XCTAssertEqual(profile.accountId, "987654321098")
        XCTAssertEqual(profile.region, "us-west-2")
    }

    func testProfileTypeDetection_StaticCredentials() {
        let configData: [String: String] = [
            "region": "eu-west-1"
        ]
        let credentialsData: [String: String] = [
            "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
            "aws_secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        ]

        let profile = AWSProfile(name: "static-profile", configData: configData, credentialsData: credentialsData)

        XCTAssertEqual(profile.type, .staticCredentials)
        XCTAssertNil(profile.accountId) // Static credentials don't have account ID until validated
        XCTAssertEqual(profile.region, "eu-west-1")
    }

    func testProfileTypeDetection_Environment() {
        let configData: [String: String] = [
            "region": "ap-southeast-1"
        ]

        let profile = AWSProfile(name: "env-profile", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.type, .environment)
        XCTAssertNil(profile.accountId)
    }

    // MARK: - Account ID Extraction Tests

    func testAccountIdExtraction_ValidARN() {
        let configData: [String: String] = [
            "role_arn": "arn:aws:iam::111222333444:role/MyRole"
        ]

        let profile = AWSProfile(name: "test", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.accountId, "111222333444")
    }

    func testAccountIdExtraction_ValidARN_WithPath() {
        let configData: [String: String] = [
            "role_arn": "arn:aws:iam::555666777888:role/path/to/MyRole"
        ]

        let profile = AWSProfile(name: "test", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.accountId, "555666777888")
    }

    func testAccountIdExtraction_InvalidARN() {
        let configData: [String: String] = [
            "role_arn": "invalid-arn-format"
        ]

        let profile = AWSProfile(name: "test", configData: configData, credentialsData: nil)

        XCTAssertNil(profile.accountId)
    }

    func testAccountIdExtraction_MalformedARN() {
        let configData: [String: String] = [
            "role_arn": "arn:aws:iam::12345:role/TooShort" // Account ID must be 12 digits
        ]

        let profile = AWSProfile(name: "test", configData: configData, credentialsData: nil)

        XCTAssertNil(profile.accountId)
    }

    // MARK: - Display Text Tests

    func testDisplayText_FullProfile() {
        let configData: [String: String] = [
            "sso_start_url": "https://example.awsapps.com/start",
            "sso_account_id": "123456789012",
            "region": "us-east-1"
        ]

        let profile = AWSProfile(name: "my-profile", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.displayText, "my-profile (123456789012) [us-east-1]")
    }

    func testDisplayText_NoAccountId() {
        let configData: [String: String] = [
            "region": "us-west-2"
        ]

        let profile = AWSProfile(name: "simple-profile", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.displayText, "simple-profile [us-west-2]")
    }

    func testDisplayText_NoRegion() {
        let configData: [String: String] = [
            "sso_start_url": "https://example.awsapps.com/start",
            "sso_account_id": "111111111111"
        ]

        let profile = AWSProfile(name: "no-region", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.displayText, "no-region (111111111111)")
    }

    func testDisplayText_NameOnly() {
        let profile = AWSProfile(name: "minimal", configData: [:], credentialsData: nil)

        XCTAssertEqual(profile.displayText, "minimal")
    }

    func testShortDisplayText_WithAccountId() {
        let configData: [String: String] = [
            "sso_start_url": "https://example.awsapps.com/start",
            "sso_account_id": "222222222222",
            "region": "us-east-1"
        ]

        let profile = AWSProfile(name: "short-test", configData: configData, credentialsData: nil)

        XCTAssertEqual(profile.shortDisplayText, "short-test (222222222222)")
    }

    func testShortDisplayText_WithoutAccountId() {
        let profile = AWSProfile(name: "short-test", configData: [:], credentialsData: nil)

        XCTAssertEqual(profile.shortDisplayText, "short-test")
    }

    // MARK: - Profile Type Properties Tests

    func testProfileTypeIcon() {
        XCTAssertEqual(AWSProfile.ProfileType.staticCredentials.icon, "key.fill")
        XCTAssertEqual(AWSProfile.ProfileType.sso.icon, "person.badge.key.fill")
        XCTAssertEqual(AWSProfile.ProfileType.assumeRole.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(AWSProfile.ProfileType.environment.icon, "globe")
    }

    func testProfileTypeDescription() {
        XCTAssertEqual(AWSProfile.ProfileType.staticCredentials.description, "Static Credentials")
        XCTAssertEqual(AWSProfile.ProfileType.sso.description, "AWS SSO")
        XCTAssertEqual(AWSProfile.ProfileType.assumeRole.description, "Assume Role")
        XCTAssertEqual(AWSProfile.ProfileType.environment.description, "Environment")
    }

    func testProfileTypeCaseIterable() {
        let allCases = AWSProfile.ProfileType.allCases

        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.staticCredentials))
        XCTAssertTrue(allCases.contains(.sso))
        XCTAssertTrue(allCases.contains(.assumeRole))
        XCTAssertTrue(allCases.contains(.environment))
    }

    // MARK: - Identity and Equality Tests

    func testProfileIdentifiable() {
        let profile = AWSProfile(name: "test-profile", configData: [:], credentialsData: nil)

        XCTAssertEqual(profile.id, "test-profile")
    }

    func testProfileHashable() {
        let profile1 = AWSProfile(name: "profile-a", configData: [:], credentialsData: nil)
        let profile2 = AWSProfile(name: "profile-a", configData: [:], credentialsData: nil)
        let profile3 = AWSProfile(name: "profile-b", configData: [:], credentialsData: nil)

        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)

        // Test set membership
        var profileSet: Set<AWSProfile> = []
        profileSet.insert(profile1)
        profileSet.insert(profile2) // Should not increase count (same as profile1)
        profileSet.insert(profile3)

        XCTAssertEqual(profileSet.count, 2)
    }

    // MARK: - SSO Priority Tests

    func testSSOTakesPriorityOverCredentials() {
        // When both SSO config and credentials exist, SSO should take priority
        let configData: [String: String] = [
            "sso_start_url": "https://my-sso.awsapps.com/start",
            "sso_account_id": "123456789012"
        ]
        let credentialsData: [String: String] = [
            "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
            "aws_secret_access_key": "secret"
        ]

        let profile = AWSProfile(name: "mixed", configData: configData, credentialsData: credentialsData)

        XCTAssertEqual(profile.type, .sso)
    }
}

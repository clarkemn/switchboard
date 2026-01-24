//
//  INIParserTests.swift
//  SwitchboardTests
//
//  Unit tests for INI parser
//

import XCTest
@testable import Switchboard

final class INIParserTests: XCTestCase {

    // MARK: - Basic Parsing Tests

    func testParseSimpleINI() throws {
        let iniContent = """
        [section1]
        key1 = value1
        key2 = value2

        [section2]
        key3 = value3
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["section1"]?["key1"], "value1")
        XCTAssertEqual(result["section1"]?["key2"], "value2")
        XCTAssertEqual(result["section2"]?["key3"], "value3")
    }

    func testParseWithComments() throws {
        let iniContent = """
        # This is a comment
        [section1]
        key1 = value1
        # Another comment
        key2 = value2
        ; Semicolon comment
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertEqual(result["section1"]?.count, 2)
        XCTAssertEqual(result["section1"]?["key1"], "value1")
        XCTAssertEqual(result["section1"]?["key2"], "value2")
    }

    func testParseWithWhitespace() throws {
        let iniContent = """
        [section1]
           key1   =   value1
        key2=value2
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertEqual(result["section1"]?["key1"], "value1")
        XCTAssertEqual(result["section1"]?["key2"], "value2")
    }

    func testParseWithQuotes() throws {
        let iniContent = """
        [section1]
        key1 = "value with spaces"
        key2 = 'single quoted'
        key3 = unquoted
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertEqual(result["section1"]?["key1"], "value with spaces")
        XCTAssertEqual(result["section1"]?["key2"], "single quoted")
        XCTAssertEqual(result["section1"]?["key3"], "unquoted")
    }

    // MARK: - AWS Config Specific Tests

    func testParseAWSProfilePrefix() throws {
        let iniContent = """
        [default]
        region = us-east-1

        [profile dev]
        region = us-west-2
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertNotNil(result["default"])
        XCTAssertNotNil(result["dev"]) // "profile " prefix should be stripped
        XCTAssertNil(result["profile dev"]) // Should not exist with prefix
        XCTAssertEqual(result["dev"]?["region"], "us-west-2")
    }

    func testParseSampleConfig() throws {
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("sample-config")

        let result = try INIParser.parse(fileAt: fixtureURL)

        // Test that all expected profiles are present
        XCTAssertNotNil(result["default"])
        XCTAssertNotNil(result["dev"])
        XCTAssertNotNil(result["staging"])
        XCTAssertNotNil(result["production"])
        XCTAssertNotNil(result["sandbox-sso"])

        // Test specific values
        XCTAssertEqual(result["default"]?["region"], "us-east-1")
        XCTAssertEqual(result["staging"]?["role_arn"], "arn:aws:iam::111111111111:role/AdminRole")
        XCTAssertEqual(result["sandbox-sso"]?["sso_account_id"], "333333333333")
    }

    func testParseSampleCredentials() throws {
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("sample-credentials")

        let result = try INIParser.parse(fileAt: fixtureURL)

        XCTAssertNotNil(result["default"])
        XCTAssertNotNil(result["dev"])
        XCTAssertEqual(result["default"]?["aws_access_key_id"], "AKIAIOSFODNN7EXAMPLE")
    }

    // MARK: - Edge Cases

    func testEmptyFile() throws {
        let result = try INIParser.parse(string: "")
        XCTAssertTrue(result.isEmpty)
    }

    func testOnlyComments() throws {
        let iniContent = """
        # Comment 1
        ; Comment 2
        # Comment 3
        """

        let result = try INIParser.parse(string: iniContent)
        XCTAssertTrue(result.isEmpty)
    }

    func testEmptySection() throws {
        let iniContent = """
        [empty_section]

        [section_with_data]
        key = value
        """

        let result = try INIParser.parse(string: iniContent)

        XCTAssertNotNil(result["empty_section"])
        XCTAssertTrue(result["empty_section"]?.isEmpty ?? false)
        XCTAssertEqual(result["section_with_data"]?["key"], "value")
    }

    func testKeyWithoutSection() throws {
        let iniContent = """
        key1 = value1

        [section1]
        key2 = value2
        """

        let result = try INIParser.parse(string: iniContent)

        // Keys without a section should be ignored
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result["section1"])
    }

    // MARK: - Error Handling

    func testFileNotFound() {
        let invalidPath = URL(fileURLWithPath: "/nonexistent/path/config")

        XCTAssertThrowsError(try INIParser.parse(fileAt: invalidPath)) { error in
            XCTAssertTrue(error is INIParserError)
        }
    }
}

// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Switchboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Switchboard", targets: ["Switchboard"])
    ],
    targets: [
        .executableTarget(
            name: "Switchboard",
            path: "switchboard",
            exclude: [
                "Info.plist",
                "Resources"
            ],
            sources: [
                "SwitchboardApp.swift",
                "Models/AWSProfile.swift",
                "Services/AWSConfigService.swift",
                "Services/GrantedService.swift",
                "Services/ProfileHistoryService.swift",
                "Services/TerminalService.swift",
                "ViewModels/ProfileViewModel.swift",
                "Views/MainWindowView.swift",
                "Views/MenuBarView.swift",
                "Views/PreferencesView.swift",
                "Utilities/AppleScriptTemplates.swift",
                "Utilities/INIParser.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        ),
        .testTarget(
            name: "SwitchboardTests",
            dependencies: ["Switchboard"],
            path: "Tests",
            exclude: ["Fixtures"],
            sources: [
                "INIParserTests.swift",
                "AWSProfileTests.swift",
                "StringEscapingTests.swift"
            ]
        )
    ]
)

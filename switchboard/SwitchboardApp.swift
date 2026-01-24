//
//  SwitchboardApp.swift
//  Switchboard
//
//  Main application entry point
//

import SwiftUI

@main
struct SwitchboardApp: App {

    // MARK: - Properties

    @StateObject private var viewModel = ProfileViewModel()

    // MARK: - Scene Configuration

    var body: some Scene {
        // Main application window
        WindowGroup {
            MainWindowView()
                .environmentObject(viewModel)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 500, height: 450)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Switchboard") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Switchboard",
                            .applicationVersion: "1.0.0",
                            .credits: NSAttributedString(
                                string: "A macOS application for managing AWS CLI profiles"
                            )
                        ]
                    )
                }
            }
        }

        // Settings/Preferences window
        Settings {
            PreferencesView()
                .environmentObject(viewModel)
        }
        
        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
        } label: {
            Image(systemName: "person.badge.key")
        }
        .menuBarExtraStyle(.menu)
    }
}

//
//  PreferencesView.swift
//  Switchboard
//
//  Preferences window for app settings
//

import SwiftUI
import AppKit

/// Preferences window content
struct PreferencesView: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        TabView {
            GeneralPreferences()
                .environmentObject(viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            TerminalPreferences()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }

            GrantedPreferences()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Granted", systemImage: "person.badge.key")
                }

            DisplayPreferences()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Display", systemImage: "eye")
                }

            AdvancedPreferences()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
        .onAppear {
            // Check permissions when preferences window opens
            viewModel.checkAccessibilityPermissions()
        }
    }
}

// MARK: - General Preferences

struct GeneralPreferences: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select AWS configuration directory"
        panel.prompt = "Select"

        // Set initial directory to current value if it exists
        let expandedPath = NSString(string: viewModel.awsDirectory).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            panel.directoryURL = URL(fileURLWithPath: expandedPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            // Convert absolute path back to use tilde if in home directory
            let path = url.path
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let finalPath = path.hasPrefix(homeDir) ? path.replacingOccurrences(of: homeDir, with: "~") : path

            viewModel.awsDirectory = finalPath
            Task {
                await viewModel.updateAWSDirectory(finalPath)
            }
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Startup")) {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
                    .help("Automatically start Switchboard when you log in")
            }

            Section(header: Text("Configuration")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AWS Directory:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !viewModel.awsDirectoryExists {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .help("Directory does not exist")
                        } else if !viewModel.awsConfigFilesExist {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .help("No config or credentials files found in directory")
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("AWS Directory", text: $viewModel.awsDirectory)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onSubmit {
                                Task {
                                    await viewModel.updateAWSDirectory(viewModel.awsDirectory)
                                }
                            }

                        Button("Browse...") {
                            selectDirectory()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Reset to Default") {
                        Task {
                            await viewModel.resetAWSDirectory()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current paths:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Config: \(viewModel.configPaths.config)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("Credentials: \(viewModel.configPaths.credentials)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("File Watching")) {
                Toggle("Auto-refresh when config files change", isOn: $viewModel.enableFileWatching)
                    .help("Automatically reload profiles when AWS config files are modified")
            }

            Section(header: Text("Info")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Total Profiles:")
                        Spacer()
                        Text("\(viewModel.profiles.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Granted Status:")
                        Spacer()
                        if viewModel.isGrantedInstalled {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not Found", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Terminal Preferences

struct TerminalPreferences: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section(header: Text("Default Terminal")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Terminal Application", selection: $viewModel.preferredTerminal) {
                        ForEach(viewModel.availableTerminals) { terminal in
                            HStack {
                                Text(terminal.displayName)
                                if !terminal.isInstalled {
                                    Text("(Not Installed)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .tag(terminal.rawValue)
                        }
                    }
                    .help("Choose which terminal application to use when opening profiles")

                    // Show inline note if selected terminal needs accessibility
                    if viewModel.showAccessibilityWarning {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Accessibility permissions required")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Open Settings") {
                                viewModel.openAccessibilitySettings()
                            }
                            .font(.caption)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }

            Section(header: Text("Available Terminals")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(TerminalService.Terminal.allCases) { terminal in
                        HStack {
                            Image(systemName: terminal.isInstalled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(terminal.isInstalled ? .green : .secondary)

                            Text(terminal.displayName)

                            Spacer()

                            if !terminal.isInstalled {
                                Text("Not Installed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

        }
        .formStyle(.grouped)
        .onAppear {
            // Check permissions when terminal preferences appear
            viewModel.checkAccessibilityPermissions()
        }
    }
}

// MARK: - Granted Preferences

struct GrantedPreferences: View {

    @EnvironmentObject var viewModel: ProfileViewModel
    @State private var grantedStatus: GrantedStatus = .notInstalled

    var body: some View {
        Form {
            Section(header: Text("Granted CLI (Required)")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        if grantedStatus.isInstalled {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not Installed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }

                    if let path = grantedStatus.path {
                        HStack {
                            Text("Path:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if let version = grantedStatus.version {
                        HStack {
                            Text("Version:")
                            Spacer()
                            Text(version)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                Button("Refresh Status") {
                    viewModel.refreshGrantedStatus()
                    let grantedService = GrantedService()
                    grantedStatus = grantedService.detectGranted()
                }
            }

            if !grantedStatus.isInstalled {
                Section(header: Text("Installation Required")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Switchboard requires Granted to manage AWS credentials. Without Granted, the app cannot function.")
                            .font(.callout)
                            .foregroundColor(.primary)

                        Link(destination: URL(string: "https://docs.commonfate.io/granted/getting-started")!) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Install Granted")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("About Granted")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Granted is a CLI tool that simplifies AWS credential management, SSO authentication, and console access.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("Granted Documentation", destination: URL(string: "https://docs.commonfate.io/granted/introduction")!)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }

        }
        .formStyle(.grouped)
        .onAppear {
            let grantedService = GrantedService()
            grantedStatus = grantedService.detectGranted()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Display Preferences

struct DisplayPreferences: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section(header: Text("Profile Display")) {
                Toggle("Show account IDs", isOn: $viewModel.showAccountId)
                    .help("Display AWS account IDs next to profile names")

            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Preferences

struct AdvancedPreferences: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section(header: Text("Debugging")) {
                Button("Reload Profiles") {
                    Task {
                        await viewModel.refreshProfiles()
                    }
                }

                Button("Clear Error") {
                    viewModel.errorMessage = nil
                }
                .disabled(viewModel.errorMessage == nil)
            }

            Section(header: Text("About")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Switchboard")
                            .font(.headline)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Link("GitHub Repository", destination: URL(string: "https://github.com/clarkemn/switchboard")!)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Previews

#Preview {
    PreferencesView()
        .environmentObject(ProfileViewModel())
}

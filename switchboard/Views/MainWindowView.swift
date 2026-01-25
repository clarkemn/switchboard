//
//  MainWindowView.swift
//  Switchboard
//
//  Main window content view with profile list and controls
//

import SwiftUI

/// Main content view for the application window
struct MainWindowView: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isGrantedInstalled {
                mainContent
            } else {
                grantedRequiredView
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Re-check accessibility permissions when app becomes active
            // This handles the case where user grants permissions in System Settings and returns
            viewModel.checkAccessibilityPermissions()
        }
    }

    // MARK: - Main Content (when Granted is installed)

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header with search field
            headerSection

            Divider()

            // Profile list or empty state
            if viewModel.isLoading {
                loadingState
            } else if viewModel.filteredProfiles.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Favorites section
                    if !viewModel.favoriteProfiles.isEmpty && viewModel.searchText.isEmpty {
                        favoritesSection
                        Divider()
                    }

                    // All profiles list
                    profileList
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await viewModel.refreshProfiles()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh Profiles")
            }
        }
    }

    // MARK: - Granted Required View

    private var grantedRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Granted Required")
                .font(.title)
                .fontWeight(.semibold)

            Text("Switchboard uses Granted to manage AWS credentials.\nPlease install Granted to continue.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Link(destination: URL(string: "https://docs.commonfate.io/granted/getting-started")!) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Install Granted")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)

                Link("View Documentation", destination: URL(string: "https://docs.commonfate.io/granted/introduction")!)
                    .font(.caption)
            }

            Button("Check Again") {
                viewModel.refreshGrantedStatus()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search profiles...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Accessibility permission warning
            if viewModel.showAccessibilityWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.selectedTerminal.displayName) requires Accessibility permissions")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Grant permissions in System Settings, then restart the app. Note: Local builds may need to be re-authorized after each rebuild.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button("Recheck") {
                            viewModel.checkAccessibilityPermissions()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Open Settings") {
                            viewModel.openAccessibilitySettings()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Dismiss") {
                            viewModel.dismissAccessibilityWarning()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // Error message if present
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Favorites", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(viewModel.favoriteProfiles) { profile in
                ProfileRow(profile: profile)
                    .environmentObject(viewModel)
                    .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Profile List

    private var profileList: some View {
        List(viewModel.filteredProfiles) { profile in
            ProfileRow(profile: profile)
                .environmentObject(viewModel)
        }
        .listStyle(.inset)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading profiles...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if viewModel.searchText.isEmpty {
                Text("No AWS profiles found")
                    .font(.headline)
                Text("Check ~/.aws/config")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No matching profiles")
                    .font(.headline)
                Text("Try a different search")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Refresh") {
                Task {
                    await viewModel.refreshProfiles()
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Profile Row

/// Individual profile row in the list
struct ProfileRow: View {

    let profile: AWSProfile
    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Profile type icon
            if viewModel.showProfileTypeIcon {
                Image(systemName: profile.type.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
            }

            // Profile info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .medium))

                if let region = profile.region {
                    Text(region)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Account ID
            if viewModel.showAccountId, let accountId = profile.accountId {
                Text(accountId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Action buttons
            HStack(spacing: 4) {
                // Favorite button
                Button(action: {
                    viewModel.toggleFavorite(profile)
                }) {
                    Image(systemName: viewModel.isFavorite(profile) ? "star.fill" : "star")
                        .foregroundColor(viewModel.isFavorite(profile) ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help(viewModel.isFavorite(profile) ? "Remove from Favorites" : "Add to Favorites")

                Button(action: {
                    viewModel.openTerminal(with: profile)
                }) {
                    Image(systemName: "terminal")
                }
                .buttonStyle(.borderless)
                .help("Open in Terminal (assume)")

                if profile.supportsConsole {
                    Button(action: {
                        viewModel.openConsole(with: profile)
                    }) {
                        Image(systemName: "globe")
                    }
                    .buttonStyle(.borderless)
                    .help("Open AWS Console (assume -c)")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open in Terminal") {
            viewModel.openTerminal(with: profile)
        }

        if profile.supportsConsole {
            Button("Open AWS Console") {
                viewModel.openConsole(with: profile)
            }
        }

        Divider()

        Button("Copy Profile Name") {
            viewModel.copyProfileName(profile)
        }

        if profile.accountId != nil {
            Button("Copy Account ID") {
                viewModel.copyAccountId(profile)
            }
        }

        Button("Copy Assume Command") {
            viewModel.copyExportCommand(profile)
        }

        Divider()

        if let region = profile.region {
            Text("Region: \(region)")
                .font(.caption)
        }

        Text("Type: \(profile.type.description)")
            .font(.caption)
    }
}

// MARK: - Previews

#Preview {
    MainWindowView()
        .environmentObject(ProfileViewModel())
}

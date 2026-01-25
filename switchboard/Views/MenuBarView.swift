//
//  MenuBarView.swift
//  Switchboard
//
//  Menu bar dropdown view for quick profile access
//

import SwiftUI

/// Menu bar dropdown view
struct MenuBarView: View {

    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isGrantedInstalled {
                mainMenuContent
            } else {
                grantedRequiredContent
            }
        }
    }

    // MARK: - Main Menu Content (when Granted is installed)

    private var mainMenuContent: some View {
        VStack(spacing: 0) {
            // Accessibility warning
            if viewModel.showAccessibilityWarning {
                VStack(spacing: 4) {
                    Text("\(viewModel.selectedTerminal.displayName) requires Accessibility permissions")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)

                    Button("Open Settings") {
                        viewModel.openAccessibilitySettings()
                    }
                    .font(.caption)
                    .controlSize(.small)
                    .padding(.bottom, 8)
                }
                Divider()
            }

            // Favorites section
            if !viewModel.favoriteProfiles.isEmpty {
                favoriteSection
                Divider()
            }

            // Recents section
            if !viewModel.recentProfiles.isEmpty {
                recentSection
                Divider()
            }

            // All Profiles submenu
            allProfilesMenu

            Divider()

            // App actions
            appActions
        }
    }

    // MARK: - Granted Required Content

    private var grantedRequiredContent: some View {
        VStack(spacing: 0) {
            Text("Granted Required")
                .font(.headline)
                .padding(.vertical, 8)

            Divider()

            Link(destination: URL(string: "https://docs.commonfate.io/granted/getting-started")!) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Install Granted")
                }
            }
            .padding(.vertical, 4)

            Button("Check Again") {
                viewModel.refreshGrantedStatus()
            }
            .padding(.vertical, 4)

            Divider()

            appActions
        }
    }

    // MARK: - Favorites Section

    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Favorites")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(viewModel.favoriteProfiles) { profile in
                ProfileMenuItem(profile: profile)
                    .environmentObject(viewModel)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Recents Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recent")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(viewModel.recentProfiles) { profile in
                ProfileMenuItem(profile: profile)
                    .environmentObject(viewModel)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - All Profiles Menu

    private var allProfilesMenu: some View {
        Menu("All Profiles") {
            ForEach(viewModel.profiles) { profile in
                Menu {
                    ProfileSubmenu(profile: profile)
                        .environmentObject(viewModel)
                } label: {
                    if viewModel.showProfileTypeIcon {
                        Label(profile.name, systemImage: profile.type.icon)
                    } else {
                        Text(profile.name)
                    }
                }
            }
        }
    }

    // MARK: - App Actions

    private var appActions: some View {
        VStack(spacing: 0) {
            Button("Open Switchboard") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Preferences...") {
                NSApp.activate(ignoringOtherApps: true)
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - Profile Menu Item

/// Individual profile menu item
struct ProfileMenuItem: View {
    let profile: AWSProfile
    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        Menu {
            ProfileSubmenu(profile: profile)
                .environmentObject(viewModel)
        } label: {
            HStack {
                if viewModel.showProfileTypeIcon {
                    Image(systemName: profile.type.icon)
                }
                Text(profile.name)
                Spacer()
            }
        }
    }
}

// MARK: - Profile Submenu

/// Submenu for a profile with actions
struct ProfileSubmenu: View {
    let profile: AWSProfile
    @EnvironmentObject var viewModel: ProfileViewModel

    var body: some View {
        Button("Open Terminal") {
            viewModel.openTerminal(with: profile)
        }

        if profile.supportsConsole {
            Button("Open Console") {
                viewModel.openConsole(with: profile)
            }
        }

        Divider()

        Button(viewModel.isFavorite(profile) ? "Remove Favorite" : "Add Favorite") {
            viewModel.toggleFavorite(profile)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(ProfileViewModel())
}

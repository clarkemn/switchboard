//
//  ProfileHistoryService.swift
//  Switchboard
//
//  Service for tracking profile favorites and recent usage
//

import Foundation
import os.log

/// Logger for ProfileHistoryService
private let logger = Logger(subsystem: "com.switchboard.app", category: "ProfileHistoryService")

/// Entry representing a recent profile usage
struct RecentEntry: Codable, Equatable {
    let profileName: String
    let timestamp: Date
}

/// Data structure for persisting profile usage
struct ProfileUsageData: Codable {
    var favorites: Set<String>
    var recentUsage: [RecentEntry]
    
    init() {
        self.favorites = []
        self.recentUsage = []
    }
}

/// Service for tracking profile favorites and recents
class ProfileHistoryService {
    
    // MARK: - Properties
    
    /// UserDefaults key for storing profile usage data
    private static let storageKey = "com.switchboard.profileUsage"
    
    /// Maximum number of recent entries to keep
    private let maxRecents: Int
    
    /// Cached usage data
    private var usageData: ProfileUsageData
    
    // MARK: - Initialization
    
    /// Initialize the service
    /// - Parameter maxRecents: Maximum number of recent entries to keep (default: 10)
    init(maxRecents: Int = 10) {
        self.maxRecents = maxRecents
        self.usageData = Self.loadUsageData()
    }
    
    // MARK: - Favorites
    
    /// Toggle favorite status for a profile
    /// - Parameter profileName: Name of the profile
    func toggleFavorite(_ profileName: String) {
        if usageData.favorites.contains(profileName) {
            usageData.favorites.remove(profileName)
            logger.info("Removed favorite: \(profileName)")
        } else {
            usageData.favorites.insert(profileName)
            logger.info("Added favorite: \(profileName)")
        }
        saveUsageData()
    }
    
    /// Check if a profile is favorited
    /// - Parameter profileName: Name of the profile
    /// - Returns: True if the profile is favorited
    func isFavorite(_ profileName: String) -> Bool {
        return usageData.favorites.contains(profileName)
    }
    
    /// Get all favorited profiles (sorted alphabetically)
    /// - Returns: Array of profile names
    func getFavorites() -> [String] {
        return Array(usageData.favorites).sorted()
    }
    
    // MARK: - Recents
    
    /// Record usage of a profile
    /// - Parameter profileName: Name of the profile
    func recordUsage(_ profileName: String) {
        let entry = RecentEntry(profileName: profileName, timestamp: Date())
        
        // Remove any existing entries for this profile
        usageData.recentUsage.removeAll { $0.profileName == profileName }
        
        // Add new entry at the beginning
        usageData.recentUsage.insert(entry, at: 0)
        
        // Trim to max recents
        if usageData.recentUsage.count > maxRecents {
            usageData.recentUsage = Array(usageData.recentUsage.prefix(maxRecents))
        }
        
        logger.info("Recorded usage for profile: \(profileName)")
        saveUsageData()
    }
    
    /// Get recent profiles (most recent first)
    /// - Parameter limit: Maximum number of recents to return (default: maxRecents)
    /// - Returns: Array of profile names
    func getRecents(limit: Int? = nil) -> [String] {
        let count = min(limit ?? maxRecents, usageData.recentUsage.count)
        return Array(usageData.recentUsage.prefix(count).map { $0.profileName })
    }
    
    // MARK: - Persistence
    
    /// Load usage data from UserDefaults
    private static func loadUsageData() -> ProfileUsageData {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            logger.info("No existing usage data found, creating new")
            return ProfileUsageData()
        }
        
        do {
            let decoder = JSONDecoder()
            let usageData = try decoder.decode(ProfileUsageData.self, from: data)
            logger.info("Loaded usage data: \(usageData.favorites.count) favorites, \(usageData.recentUsage.count) recents")
            return usageData
        } catch {
            logger.error("Failed to decode usage data: \(error.localizedDescription)")
            return ProfileUsageData()
        }
    }
    
    /// Save usage data to UserDefaults
    private func saveUsageData() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self.usageData)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            logger.info("Saved usage data: \(self.usageData.favorites.count) favorites, \(self.usageData.recentUsage.count) recents")
        } catch {
            logger.error("Failed to encode usage data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    /// Remove all recents for profiles that no longer exist
    /// - Parameter validProfiles: Set of valid profile names
    func cleanupRecents(validProfiles: Set<String>) {
        let originalCount = self.usageData.recentUsage.count
        self.usageData.recentUsage.removeAll { !validProfiles.contains($0.profileName) }
        
        if self.usageData.recentUsage.count != originalCount {
            logger.info("Cleaned up recents: removed \(originalCount - self.usageData.recentUsage.count) invalid entries")
            saveUsageData()
        }
    }
    
    /// Remove all favorites for profiles that no longer exist
    /// - Parameter validProfiles: Set of valid profile names
    func cleanupFavorites(validProfiles: Set<String>) {
        let originalCount = self.usageData.favorites.count
        self.usageData.favorites = self.usageData.favorites.filter { validProfiles.contains($0) }
        
        if self.usageData.favorites.count != originalCount {
            logger.info("Cleaned up favorites: removed \(originalCount - self.usageData.favorites.count) invalid entries")
            saveUsageData()
        }
    }
}

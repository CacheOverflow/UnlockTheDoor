//
//  UnlockDoorIntent.swift
//  UnlockTheDoor Watch App
//
//  Created by Assistant on 2025-09-08.
//

import AppIntents
import SwiftUI

struct UnlockDoorIntent: AppIntent {
    static var title: LocalizedStringResource = "Unlock Hotel Room"
    static var description = IntentDescription("Unlock your hotel room door using UnlockTheDoor")
    
    // This makes the intent available for Siri and Shortcuts
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check if session is configured
        let sessionStore = SessionStore.shared
        guard sessionStore.isConfigured else {
            return .result(dialog: "Please configure your room first using the iPhone app.")
        }
        
        // Check if we have a valid cookie
        guard sessionStore.hasValidCookie else {
            return .result(dialog: "Your session has expired. Please open the iPhone app to refresh it.")
        }
        
        // Check network connectivity
        let networkMonitor = NetworkMonitor.shared
        guard networkMonitor.hasInternet else {
            return .result(dialog: "No internet connection. Please check your connection and try again.")
        }
        
        // Perform the unlock
        let doorService = DoorUnlockService.shared
        
        do {
            // Trigger the unlock
            try await doorService.unlockDoor()
            
            return .result(dialog: "Door unlocked successfully!")
        } catch {
            return .result(dialog: "Failed to unlock door: \(error.localizedDescription)")
        }
    }
}

// App Shortcuts provider for Watch
struct UnlockTheDoorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UnlockDoorIntent(),
            phrases: [
                "Run \(.applicationName)"
            ],
            shortTitle: "Unlock The Door",
            systemImageName: "lock.open.fill"
        )
    }
}
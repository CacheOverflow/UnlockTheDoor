//
//  UnlockDoorIntent.swift
//  UnlockTheDoor
//
//  Created by Assistant on 2025-09-08.
//

import AppIntents
import SwiftUI

struct UnlockDoorIntent: AppIntent {
    static var title: LocalizedStringResource = "Unlock Door"
    static var description = IntentDescription("Unlock your hotel room door")
    
    // This makes the intent available for Siri and Shortcuts
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Check if session is configured
        let sessionStore = SessionStore.shared
        guard sessionStore.hasStoredSession else {
            return .result(
                dialog: "Please configure your room first by opening the app and adding your SMS link.",
                view: UnlockResultView(success: false, message: "No room configured")
            )
        }
        
        // Check if we have a valid cookie
        guard CookieManager.shared.hasValidSession() else {
            return .result(
                dialog: "Your session has expired. Please open the app to refresh it.",
                view: UnlockResultView(success: false, message: "Session expired")
            )
        }
        
        // Perform the unlock
        let doorService = DoorUnlockService.shared
        
        do {
            // Trigger the unlock
            await doorService.unlockDoor()
            
            // Wait a moment for the operation to complete
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if it was successful
            if doorService.lastUnlockSuccessful {
                return .result(
                    dialog: "Door unlocked successfully!",
                    view: UnlockResultView(success: true, message: "Door unlocked! Room \(sessionStore.doorId)")
                )
            } else {
                return .result(
                    dialog: "Failed to unlock the door. Please try again.",
                    view: UnlockResultView(success: false, message: doorService.statusMessage)
                )
            }
        } catch {
            return .result(
                dialog: "Error unlocking door: \(error.localizedDescription)",
                view: UnlockResultView(success: false, message: error.localizedDescription)
            )
        }
    }
}

// Simple view for Siri results
struct UnlockResultView: View {
    let success: Bool
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: success ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(success ? .green : .red)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// App Shortcuts provider
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
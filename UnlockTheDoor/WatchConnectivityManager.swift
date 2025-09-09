//
//  WatchConnectivityManager.swift
//  UnlockTheDoor
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchAppInstalled = false
    
    override init() {
        super.init()
        // DO NOT activate here - let AppDelegate handle it
    }
    
    func activateConnection() {
        // This is now only called from AppDelegate, not from ContentView
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        if session.activationState == .notActivated {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Send Messages to Watch
    
    func sendSessionUpdate() {
        // Update both context and send message (used on initial connection)
        updateApplicationContext()
        
        // Then send immediate message if reachable
        if WCSession.default.isReachable {
            sendDirectMessageToWatch()
        }
    }
    
    private func sendDirectMessageToWatch() {
        // Send direct message without updating context (avoids duplicates)
        guard WCSession.default.isReachable else { 
            return 
        }
        
        let sessionStore = SessionStore.shared
        let cookieValue = CookieManager.shared.getSessionCookie()
        let cookieExpiry = CookieManager.shared.getSessionExpiry()
        
        let message = [
            "action": "sessionUpdate",
            "doorId": sessionStore.doorId,
            "baseUrl": sessionStore.baseUrl,
            "cookie": cookieValue,
            "cookieExpiry": cookieExpiry?.timeIntervalSince1970 ?? 0,
            "isConfigured": sessionStore.hasStoredSession,
            "language": LanguageManager.shared.currentLanguage.rawValue
        ] as [String : Any]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("✅ Watch acknowledged session update")
        }) { error in
            print("⚠️ Error sending session update via message: \(error.localizedDescription)")
        }
    }
    
    private func updateApplicationContext() {
        guard WCSession.default.activationState == .activated else { return }
        
        let sessionStore = SessionStore.shared
        let cookieValue = CookieManager.shared.getSessionCookie()
        let cookieExpiry = CookieManager.shared.getSessionExpiry()
        
        let context = [
            "doorId": sessionStore.doorId,
            "baseUrl": sessionStore.baseUrl,
            "cookie": cookieValue,
            "cookieExpiry": cookieExpiry?.timeIntervalSince1970 ?? 0,
            "isConfigured": sessionStore.hasStoredSession,
            "language": LanguageManager.shared.currentLanguage.rawValue
        ] as [String : Any]
        
        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("Error updating application context: \(error)")
        }
    }
    
    func sendLanguageUpdate(_ language: String) {
        guard WCSession.default.activationState == .activated else { return }
        
        // Send immediate message if reachable
        if WCSession.default.isReachable {
            let message = ["action": "languageUpdate", "language": language]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error sending language update: \(error)")
            }
        }
        
        // Also update application context for persistence
        updateApplicationContext()
    }
    
    // MARK: - Receive Messages from Watch
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages that expect a reply
        if let action = message["action"] as? String {
            switch action {
            case "requestUpdate":
                // Watch is requesting session update - send direct message only (no context)
                print("📲 Watch requested session update")
                sendDirectMessageToWatch()
                replyHandler(["status": "sent"])
            default:
                replyHandler(["status": "unknown"])
            }
        } else {
            replyHandler(["status": "no action"])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // This handles messages without reply handler - we don't use this anymore
        // All Watch requests come with reply handler
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ iPhone: WC Session activation failed: \(error)")
            return
        }
        
        print("✅ iPhone: WC Session activated successfully")
        print("   Activation State: \(activationState.rawValue)")
        print("   Is Paired: \(session.isPaired)")
        print("   Is Watch App Installed: \(session.isWatchAppInstalled)")
        print("   Is Reachable: \(session.isReachable)")
        
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isPaired && session.isWatchAppInstalled
            print("⌚ Watch app installed: \(self.isWatchAppInstalled)")
        }
        
        // Only update context on activation for Watch to read when it launches
        if session.isWatchAppInstalled {
            DispatchQueue.main.async {
                self.updateApplicationContext()
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 iPhone: Watch reachability changed to: \(session.isReachable)")
        
        // Check if Watch app installation status changed
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isPaired && session.isWatchAppInstalled
        }
        
        // Don't auto-send on reachability change - Watch will request if needed
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("📱 iPhone: Watch state changed")
        print("   Is Paired: \(session.isPaired)")
        print("   Is Watch App Installed: \(session.isWatchAppInstalled)")
        
        // Update installation status when Watch state changes (app installed/uninstalled)
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isPaired && session.isWatchAppInstalled
        }
        
        // Only update context for persistence when Watch app is installed
        if session.isPaired && session.isWatchAppInstalled {
            self.updateApplicationContext()
        }
    }
}
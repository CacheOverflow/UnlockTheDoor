//
//  WatchConnectivityManager.swift
//  UnlockTheDoor Watch App
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var isPhoneConnected = false
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    private var hasActivated = false
    private var syncCompletionHandlers: [(Bool) -> Void] = []
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else {
            print("WCSession not supported on this device")
            return
        }
        
        let session = WCSession.default
        
        // If already activated, just update the current state
        if session.activationState == .activated {
            DispatchQueue.main.async {
                self.isPhoneConnected = session.isReachable
                print("📱 Session already active. iPhone reachable: \(session.isReachable)")
            }
            
            // Check for any pending application context
            if !session.receivedApplicationContext.isEmpty {
                print("📲 Processing existing application context")
                self.session(session, didReceiveApplicationContext: session.receivedApplicationContext)
            }
            // Don't request update here - let ContentView handle it once
            return
        }
        
        // Only set delegate and activate if not already done
        if !hasActivated {
            hasActivated = true
            session.delegate = self
            session.activate()
            print("🚀 Activating WCSession...")
        }
    }
    
    private func requestSessionUpdateWithRetry(retryCount: Int = 0) {
        // Simplified - just try once, don't retry automatically
        if WCSession.default.isReachable {
            print("📲 Requesting session update")
            requestSessionUpdate()
        } else {
            print("⚠️ iPhone not reachable for session update")
        }
    }
    
    // MARK: - Request Session Update
    
    func requestSessionUpdate(completion: ((Bool) -> Void)? = nil) {
        // If already syncing, just add completion handler
        if isSyncing {
            print("⏳ Already syncing, queuing completion handler")
            if let completion = completion {
                syncCompletionHandlers.append(completion)
            }
            return
        }
        
        // Add completion handler to queue
        if let completion = completion {
            syncCompletionHandlers.append(completion)
        }
        
        // Set syncing flag
        DispatchQueue.main.async {
            self.isSyncing = true
        }
        
        guard WCSession.default.isReachable else {
            print("⚠️ iPhone not reachable for sync")
            // Try to use application context as fallback
            if !WCSession.default.receivedApplicationContext.isEmpty {
                self.session(WCSession.default, didReceiveApplicationContext: WCSession.default.receivedApplicationContext)
            }
            DispatchQueue.main.async {
                self.isSyncing = false
                self.callSyncCompletions(success: false)
            }
            return
        }
        
        print("📲 Requesting session update from iPhone...")
        let message = ["action": "requestUpdate"]
        WCSession.default.sendMessage(message, replyHandler: { response in
            // Success - completion will be called when we receive the update
            print("✅ Session update request acknowledged by iPhone")
        }) { error in
            print("⚠️ Could not send message to iPhone: \(error.localizedDescription)")
            // iPhone app might not be running - use application context as fallback
            if !WCSession.default.receivedApplicationContext.isEmpty {
                print("📲 Using cached application context instead")
                self.session(WCSession.default, didReceiveApplicationContext: WCSession.default.receivedApplicationContext)
            } else {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.callSyncCompletions(success: false)
                }
            }
        }
    }
    
    private func callSyncCompletions(success: Bool) {
        let handlers = syncCompletionHandlers
        syncCompletionHandlers.removeAll()
        for handler in handlers {
            handler(success)
        }
    }
    
    // MARK: - Watch Connection Info
    
    // Watch doesn't need to "request iPhone to unlock" anymore
    // When iPhone is nearby, Watch uses iPhone's internet transparently
    // Watch always makes its own HTTPS request (1 request only!)
    
    // MARK: - Connection Strategy
    
    // Watch prefers iPhone when available (faster, more reliable)
    // But CAN unlock directly with WiFi/LTE using synced cookie
    // The PHPSESSID cookie is portable and works from any network
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WC Session activation failed: \(error)")
            return
        }
        
        print("✅ WC Session activated successfully")
        print("   Activation State: \(activationState.rawValue)")
        print("   Is Companion App Installed: \(session.isCompanionAppInstalled)")
        print("   Is Reachable: \(session.isReachable)")
        
        DispatchQueue.main.async {
            self.isPhoneConnected = session.isReachable
            print("📱 iPhone Connected set to: \(self.isPhoneConnected)")
        }
        
        // Check for existing application context from iPhone
        if !session.receivedApplicationContext.isEmpty {
            print("📲 Found existing application context from iPhone")
            self.session(session, didReceiveApplicationContext: session.receivedApplicationContext)
        } else {
            print("⚠️ No existing application context found")
            // Don't request here - ContentView will handle initial sync
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isPhoneConnected = session.isReachable
            print("✅ Updated isPhoneConnected to: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Update door configuration and cookie from iPhone
        DispatchQueue.main.async {
            let doorId = applicationContext["doorId"] as? String ?? ""
            let baseUrl = applicationContext["baseUrl"] as? String ?? ""
            let cookieValue = applicationContext["cookie"] as? String ?? ""
            let cookieExpiry = (applicationContext["cookieExpiry"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            let isConfigured = applicationContext["isConfigured"] as? Bool ?? false
            
            // Handle language update
            if let languageCode = applicationContext["language"] as? String {
                LanguageManager.shared.setLanguageFromString(languageCode)
            }
            
            SessionStore.shared.updateFromPhone(
                doorId: doorId,
                baseUrl: baseUrl,
                cookie: cookieValue,
                cookieExpiry: cookieExpiry,
                isConfigured: isConfigured
            )
            
            self.lastSyncTime = Date()
            self.isSyncing = false
            self.callSyncCompletions(success: true)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages that expect a reply
        print("📨 Received message with reply handler")
        self.session(session, didReceiveMessage: message)
        // Send acknowledgment
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                switch action {
                case "sessionUpdate":
                    // iPhone is updating cookie and configuration
                    let doorId = message["doorId"] as? String ?? ""
                    let baseUrl = message["baseUrl"] as? String ?? ""
                    let cookieValue = message["cookie"] as? String ?? ""
                    let cookieExpiry = (message["cookieExpiry"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
                    let isConfigured = message["isConfigured"] as? Bool ?? false
                    
                    // Handle language update
                    if let languageCode = message["language"] as? String {
                        LanguageManager.shared.setLanguageFromString(languageCode)
                    }
                    
                    SessionStore.shared.updateFromPhone(
                        doorId: doorId,
                        baseUrl: baseUrl,
                        cookie: cookieValue,
                        cookieExpiry: cookieExpiry,
                        isConfigured: isConfigured
                    )
                    
                    self.lastSyncTime = Date()
                    self.isSyncing = false
                    self.callSyncCompletions(success: true)
                case "languageUpdate":
                    // iPhone is updating language preference
                    if let languageCode = message["language"] as? String {
                        LanguageManager.shared.setLanguageFromString(languageCode)
                    }
                default:
                    break
                }
            }
        }
    }
}
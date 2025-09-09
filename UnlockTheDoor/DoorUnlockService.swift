//
//  DoorUnlockService.swift
//  UnlockTheDoor
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation
import UIKit

enum DoorUnlockError: Error, LocalizedError {
    case networkError
    case sessionExpired
    case invalidResponse
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "network_error".localized
        case .sessionExpired:
            return "session_expired".localized
        case .invalidResponse:
            return "invalid_response".localized
        case .unknownError:
            return "something_went_wrong".localized
        }
    }
}

@MainActor
final class DoorUnlockService: ObservableObject, @unchecked Sendable {
    static let shared = DoorUnlockService()
    
    @Published var isUnlocking = false
    @Published var lastUnlockTime: Date?
    @Published var statusMessage = ""
    @Published var sessionValid = false
    @Published var sessionExpiry: Date?
    @Published var lastUnlockSuccessful = false
    
    // Dynamic URLs from SessionStore
    private var sessionStore = SessionStore.shared
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        // Don't block init - let ContentView call checkSessionValidity async
    }
    
    func checkSessionValidity() async {
        // Simple check - no need for complex task detachment
        let valid = CookieManager.shared.hasValidSession()
        let expiry = CookieManager.shared.getSessionExpiry()
        
        await MainActor.run {
            sessionValid = valid
            sessionExpiry = expiry
        }
    }
    
    func unlockDoor() async {
        // Start background task to ensure completion even if app goes to background
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Clean up if we run out of time
            Task { @MainActor in
                self?.endBackgroundTask()
            }
        }
        
        defer {
            // End background task when we're done
            endBackgroundTask()
        }
        
        // Check if we have a configured door
        guard sessionStore.hasStoredSession else {
            await MainActor.run {
                statusMessage = "paste_sms_link".localized
                lastUnlockSuccessful = false
            }
            return
        }
        
        await MainActor.run {
            isUnlocking = true
            statusMessage = "unlocking".localized
            lastUnlockSuccessful = false
        }
        
        defer {
            Task { @MainActor in
                isUnlocking = false
            }
        }
        
        // iPhone always does direct unlock
        #if DEBUG
        CookieManager.shared.debugPrintAllCookies()
        #endif
        
        do {
            // Only refresh if we truly have no session
            // Do NOT refresh if we just got a cookie from SMS link processing
            if !CookieManager.shared.hasValidSession() {
                print("⚠️ No valid session found, attempting to refresh...")
                await MainActor.run {
                    statusMessage = "syncing".localized
                }
                try await refreshSession()
            } else {
                print("✅ Using existing session cookie for unlock")
            }
            
            try await performUnlock()
            
            await MainActor.run {
                lastUnlockTime = Date()
                statusMessage = "unlocked".localized
                lastUnlockSuccessful = true
            }
            
            await checkSessionValidity()
            
            // Proactively sync updated session to Watch after successful unlock
            WatchConnectivityManager.shared.sendSessionUpdate()
            
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            await MainActor.run {
                statusMessage = ""
            }
        } catch {
            await MainActor.run {
                statusMessage = error.localizedDescription
                lastUnlockSuccessful = false
            }
        }
    }
    
    func refreshSession() async throws {
        guard let urlString = sessionStore.getSessionRefreshUrl() else {
            throw DoorUnlockError.invalidResponse
        }
        let success = try await attemptRefreshSession(urlString: urlString)
        if !success {
            throw DoorUnlockError.invalidResponse
        }
    }
    
    private func attemptRefreshSession(urlString: String) async throws -> Bool {
        // Use the session refresh URL from SessionStore
        let loginURL = urlString
        
        guard let url = URL(string: loginURL) else {
            print("Invalid URL: \(loginURL)")
            return false
        }
        
        print("Attempting to fetch session from: \(url)")
        
        // DO NOT clear existing cookies - we might have a valid one from SMS link!
        // CookieManager.shared.clearSession() // REMOVED - this was deleting good cookies!
        
        // Make the request - the cookie should be set automatically by URLSession
        let (_, response) = try await NetworkManager.shared.performRequest(url: url, followRedirects: true)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Response is not HTTP response")
            return false
        }
        
        print("Final Response - Status: \(httpResponse.statusCode)")
        print("Final Response - URL: \(httpResponse.url?.absoluteString ?? "none")")
        
        // The cookie should have been automatically stored by URLSession during the redirect
        #if DEBUG
        CookieManager.shared.debugPrintAllCookies()
        #endif
        
        // Check if we have a valid session now
        if CookieManager.shared.hasValidSession() {
            print("Session successfully established")
            // Proactively sync the new session to Watch
            WatchConnectivityManager.shared.sendSessionUpdate()
            return true
        }
        
        print("Failed to establish session - checking cookie storage")
        
        // If no cookie found, it might be because we need to explicitly handle the redirect
        // Try without following redirects
        let (_, response2) = try await NetworkManager.shared.performRequest(url: url, followRedirects: false)
        
        if let httpResponse2 = response2 as? HTTPURLResponse {
            print("Direct Response - Status: \(httpResponse2.statusCode)")
            CookieManager.shared.saveCookie(from: response2)
            
            if httpResponse2.statusCode == 302 {
                // Follow the redirect manually
                if let location = httpResponse2.allHeaderFields["Location"] as? String ?? 
                                 httpResponse2.allHeaderFields["location"] as? String,
                   let redirectURL = URL(string: location) {
                    print("Following redirect to: \(redirectURL)")
                    let (_, _) = try await NetworkManager.shared.performRequest(url: redirectURL, followRedirects: true)
                }
            }
        }
        
        #if DEBUG
        CookieManager.shared.debugPrintAllCookies()
        #endif
        let hasSession = CookieManager.shared.hasValidSession()
        if hasSession {
            // Proactively sync the refreshed session to Watch
            WatchConnectivityManager.shared.sendSessionUpdate()
        }
        return hasSession
    }
    
    private func performUnlock() async throws {
        guard let unlockURLString = sessionStore.getDoorUnlockUrl(),
              let url = URL(string: unlockURLString) else {
            throw DoorUnlockError.networkError
        }
        
        print("Performing unlock request to: \(url)")
        #if DEBUG
        CookieManager.shared.debugPrintAllCookies()
        #endif
        
        // Don't send Cookie header manually - let URLSession handle it
        let headers = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
        ]
        
        // Don't follow redirects for unlock - we want to see the 302
        let (_, response) = try await NetworkManager.shared.performRequest(url: url, headers: headers, followRedirects: false)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Unlock response is not HTTP response")
            throw DoorUnlockError.invalidResponse
        }
        
        print("Unlock Response - Status: \(httpResponse.statusCode)")
        print("Unlock Response - Headers: \(httpResponse.allHeaderFields)")
        
        // Check for redirect location
        if httpResponse.statusCode == 302 {
            let location = httpResponse.allHeaderFields["Location"] as? String
                ?? httpResponse.allHeaderFields["location"] as? String
            print("Redirect location: \(location ?? "none")")
        }
        
        // Save any new cookies from the response
        CookieManager.shared.saveCookie(from: response)
        
        // Check if we got redirected to the correct location
        if httpResponse.statusCode == 302 {
            let location = httpResponse.allHeaderFields["Location"] as? String
                ?? httpResponse.allHeaderFields["location"] as? String
            
            // According to HAR logs, successful unlock redirects to /myaccount/key/
            if location?.contains("/myaccount/key") == true {
                print("✅ Door unlock SUCCESSFUL - redirected to /myaccount/key/")
            } else if location?.contains("/login") == true {
                print("❌ Door unlock FAILED - redirected to login (session invalid)")
                CookieManager.shared.clearSession()
                throw DoorUnlockError.sessionExpired
            } else {
                print("⚠️ Unexpected redirect location: \(location ?? "none")")
            }
        } else if httpResponse.statusCode == 200 {
            // Should not happen based on HAR logs
            print("⚠️ Got 200 instead of expected 302 redirect")
            throw DoorUnlockError.invalidResponse
        } else {
            print("❌ Unlock failed - unexpected status: \(httpResponse.statusCode)")
            throw DoorUnlockError.invalidResponse
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
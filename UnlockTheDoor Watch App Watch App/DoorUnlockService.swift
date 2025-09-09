//
//  DoorUnlockService.swift
//  UnlockTheDoor Watch App
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation
import WatchConnectivity

enum DoorUnlockError: Error, LocalizedError {
    case networkError
    case sessionExpired
    case invalidResponse
    case unknownError
    case notConfigured
    case syncInProgress
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "no_network".localized
        case .sessionExpired:
            return "please_refresh_iphone".localized
        case .invalidResponse:
            return "could_not_connect".localized
        case .unknownError:
            return "something_went_wrong".localized
        case .notConfigured:
            return "setup_first".localized
        case .syncInProgress:
            return "syncing".localized
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection or move closer to your iPhone"
        case .sessionExpired:
            return "Open the iPhone app to refresh your session"
        case .invalidResponse:
            return "Try again in a moment"
        case .notConfigured:
            return "Configure your room in the iPhone app first"
        case .syncInProgress:
            return "Please wait while syncing with iPhone"
        default:
            return nil
        }
    }
}

class DoorUnlockService: ObservableObject {
    static let shared = DoorUnlockService()
    
    @Published var isUnlocking = false
    @Published var lastUnlockTime: Date?
    @Published var statusMessage = ""
    
    // Dynamic URLs from SessionStore
    private var sessionStore = SessionStore.shared
    
    private init() {}
    
    func unlockDoor() async throws {
        // Check configuration first
        guard sessionStore.isConfigured else {
            await MainActor.run {
                statusMessage = "setup_first".localized
            }
            throw DoorUnlockError.notConfigured
        }
        
        // Check if we have valid cookie synced from iPhone
        if !sessionStore.hasValidCookie {
            // Try to recover by checking HTTPCookieStorage directly
            if !CookieManager.shared.hasValidSession() {
                // No valid cookie anywhere - need to sync with iPhone
                await MainActor.run {
                    statusMessage = "sync_iphone".localized
                }
                throw DoorUnlockError.sessionExpired
            }
            // Cookie exists in storage but not synced to SessionStore
            // This can happen after app restart - use the stored cookie
            print("✅ Found valid cookie in HTTPCookieStorage, proceeding")
        }
        
        await MainActor.run {
            isUnlocking = true
            statusMessage = "unlocking".localized
        }
        
        defer {
            Task { @MainActor in
                isUnlocking = false
            }
        }
        
        let networkMonitor = NetworkMonitor.shared
        
        // SIMPLE: Watch always makes ONE direct HTTPS request if it has internet
        // (Internet can come from Watch's own WiFi/LTE OR iPhone's proxy)
        
        if networkMonitor.hasInternet {
            // We have internet (either standalone or via iPhone proxy)
            // Make ONE direct request from Watch
            await MainActor.run {
                statusMessage = "unlocking".localized
            }
            
            try await performDirectUnlock()
            
            await MainActor.run {
                lastUnlockTime = Date()
                statusMessage = "unlocked".localized
            }
        } else {
            // No internet at all - cannot unlock
            await MainActor.run {
                statusMessage = "no_network".localized
            }
            throw DoorUnlockError.networkError
        }
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            statusMessage = ""
        }
    }
    
    private func performDirectUnlock() async throws {
        guard let unlockUrl = sessionStore.getDoorUnlockUrl(),
              let url = URL(string: unlockUrl) else {
            throw DoorUnlockError.invalidResponse
        }
        
        // Verify we have a cookie to send
        guard !sessionStore.cookieValue.isEmpty else {
            throw DoorUnlockError.sessionExpired
        }
        
        // Use NetworkManager to control redirect behavior - we need to see the 302!
        let (_, response) = try await NetworkManager.shared.performRequest(url: url, headers: [
            "Cookie": "PHPSESSID=\(sessionStore.cookieValue)",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        ], followRedirects: false)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoorUnlockError.invalidResponse
        }
        
        print("Direct unlock response: \(httpResponse.statusCode)")
        
        // Check for redirect to verify success
        if httpResponse.statusCode == 302 {
            let location = httpResponse.allHeaderFields["Location"] as? String ?? 
                          httpResponse.allHeaderFields["location"] as? String
            
            print("🔓 Got 302 redirect. Location: \(location ?? "none")")
            
            if let location = location {
                if location.contains("/myaccount/key") {
                    print("✅ Door unlock SUCCESSFUL - redirected to /myaccount/key/")
                    await MainActor.run {
                        lastUnlockTime = Date()
                        statusMessage = "unlocked".localized
                    }
                    return
                } else if location.contains("/login") {
                    print("❌ Session expired - redirected to login")
                    // Session expired - clear stored cookie
                    SessionStore.shared.cookieValue = ""
                    SessionStore.shared.cookieExpiry = nil
                    throw DoorUnlockError.sessionExpired
                } else {
                    print("⚠️ Unexpected redirect to: \(location)")
                    // Assume success if we got 302 with any other location
                    await MainActor.run {
                        lastUnlockTime = Date()
                        statusMessage = "unlocked".localized
                    }
                    return
                }
            } else {
                // 302 with no location header - treat as success
                print("✅ Got 302 with no location - treating as success")
                await MainActor.run {
                    lastUnlockTime = Date()
                    statusMessage = "unlocked".localized
                }
                return
            }
        }
        
        // 200 should NOT happen if we're preventing redirects correctly
        if httpResponse.statusCode == 200 {
            print("⚠️ Got 200 - URLSession followed redirect automatically. Door may not have unlocked!")
            throw DoorUnlockError.invalidResponse
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            // Unauthorized - session expired
            SessionStore.shared.cookieValue = ""
            SessionStore.shared.cookieExpiry = nil
            throw DoorUnlockError.sessionExpired
        } else {
            print("❌ Unexpected status code: \(httpResponse.statusCode)")
            throw DoorUnlockError.unknownError
        }
    }
}
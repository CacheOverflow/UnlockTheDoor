import Foundation
import SwiftUI

class SessionStore: ObservableObject {
    static let shared = SessionStore()
    
    @Published var doorId: String = ""
    @Published var baseUrl: String = ""
    @Published var cookieValue: String = ""
    @Published var cookieExpiry: Date?
    @Published var isConfigured: Bool = false
    
    private let doorIdKey = "stored_door_id"
    private let baseUrlKey = "stored_base_url"
    private let cookieKey = "stored_cookie"
    private let cookieExpiryKey = "cookie_expiry"
    private let configuredKey = "is_configured"
    private let appGroup = "group.cacheoverflow.UnlockTheDoor"
    
    private var sharedDefaults: UserDefaults? {
        // For Watch app, use standard UserDefaults since App Groups have restrictions
        // Data will be synced via WatchConnectivity instead
        return UserDefaults.standard
    }
    
    var hasValidCookie: Bool {
        guard !cookieValue.isEmpty,
              let expiry = cookieExpiry else { return false }
        return expiry > Date()
    }
    
    init() {
        loadStoredData()
    }
    
    func loadStoredData() {
        // Use standard UserDefaults for Watch
        let defaults = UserDefaults.standard
        
        doorId = defaults.string(forKey: doorIdKey) ?? ""
        baseUrl = defaults.string(forKey: baseUrlKey) ?? ""
        cookieValue = defaults.string(forKey: cookieKey) ?? ""
        if let expiryInterval = defaults.object(forKey: cookieExpiryKey) as? TimeInterval {
            cookieExpiry = Date(timeIntervalSince1970: expiryInterval)
        }
        isConfigured = defaults.bool(forKey: configuredKey)
        
        // If we have stored cookie data but no HTTPCookie, recreate it
        if !cookieValue.isEmpty && !baseUrl.isEmpty {
            // Check if cookie exists in HTTPCookieStorage
            if !CookieManager.shared.hasValidSession() {
                // Recreate the cookie in HTTPCookieStorage
                createAndStoreCookie(value: cookieValue, domain: baseUrl, expiry: cookieExpiry)
            }
        }
    }
    
    func updateFromPhone(doorId: String, baseUrl: String, cookie: String, cookieExpiry: Date?, isConfigured: Bool) {
        // Use standard UserDefaults for Watch
        let defaults = UserDefaults.standard
        
        self.doorId = doorId
        self.baseUrl = baseUrl
        self.cookieValue = cookie
        self.cookieExpiry = cookieExpiry
        self.isConfigured = isConfigured
        
        defaults.set(doorId, forKey: doorIdKey)
        defaults.set(baseUrl, forKey: baseUrlKey)
        defaults.set(cookie, forKey: cookieKey)
        defaults.set(cookieExpiry?.timeIntervalSince1970, forKey: cookieExpiryKey)
        defaults.set(isConfigured, forKey: configuredKey)
        defaults.synchronize()
        
        // IMPORTANT: Also create and store the cookie in HTTPCookieStorage
        // This ensures the cookie persists and can be used by URLSession
        if !cookie.isEmpty && !baseUrl.isEmpty {
            createAndStoreCookie(value: cookie, domain: baseUrl, expiry: cookieExpiry)
        }
        
#if DEBUG
        print("⌚ Updated: Room \(doorId), Cookie valid: \(hasValidCookie)")
#endif
    }
    
    private func createAndStoreCookie(value: String, domain: String, expiry: Date?) {
        // Clean the domain (remove protocol if present)
        let cleanDomain = domain
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Create cookie properties
        var cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .name: "PHPSESSID",
            .value: value,
            .domain: cleanDomain.hasPrefix(".") ? cleanDomain : ".\(cleanDomain)",  // Ensure dot prefix for broader compatibility
            .path: "/",
            .version: "0"
        ]
        
        // Add expiry if provided (otherwise it's a session cookie)
        if let expiryDate = expiry {
            cookieProperties[.expires] = expiryDate
        }
        
        // Create and store the cookie
        if let cookie = HTTPCookie(properties: cookieProperties) {
            HTTPCookieStorage.shared.setCookie(cookie)
#if DEBUG
            print("✅ Created and stored HTTPCookie:")
            print("   Name: \(cookie.name)")
            print("   Value: \(cookie.value)")
            print("   Domain: \(cookie.domain)")
            print("   Path: \(cookie.path)")
            print("   Expires: \(String(describing: cookie.expiresDate))")
#endif
        } else {
            print("❌ Failed to create HTTPCookie")
        }
    }
    
    func getDoorUnlockUrl() -> String? {
        guard !baseUrl.isEmpty else { return nil }
        let cleanBaseUrl = baseUrl.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        return "https://\(cleanBaseUrl)/myaccount/key/unlock/"
    }
}
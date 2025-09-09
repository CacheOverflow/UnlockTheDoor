//
//  CookieManager.swift
//  UnlockTheDoor
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation

class CookieManager {
    static let shared = CookieManager()
    
    private init() {}
    
    func saveCookie(from response: URLResponse?) {
        guard let httpResponse = response as? HTTPURLResponse,
              let url = httpResponse.url,
              let headerFields = httpResponse.allHeaderFields as? [String: String] else {
            return
        }
        
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            if cookie.name == "PHPSESSID" {
                HTTPCookieStorage.shared.setCookie(cookie)
#if DEBUG
                print("Saved cookie to storage: \(cookie.name)=\(cookie.value)")
                print("Cookie domain: \(cookie.domain)")
                print("Cookie path: \(cookie.path)")
                print("Cookie expires: \(String(describing: cookie.expiresDate))")
#endif
            }
        }
    }
    
    func hasValidSession() -> Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return false }
        
        // Get the base URL from SessionStore to check cookies
        let sessionStore = SessionStore.shared
        guard !sessionStore.baseUrl.isEmpty else { return false }
        
        for cookie in cookies {
            // Check if this is a PHPSESSID cookie for our domain
            // Cookie domains can start with a dot (e.g., .pynguest.app)
            let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            let isOurDomain = cookieDomain == sessionStore.baseUrl || 
                             sessionStore.baseUrl.hasSuffix(cookieDomain) || 
                             cookieDomain.hasSuffix(sessionStore.baseUrl)
            
            if cookie.name == "PHPSESSID" && isOurDomain {
                // Check if cookie is still valid (within 23 hours to be safe)
                if let expiryDate = cookie.expiresDate {
                    if Date() < expiryDate {
#if DEBUG
                        print("Found valid session cookie: \(cookie.value)")
                        print("Cookie will expire at: \(expiryDate)")
#endif
                        return true
                    } else {
                        print("Found expired session cookie")
                    }
                } else {
                    // Session cookie without expiry - consider it valid
#if DEBUG
                    print("Found session cookie without expiry: \(cookie.value)")
#endif
                    return true
                }
            }
        }
        return false
    }
    
    func clearSession() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        
        let sessionStore = SessionStore.shared
        
        for cookie in cookies {
            // Delete PHPSESSID for the configured domain, or all PHPSESSID if no domain configured
            if cookie.name == "PHPSESSID" {
                if sessionStore.baseUrl.isEmpty {
                    // No domain configured - delete all PHPSESSID cookies
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    print("Deleted session cookie")
                } else {
                    // Check if this cookie belongs to our domain
                    let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                    let isOurDomain = cookieDomain == sessionStore.baseUrl || 
                                     sessionStore.baseUrl.hasSuffix(cookieDomain) || 
                                     cookieDomain.hasSuffix(sessionStore.baseUrl)
                    if isOurDomain {
                        HTTPCookieStorage.shared.deleteCookie(cookie)
                        print("Deleted session cookie for domain: \(cookie.domain)")
                    }
                }
            }
        }
    }
    
    func getSessionExpiry() -> Date? {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return nil }
        
        let sessionStore = SessionStore.shared
        guard !sessionStore.baseUrl.isEmpty else { return nil }
        
        for cookie in cookies {
            // Check if this is a PHPSESSID cookie for our domain
            let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            let isOurDomain = cookieDomain == sessionStore.baseUrl || 
                             sessionStore.baseUrl.hasSuffix(cookieDomain) || 
                             cookieDomain.hasSuffix(sessionStore.baseUrl)
            
            if cookie.name == "PHPSESSID" && isOurDomain {
                // If no expiry date, assume it expires in 23 hours
                return cookie.expiresDate ?? Date().addingTimeInterval(23 * 60 * 60)
            }
        }
        return nil
    }
    
    func getSessionCookie() -> String {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return "" }
        
        let sessionStore = SessionStore.shared
        guard !sessionStore.baseUrl.isEmpty else { return "" }
        
        for cookie in cookies {
            // Check if this is a PHPSESSID cookie for our domain
            let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            let isOurDomain = cookieDomain == sessionStore.baseUrl || 
                             sessionStore.baseUrl.hasSuffix(cookieDomain) || 
                             cookieDomain.hasSuffix(sessionStore.baseUrl)
            
            if cookie.name == "PHPSESSID" && isOurDomain {
                return cookie.value
            }
        }
        return ""
    }
    
    func debugPrintAllCookies() {
#if DEBUG
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            print("No cookies in storage")
            return
        }
        
        print("=== All Cookies ===")
        for cookie in cookies {
            print("Cookie: \(cookie.name)=\(cookie.value) | Domain: \(cookie.domain) | Path: \(cookie.path)")
        }
        print("==================")
#endif
    }
}
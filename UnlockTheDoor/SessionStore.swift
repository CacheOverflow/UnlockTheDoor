import Foundation
import SwiftUI

class SessionStore: ObservableObject {
    static let shared = SessionStore()
    
    @Published var smsLink: String = ""
    @Published var doorId: String = ""
    @Published var baseUrl: String = ""
    @Published var sessionPath: String = ""
    @Published var hasStoredSession: Bool = false
    
    private let smsLinkKey = "stored_sms_link"
    private let doorIdKey = "stored_door_id"
    private let baseUrlKey = "stored_base_url"
    private let sessionPathKey = "stored_session_path"
    private let appGroup = "group.cacheoverflow.UnlockTheDoor"
    
    private lazy var sharedDefaults: UserDefaults? = {
        return UserDefaults(suiteName: appGroup)
    }()
    
    init() {
        // Don't load anything in init - let ContentView's onAppear handle it
    }
    
    func loadStoredSession() {
        guard let defaults = sharedDefaults else { return }
        
        smsLink = defaults.string(forKey: smsLinkKey) ?? ""
        doorId = defaults.string(forKey: doorIdKey) ?? ""
        baseUrl = defaults.string(forKey: baseUrlKey) ?? ""
        sessionPath = defaults.string(forKey: sessionPathKey) ?? ""
        hasStoredSession = !smsLink.isEmpty && !doorId.isEmpty
    }
    
    func processSmsLink(_ link: String) async throws -> Bool {
        // Clean the link
        var cleanedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Store the original link for fallback
        _ = cleanedLink
        
        // Check for demo mode (demo.k3y.in/anything)
        if cleanedLink.lowercased().contains("demo.k3y.in") {
            return await processDemoLink(cleanedLink)
        }
        
        // Always use HTTPS for security (convert HTTP to HTTPS)
        if !cleanedLink.hasPrefix("http://") && !cleanedLink.hasPrefix("https://") {
            cleanedLink = "https://\(cleanedLink)"
        } else if cleanedLink.hasPrefix("http://") {
            // Convert HTTP to HTTPS
            cleanedLink = cleanedLink.replacingOccurrences(of: "http://", with: "https://")
        }
        
        guard !cleanedLink.isEmpty,
              let url = URL(string: cleanedLink) else {
            throw SessionError.invalidLink
        }
        
        // Follow redirects to get final URL and door ID
        let (finalUrl, doorId) = try await followRedirects(from: url)
        
        // Validate we got a proper door ID
        guard !doorId.isEmpty else {
            throw SessionError.noDoorIdFound
        }
        
        // Store the extracted information
        guard let defaults = sharedDefaults else {
            throw SessionError.storageError
        }
        
        // Store values locally first
        let finalSmsLink = cleanedLink
        let finalDoorId = doorId
        let finalBaseUrl = finalUrl.host ?? ""
        let finalSessionPath = finalUrl.path
        
        // Update on main thread to avoid threading issues
        await MainActor.run {
            self.smsLink = finalSmsLink
            self.doorId = finalDoorId
            self.baseUrl = finalBaseUrl
            self.sessionPath = finalSessionPath
            
            // Clean up baseUrl - remove any protocol and trailing slashes
            if self.baseUrl.contains("://") {
                if let urlComponents = URLComponents(string: "https://\(self.baseUrl)"),
                   let host = urlComponents.host {
                    self.baseUrl = host
                }
            }
            self.baseUrl = self.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            print("Stored session - Door: \(self.doorId), Base URL: \(self.baseUrl), Path: \(self.sessionPath)")
            
            hasStoredSession = true
        }
        
        // Save to defaults outside of MainActor
        defaults.set(finalSmsLink, forKey: smsLinkKey)
        defaults.set(finalDoorId, forKey: doorIdKey)
        defaults.set(finalBaseUrl, forKey: baseUrlKey)
        defaults.set(finalSessionPath, forKey: sessionPathKey)
        defaults.synchronize()
        
        // Notify watch of the new session
        WatchConnectivityManager.shared.sendSessionUpdate()
        
        return true
    }
    
    private func generateConsistentRoomId(from input: String) -> String {
        // Create a consistent hash from the input string
        var hash = 0
        for char in input.unicodeScalars {
            hash = ((hash << 5) &- hash) &+ Int(char.value)
        }
        
        // Use the hash to generate consistent 4-digit groups
        // Make it look like the production format: XXXX-XXXX-XXXX
        let part1 = abs(hash % 10000)
        let part2 = abs((hash >> 8) % 10000)
        let part3 = abs((hash >> 16) % 10000)
        
        // Format with leading zeros and combine with letters for more realistic look
        let letters = "abcdef"
        let letterIndex = abs(hash) % letters.count
        let letter = letters[letters.index(letters.startIndex, offsetBy: letterIndex)]
        
        // Convert Character to String for formatting
        return String(format: "%04d-%04d-%02d%@%d", part1, part2, part3 / 100, String(letter), part3 % 10)
    }
    
    private func processDemoLink(_ link: String) async -> Bool {
        // Extract the demo room ID from the link (e.g., demo.k3y.in/Room101)
        let components = link.split(separator: "/")
        let inputRoomId = components.last.map(String.init) ?? "DemoRoom"
        
        // Generate a consistent UUID-like format based on the input
        // Use the input as a seed to generate consistent room IDs
        let demoRoomId = generateConsistentRoomId(from: inputRoomId)
        
        // Simulate realistic network delay (2-3 seconds like following redirects)
        let delay = Double.random(in: 2.0...3.0)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Update on main thread
        await MainActor.run {
            self.smsLink = link
            self.doorId = demoRoomId
            self.baseUrl = "demo.k3y.in"
            self.sessionPath = "/demo/\(demoRoomId)"
            self.hasStoredSession = true
            
            print("📱 DEMO MODE ACTIVATED - Room: \(self.doorId)")
        }
        
        // Save demo session to UserDefaults
        if let defaults = sharedDefaults {
            defaults.set(link, forKey: smsLinkKey)
            defaults.set(demoRoomId, forKey: doorIdKey)
            defaults.set("demo.k3y.in", forKey: baseUrlKey)
            defaults.set("/demo/\(demoRoomId)", forKey: sessionPathKey)
            defaults.synchronize()
        }
        
        // Create a mock cookie for consistency
        CookieManager.shared.saveDemoCookie(domain: "demo.k3y.in")
        
        // Notify Watch
        WatchConnectivityManager.shared.sendSessionUpdate()
        
        return true
    }
    
    private func followRedirects(from url: URL) async throws -> (URL, String) {
        var currentUrl = url
        var doorId = ""
        var finalUrl: URL = url
        var redirectCount = 0
        let maxRedirects = 5
        
        // IMPORTANT: For k3y.in, we need to follow redirects manually to capture the door ID
        // The actual door ID is in the mybook URL, not the k3y.in short code
        
        // Follow the redirect chain manually to capture door ID from intermediate URLs
        while redirectCount < maxRedirects {
            // NEVER auto-follow redirects - we need to see each step to extract the door ID
            let (_, response) = try await NetworkManager.shared.performRequest(url: currentUrl, followRedirects: false)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SessionError.invalidResponse
            }
            
            print("Response from \(currentUrl): Status \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
            
            // Save any cookies that were set (important for mybook URL)
            CookieManager.shared.saveCookie(from: response)
            
            // Update finalUrl to current response URL (might be different due to normalization)
            if let responseUrl = httpResponse.url {
                finalUrl = responseUrl
            }
            
            // Check for redirect
            if httpResponse.statusCode == 301 || httpResponse.statusCode == 302 || httpResponse.statusCode == 303 || httpResponse.statusCode == 307 || httpResponse.statusCode == 308 {
                guard let location = httpResponse.value(forHTTPHeaderField: "Location") ?? 
                             httpResponse.value(forHTTPHeaderField: "location") else {
                    print("No Location header found in redirect response")
                    break
                }
                
                print("Redirecting to: \(location)")
                
                // Parse the redirect URL  
                let redirectUrl: URL
                if location.hasPrefix("http://") || location.hasPrefix("https://") {
                    guard let absoluteUrl = URL(string: location) else {
                        throw SessionError.invalidResponse
                    }
                    redirectUrl = absoluteUrl
                } else {
                    // Relative URL
                    guard let relativeUrl = URL(string: location, relativeTo: currentUrl) else {
                        throw SessionError.invalidResponse
                    }
                    redirectUrl = relativeUrl
                }
                
                // ALWAYS try to extract door ID from redirect URLs
                // The mybook URL has the actual door ID, not the k3y.in short code
                let pathComponents = redirectUrl.pathComponents
                print("Redirect URL path components: \(pathComponents)")
                
                // Check for mybook format: /login/mybook/1858-4537-74a1/
                if pathComponents.contains("mybook"),
                   let mybookIndex = pathComponents.firstIndex(of: "mybook"),
                   mybookIndex + 1 < pathComponents.count {
                    let extractedId = pathComponents[mybookIndex + 1].replacingOccurrences(of: "/", with: "")
                    if !extractedId.isEmpty {
                        doorId = extractedId
                        print("✅ Found door ID in mybook path: \(doorId)")
                    }
                }
                // Check for door format: /go/door/8383838/1/
                else if pathComponents.contains("door"),
                        let doorIndex = pathComponents.firstIndex(of: "door"),
                        doorIndex + 1 < pathComponents.count {
                    let extractedId = pathComponents[doorIndex + 1].replacingOccurrences(of: "/", with: "")
                    if !extractedId.isEmpty {
                        doorId = extractedId
                        print("✅ Found door ID in door path: \(doorId)")
                    }
                }
                
                currentUrl = redirectUrl
                finalUrl = redirectUrl
                redirectCount += 1
            } else if httpResponse.statusCode == 200 {
                // k3y.in might return 200 with a meta refresh or JavaScript redirect
                // Check if this is k3y.in returning HTML
                if currentUrl.host?.contains("k3y.in") == true {
                    print("⚠️ k3y.in returned 200 - may use meta refresh or JavaScript redirect")
                    print("⚠️ Cannot extract proper door ID from k3y.in HTML response")
                    // We'll have to use the short ID as fallback
                }
                
                print("Final destination reached: \(finalUrl)")
                break
            } else {
                // Unexpected status code
                print("Unexpected status code: \(httpResponse.statusCode)")
                throw SessionError.invalidResponse
            }
        }
        
        // Only use k3y.in short ID as last resort if we didn't find a proper door ID
        if doorId.isEmpty && url.host?.contains("k3y.in") == true {
            // For k3y.in links, the ID might be the last path component
            let shortId = url.lastPathComponent
            if !shortId.isEmpty {
                doorId = shortId
                print("⚠️ WARNING: Using k3y.in short ID as door ID (no proper door ID found): \(doorId)")
                print("⚠️ This may not work correctly. The app needs the actual door ID from the redirect.")
                print("⚠️ Try opening the link in Safari first to establish the session.")
            }
        }
        
        // Ensure we have a valid final URL and door ID
        guard !doorId.isEmpty else {
            print("❌ No door ID found in redirect chain")
            throw SessionError.noDoorIdFound
        }
        
        print("Final URL: \(finalUrl), Door ID: \(doorId)")
        return (finalUrl, doorId)
    }
    
    func deleteSession() {
        guard let defaults = sharedDefaults else { return }
        
        // Clear stored data
        smsLink = ""
        doorId = ""
        baseUrl = ""
        sessionPath = ""
        hasStoredSession = false
        
        // Remove from UserDefaults
        defaults.removeObject(forKey: smsLinkKey)
        defaults.removeObject(forKey: doorIdKey)
        defaults.removeObject(forKey: baseUrlKey)
        defaults.removeObject(forKey: sessionPathKey)
        defaults.synchronize()
        
        // Clear cookies
        CookieManager.shared.clearSession()
        
        // Notify watch
        WatchConnectivityManager.shared.sendSessionUpdate()
    }
    
    func getDoorUnlockUrl() -> String? {
        guard !baseUrl.isEmpty else {
            return nil
        }
        // Always use HTTPS for API calls
        let cleanBaseUrl = baseUrl.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        // Based on HAR logs, the unlock URL is /myaccount/key/unlock/
        return "https://\(cleanBaseUrl)/myaccount/key/unlock/"
    }
    
    func getSessionRefreshUrl() -> String? {
        guard !baseUrl.isEmpty else {
            return nil
        }
        // Always use HTTPS for API calls
        let cleanBaseUrl = baseUrl.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        return "https://\(cleanBaseUrl)/myaccount/"
    }
}

enum SessionError: LocalizedError {
    case invalidLink
    case invalidResponse
    case storageError
    case noDoorIdFound
    
    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "Invalid SMS link. Please paste the complete link from your SMS."
        case .invalidResponse:
            return "Unable to process the link. Please check your internet connection."
        case .storageError:
            return "Unable to save session data."
        case .noDoorIdFound:
            return "Could not extract door information from the link."
        }
    }
}
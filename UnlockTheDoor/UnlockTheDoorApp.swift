import SwiftUI
import WatchConnectivity
import AppIntents

@main
struct UnlockTheDoorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Register App Shortcuts for Siri
        UnlockTheDoorShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        if url.scheme == "unlockthedoor" && url.host == "unlock" {
            NotificationCenter.default.post(name: Notification.Name("PerformUnlock"), object: nil)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = WatchConnectivityManager.shared
            session.activate()
            // Don't call sendSessionUpdate here - it will be called from activationDidCompleteWith
        }
        return true
    }
}
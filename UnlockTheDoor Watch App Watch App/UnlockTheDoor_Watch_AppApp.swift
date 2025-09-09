import SwiftUI
import WatchConnectivity
import AppIntents

@main
struct UnlockTheDoor_Watch_App_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var shouldUnlock = false
    
    init() {
        // Register App Shortcuts for Siri
        UnlockTheDoorShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(shouldUnlock: $shouldUnlock)
                .onOpenURL { url in
                    if url.absoluteString == "unlockthedoor://unlock" {
                        shouldUnlock = true
                    }
                }
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        print("🚀 Watch App Did Finish Launching")
        
        // Initialize WatchConnectivity
        WatchConnectivityManager.shared.activate()
        
        print("✅ WatchConnectivity initialized")
    }
}
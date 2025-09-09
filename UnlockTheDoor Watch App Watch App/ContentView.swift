//
//  ContentView.swift
//  UnlockTheDoor Watch App
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var doorService = DoorUnlockService.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var shouldUnlock: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var connectionCheckTimer: Timer?
    @State private var hasAttemptedSync = false
    @State private var isWaitingForSync = false
    
    init(shouldUnlock: Binding<Bool> = .constant(false)) {
        self._shouldUnlock = shouldUnlock
    }
    
    private var canUnlock: Bool {
        if doorService.isUnlocking { return false }
        if isWaitingForSync { return false }  // Don't allow unlock while syncing
        if !sessionStore.isConfigured { return false }
        if !sessionStore.hasValidCookie { return false }
        
        // Can unlock only if we have internet (iPhone proxy or direct)
        return networkMonitor.hasInternet
    }
    
    private var buttonText: String {
        if doorService.isUnlocking {
            return "unlocking".localized
        } else if isWaitingForSync {
            return "syncing".localized
        } else if !sessionStore.isConfigured {
            return "setup_first".localized
        } else if !sessionStore.hasValidCookie {
            return "sync_iphone".localized
        } else if !networkMonitor.hasInternet {
            return "no_network".localized
        } else {
            return "tap_to_unlock".localized
        }
    }
    
    private var buttonColor: Color {
        if !canUnlock {
            return .gray
        } else {
            return .blue  // Ready to unlock
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: doorService.isUnlocking ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(doorService.isUnlocking ? Color.green : Color.blue)
                    .contentTransition(.symbolEffect(.automatic))
                
                // Show unlocking indicator
                if doorService.isUnlocking {
                    Image(systemName: "network")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                        .offset(x: 30, y: -20)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }
            
            VStack(spacing: 4) {
                if isWaitingForSync {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                        Text("syncing".localized)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else if !sessionStore.isConfigured {
                    Text("setup_first".localized)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                } else if !sessionStore.hasValidCookie {
                    Text("sync_iphone".localized)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                } else if !sessionStore.doorId.isEmpty {
                    Text("\("room".localized) \(sessionStore.doorId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !doorService.statusMessage.isEmpty {
                    Text(doorService.statusMessage)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                
                // Show connection and config status icons
                HStack(spacing: 6) {
                    // iPhone connection with real-time status
                    HStack(spacing: 2) {
                        Image(systemName: connectivityManager.isPhoneConnected ? "iphone" : "iphone.slash")
                            .font(.caption2)
                            .foregroundStyle(connectivityManager.isPhoneConnected ? .green : .gray)
                        if connectivityManager.isPhoneConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // Internet status when iPhone disconnected
                    if !connectivityManager.isPhoneConnected {
                        Image(systemName: networkMonitor.hasInternet ? "network" : "network.slash")
                            .font(.caption2)
                            .foregroundStyle(networkMonitor.hasInternet ? .green : .red)
                    }
                    
                    // Configuration/cookie status
                    if sessionStore.isConfigured {
                        Image(systemName: sessionStore.hasValidCookie ? "key.fill" : "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundStyle(sessionStore.hasValidCookie ? .green : .orange)
                    } else {
                        Image(systemName: "gear.badge.xmark")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Button(action: {
                Task {
                    await unlockDoor()
                }
            }) {
                HStack {
                    if doorService.isUnlocking {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "key.fill")
                    }
                    Text(buttonText)
                }
            }
            .disabled(!canUnlock)
            .buttonStyle(.borderedProminent)
            .tint(buttonColor)
            .controlSize(.large)
            .handGestureShortcut(.primaryAction)  // Enable double-tap support!
            
        }
        .padding()
        .alert("something_went_wrong".localized, isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: shouldUnlock) { oldValue, newValue in
            if newValue {
                Task {
                    await unlockDoor()
                    shouldUnlock = false
                }
            }
        }
        .task {
            if shouldUnlock {
                // Trigger immediate network check when launched from widget
                networkMonitor.startConnectivityChecks()
                await unlockDoor()
                shouldUnlock = false
            }
        }
        .onContinueUserActivity("com.cacheoverflow.UnlockTheDoor.unlock") { _ in
            Task {
                await unlockDoor()
            }
        }
        .onAppear {
            print("ContentView appeared")
            // Ensure WatchConnectivity is activated
            connectivityManager.activate()
            
            // Start fast connection checking while app is visible
            startConnectionMonitoring()
            
            // Attempt initial sync if we don't have valid data
            attemptInitialSync()
        }
        .onDisappear {
            print("ContentView disappeared")
            stopConnectionMonitoring()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                startConnectionMonitoring()
            } else if newPhase == .background {
                stopConnectionMonitoring()
            }
        }
    }
    
    private func unlockDoor() async {
        // If we don't have valid cookie, try to sync first
        if !sessionStore.hasValidCookie && connectivityManager.isPhoneConnected {
            isWaitingForSync = true
            
            // Request sync with timeout
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.requestSyncWithTimeout()
                }
            }
            
            isWaitingForSync = false
        }
        
        // When launched from widget, wait briefly for network to initialize
        // This prevents immediate "no network" errors
        if !networkMonitor.hasInternet && !networkMonitor.hasPerformedInitialCheck {
            // Give network monitor up to 2 seconds to check connectivity
            for _ in 0..<4 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if networkMonitor.hasInternet || networkMonitor.hasPerformedInitialCheck {
                    break
                }
            }
        }
        
        do {
            try await doorService.unlockDoor()
            // Use modern haptic feedback
            await playHaptic(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            await playHaptic(.error)
        }
    }
    
    private func requestSyncWithTimeout() async {
        await withCheckedContinuation { continuation in
            var completed = false
            
            // Set a timeout
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds timeout
                if !completed {
                    completed = true
                    continuation.resume()
                }
            }
            
            // Request sync
            connectivityManager.requestSessionUpdate { success in
                if !completed {
                    completed = true
                    continuation.resume()
                }
            }
        }
    }
    
    private func attemptInitialSync() {
        // Only sync if we need to and haven't tried yet
        guard !hasAttemptedSync else { return }
        
        hasAttemptedSync = true
        
        // Only request sync if we don't have valid data
        guard !sessionStore.isConfigured || !sessionStore.hasValidCookie else { 
            print("✅ Already have valid session, skipping initial sync")
            return 
        }
        
        // If iPhone is connected, request sync
        if connectivityManager.isPhoneConnected {
            isWaitingForSync = true
            connectivityManager.requestSessionUpdate { success in
                DispatchQueue.main.async {
                    self.isWaitingForSync = false
                }
            }
            
            // Set a timeout for the sync
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    self.isWaitingForSync = false
                }
            }
        }
    }
    
    @MainActor
    private func playHaptic(_ type: HapticType) async {
        #if os(watchOS)
        let impactStyle: WKHapticType = type == .success ? .success : .failure
        WKInterfaceDevice.current().play(impactStyle)
        #endif
    }
    
    private func startConnectionMonitoring() {
        // Stop any existing timer
        connectionCheckTimer?.invalidate()
        
        // Check immediately
        updateConnectionStatus()
        
        // Start internet connectivity checks
        networkMonitor.startConnectivityChecks()
        
        // Check every 3 seconds for faster detection
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.updateConnectionStatus()
        }
    }
    
    private func stopConnectionMonitoring() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
        
        // Stop internet connectivity checks to save battery
        networkMonitor.stopConnectivityChecks()
    }
    
    private func updateConnectionStatus() {
        let isReachable = WCSession.default.isReachable
        if connectivityManager.isPhoneConnected != isReachable {
            print("📱 Connection status changed: \(isReachable)")
            connectivityManager.isPhoneConnected = isReachable
        }
        
        // Only log state changes, not every check
        // This reduces log spam significantly
    }
}

enum HapticType {
    case success
    case error
}

#Preview {
    ContentView()
}

//
//  NetworkMonitor.swift
//  UnlockTheDoor Watch App
//
//  Created by Assistant on 2025-09-08.
//

import Foundation
import Network
import WatchKit

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var connectivityCheckTimer: Timer?
    
    @Published var hasInternet = false
    @Published var hasPerformedInitialCheck = false
    
    private init() {
        startMonitoring()
        // Don't start connectivity checks here - let ContentView control it
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Path is satisfied, but let's verify with actual connection test
                self?.checkInternetConnectivity()
            } else {
                // No path available, definitely no internet
                DispatchQueue.main.async {
                    self?.hasInternet = false
                    print("📶 No network path available")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func startConnectivityChecks() {
        // Stop any existing timer first
        stopConnectivityChecks()
        
        // Initial check
        checkInternetConnectivity()
        
        // Periodic checks every 5 seconds for better responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.connectivityCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                self?.checkInternetConnectivity()
            }
        }
    }
    
    func stopConnectivityChecks() {
        // Cancel any active check first
        activeCheckTask?.cancel()
        activeCheckTask = nil
        
        // Then invalidate timer
        connectivityCheckTimer?.invalidate()
        connectivityCheckTimer = nil
    }
    
    private var activeCheckTask: URLSessionDataTask?
    
    private func checkInternetConnectivity() {
        // Cancel any existing check to prevent overlap
        activeCheckTask?.cancel()
        
        // Use HTTPS connectivity check instead of DNS (DNS is blocked when using iPhone proxy)
        let url = URL(string: "https://www.apple.com/library/test/success.html")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0  // Increased timeout to reduce false negatives
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        activeCheckTask = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            // Ignore cancelled tasks
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }
            
            DispatchQueue.main.async {
                // Mark that we've performed at least one check
                self.hasPerformedInitialCheck = true
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    if self.hasInternet != true {
                        self.hasInternet = true
                        print("✅ Internet connection verified via HTTPS")
                    }
                } else {
                    if self.hasInternet != false {
                        self.hasInternet = false
                        if let error = error {
                            print("❌ No internet connection: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        activeCheckTask?.resume()
    }
    
    deinit {
        // Clean up timer first before cancelling monitor
        stopConnectivityChecks()
        monitor.cancel()
    }
}
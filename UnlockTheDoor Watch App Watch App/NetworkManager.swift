//
//  NetworkManager.swift
//  UnlockTheDoor Watch App
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import Foundation

class NetworkManager: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let shared = NetworkManager()
    
    private var shouldFollowRedirects = true
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
    }
    
    func performRequest(url: URL, headers: [String: String] = [:], followRedirects: Bool = false) async throws -> (Data?, URLResponse?) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Store whether we should follow redirects for the delegate method
        shouldFollowRedirects = followRedirects
        
        // Always use the delegate-based API so our redirect handler gets called
        let (data, response) = try await session.data(for: request, delegate: self)
        return (data, response)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        #if DEBUG
        print("Redirect detected from \(response.url?.absoluteString ?? "unknown") to \(request.url?.absoluteString ?? "unknown")")
        print("Should follow redirects: \(shouldFollowRedirects)")
        #endif
        
        // If we shouldn't follow redirects, pass nil to stop the redirect
        if !shouldFollowRedirects {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}
//
//  LanguageManager.swift
//  UnlockTheDoor
//
//  Created by Assistant on 2025-09-08.
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case romanian = "ro"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case ukrainian = "uk"
    case bulgarian = "bg"
    case turkish = "tr"
    case hebrew = "he"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    
    var displayName: String {
        switch self {
        case .english: return "EN"
        case .romanian: return "RO"
        case .german: return "DE"
        case .french: return "FR"
        case .spanish: return "ES"
        case .portuguese: return "PT"
        case .ukrainian: return "UK"
        case .bulgarian: return "BG"
        case .turkish: return "TR"
        case .hebrew: return "HE"
        case .chinese: return "ZH"
        case .japanese: return "JA"
        case .korean: return "KO"
        }
    }
    
    var localizedName: String {
        switch self {
        case .english: return "English"
        case .romanian: return "Română"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .ukrainian: return "Українська"
        case .bulgarian: return "Български"
        case .turkish: return "Türkçe"
        case .hebrew: return "עברית"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .english: return "🇺🇸"
        case .romanian: return "🇷🇴"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇵🇹"
        case .ukrainian: return "🇺🇦"
        case .bulgarian: return "🇧🇬"
        case .turkish: return "🇹🇷"
        case .hebrew: return "🇮🇱"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // Store the language bundle to avoid repeated lookups
    private var languageBundle: Bundle?
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            // Save to UserDefaults synchronously but efficiently
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            
            // Only create app group defaults when actually changing language (rare operation)
            if let sharedDefaults = UserDefaults(suiteName: "group.cacheoverflow.UnlockTheDoor") {
                sharedDefaults.set(currentLanguage.rawValue, forKey: "AppLanguage")
            }
            
            // Update the language bundle cache
            updateLanguageBundle()
            
            // Sync with Watch via WatchConnectivity (only if needed)
            if oldValue != currentLanguage {
                Task {
                    WatchConnectivityManager.shared.sendLanguageUpdate(self.currentLanguage.rawValue)
                }
            }
        }
    }
    
    private init() {
        // Quick initialization - just set the current language
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .english
        
        // Update bundle cache
        updateLanguageBundle()
    }
    
    private func updateLanguageBundle() {
        // Cache the bundle for the current language
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.languageBundle = bundle
        } else {
            self.languageBundle = Bundle.main
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    // Provide a method to get localized strings using the cached bundle
    func localizedString(for key: String, comment: String = "") -> String {
        return languageBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
}

// SwiftUI helper for localized strings - now uses LanguageManager's cached bundle
extension String {
    var localized: String {
        // Use the LanguageManager's cached bundle for faster lookups
        return LanguageManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(for: self)
        return String(format: format, arguments: arguments)
    }
}
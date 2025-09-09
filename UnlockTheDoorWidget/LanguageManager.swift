//
//  LanguageManager.swift
//  UnlockTheDoorWidget
//
//  Created by Assistant on 2025-09-08.
//

import Foundation
import SwiftUI

// Simple language manager for Widget without runtime manipulation
class WidgetLanguageManager {
    static let shared = WidgetLanguageManager()
    
    private var languageBundle: Bundle?
    
    private init() {
        // Read the language preference from UserDefaults (shared with main app via app group)
        let sharedDefaults = UserDefaults(suiteName: "group.cacheoverflow.UnlockTheDoor")
        let savedLanguage = sharedDefaults?.string(forKey: "AppLanguage") ?? UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        
        // Cache the bundle for the saved language
        if let path = Bundle.main.path(forResource: savedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.languageBundle = bundle
        } else {
            self.languageBundle = Bundle.main
        }
    }
    
    func localizedString(for key: String) -> String {
        return languageBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
}

// SwiftUI helper for localized strings - uses cached bundle
extension String {
    var localized: String {
        return WidgetLanguageManager.shared.localizedString(for: self)
    }
}
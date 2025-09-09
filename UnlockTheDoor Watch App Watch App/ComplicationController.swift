//
//  ComplicationController.swift
//  UnlockTheDoor Watch App
//
//  Created by TirzumanDaniel on 06.09.2025.
//

import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        // Create a user activity for launching the unlock action
        let userActivity = NSUserActivity(activityType: "com.cacheoverflow.UnlockTheDoor.unlock")
        userActivity.title = "tap_to_unlock".localized
        userActivity.userInfo = ["action": "unlock"]
        
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.cacheoverflow.UnlockTheDoor.complication",
                displayName: "app_title".localized,
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianSmallFlat,
                    .utilitarianLarge,
                    .extraLarge,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular,
                    .graphicBezel,
                    .graphicExtraLarge
                ],
                userActivity: userActivity
            )
        ]
        handler(descriptors)
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Update every hour
        handler(Date().addingTimeInterval(3600))
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = makeTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = makeTemplate(for: complication.family)
        handler(template)
    }
    
    // MARK: - Template Creation
    
    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        let lockImage = UIImage(systemName: "lock.fill")!
        let sessionValid = CookieManager.shared.hasValidSession()
        let statusText = sessionValid ? "tap_to_unlock".localized : "sync_iphone".localized
        
        switch family {
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            template.imageProvider.tintColor = sessionValid ? .green : .orange
            return template
            
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            template.imageProvider.tintColor = sessionValid ? .green : .orange
            return template
            
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody(
                headerImageProvider: CLKImageProvider(onePieceImage: lockImage),
                headerTextProvider: CLKTextProvider(format: "app_title".localized),
                body1TextProvider: CLKTextProvider(format: "unlock_door".localized),
                body2TextProvider: CLKTextProvider(format: statusText)
            )
            return template
            
        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            template.imageProvider.tintColor = sessionValid ? .green : .orange
            return template
            
        case .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKTextProvider(format: "unlock_door".localized),
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            return template
            
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKTextProvider(format: "unlock_door".localized),
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            return template
            
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            template.imageProvider.tintColor = sessionValid ? .green : .orange
            return template
            
        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: CLKTextProvider(format: "room".localized),
                imageProvider: CLKFullColorImageProvider(fullColorImage: lockImage)
            )
            return template
            
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularStackImage(
                line1ImageProvider: CLKFullColorImageProvider(fullColorImage: lockImage),
                line2TextProvider: CLKTextProvider(format: "unlock_door".localized)
            )
            return template
            
        case .graphicRectangular:
            // Enhanced for Smart Stack - this is the main one that appears
            let template = CLKComplicationTemplateGraphicRectangularStandardBody(
                headerImageProvider: CLKFullColorImageProvider(fullColorImage: lockImage),
                headerTextProvider: CLKTextProvider(format: "app_title".localized),
                body1TextProvider: CLKTextProvider(format: "🚪 " + "tap_to_unlock".localized),
                body2TextProvider: CLKTextProvider(format: sessionValid ? "✅ " + "tap_to_unlock".localized : "⚠️ " + "sync_iphone".localized)
            )
            return template
            
        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularStackImage(
                line1ImageProvider: CLKFullColorImageProvider(fullColorImage: lockImage),
                line2TextProvider: CLKTextProvider(format: "room".localized)
            )
            
            let template = CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: CLKTextProvider(format: "unlock_door".localized)
            )
            return template
            
        case .graphicExtraLarge:
            if #available(watchOS 7.0, *) {
                let template = CLKComplicationTemplateGraphicExtraLargeCircularStackImage(
                    line1ImageProvider: CLKFullColorImageProvider(fullColorImage: lockImage),
                    line2TextProvider: CLKTextProvider(format: "unlock_door".localized)
                )
                return template
            } else {
                let template = CLKComplicationTemplateGraphicCircularStackImage(
                    line1ImageProvider: CLKFullColorImageProvider(fullColorImage: lockImage),
                    line2TextProvider: CLKTextProvider(format: "unlock_door".localized)
                )
                return template
            }
            
        @unknown default:
            let template = CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: lockImage)
            )
            return template
        }
    }
}
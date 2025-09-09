//
//  UnlockTheDoorWidget.swift
//  UnlockTheDoorWidget
//
//  Created by TirzumanDaniel on 07.09.2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        // Create timeline entries for the next 5 hours
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct UnlockTheDoorWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // This is what shows in Smart Stack - THE MAIN ONE!
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock The Door")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("Tap to unlock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "unlockthedoor://unlock"))
            
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .widgetAccentable()
                    Text("Unlock")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .widgetURL(URL(string: "unlockthedoor://unlock"))
            
        case .accessoryInline:
            HStack {
                Image(systemName: "lock.fill")
                Text("Unlock")
            }
            .widgetURL(URL(string: "unlockthedoor://unlock"))
            
        case .accessoryCorner:
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .widgetAccentable()
                .widgetLabel {
                    Text("Unlock")
                        .font(.system(size: 12))
                }
            
        @unknown default:
            Image(systemName: "lock.fill")
                .widgetAccentable()
        }
    }
}

@main
struct UnlockTheDoorWidget: Widget {
    let kind: String = "UnlockTheDoorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UnlockTheDoorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Unlock The Door")
        .description("Quick unlock access")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct UnlockTheDoorWidget_Previews: PreviewProvider {
    static var previews: some View {
        UnlockTheDoorWidgetEntryView(entry: SimpleEntry(date: .now))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
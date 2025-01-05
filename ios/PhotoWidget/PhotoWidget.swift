//
//  PhotoWidget.swift
//  PhotoWidget
//
//  Created by Pierugo Pace on 17.12.2024.
//

import WidgetKit
import SwiftUI

private let widgetGroupId = "group.com.example.widgetMemoriesGroup"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoWidgetEntry {
        PhotoWidgetEntry(date: Date(), filename: nil, displaySize: context.displaySize)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoWidgetEntry) -> ()) {
        let entry: PhotoWidgetEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            // Get the data from the user defaults to display
            let userDefaults = UserDefaults(suiteName: widgetGroupId)
            let filename = userDefaults?.string(forKey: "filename")
            entry = PhotoWidgetEntry(date: Date(), filename: filename, displaySize: context.displaySize)
        }
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct PhotoWidgetEntry: TimelineEntry {
    let date: Date
    let filename: String?
    let displaySize: CGSize
}

struct PhotoWidgetEntryView : View {
    var entry: Provider.Entry
    var Photo: some View {
        if let filename = entry.filename,
           let uiImage = UIImage(contentsOfFile: filename) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: entry.displaySize.width,
                        height: entry.displaySize.height,
                        alignment: .center
                    )
                    .clipped()
            )
        }
        
        return AnyView(
            Color.black
                .frame(
                    width: entry.displaySize.width,
                    height: entry.displaySize.height
                )
        )
    }

    var body: some View {
        Photo
    }
}

struct PhotoWidget: Widget {
    let kind: String = "PhotoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PhotoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PhotoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Widget")
        .description("Widget displaying pictures together.")
    }
}

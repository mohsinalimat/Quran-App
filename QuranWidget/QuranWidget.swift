//
//  QuranWidget.swift
//  QuranWidget
//
//  Created by Ali Earp on 16/06/2024.
//

import WidgetKit
import SwiftUI
import Alamofire
import SwiftSoup

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), prayerTimes: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        fetchPrayerTimes { prayerTimes in
            if let prayerTimes = prayerTimes {
                let entry = SimpleEntry(date: Date(), prayerTimes: prayerTimes)
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        
        fetchPrayerTimes { prayerTimes in
            if let prayerTimes = prayerTimes {
                let entry = SimpleEntry(date: Date(), prayerTimes: prayerTimes)
                entries.append(entry)
            }
            
            if let updateDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) {
                let timeline = Timeline(entries: entries, policy: .after(updateDate))
                completion(timeline)
            }
        }
    }
    
    private func fetchPrayerTimes(completion: @escaping ([String: String]?) -> Void) {
        let url = "https://najaf.org/english/"

        AF.request(url).responseString { response in
            switch response.result {
            case .success(let html):
                do {
                    let document = try SwiftSoup.parse(html)
                    
                    let prayerTimeDiv = try document.select("#prayer_time").first()
                    let prayerItems = try prayerTimeDiv?.select("ul > li")
                    
                    var prayerTimes: [String : String] = [:]
                    
                    for item in prayerItems ?? Elements() {
                        let prayerName = try item.text().letters
                        let prayerTime = try item.select("span").text()
                        prayerTimes[prayerName] = prayerTime
                    }
                    
                    completion(prayerTimes)
                } catch {
                    print("Error parsing HTML: \(error)")
                    completion(nil)
                }
            case .failure(let error):
                print("Request failed with error: \(error)")
                completion(nil)
            }
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let prayerTimes: [String : String]
}

struct QuranWidgetEntryView : View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    var entry: Provider.Entry
    
    private let prayers = ["Dawn", "Sunrise", "Noon", "Sunset", "Maghrib"]
    private let prayersRenamed = ["Dawn" : "Fajr", "Sunrise" : "Sunrise", "Noon" : "Zuhr", "Sunset" : "Sunset", "Maghrib" : "Maghrib", "Midnight" : "Midnight"]
    
    private let columns: [GridItem] = [GridItem](repeating: GridItem(.flexible()), count: 2)
    private let rows: [GridItem] = [GridItem](repeating: GridItem(.flexible()), count: 5)
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            VStack(spacing: 0) {
                ForEach(prayerTimes, id: \.key) { prayer in
                    LazyVGrid(columns: columns) {
                        Text(prayersRenamed[prayer.key] ?? prayer.key)
                            .foregroundStyle(Color.secondary)
                        
                        Text(prayerTimeString(prayer.value))
                            .bold()
                    }
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .padding(.vertical, 5)
                }
            }
        case .systemMedium:
            VStack(spacing: 0) {
                Spacer()
                
                LazyVGrid(columns: rows) {
                    ForEach(prayerTimes, id: \.key) { prayer in
                        Text(prayersRenamed[prayer.key] ?? prayer.key)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                }.font(.system(size: 14))
                
                Spacer()
                
                LazyVGrid(columns: rows) {
                    ForEach(prayerTimes, id: \.key) { prayer in
                        Text(prayerTimeString(prayer.value))
                            .bold()
                            .multilineTextAlignment(.center)
                    }
                }.font(.system(size: 18))
                
                Spacer()
            }
        default:
            EmptyView()
        }
    }
    
    private var prayerTimes: [Dictionary<String, Date>.Element] {
        let filteredPrayerTimes = entry.prayerTimes.filter { prayerTime in
            prayers.contains { prayer in
                prayer == prayerTime.key
            }
        }
        
        var prayerTimesDates: [String : Date] = [:]
        
        for (prayer, time) in filteredPrayerTimes {
            var dateComponents = DateComponents()
            
            if let hour = Int(time.dropLast(3)) {
                if (prayer == "Noon" && hour != 11) || prayer == "Sunset" || prayer == "Maghrib" || prayer == "Midnight" {
                    dateComponents.hour = hour + 12
                } else {
                    dateComponents.hour = hour
                }
            }
            
            dateComponents.minute = Int(time.dropFirst(3))
            
            prayerTimesDates[prayer] = Calendar.current.date(from: dateComponents)
        }
        
        return prayerTimesDates.sorted {
            prayers.firstIndex(of: $0.key) ?? 0 < prayers.firstIndex(of: $1.key) ?? 0
        }
    }
    
    private func prayerTimeString(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}

struct QuranWidget: Widget {
    let kind: String = "QuranWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                QuranWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuranWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Prayer Times")
        .description("See prayer times at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    QuranWidget()
} timeline: {
    let prayerTimesModel: PrayerTimesModel = PrayerTimesModel()
    
    SimpleEntry(date: .now, prayerTimes: ["Imsaak" : "02:11", "Dawn" : "02:21", "Sunrise" : "04:43", "Noon" : "01:01", "Sunset" : "09:20", "Maghrib" : "9:35", "Midnight" : "11:50"])
}

#Preview(as: .systemMedium) {
    QuranWidget()
} timeline: {
    let prayerTimesModel: PrayerTimesModel = PrayerTimesModel()
    
    SimpleEntry(date: .now, prayerTimes: ["Imsaak" : "02:11", "Dawn" : "02:21", "Sunrise" : "04:43", "Noon" : "01:01", "Sunset" : "09:20", "Maghrib" : "9:35", "Midnight" : "11:50"])
}

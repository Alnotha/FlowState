//
//  WeeklyOverviewView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData
import Charts

struct WeeklyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    
    // Calculate week data
    private var weekData: [(day: String, count: Int, date: Date)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        var data: [(day: String, count: Int, date: Date)] = []
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let dayName = day.formatted(.dateTime.weekday(.abbreviated))
                let entriesOnDay = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
                data.append((dayName, entriesOnDay, day))
            }
        }
        
        return data
    }
    
    private var totalWords: Int {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return entries
            .filter { $0.date >= startOfWeek }
            .reduce(0) { $0 + $1.wordCount }
    }
    
    private var daysJournaled: Int {
        weekData.filter { $0.count > 0 }.count
    }
    
    private var averageWords: Int {
        daysJournaled > 0 ? totalWords / daysJournaled : 0
    }
    
    var body: some View {
        List {
            // Summary Stats
            Section {
                HStack(spacing: 0) {
                    WeeklyStat(value: "\(daysJournaled)", label: "Days", sublabel: "/ 7")
                    Divider()
                    WeeklyStat(value: "\(totalWords)", label: "Words", sublabel: "total")
                    Divider()
                    WeeklyStat(value: "\(averageWords)", label: "Avg", sublabel: "per day")
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
            } header: {
                Text("This Week")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            
            // Chart
            Section {
                Chart {
                    ForEach(weekData, id: \.day) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Entries", item.count)
                        )
                        .foregroundStyle(Calendar.current.isDateInToday(item.date) ? Color.accentColor : Color.gray.opacity(0.5))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding()
            } header: {
                Text("Daily Activity")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            
            // Progress message
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if daysJournaled >= 7 {
                        Label("Perfect Week!", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                        Text("You journaled every day this week.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if daysJournaled >= 5 {
                        Label("Great Progress", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                        Text("You're building a strong habit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if daysJournaled >= 3 {
                        Label("Keep Going", systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                            .fontWeight(.semibold)
                        Text("You're making progress.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Start Building", systemImage: "calendar")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        Text("Try journaling more regularly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Weekly Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Weekly Stat

struct WeeklyStat: View {
    let value: String
    let label: String
    let sublabel: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(sublabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        WeeklyOverviewView()
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}

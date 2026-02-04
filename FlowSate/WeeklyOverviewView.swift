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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your journaling activity this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Stats cards
                HStack(spacing: 16) {
                    StatCard(
                        title: "Days",
                        value: "\(daysJournaled)/7",
                        icon: "calendar.badge.checkmark",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Total Words",
                        value: "\(totalWords)",
                        icon: "text.alignleft",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                
                // Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Activity Chart")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    Chart {
                        ForEach(weekData, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Entries", item.count)
                            )
                            .foregroundStyle(Calendar.current.isDateInToday(item.date) ? Color.blue.gradient : Color.green.gradient)
                            .cornerRadius(8)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    .padding(.horizontal)
                }
                
                // Insights section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Insights")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        InsightCard(
                            icon: "flame.fill",
                            title: "Keep it up!",
                            description: "You've journaled \(daysJournaled) days this week",
                            color: .orange
                        )
                        
                        if daysJournaled >= 5 {
                            InsightCard(
                                icon: "star.fill",
                                title: "Consistency Champion",
                                description: "5+ days of journaling this week!",
                                color: .yellow
                            )
                        }
                        
                        if totalWords > 1000 {
                            InsightCard(
                                icon: "book.fill",
                                title: "Prolific Writer",
                                description: "Over 1,000 words written this week",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack {
        WeeklyOverviewView()
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}

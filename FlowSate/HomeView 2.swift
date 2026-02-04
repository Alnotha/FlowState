//
//  HomeView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var showingEditor = false
    
    // Get today's entry if it exists
    private var todayEntry: JournalEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }
    
    // Calculate weekly journaling streak
    private var weeklyStreak: Int {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        let thisWeekEntries = entries.filter { entry in
            entry.date >= startOfWeek && entry.date <= today
        }
        
        // Count unique days
        let uniqueDays = Set(thisWeekEntries.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Weekly stats section
                Section {
                    WeeklyStreakCard(streak: weeklyStreak)
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("This Week")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                
                // Today's entry section
                Section {
                    if let entry = todayEntry {
                        TodayEntryCard(entry: entry)
                            .listRowInsets(EdgeInsets())
                            .onTapGesture {
                                showingEditor = true
                            }
                    } else {
                        EmptyEntryCard()
                            .listRowInsets(EdgeInsets())
                            .onTapGesture {
                                createTodayEntry()
                            }
                    }
                } header: {
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                
                // Recent entries
                if !entries.isEmpty && entries.filter({ !$0.isToday }).count > 0 {
                    Section {
                        ForEach(entries.prefix(5)) { entry in
                            if !entry.isToday {
                                NavigationLink(destination: JournalEditorView(entry: entry)) {
                                    EntryRowCard(entry: entry)
                                }
                                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                            }
                        }
                        
                        NavigationLink(destination: EntryLibraryView()) {
                            HStack {
                                Text("View All Entries")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    } header: {
                        Text("Recent Entries")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: WeeklyOverviewView()) {
                        Image(systemName: "chart.xyaxis.line")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let entry = todayEntry {
                    NavigationStack {
                        JournalEditorView(entry: entry)
                    }
                }
            }
        }
    }
    
    private func createTodayEntry() {
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        showingEditor = true
    }
}

// MARK: - Supporting Views (MacroFactor Style)

struct WeeklyStreakCard: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Days Journaled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("/ 7")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct TodayEntryCard: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(entry.wordCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("words")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let mood = entry.mood {
                    Text(moodEmoji(for: mood))
                        .font(.title2)
                }
            }
            
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to start writing...")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
            
            HStack {
                if let photoData = entry.photoData, !photoData.isEmpty {
                    Label("\(photoData.count) photo\(photoData.count == 1 ? "" : "s")", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Tap to edit")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func moodEmoji(for mood: String) -> String {
        switch mood.lowercased() {
        case "happy": return "😊"
        case "calm": return "😌"
        case "sad": return "😔"
        case "frustrated": return "😤"
        case "thoughtful": return "🤔"
        default: return "😐"
        }
    }
}

struct EmptyEntryCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Start Today's Entry")
                .font(.headline)
            
            Text("Tap to begin journaling")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
    }
}

struct EntryRowCard: View {
    let entry: JournalEntry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedDate)
                    .font(.body)
                    .fontWeight(.medium)
                
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Empty entry")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.wordCount)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text("words")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}

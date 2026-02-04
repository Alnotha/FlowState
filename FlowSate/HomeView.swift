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
            ScrollView {
                VStack(spacing: 24) {
                    // Header with greeting
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greetingText)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Weekly streak card
                    WeeklyStreakCard(streak: weeklyStreak)
                        .padding(.horizontal)
                    
                    // Today's entry section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Entry")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        if let entry = todayEntry {
                            TodayEntryCard(entry: entry)
                                .padding(.horizontal)
                                .onTapGesture {
                                    showingEditor = true
                                }
                        } else {
                            EmptyEntryCard()
                                .padding(.horizontal)
                                .onTapGesture {
                                    createTodayEntry()
                                }
                        }
                    }
                    
                    // Recent entries
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Entries")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                NavigationLink(destination: EntryLibraryView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            ForEach(entries.prefix(5)) { entry in
                                if !entry.isToday {
                                    NavigationLink(destination: JournalEditorView(entry: entry)) {
                                        EntryRowCard(entry: entry)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: WeeklyOverviewView()) {
                        Image(systemName: "chart.bar.fill")
                            .font(.body)
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
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    private func createTodayEntry() {
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        showingEditor = true
    }
}

// MARK: - Supporting Views

struct WeeklyStreakCard: View {
    let streak: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 36, weight: .bold))
                    Text("days")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40))
                .foregroundStyle(.green.gradient)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct TodayEntryCard: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Journal", systemImage: "pencil.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Text("\(entry.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            } else {
                Text("Tap to start writing...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            HStack {
                Spacer()
                Text("Edit Entry")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct EmptyEntryCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            
            Text("Start Today's Entry")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Tap here to begin journaling")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct EntryRowCard: View {
    let entry: JournalEntry
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Empty entry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.wordCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("words")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}

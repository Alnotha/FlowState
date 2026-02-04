//
//  EntryLibraryView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData

struct EntryLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var searchText = ""
    
    private var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        } else {
            return entries.filter { entry in
                entry.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Group entries by month
    private var groupedEntries: [(month: String, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            entry.date.formatted(.dateTime.year().month(.wide))
        }
        
        return grouped.map { (month: $0.key, entries: $0.value) }
            .sorted { first, second in
                // Sort by most recent month first
                guard let firstDate = first.entries.first?.date,
                      let secondDate = second.entries.first?.date else {
                    return false
                }
                return firstDate > secondDate
            }
    }
    
    private var totalEntries: Int {
        entries.count
    }
    
    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }
    
    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyLibraryView()
            } else {
                List {
                    // Summary stats
                    Section {
                        HStack(spacing: 0) {
                            LibraryStat(value: "\(totalEntries)", label: "Entries")
                            Divider()
                            LibraryStat(value: "\(totalWords)", label: "Words")
                            Divider()
                            LibraryStat(value: "\(entries.filter { $0.photoData != nil }.count)", label: "Photos")
                        }
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical)
                    } header: {
                        Text("All Time")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                    
                    // Entries by month
                    ForEach(groupedEntries, id: \.month) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                NavigationLink(destination: JournalEditorView(entry: entry)) {
                                    EntryLibraryRow(entry: entry)
                                }
                            }
                            .onDelete { indexSet in
                                deleteEntries(in: section.entries, at: indexSet)
                            }
                        } header: {
                            Text(section.month)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search entries...")
            }
        }
        .navigationTitle("All Entries")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteEntries(in section: [JournalEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(section[index])
        }
    }
}

// MARK: - Library Stat

struct LibraryStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Entry Library Row

struct EntryLibraryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
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
                
                HStack(spacing: 12) {
                    if let mood = entry.mood {
                        Text(moodEmoji(for: mood))
                            .font(.caption)
                    }
                    
                    if let photoData = entry.photoData, !photoData.isEmpty {
                        Label("\(photoData.count)", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
        .padding(.vertical, 4)
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

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No Entries Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start journaling to see your entries here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        EntryLibraryView()
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}

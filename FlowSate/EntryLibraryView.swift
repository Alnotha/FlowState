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
    @State private var showingExportSheet = false

    private var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        } else {
            return entries.filter { entry in
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                (entry.mood?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                guard let firstDate = first.entries.first?.date,
                      let secondDate = second.entries.first?.date else {
                    return false
                }
                return firstDate > secondDate
            }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyLibraryView()
            } else {
                List {
                    ForEach(groupedEntries, id: \.month) { section in
                        Section(header: Text(section.month)) {
                            ForEach(section.entries) { entry in
                                NavigationLink(destination: JournalEditorView(entry: entry)) {
                                    EntryLibraryRow(entry: entry)
                                }
                            }
                            .onDelete { indexSet in
                                deleteEntries(in: section.entries, at: indexSet)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search entries...")
            }
        }
        .navigationTitle("All Entries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export entries")
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(entries: filteredEntries.isEmpty ? entries : filteredEntries)
        }
    }

    private func deleteEntries(in section: [JournalEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(section[index])
        }
    }
}

// MARK: - Entry Library Row

struct EntryLibraryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let emoji = entry.moodEmoji {
                    Text(emoji)
                        .font(.caption)
                }

                Text("\(entry.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Empty entry")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            if let photoData = entry.photoData, !photoData.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(photoData.count) photo\(photoData.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.date.formatted(date: .abbreviated, time: .omitted))\(entry.mood.map { ", mood: \($0)" } ?? ""), \(entry.wordCount) words. \(entry.content.isEmpty ? "Empty entry" : String(entry.content.prefix(80)))")
    }
}

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Entries Yet")
                .font(.title2)
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

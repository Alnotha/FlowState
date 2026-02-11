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
    @State private var showingSettings = false
    @State private var showingChat = false
    @State private var nudge: EmotionalNudge?
    @State private var showNudge = true
    @State private var detectedThemes: [DetectedTheme]?
    @AppStorage("userName") private var userName: String = ""

    private var todayEntry: JournalEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
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
                            .accessibilityAddTraits(.isHeader)

                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                    // Streak card
                    StreakCardView(entries: entries)
                        .padding(.horizontal)

                    // AI Nudge Banner
                    if let nudge, showNudge {
                        NudgeBanner(
                            nudge: nudge,
                            onAction: {
                                createTodayEntry()
                            },
                            onDismiss: {
                                withAnimation { showNudge = false }
                            }
                        )
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

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
                            if AIService.shared.canUseAI && AIService.shared.smartPromptsEnabled {
                                SmartPromptCard(
                                    recentEntries: entries,
                                    onStartWriting: { _ in
                                        createTodayEntry()
                                    }
                                )
                                .padding(.horizontal)
                            } else {
                                EmptyEntryCard()
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        createTodayEntry()
                                    }
                            }
                        }
                    }

                    // Themes & Patterns (shown after 14+ entries)
                    if AIService.shared.canUseAI && entries.count >= 14 {
                        ThemesPreviewCard(themes: detectedThemes)
                            .padding(.horizontal)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if AIService.shared.canUseAI && AIService.shared.chatEnabled {
                            Button {
                                showingChat = true
                            } label: {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.body)
                            }
                            .accessibilityLabel("Chat with journal")
                        }

                        NavigationLink(destination: WeeklyReviewView()) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.body)
                        }
                        .accessibilityLabel("Weekly review")

                        NavigationLink(destination: WeeklyOverviewView()) {
                            Image(systemName: "chart.bar.fill")
                                .font(.body)
                        }
                        .accessibilityLabel("All entries")
                    }
                }
            }
            .sheet(isPresented: $showingEditor, onDismiss: {
                if let entry = todayEntry, entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    modelContext.delete(entry)
                }
            }) {
                if let entry = todayEntry {
                    NavigationStack {
                        JournalEditorView(entry: entry)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .fullScreenCover(isPresented: $showingChat) {
                JournalChatView()
                    .modelContainer(for: JournalEntry.self)
            }
            .task {
                if entries.count >= 14 {
                    async let nudgeTask = AIService.shared.generateNudge(
                        recentEntries: Array(entries.prefix(5)),
                        currentStreak: StreakManager.currentStreak(from: entries),
                        totalEntries: entries.count
                    )
                    async let themesTask = AIService.shared.detectThemes(entries: entries)

                    nudge = await nudgeTask
                    detectedThemes = await themesTask
                } else {
                    nudge = await AIService.shared.generateNudge(
                        recentEntries: Array(entries.prefix(5)),
                        currentStreak: StreakManager.currentStreak(from: entries),
                        totalEntries: entries.count
                    )
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let nameSuffix = userName.isEmpty ? "" : ", \(userName)"
        switch hour {
        case 0..<12: return "Good Morning\(nameSuffix)"
        case 12..<17: return "Good Afternoon\(nameSuffix)"
        default: return "Good Evening\(nameSuffix)"
        }
    }

    private func createTodayEntry() {
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        showingEditor = true
    }
}

// MARK: - Supporting Views

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

            if let mood = entry.mood {
                HStack(spacing: 4) {
                    Text(moodEmoji(for: mood))
                        .font(.caption)
                    Text(mood.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's journal entry, \(entry.wordCount) words\(entry.mood.map { ", mood: \($0)" } ?? ""). \(entry.content.isEmpty ? "Tap to start writing" : String(entry.content.prefix(100)))")
        .accessibilityHint("Double tap to edit entry")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Write today's journal entry")
        .accessibilityHint("Double tap to start writing")
    }
}

struct EntryRowCard: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.formattedDate)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let mood = entry.mood {
                        Text(moodEmoji(for: mood))
                            .font(.caption)
                    }
                }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.formattedDate)\(entry.mood.map { ", mood: \($0)" } ?? ""), \(entry.wordCount) words. \(entry.content.isEmpty ? "Empty entry" : String(entry.content.prefix(80)))")
    }
}

// MARK: - Themes Preview Card

struct ThemesPreviewCard: View {
    let themes: [DetectedTheme]?

    var body: some View {
        NavigationLink(destination: ThemeInsightsView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Themes & Patterns", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.purple)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let themes, !themes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What you've been writing about")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(themes.prefix(4)) { theme in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.sentiment.color)
                                            .frame(width: 6, height: 6)
                                        Text(theme.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(theme.sentiment.color.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        if let topTheme = themes.first {
                            HStack(spacing: 6) {
                                Image(systemName: topTheme.trend.icon)
                                    .font(.caption2)
                                    .foregroundStyle(topTheme.sentiment.color)

                                Text("\(topTheme.name) is \(topTheme.trend.label.lowercased()) in your writing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Analyzing your journal...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Themes and patterns. \(themes?.first.map { "Top theme: \($0.name)" } ?? "Analyzing your journal"). Tap to see more.")
    }
}

#Preview {
    HomeView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}

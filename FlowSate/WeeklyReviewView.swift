//
//  WeeklyReviewView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData
import Charts

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var allEntries: [JournalEntry]

    private var weekStart: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? Date()
    }

    private var weekEntries: [JournalEntry] {
        let endOfSaturday = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        return allEntries.filter { $0.date >= weekStart && $0.date < endOfSaturday }
    }

    private func moodColor(for mood: String) -> Color {
        switch mood.lowercased() {
        case "happy": return .yellow
        case "calm": return .mint
        case "sad": return .blue
        case "frustrated": return .red
        case "thoughtful": return .purple
        default: return .gray
        }
    }

    private var moodDistribution: [(mood: String, count: Int)] {
        let moods = weekEntries.compactMap { $0.mood?.lowercased() }
        let grouped = Dictionary(grouping: moods) { $0 }
        return grouped.map { (mood: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var mostCommonMood: String? { moodDistribution.first?.mood }

    private var totalWordsThisWeek: Int {
        weekEntries.reduce(0) { $0 + $1.wordCount }
    }

    private var averageWordsPerEntry: Int {
        guard !weekEntries.isEmpty else { return 0 }
        return totalWordsThisWeek / weekEntries.count
    }

    private var bestWritingDay: (dayName: String, words: Int)? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weekEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        guard let best = grouped.max(by: {
            $0.value.reduce(0) { $0 + $1.wordCount } < $1.value.reduce(0) { $0 + $1.wordCount }
        }) else { return nil }
        let words = best.value.reduce(0) { $0 + $1.wordCount }
        let dayName = best.key.formatted(.dateTime.weekday(.wide))
        return (dayName, words)
    }

    private var entriesWithPhotos: Int {
        weekEntries.filter { ($0.photoData?.isEmpty == false) }.count
    }

    private var longestEntry: JournalEntry? {
        weekEntries.max(by: { $0.wordCount < $1.wordCount })
    }

    private var consistencyScore: Double {
        let calendar = Calendar.current
        let uniqueDays = Set(weekEntries.map { calendar.startOfDay(for: $0.date) })
        return Double(uniqueDays.count) / 7.0
    }

    private var consistencyPercentage: Int {
        Int((consistencyScore * 100).rounded())
    }

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    @State private var aiReflection: String?
    @State private var isLoadingReflection = false

    private var reflectionMessage: String {
        if weekEntries.isEmpty {
            return "Every great journey begins with a single step. Start capturing your thoughts this week -- your future self will thank you."
        }
        if consistencyScore >= 0.85 && totalWordsThisWeek > 1000 {
            return "What an incredible week of reflection. You showed up consistently and poured your thoughts onto the page. Keep nurturing this powerful habit."
        }
        if consistencyScore >= 0.7 {
            return "Strong consistency this week. Showing up regularly is the foundation of self-awareness. You are building something meaningful."
        }
        if consistencyScore >= 0.4 {
            return "You made time for reflection this week, and that matters. Even a few entries can spark real insight. See if you can add one more day next week."
        }
        return "You took a moment to journal this week, and that counts. Small steps lead to lasting habits. Try setting a gentle reminder for tomorrow."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Review")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    Text(dateRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // Mood Summary
                moodSummarySection

                // Writing Trends
                writingTrendsSection

                // Highlights
                weekHighlightsSection

                // Theme Insights Link
                if AIService.shared.canUseAI && AIService.shared.themeDetectionEnabled {
                    NavigationLink(destination: ThemeInsightsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "tag.fill")
                                .font(.title2)
                                .foregroundStyle(.purple.gradient)
                                .frame(width: 40, height: 40)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Themes & Patterns")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Discover recurring topics in your journal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }

                // Reflection
                reflectionSection
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAIReflection()
        }
    }

    private var moodSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood Summary")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if moodDistribution.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "face.dashed")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No moods recorded this week")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tag a mood on your journal entries to see your emotional patterns here.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Chart(moodDistribution, id: \.mood) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Mood", item.mood.capitalized)
                        )
                        .foregroundStyle(moodColor(for: item.mood).gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                            Text("\(moodEmoji(for: item.mood)) \(item.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.caption)
                        }
                    }
                    .frame(height: CGFloat(moodDistribution.count) * 48 + 16)
                    .accessibilityLabel("Mood distribution: \(moodDistribution.map { "\($0.mood.capitalized) \($0.count) times" }.joined(separator: ", "))")

                    if let topMood = mostCommonMood {
                        HStack(spacing: 8) {
                            Text(moodEmoji(for: topMood))
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Most Common Mood")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(topMood.capitalized)
                                    .font(.headline)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)
            }
        }
    }

    private var writingTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Writing Trends")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            HStack(spacing: 16) {
                ReviewStatCard(title: "Total Words", value: "\(totalWordsThisWeek)", icon: "text.alignleft", color: .blue)
                ReviewStatCard(title: "Avg / Entry", value: "\(averageWordsPerEntry)", icon: "divide", color: .indigo)
            }
            .padding(.horizontal)

            if let best = bestWritingDay {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.orange.gradient)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best Writing Day")
                            .font(.headline)
                        Text("\(best.dayName) -- \(best.words) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                .padding(.horizontal)
            }
        }
    }

    private var weekHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week Highlights")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ReviewHighlightRow(icon: "photo.fill", title: "Entries with Photos", detail: "\(entriesWithPhotos)", color: .blue)

                if let longest = longestEntry {
                    ReviewHighlightRow(
                        icon: "doc.text.fill",
                        title: "Longest Entry",
                        detail: "\(longest.date.formatted(.dateTime.month(.abbreviated).day())) -- \(longest.wordCount) words",
                        color: .green
                    )
                }

                ReviewHighlightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Consistency Score",
                    detail: "\(consistencyPercentage)%",
                    color: consistencyScore >= 0.7 ? .green : (consistencyScore >= 0.4 ? .orange : .red)
                )
            }
            .padding(.horizontal)
        }
    }

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.yellow.gradient)

                Text(aiReflection ?? reflectionMessage)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .redacted(reason: isLoadingReflection ? .placeholder : [])
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("AI weekly reflection: \(aiReflection ?? reflectionMessage)")
            .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - AI Reflection Loading

    private func loadAIReflection() async {
        guard !weekEntries.isEmpty else { return }
        isLoadingReflection = true
        let stats = WeeklyStats(
            totalWords: totalWordsThisWeek,
            averageWordsPerEntry: averageWordsPerEntry,
            daysJournaled: Set(weekEntries.map { Calendar.current.startOfDay(for: $0.date) }).count,
            consistencyScore: consistencyScore,
            bestWritingDay: bestWritingDay?.dayName,
            bestWritingDayWords: bestWritingDay?.words ?? 0,
            entriesWithPhotos: entriesWithPhotos
        )
        aiReflection = await AIService.shared.generateWeeklyReflection(
            entries: weekEntries,
            moodDistribution: moodDistribution.map { ($0.mood, $0.count) },
            stats: stats
        )
        isLoadingReflection = false
    }
}

// MARK: - Review Stat Card

private struct ReviewStatCard: View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Review Highlight Row

private struct ReviewHighlightRow: View {
    let icon: String
    let title: String
    let detail: String
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
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail)")
    }
}

#Preview {
    NavigationStack {
        WeeklyReviewView()
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}

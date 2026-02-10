//
//  StreakManager.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI

// MARK: - StreakManager

struct StreakManager {

    static func currentStreak(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = uniqueJournaledDays(from: entries, calendar: calendar)

        guard !uniqueDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())

        let start: Date
        if uniqueDays.contains(today) {
            start = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  uniqueDays.contains(yesterday) {
            start = yesterday
        } else {
            return 0
        }

        var streak = 0
        var current = start
        while uniqueDays.contains(current) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }

        return streak
    }

    static func longestStreak(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = uniqueJournaledDays(from: entries, calendar: calendar)

        guard !uniqueDays.isEmpty else { return 0 }

        let sorted = uniqueDays.sorted()

        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: sorted[i - 1])!
            if calendar.isDate(sorted[i], inSameDayAs: expected) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    static func totalEntries(from entries: [JournalEntry]) -> Int {
        entries.count
    }

    static func averageWordsPerEntry(from entries: [JournalEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.wordCount }
        return Int((Double(total) / Double(entries.count)).rounded())
    }

    static func thisWeekCount(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return 0 }

        return entries.filter { $0.date >= startOfWeek && $0.date <= today }.count
    }

    static func thisMonthCount(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) else { return 0 }

        return entries.filter { $0.date >= startOfMonth && $0.date <= today }.count
    }

    static func journaledToday(from entries: [JournalEntry]) -> Bool {
        entries.contains { Calendar.current.isDateInToday($0.date) && !$0.content.isEmpty }
    }

    private static func uniqueJournaledDays(
        from entries: [JournalEntry],
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            entries
                .filter { !$0.content.isEmpty }
                .map { calendar.startOfDay(for: $0.date) }
        )
    }
}

// MARK: - StreakCardView

struct StreakCardView: View {
    let entries: [JournalEntry]

    private var currentStreak: Int { StreakManager.currentStreak(from: entries) }
    private var longestStreak: Int { StreakManager.longestStreak(from: entries) }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange.gradient)

                    Text("\(currentStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Current Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.yellow.gradient)

                    Text("\(longestStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            WeekDotRow(entries: entries)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - WeekDotRow

private struct WeekDotRow: View {
    let entries: [JournalEntry]

    private var weekDays: [(label: String, journaled: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return [] }

        let journaledDays: Set<Date> = Set(
            entries
                .filter { !$0.content.isEmpty }
                .map { calendar.startOfDay(for: $0.date) }
        )

        var days: [(label: String, journaled: Bool)] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { continue }
            let label = day.formatted(.dateTime.weekday(.narrow))
            let didJournal = journaledDays.contains(calendar.startOfDay(for: day))
            days.append((label, didJournal))
        }
        return days
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(day.journaled ? Color.orange : Color.clear)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        day.journaled ? Color.orange : Color.secondary.opacity(0.3),
                                        lineWidth: 2
                                    )
                            )
                            .frame(width: 28, height: 28)

                        Text(day.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    StreakCardView(entries: [])
        .padding()
        .background(Color(.systemGroupedBackground))
}

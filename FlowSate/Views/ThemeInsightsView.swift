//
//  ThemeInsightsView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI
import SwiftData

struct ThemeInsightsView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var themes: [DetectedTheme]?
    @State private var isLoading = true
    @State private var selectedTheme: DetectedTheme?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if isLoading {
                    loadingState
                } else if let themes, !themes.isEmpty {
                    themeChips(themes)
                    themeCards(themes)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Themes & Patterns")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadThemes()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Themes")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Recurring topics and patterns across your journal entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Theme Chips

    private func themeChips(_ themes: [DetectedTheme]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(themes) { theme in
                    Button {
                        withAnimation { selectedTheme = theme }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(theme.sentiment.color)
                                .frame(width: 8, height: 8)
                            Text(theme.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(theme.frequency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedTheme?.id == theme.id
                                ? theme.sentiment.color.opacity(0.15)
                                : Color(.systemBackground)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Theme Cards

    private func themeCards(_ themes: [DetectedTheme]) -> some View {
        let displayThemes = selectedTheme.map { [$0] } ?? themes

        return VStack(spacing: 16) {
            ForEach(displayThemes) { theme in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.name)
                                .font(.headline)

                            HStack(spacing: 12) {
                                Label("\(theme.frequency) entries", systemImage: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 4) {
                                    Image(systemName: theme.trend.icon)
                                        .font(.caption)
                                    Text(theme.trend.label)
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.sentiment.color)
                                .frame(width: 10, height: 10)
                            Text(theme.sentiment.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.sentiment.color.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    if !theme.excerpts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(theme.excerpts, id: \.self) { excerpt in
                                HStack(alignment: .top, spacing: 8) {
                                    Rectangle()
                                        .fill(theme.sentiment.color.opacity(0.4))
                                        .frame(width: 3)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))

                                    Text("\"\(excerpt)\"")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }
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

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .frame(height: 120)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    .padding(.horizontal)
                    .redacted(reason: .placeholder)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Not enough entries yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Keep journaling and themes will emerge from your writing.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - Load

    private func loadThemes() async {
        isLoading = true
        themes = await AIService.shared.detectThemes(entries: entries)
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ThemeInsightsView()
            .modelContainer(for: JournalEntry.self, inMemory: true)
    }
}

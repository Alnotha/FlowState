//
//  AIService.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import Foundation
import Combine
import SwiftUI
import NaturalLanguage

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    @AppStorage("aiEnabled") var isEnabled = false
    @AppStorage("aiMoodSuggestion") var moodSuggestionEnabled = true
    @AppStorage("aiSmartPrompts") var smartPromptsEnabled = true
    @AppStorage("aiWeeklyReflection") var weeklyReflectionEnabled = true
    @AppStorage("aiChat") var chatEnabled = true
    @AppStorage("aiThemeDetection") var themeDetectionEnabled = true
    @AppStorage("aiNudges") var nudgesEnabled = true

    @Published var isProcessing = false

    var canUseAI: Bool {
        isEnabled && AuthenticationManager.shared.authState.isSignedIn
    }

    private let client = CloudflareClient.shared
    private let cache = NSCache<NSString, CachedResponse>()

    private init() {
        cache.countLimit = 50
    }

    // MARK: - Feature 1: Smart Journal Prompts

    func generateJournalPrompt(
        recentEntries: [JournalEntry],
        currentMood: String?,
        timeOfDay: TimeOfDay
    ) async -> String? {
        guard canUseAI && smartPromptsEnabled else { return nil }

        let cacheKey = "prompt_\(Calendar.current.component(.hour, from: Date()))" as NSString
        if let cached = cache.object(forKey: cacheKey), !cached.isExpired(ttl: 4 * 3600) {
            return cached.value
        }

        let entrySummaries = recentEntries.prefix(5).enumerated().map { index, entry in
            let mood = entry.mood.map { " (\($0))" } ?? ""
            let preview = String(entry.content.prefix(80)).replacingOccurrences(of: "\n", with: " ")
            return "- Entry \(index + 1)\(mood): \(preview)"
        }.joined(separator: "\n")

        let moodContext = currentMood.map { "Their current mood seems \($0). " } ?? ""

        let system = """
        You are a thoughtful journaling companion. Generate a single warm, specific \
        journaling prompt based on the user's recent entries and context. The prompt \
        should feel like it comes from a close friend who genuinely knows them. Never \
        be generic. Reference themes from their recent writing without quoting directly. \
        Keep it to 1-2 sentences. Do not use quotation marks.
        """

        let message = """
        It's \(timeOfDay.greeting). \(moodContext)

        Recent entries:
        \(entrySummaries.isEmpty ? "No recent entries yet." : entrySummaries)

        Generate one journaling prompt.
        """

        do {
            let response = try await client.sendMessage(
                system: system,
                messages: [ClaudeMessage(role: "user", content: message)],
                model: .haiku,
                maxTokens: 150,
                temperature: 0.9
            )
            cache.setObject(CachedResponse(value: response.content), forKey: cacheKey)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Feature 2: Mood Suggestion

    func suggestMood(from content: String) async -> MoodSuggestion? {
        guard canUseAI && moodSuggestionEnabled else { return nil }

        // Try local NLTagger first
        if let local = localSentimentAnalysis(content), local.confidence > 0.7 {
            return MoodSuggestion(
                suggestedMood: local.mood,
                confidence: local.confidence,
                reasoning: "It sounds like you might be feeling \(local.mood)."
            )
        }

        let system = """
        Analyze the emotional tone of this journal entry. Suggest one mood from \
        exactly these options: happy, calm, sad, frustrated, thoughtful.

        Respond in JSON: {"mood": "...", "confidence": 0.0-1.0, "reasoning": "It sounds like you might be feeling..."}

        The reasoning should be gentle and warm. One sentence.
        """

        do {
            let response = try await client.sendMessage(
                system: system,
                messages: [ClaudeMessage(role: "user", content: content)],
                model: .haiku,
                maxTokens: 100,
                temperature: 0.3
            )
            return parseMoodSuggestion(response.content)
        } catch {
            return nil
        }
    }

    // MARK: - Feature 3: AI Weekly Reflection

    func generateWeeklyReflection(
        entries: [JournalEntry],
        moodDistribution: [(String, Int)],
        stats: WeeklyStats
    ) async -> String? {
        guard canUseAI && weeklyReflectionEnabled else { return nil }

        let weekKey = "reflection_\(Calendar.current.component(.weekOfYear, from: Date()))" as NSString
        if let cached = cache.object(forKey: weekKey), !cached.isExpired(ttl: 24 * 3600) {
            return cached.value
        }

        let moodSummary = moodDistribution.map { "\($0.0) (\($0.1)x)" }.joined(separator: ", ")

        let entrySummaries = entries.prefix(7).map { entry in
            let day = entry.date.formatted(.dateTime.weekday(.wide))
            let mood = entry.mood.map { " (\($0))" } ?? ""
            let preview = String(entry.content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
            return "- \(day)\(mood): \(preview)"
        }.joined(separator: "\n")

        let system = """
        You are a warm, insightful journaling companion reflecting on someone's week. \
        You speak like a thoughtful therapist -- noticing patterns, celebrating growth, \
        and gently naming what might be hard. Never be generic or cheesy. Reference \
        specific themes from the data. Keep your reflection to 3-4 sentences. Use "you" language.
        """

        let message = """
        Weekly summary:
        - \(stats.daysJournaled) of 7 days journaled (\(Int(stats.consistencyScore * 100))% consistency)
        - \(stats.totalWords) total words, avg \(stats.averageWordsPerEntry) per entry
        - Moods: \(moodSummary.isEmpty ? "none recorded" : moodSummary)
        \(stats.bestWritingDay.map { "- Best writing day: \($0) (\(stats.bestWritingDayWords) words)" } ?? "")

        Entry summaries:
        \(entrySummaries.isEmpty ? "No entries this week." : entrySummaries)

        Generate a weekly reflection.
        """

        do {
            let response = try await client.sendMessage(
                system: system,
                messages: [ClaudeMessage(role: "user", content: message)],
                model: .sonnet,
                maxTokens: 250,
                temperature: 0.7
            )
            cache.setObject(CachedResponse(value: response.content), forKey: weekKey)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Feature 4: Chat with Journal

    func chatWithJournal(
        query: String,
        conversationHistory: [ChatMessage],
        entries: [JournalEntry]
    ) -> AsyncThrowingStream<String, Error> {
        guard canUseAI && chatEnabled else {
            return AsyncThrowingStream { $0.finish() }
        }

        let entryContext = entries.prefix(30).map { entry in
            let date = entry.date.formatted(.dateTime.month(.abbreviated).day().year())
            let mood = entry.mood.map { " | Mood: \($0)" } ?? ""
            let preview = String(entry.content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
            return "- \(date)\(mood) | \(entry.wordCount) words: \(preview)"
        }.joined(separator: "\n")

        let system = """
        You are a reflective companion who has read the user's journal entries. \
        Help them explore their thoughts and feelings by referencing what they've written. \
        Be warm, perceptive, and honest. NEVER fabricate entries or dates -- if unsure, say so. \
        When referencing an entry, mention the date. Keep responses concise (2-4 sentences) \
        unless asked for more detail.

        Journal entries (most recent first):
        \(entryContext.isEmpty ? "No entries yet." : entryContext)
        """

        var messages = conversationHistory.map {
            ClaudeMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        }
        messages.append(ClaudeMessage(role: "user", content: query))

        let client = self.client
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await client.streamMessage(
                        system: system,
                        messages: messages,
                        model: .sonnet,
                        maxTokens: 500,
                        temperature: 0.7
                    )
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Feature 5: Theme Detection

    func detectThemes(entries: [JournalEntry]) async -> [DetectedTheme]? {
        guard canUseAI && themeDetectionEnabled else { return nil }

        let entryCount = entries.count
        let cacheKey = "themes_\(entryCount)" as NSString
        if let cached = cache.object(forKey: cacheKey), !cached.isExpired(ttl: 24 * 3600) {
            return parseThemes(cached.value)
        }

        let entrySummaries = entries.prefix(30).map { entry in
            let date = entry.date.formatted(.dateTime.month(.abbreviated).day())
            let mood = entry.mood.map { " (\($0))" } ?? ""
            let preview = String(entry.content.prefix(150)).replacingOccurrences(of: "\n", with: " ")
            return "- \(date)\(mood): \(preview)"
        }.joined(separator: "\n")

        let system = """
        Identify 3-7 recurring themes in these journal entries. For each theme, determine:
        1. A short name (1-2 words)
        2. How many entries mention it
        3. Sentiment (positive/neutral/negative/mixed)
        4. Trend (increasing/stable/decreasing)
        5. Two brief excerpts

        Respond ONLY with JSON:
        {"themes": [{"name": "...", "count": N, "sentiment": "...", "trend": "...", "excerpts": ["...", "..."]}]}
        """

        do {
            let response = try await client.sendMessage(
                system: system,
                messages: [ClaudeMessage(role: "user", content: entrySummaries.isEmpty ? "No entries." : entrySummaries)],
                model: .sonnet,
                maxTokens: 600,
                temperature: 0.5
            )
            cache.setObject(CachedResponse(value: response.content), forKey: cacheKey)
            return parseThemes(response.content)
        } catch {
            return nil
        }
    }

    // MARK: - Feature 6: Gentle Nudges

    func generateNudge(
        recentEntries: [JournalEntry],
        currentStreak: Int,
        totalEntries: Int
    ) async -> EmotionalNudge? {
        guard canUseAI && nudgesEnabled else { return nil }

        let cacheKey = "nudge_\(Calendar.current.startOfDay(for: Date()))" as NSString
        if let cached = cache.object(forKey: cacheKey), !cached.isExpired(ttl: 12 * 3600) {
            return parseNudge(cached.value)
        }

        let recentMoods = recentEntries.prefix(5).compactMap { $0.mood }
        let avgWords = recentEntries.isEmpty ? 0 : recentEntries.reduce(0) { $0 + $1.wordCount } / recentEntries.count

        let system = """
        Generate a brief, genuinely warm message for a journaling app user. \
        Be human, not robotic. Never preachy or condescending. 1-2 sentences max.

        Respond in JSON: {"message": "...", "type": "encouragement|celebration|gentleCheck|suggestion", "actionLabel": "optional CTA or null"}
        """

        let message = """
        Context:
        - Current streak: \(currentStreak) days
        - Total entries: \(totalEntries)
        - Recent moods (last 5): \(recentMoods.isEmpty ? "none" : recentMoods.joined(separator: ", "))
        - Average words per entry recently: \(avgWords)
        """

        do {
            let response = try await client.sendMessage(
                system: system,
                messages: [ClaudeMessage(role: "user", content: message)],
                model: .haiku,
                maxTokens: 100,
                temperature: 0.8
            )
            cache.setObject(CachedResponse(value: response.content), forKey: cacheKey)
            return parseNudge(response.content)
        } catch {
            return nil
        }
    }

    // MARK: - Local Sentiment Analysis

    private func localSentimentAnalysis(_ text: String) -> (mood: String, confidence: Double)? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        guard let tag = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0,
              let score = Double(tag.rawValue) else {
            return nil
        }

        if score > 0.5 { return ("happy", score) }
        if score > 0.1 { return ("calm", score * 0.8) }
        if score < -0.5 { return ("frustrated", abs(score)) }
        if score < -0.2 { return ("sad", abs(score) * 0.8) }
        return ("thoughtful", 0.4)
    }

    // MARK: - JSON Parsing

    private func parseMoodSuggestion(_ json: String) -> MoodSuggestion? {
        guard let data = extractJSON(from: json),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mood = dict["mood"] as? String,
              let reasoning = dict["reasoning"] as? String else {
            return nil
        }
        let confidence = dict["confidence"] as? Double ?? 0.5
        let validMoods = ["happy", "calm", "sad", "frustrated", "thoughtful"]
        guard validMoods.contains(mood.lowercased()) else { return nil }
        return MoodSuggestion(suggestedMood: mood.lowercased(), confidence: confidence, reasoning: reasoning)
    }

    private func parseThemes(_ json: String) -> [DetectedTheme]? {
        guard let data = extractJSON(from: json),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let themes = dict["themes"] as? [[String: Any]] else {
            return nil
        }

        return themes.compactMap { t in
            guard let name = t["name"] as? String,
                  let count = t["count"] as? Int else { return nil }
            let sentiment = ThemeSentiment(rawValue: t["sentiment"] as? String ?? "neutral") ?? .neutral
            let trend = ThemeTrend(rawValue: t["trend"] as? String ?? "stable") ?? .stable
            let excerpts = t["excerpts"] as? [String] ?? []
            return DetectedTheme(name: name, frequency: count, sentiment: sentiment, trend: trend, excerpts: excerpts)
        }
    }

    private func parseNudge(_ json: String) -> EmotionalNudge? {
        guard let data = extractJSON(from: json),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = dict["message"] as? String else {
            return nil
        }
        let typeString = dict["type"] as? String ?? "encouragement"
        let type: NudgeType = switch typeString {
        case "celebration": .celebration
        case "gentleCheck": .gentleCheck
        case "suggestion": .suggestion
        default: .encouragement
        }
        let actionLabel = dict["actionLabel"] as? String
        return EmotionalNudge(message: message, type: type, actionLabel: actionLabel)
    }

    private func extractJSON(from text: String) -> Data? {
        // Handle cases where Claude wraps JSON in markdown code blocks
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.data(using: .utf8)
    }
}

// MARK: - Cache Helper

private class CachedResponse: NSObject {
    let value: String
    let createdAt: Date

    init(value: String) {
        self.value = value
        self.createdAt = Date()
    }

    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(createdAt) > ttl
    }
}

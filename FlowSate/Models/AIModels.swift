//
//  AIModels.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import Foundation
import SwiftUI

// MARK: - Claude API Types

nonisolated struct ClaudeMessage: Codable, Sendable {
    let role: String
    let content: String
}

nonisolated struct ClaudeRequestBody: Codable, Sendable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [[String: String]]
    let temperature: Double?
    let stream: Bool?
}

nonisolated struct ClaudeAPIResponse: Codable, Sendable {
    let id: String?
    let content: [ClaudeContent]?
    let usage: ClaudeUsage?
    let stop_reason: String?
    let error: ClaudeErrorDetail?

    nonisolated struct ClaudeContent: Codable, Sendable {
        let type: String
        let text: String?
    }

    nonisolated struct ClaudeUsage: Codable, Sendable {
        let input_tokens: Int
        let output_tokens: Int
    }

    nonisolated struct ClaudeErrorDetail: Codable, Sendable {
        let type: String?
        let message: String?
    }
}

nonisolated struct ClaudeResponse: Sendable {
    let content: String
    let inputTokens: Int
    let outputTokens: Int
}

nonisolated enum ClaudeModel: Sendable {
    case haiku
    case sonnet

    var identifier: String {
        switch self {
        case .haiku: return "claude-haiku-4-5-20251001"
        case .sonnet: return "claude-sonnet-4-5-20250929"
        }
    }
}

enum ClaudeAPIError: LocalizedError {
    case noWorkerURL
    case rateLimited
    case unauthorized
    case overloaded
    case invalidResponse(statusCode: Int)
    case networkError(Error)
    case decodingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noWorkerURL: return "AI proxy URL not configured"
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .unauthorized: return "Unauthorized request"
        case .overloaded: return "AI service is busy. Try again shortly."
        case .invalidResponse(let code): return "Unexpected response (code \(code))"
        case .networkError(let error): return error.localizedDescription
        case .decodingError: return "Failed to read AI response"
        case .apiError(let msg): return msg
        }
    }
}

// MARK: - Feature Types

struct MoodSuggestion {
    let suggestedMood: String
    let confidence: Double
    let reasoning: String
}

struct DetectedTheme: Identifiable {
    let id = UUID()
    let name: String
    let frequency: Int
    let sentiment: ThemeSentiment
    let trend: ThemeTrend
    let excerpts: [String]
}

enum ThemeSentiment: String, Codable {
    case positive, neutral, negative, mixed

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        case .mixed: return .orange
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

enum ThemeTrend: String, Codable {
    case increasing, stable, decreasing

    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

struct EmotionalNudge {
    let message: String
    let type: NudgeType
    let actionLabel: String?
}

enum NudgeType {
    case encouragement, celebration, gentleCheck, suggestion

    var icon: String {
        switch self {
        case .encouragement: return "hand.thumbsup.fill"
        case .celebration: return "party.popper.fill"
        case .gentleCheck: return "heart.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .encouragement: return .blue
        case .celebration: return .orange
        case .gentleCheck: return .pink
        case .suggestion: return .purple
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    var content: String
    let timestamp: Date

    init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum ChatRole {
    case user, assistant
}

struct WeeklyStats {
    let totalWords: Int
    let averageWordsPerEntry: Int
    let daysJournaled: Int
    let consistencyScore: Double
    let bestWritingDay: String?
    let bestWritingDayWords: Int
    let entriesWithPhotos: Int
}

enum TimeOfDay {
    case morning, afternoon, evening, lateNight

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return .lateNight
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    var greeting: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        case .lateNight: return "late night"
        }
    }
}

//
//  SmartPromptCard.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI

struct SmartPromptCard: View {
    let recentEntries: [JournalEntry]
    let onStartWriting: (String?) -> Void

    @State private var prompt: String?
    @State private var isLoading = false

    private static let fallbackPrompts = [
        "What's something small that brought you joy today?",
        "Describe a moment from today that surprised you.",
        "What's been on your mind the most this week?",
        "Write about a conversation that stuck with you recently.",
        "What would you tell your future self about how you feel right now?",
        "What's one thing you're grateful for that you usually overlook?",
        "Describe the last time you felt truly at peace.",
        "What challenge are you working through right now? How does it feel?",
        "Write about someone who made a difference in your day.",
        "What's a thought you keep coming back to?",
        "How has your mood shifted over the past few days?",
        "What do you need more of in your life right now?",
        "Describe where you are right now -- what do you see, hear, feel?",
        "What's something you've been putting off thinking about?",
        "Write a letter to yourself from one year ago."
    ]

    private var fallbackPrompt: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return Self.fallbackPrompts[dayOfYear % Self.fallbackPrompts.count]
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.yellow.gradient)

                Text("Today's Prompt")
                    .font(.headline)

                Spacer()

                Button {
                    Task { await refreshPrompt() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .disabled(isLoading)
                .accessibilityLabel("Get new prompt")
            }

            Text(prompt ?? fallbackPrompt)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: isLoading ? .placeholder : [])
                .accessibilityAddTraits(.isStaticText)

            Button {
                onStartWriting(prompt ?? fallbackPrompt)
            } label: {
                Text("Start Writing")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Write today's journal entry")
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .task {
            await refreshPrompt()
        }
    }

    private func refreshPrompt() async {
        isLoading = true
        prompt = await AIService.shared.generateJournalPrompt(
            recentEntries: recentEntries,
            currentMood: nil,
            timeOfDay: .current
        )
        isLoading = false
    }
}

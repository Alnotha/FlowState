//
//  JournalChatView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI
import SwiftData

struct JournalChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @FocusState private var isInputFocused: Bool

    private let suggestedQuestions = [
        "When was the last time I felt really happy?",
        "What patterns do you see in my writing?",
        "What have I been stressed about lately?",
        "Summarize my week in a few sentences",
        "What topics come up most in my journal?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                inputBar
            }
            .navigationTitle("Chat with Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)

                VStack(spacing: 8) {
                    Text("Ask Your Journal")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Explore your thoughts and discover patterns in your writing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Try asking:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(suggestedQuestions, id: \.self) { question in
                        Button {
                            sendMessage(question)
                        } label: {
                            HStack {
                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isStreaming {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) {
                withAnimation {
                    if let lastID = messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your journal...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage(inputText) }

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isStreaming ? .gray : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isStreaming = true

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        Task {
            let stream = AIService.shared.chatWithJournal(
                query: trimmed,
                conversationHistory: Array(messages.dropLast()),
                entries: entries
            )

            do {
                for try await chunk in stream {
                    messages[assistantIndex].content += chunk
                }
            } catch {
                if messages[assistantIndex].content.isEmpty {
                    messages[assistantIndex].content = "Sorry, I couldn't process that. Please try again."
                }
            }

            isStreaming = false
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color(.systemBackground))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .onAppear { animating = true }
    }
}

#Preview {
    JournalChatView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}

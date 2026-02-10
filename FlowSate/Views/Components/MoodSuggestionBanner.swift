//
//  MoodSuggestionBanner.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI

struct MoodSuggestionBanner: View {
    let suggestion: MoodSuggestion
    let onAccept: (String) -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var autoDismissTask: Task<Void, Never>?

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

    var body: some View {
        if isVisible {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(moodEmoji(for: suggestion.suggestedMood))
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.reasoning)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isStaticText)

                        Text("Tap to set your mood")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Dismiss suggestion")
                }

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        onAccept(suggestion.suggestedMood)
                    } label: {
                        Text("Yes, that's right")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Accept mood suggestion")

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Text("Not quite")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Dismiss suggestion")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 12, y: -4)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func appear() -> MoodSuggestionBanner {
        var view = self
        view._isVisible = State(initialValue: true)
        return view
    }
}

// MARK: - View Modifier for Easy Integration

struct MoodSuggestionModifier: ViewModifier {
    let suggestion: MoodSuggestion?
    let onAccept: (String) -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if let suggestion {
                    MoodSuggestionBanner(
                        suggestion: suggestion,
                        onAccept: onAccept,
                        onDismiss: onDismiss
                    )
                    .appear()
                }
            }
    }
}

extension View {
    func moodSuggestion(
        _ suggestion: MoodSuggestion?,
        onAccept: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(MoodSuggestionModifier(
            suggestion: suggestion,
            onAccept: onAccept,
            onDismiss: onDismiss
        ))
    }
}

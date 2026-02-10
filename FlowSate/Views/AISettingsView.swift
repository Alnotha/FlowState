//
//  AISettingsView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI
import AuthenticationServices

struct AISettingsView: View {
    @ObservedObject private var aiService = AIService.shared
    @ObservedObject private var authManager = AuthenticationManager.shared

    @State private var workerURL = CloudflareClient.workerURL
    @State private var showingPrivacyInfo = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success, failed(String)
    }

    var body: some View {
        List {
            accountSection
            masterToggleSection
            connectionSection
            featureTogglesSection
            privacySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI Features")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPrivacyInfo) {
            aiPrivacySheet
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            switch authManager.authState {
            case .signedOut:
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            Task { await authManager.handleAppleSignIn(credential: credential) }
                        }
                    case .failure:
                        break
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)

            case .signingIn:
                HStack {
                    ProgressView()
                    Text("Signing in...")
                        .foregroundStyle(.secondary)
                }

            case .signedIn:
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userDisplayName ?? "Apple ID User")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Signed in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign Out", role: .destructive) {
                        authManager.signOut()
                    }
                    .font(.subheadline)
                }

            case .error(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sign-in failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                Task { await authManager.handleAppleSignIn(credential: credential) }
                            }
                        case .failure: break
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                }
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Sign in with Apple to enable AI features. Your journal entries stay private and on-device.")
        }
    }

    // MARK: - Master Toggle

    private var masterToggleSection: some View {
        Section {
            Toggle("Enable AI Features", isOn: $aiService.isEnabled)
                .onChange(of: aiService.isEnabled) { _, newValue in
                    if newValue && workerURL.isEmpty {
                        showingPrivacyInfo = true
                    }
                }
        } header: {
            Text("AI Assistant")
        } footer: {
            Text("AI features use Claude by Anthropic to provide personalized insights, prompts, and mood analysis.")
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Worker URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("https://your-worker.workers.dev", text: $workerURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: workerURL) { _, newValue in
                        CloudflareClient.workerURL = newValue
                    }
            }

            Button {
                testConnection()
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(workerURL.isEmpty)

            if case .failed(let message) = testStatus {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("Enter your Cloudflare Worker URL. Deploy the worker from the cloudflare-worker folder in this project.")
        }
    }

    // MARK: - Feature Toggles

    private var featureTogglesSection: some View {
        Section {
            Toggle(isOn: $aiService.smartPromptsEnabled) {
                Label("Smart Prompts", systemImage: "sparkles")
            }

            Toggle(isOn: $aiService.moodSuggestionEnabled) {
                Label("Mood Suggestions", systemImage: "face.smiling")
            }

            Toggle(isOn: $aiService.weeklyReflectionEnabled) {
                Label("Weekly Reflections", systemImage: "text.quote")
            }

            Toggle(isOn: $aiService.chatEnabled) {
                Label("Journal Chat", systemImage: "bubble.left.and.text.bubble.right")
            }

            Toggle(isOn: $aiService.themeDetectionEnabled) {
                Label("Theme Detection", systemImage: "tag")
            }

            Toggle(isOn: $aiService.nudgesEnabled) {
                Label("Gentle Nudges", systemImage: "heart")
            }
        } header: {
            Text("Features")
        }
        .disabled(!aiService.isEnabled)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            Button {
                showingPrivacyInfo = true
            } label: {
                Label("What data is shared?", systemImage: "lock.shield")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("AI features send journal summaries (not full text) to Anthropic's Claude API through your private proxy. No personal identifiers are ever sent.")
        }
    }

    // MARK: - Privacy Sheet

    private var aiPrivacySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How AI Features Work")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("FlowState's AI features are designed with your privacy in mind.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    privacyRow(
                        icon: "sparkles",
                        title: "Smart Prompts",
                        detail: "Sends mood labels and brief summaries (not full entries) to generate personalized prompts.",
                        sensitivity: "Low"
                    )

                    privacyRow(
                        icon: "face.smiling",
                        title: "Mood Suggestions",
                        detail: "Sends the current entry text for sentiment analysis. Uses on-device analysis first; only calls AI for ambiguous text.",
                        sensitivity: "High"
                    )

                    privacyRow(
                        icon: "text.quote",
                        title: "Weekly Reflections",
                        detail: "Sends mood labels, word counts, and brief summaries to generate weekly insights.",
                        sensitivity: "Low"
                    )

                    privacyRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "Journal Chat",
                        detail: "Sends the first ~100 characters of your last 30 entries for context. Never the full text.",
                        sensitivity: "Medium"
                    )

                    privacyRow(
                        icon: "tag",
                        title: "Theme Detection",
                        detail: "Sends brief excerpts from recent entries to identify recurring topics.",
                        sensitivity: "Medium"
                    )

                    privacyRow(
                        icon: "heart",
                        title: "Gentle Nudges",
                        detail: "Sends only mood labels and streak statistics. No entry content.",
                        sensitivity: "Very Low"
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Safeguards")
                            .font(.headline)

                        bulletPoint("All AI features are off by default")
                        bulletPoint("You control each feature individually")
                        bulletPoint("No personal identifiers are ever sent")
                        bulletPoint("Your proxy means no third-party servers see your data")
                        bulletPoint("Disable anytime to return to fully offline mode")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingPrivacyInfo = false }
                }
            }
        }
    }

    private func privacyRow(icon: String, title: String, detail: String, sensitivity: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(sensitivity)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Test Connection

    private func testConnection() {
        testStatus = .testing
        Task {
            do {
                let _ = try await CloudflareClient.shared.sendMessage(
                    system: "Respond with just the word 'connected'.",
                    messages: [ClaudeMessage(role: "user", content: "test")],
                    model: .haiku,
                    maxTokens: 10,
                    temperature: 0
                )
                testStatus = .success
            } catch {
                testStatus = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}

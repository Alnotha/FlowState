//
//  SettingsView.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var authManager = AuthenticationManager.shared
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @State private var showingExportAlert = false

    var body: some View {
        List {
            accountSection
            notificationsSection
            aiSection
            appearanceSection
            dataSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var accountSection: some View {
        Section {
            if authManager.authState.isSignedIn {
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
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signed in as \(authManager.userDisplayName ?? "Apple ID User")")
            } else {
                NavigationLink {
                    AISettingsView()
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign In")
                                .font(.subheadline)
                            Text("Required for AI features")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Account")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Daily Reminder", isOn: $notificationManager.isEnabled)
                .onChange(of: notificationManager.isEnabled) { _, newValue in
                    if newValue {
                        Task {
                            let granted = await notificationManager.requestPermission()
                            if !granted {
                                notificationManager.isEnabled = false
                            }
                        }
                    }
                }

            if notificationManager.isEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $notificationManager.reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Receive a gentle reminder to journal each day.")
        }
    }

    private var aiSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                Label("AI Features", systemImage: "sparkles")
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text("Personalized prompts, mood suggestions, and insights powered by AI.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Color Scheme", selection: $appColorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        } header: {
            Text("Appearance")
        }
    }

    private var dataSection: some View {
        Section {
            NavigationLink {
                // ExportSheet will be presented from EntryLibraryView
                Text("Use the export button in All Entries to export your journal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } label: {
                Label("Export Entries", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Data")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }

            NavigationLink {
                AboutFlowStateView()
            } label: {
                Label("About FlowState", systemImage: "info.circle")
            }

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(version) (\(build))")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Version \(version), build \(build)")
            }
        }
    }
}

// MARK: - About View

struct AboutFlowStateView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text("FlowState")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("A minimal journaling companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 16) {
                    AboutFeatureRow(icon: "pencil.circle.fill", title: "Daily Journaling", description: "Capture your thoughts, feelings, and memories every day.", color: .blue)
                    AboutFeatureRow(icon: "photo.fill", title: "Photo Memories", description: "Attach photos to bring your entries to life.", color: .green)
                    AboutFeatureRow(icon: "chart.bar.fill", title: "Weekly Insights", description: "Track your journaling streaks and word counts.", color: .orange)
                    AboutFeatureRow(icon: "face.smiling.fill", title: "Mood Tracking", description: "Record how you feel alongside each entry.", color: .purple)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)

                Text("Made with care for mindful reflection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutFeatureRow: View {
    let icon: String
    let title: String
    let description: String
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
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

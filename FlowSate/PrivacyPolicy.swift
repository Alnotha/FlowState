//
//  PrivacyPolicy.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Effective Date: January 2026")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("FlowState is built with your privacy as a core principle. We believe your journal is deeply personal, and your data should belong entirely to you.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                policySection(
                    title: "Data Collection & Storage",
                    content: "All journal entries, mood data, and associated content are stored locally on your device using Apple's SwiftData framework. Your data never leaves your device unless you explicitly enable iCloud sync. We do not collect, transmit, or have access to any of your journal content, personal information, or usage patterns."
                )

                policySection(
                    title: "iCloud Sync",
                    content: "FlowState offers optional iCloud sync to keep your journal entries available across your Apple devices. When enabled, your data is transmitted and stored using Apple's iCloud infrastructure, governed by Apple's own privacy policy. FlowState does not operate any servers or intermediary services for syncing. You can disable iCloud sync at any time."
                )

                policySection(
                    title: "Photos & Attachments",
                    content: "Photos you attach to journal entries are stored locally on your device. They are never uploaded to third-party servers. If iCloud sync is enabled, photo attachments sync through Apple's iCloud infrastructure alongside your journal entries."
                )

                policySection(
                    title: "Analytics & Tracking",
                    content: "FlowState does not include any analytics frameworks, tracking pixels, or usage monitoring of any kind. We do not track how you use the app, what you write, or when you write. Your journaling experience is completely private."
                )

                policySection(
                    title: "Third-Party Services",
                    content: "FlowState does not integrate with third-party advertising, analytics, or tracking services. When AI features are enabled, brief summaries of your journal entries are processed through a secure proxy to Anthropic's Claude AI. See the AI Features section below for details."
                )

                policySection(
                    title: "Data Retention & Deletion",
                    content: "You are in complete control of your data at all times. All journal entries can be deleted from within the app whenever you choose. When you delete an entry, it is permanently removed. Uninstalling FlowState removes all locally stored data from that device."
                )

                policySection(
                    title: "Data Export",
                    content: "FlowState allows you to export your journal entries at any time. Your data is yours, and you should always be able to take it with you."
                )

                policySection(
                    title: "AI Features",
                    content: "FlowState offers optional AI-powered features including smart prompts, mood suggestions, weekly reflections, journal chat, theme detection, and gentle nudges. These features are disabled by default and require explicit opt-in. When enabled, brief summaries of your entries (not full text, except for mood suggestions) are sent to Anthropic's Claude API through your private proxy server. No personal identifiers are ever included. You can disable AI features at any time to return to fully offline mode."
                )

                policySection(
                    title: "Children's Privacy",
                    content: "FlowState does not knowingly collect any personal information from anyone, including children. Since all data remains on your device and we have no access to it, the app is suitable for users of all ages."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("If you have any questions about this privacy policy, please contact us at:")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("support@flowstateapp.com")
                        .font(.body)
                        .foregroundStyle(.blue)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}

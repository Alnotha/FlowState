//
//  FlowSateApp.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FlowSateApp: App {
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @ObservedObject private var authManager = AuthenticationManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JournalEntry.self,
        ])
        // Enable CloudKit sync for iCloud support
        // Note: Requires iCloud capability + CloudKit entitlement in Xcode project settings
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback without CloudKit if entitlement isn't configured
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // Last resort: in-memory only so the app doesn't crash
                do {
                    let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    fatalError("FlowState could not create any data store: \(error.localizedDescription)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(colorScheme)
                .onAppear {
                    setupNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private var colorScheme: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func setupNotifications() {
        let manager = NotificationManager.shared
        if manager.isEnabled {
            manager.scheduleDailyReminder()
        }
    }
}

//
//  NotificationManager.swift
//  FlowSate
//
//  Created by Alyan Tharani on 1/2/26.
//

import Foundation
import Combine
import UserNotifications
import SwiftUI

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    private enum DefaultsKey {
        static let isEnabled = "notificationReminderEnabled"
        static let reminderHour = "notificationReminderHour"
        static let reminderMinute = "notificationReminderMinute"
    }

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.isEnabled)
            if isEnabled {
                scheduleDailyReminder()
            } else {
                cancelReminders()
            }
        }
    }

    @Published var reminderTime: Date {
        didSet {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            UserDefaults.standard.set(components.hour ?? 21, forKey: DefaultsKey.reminderHour)
            UserDefaults.standard.set(components.minute ?? 0, forKey: DefaultsKey.reminderMinute)
            if isEnabled {
                scheduleDailyReminder()
            }
        }
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifier = "com.flowstate.dailyReminder"

    private init() {
        let storedEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.isEnabled)
        let storedHour = UserDefaults.standard.object(forKey: DefaultsKey.reminderHour) as? Int ?? 21
        let storedMinute = UserDefaults.standard.object(forKey: DefaultsKey.reminderMinute) as? Int ?? 0

        self.isEnabled = storedEnabled

        var components = DateComponents()
        components.hour = storedHour
        components.minute = storedMinute
        self.reminderTime = Calendar.current.date(from: components) ?? Date()

        Task { [weak self] in
            await self?.checkPermissionStatus()
        }
    }

    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    func scheduleDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Journal"
        content.body = "Take a moment to reflect on your day in FlowState."
        content.sound = .default

        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error {
                print("NotificationManager: Failed to schedule reminder - \(error.localizedDescription)")
            }
        }
    }

    func cancelReminders() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    func checkPermissionStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}

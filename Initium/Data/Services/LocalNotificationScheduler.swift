import Foundation
import UserNotifications

struct TransitionNotificationDescriptor: Equatable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

struct LocalNotificationScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    static func identifier(for activity: Activity) -> String {
        "initium.transition.\(activity.id.uuidString)"
    }

    static func descriptor(
        for activity: Activity,
        plan: TransitionPlan
    ) -> TransitionNotificationDescriptor {
        let destinationTime = activity.scheduledStartAt.formatted(
            date: .omitted,
            time: .shortened
        )

        return TransitionNotificationDescriptor(
            identifier: identifier(for: activity),
            title: InitiumLocalization.string("notification.transition.title"),
            body: InitiumLocalization.string("notification.transition.body", activity.title, destinationTime),
            fireDate: plan.transitionStart
        )
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional
    }

    func schedule(
        for activity: Activity,
        plan: TransitionPlan,
        now: Date = .now
    ) async throws {
        let descriptor = Self.descriptor(for: activity, plan: plan)
        center.removePendingNotificationRequests(withIdentifiers: [descriptor.identifier])

        guard descriptor.fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = descriptor.title
        content.body = descriptor.body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: descriptor.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: descriptor.identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func remove(for activity: Activity) {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: activity)]
        )
    }

    static func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

enum NotificationPermissionTracker {
    private static let offeredKey = "initium.notificationPermissionPromptOffered"

    static var shouldOffer: Bool {
        !UserDefaults.standard.bool(forKey: offeredKey)
    }

    static func markOffered() {
        UserDefaults.standard.set(true, forKey: offeredKey)
    }
}

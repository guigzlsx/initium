import Foundation
import SwiftData

struct CalendarSyncResult: Equatable {
    let importedCount: Int
    let updatedCount: Int
    let removedCount: Int

    static let empty = CalendarSyncResult(importedCount: 0, updatedCount: 0, removedCount: 0)
}

@MainActor
struct CalendarSyncService {
    let provider: any CalendarEventProvider
    let preferences: CalendarPreferencesStore
    let notificationScheduler: LocalNotificationScheduler?

    init(
        provider: (any CalendarEventProvider)? = nil,
        preferences: CalendarPreferencesStore = CalendarPreferencesStore(),
        notificationScheduler: LocalNotificationScheduler? = LocalNotificationScheduler()
    ) {
        self.provider = provider ?? EventKitCalendarProvider()
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
    }

    func sync(
        in context: ModelContext,
        now: Date = .now
    ) async throws -> CalendarSyncResult {
        guard provider.authorizationStatus() == .fullAccess,
              preferences.isEnabled else {
            return .empty
        }

        let selectedIdentifiers = preferences.selectedCalendarIdentifiers
        guard !selectedIdentifiers.isEmpty else {
            return .empty
        }

        let window = synchronizationWindow(around: now)
        let descriptors = try await provider.fetchEvents(
            calendarIdentifiers: selectedIdentifiers,
            startDate: window.start,
            endDate: window.end
        )

        let activities = try context.fetch(FetchDescriptor<Activity>())
        var byExternalIdentifier: [String: Activity] = [:]
        for activity in activities {
            if let identifier = activity.externalEventIdentifier {
                byExternalIdentifier[identifier] = activity
            }
        }
        let importedIdentifiers = Set(descriptors.map(\.id))
        var importedCount = 0
        var updatedCount = 0

        for descriptor in descriptors {
            if let activity = byExternalIdentifier[descriptor.id] {
                apply(descriptor, to: activity)
                updatedCount += 1
            } else {
                let activity = makeActivity(from: descriptor)
                context.insert(activity)
                byExternalIdentifier[descriptor.id] = activity
                importedCount += 1
            }
        }

        var removedCount = 0
        for activity in activities where shouldInspectForRemoval(activity, selectedIdentifiers: selectedIdentifiers, window: window) {
            guard let identifier = activity.externalEventIdentifier,
                  !importedIdentifiers.contains(identifier) else {
                continue
            }

            if hasHistory(activity) {
                activity.isExternallyDeleted = true
                notificationScheduler?.remove(for: activity)
            } else {
                notificationScheduler?.remove(for: activity)
                context.delete(activity)
            }
            removedCount += 1
        }

        try context.save()

        for descriptor in descriptors {
            if let activity = byExternalIdentifier[descriptor.id] {
                await refreshNotification(for: activity, now: now)
            }
        }

        return CalendarSyncResult(
            importedCount: importedCount,
            updatedCount: updatedCount,
            removedCount: removedCount
        )
    }

    func removeExternalActivities(
        for calendarIdentifiers: Set<String>,
        in context: ModelContext
    ) throws -> Int {
        let activities = try context.fetch(FetchDescriptor<Activity>())
        var removedCount = 0

        for activity in activities where
            activity.sourceType == .calendar &&
            calendarIdentifiers.contains(activity.externalCalendarIdentifier ?? "") {
            notificationScheduler?.remove(for: activity)
            if hasHistory(activity) {
                activity.isExternallyDeleted = true
            } else {
                context.delete(activity)
            }
            removedCount += 1
        }

        try context.save()
        return removedCount
    }

    private func synchronizationWindow(around date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let end = calendar.date(byAdding: .day, value: 30, to: date) ?? date
        return (start, end)
    }

    private func makeActivity(from descriptor: CalendarEventDescriptor) -> Activity {
        let duration = descriptor.isAllDay
            ? 0
            : max(60, Int(descriptor.endDate.timeIntervalSince(descriptor.startDate).rounded()))
        let activity = Activity(
            title: descriptor.title,
            scheduledStartAt: descriptor.startDate,
            estimatedDurationSeconds: duration,
            isFixedTime: true,
            sourceType: .calendar
        )
        activity.originalScheduledStartAt = descriptor.startDate
        apply(descriptor, to: activity)
        return activity
    }

    private func apply(_ descriptor: CalendarEventDescriptor, to activity: Activity) {
        let duration = descriptor.isAllDay
            ? 0
            : max(60, Int(descriptor.endDate.timeIntervalSince(descriptor.startDate).rounded()))
        activity.title = descriptor.title
        activity.scheduledStartAt = descriptor.startDate
        activity.estimatedDurationSeconds = duration
        activity.isFixedTime = true
        activity.sourceType = .calendar
        activity.externalEventIdentifier = descriptor.id
        activity.externalCalendarIdentifier = descriptor.calendarIdentifier
        activity.externalLastModifiedAt = descriptor.lastModifiedAt
        activity.externalIsAllDay = descriptor.isAllDay
        activity.externalLocation = descriptor.location
        activity.externalNotes = descriptor.notes
        activity.isExternallyDeleted = false
    }

    private func shouldInspectForRemoval(
        _ activity: Activity,
        selectedIdentifiers: Set<String>,
        window: (start: Date, end: Date)
    ) -> Bool {
        activity.sourceType == .calendar &&
            selectedIdentifiers.contains(activity.externalCalendarIdentifier ?? "") &&
            activity.scheduledStartAt >= window.start &&
            activity.scheduledStartAt <= window.end
    }

    private func hasHistory(_ activity: Activity) -> Bool {
        activity.completedAt != nil ||
            activity.sessions.contains { $0.endedAt != nil } ||
            activity.routineSessions.contains { $0.endedAt != nil }
    }

    private func refreshNotification(for activity: Activity, now: Date) async {
        guard let notificationScheduler else { return }

        let isTerminal: Bool = switch activity.status {
        case .completed, .skipped, .cancelled, .postponed: true
        case .planned, .inProgress, .paused: false
        }

        guard !activity.externalIsAllDay,
              !activity.isExternallyDeleted,
              !isTerminal,
              let plan = TransitionPlanner().makePlan(for: activity),
              await notificationScheduler.isAuthorized() else {
            notificationScheduler.remove(for: activity)
            return
        }

        try? await notificationScheduler.schedule(for: activity, plan: plan, now: now)
    }
}

@MainActor
final class CalendarSyncCoordinator: ObservableObject {
    @Published private(set) var state: CalendarSyncState = .idle
    @Published private(set) var lastResult: CalendarSyncResult?
    @Published private(set) var errorMessage: String?

    private var isSyncing = false

    func syncIfNeeded(in context: ModelContext) async {
        guard !isSyncing else { return }
        let preferences = CalendarPreferencesStore()
        guard preferences.isEnabled else { return }

        isSyncing = true
        state = .syncing
        errorMessage = nil
        defer { isSyncing = false }

        do {
            let result = try await CalendarSyncService().sync(in: context)
            lastResult = result
            state = .succeeded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}

enum CalendarSyncState: Equatable {
    case idle
    case syncing
    case succeeded
    case failed
}

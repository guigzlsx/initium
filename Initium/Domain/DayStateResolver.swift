import Foundation

struct DayStateResolver {
    func currentActivity(from activities: [Activity], now: Date) -> Activity? {
        let orderedActivities = activities.sorted {
            $0.scheduledStartAt < $1.scheduledStartAt
        }

        if let explicitlyActive = orderedActivities.first(where: {
            !$0.externalIsAllDay &&
            !$0.isExternallyDeleted &&
            ($0.status == .inProgress || $0.status == .paused)
        }) {
            return explicitlyActive
        }

        return orderedActivities.first(where: { activity in
            !isTerminal(activity.status) &&
            !activity.externalIsAllDay &&
            !activity.isExternallyDeleted &&
            activity.status == .planned &&
            activity.scheduledStartAt <= now
        })
    }

    func nextActivity(from activities: [Activity], now: Date) -> Activity? {
        activities
            .filter {
                !isTerminal($0.status) &&
                !$0.externalIsAllDay &&
                !$0.isExternallyDeleted &&
                $0.scheduledStartAt > now
            }
            .sorted { $0.scheduledStartAt < $1.scheduledStartAt }
            .first
    }

    private func isTerminal(_ status: ActivityStatus) -> Bool {
        switch status {
        case .completed, .skipped, .cancelled, .postponed:
            return true
        case .planned, .inProgress, .paused:
            return false
        }
    }
}

import Foundation

struct ActivityTiming {
    /// Source of truth for execution time. It deliberately derives the value
    /// from persisted sessions so it remains correct after backgrounding or a
    /// relaunch.
    static func totalExecutionDuration(for activity: Activity, now: Date) -> TimeInterval {
        activity.sessions.reduce(0) { total, session in
            guard session.startedAt <= (session.endedAt ?? now) else {
                return total
            }

            if let endedAt = session.endedAt {
                guard endedAt >= session.startedAt else { return total }
                let measuredDuration = endedAt.timeIntervalSince(session.startedAt)
                let storedDuration = TimeInterval(max(0, session.actualDurationSeconds))
                return total + max(storedDuration, measuredDuration)
            }

            return total + max(0, now.timeIntervalSince(session.startedAt))
        }
    }

    static func elapsedSeconds(for activity: Activity, at date: Date) -> Int {
        Int(totalExecutionDuration(for: activity, now: date).rounded(.down))
    }

    static func remainingSeconds(for activity: Activity, at date: Date) -> Int? {
        guard activity.status == .inProgress || activity.status == .paused else {
            return nil
        }

        let elapsed = elapsedSeconds(for: activity, at: date)
        return max(0, activity.estimatedDurationSeconds - elapsed)
    }

    static func durationText(seconds: Int) -> String {
        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        return InitiumLocalization.string("duration.minutes", minutes)
    }

    static func remainingText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 {
            return remainingSeconds == 0
                ? InitiumLocalization.string("duration.minutes.remaining", minutes)
                : InitiumLocalization.string("duration.minutes.seconds.remaining", minutes, remainingSeconds)
        }

        return InitiumLocalization.string("duration.seconds.remaining", remainingSeconds)
    }
}

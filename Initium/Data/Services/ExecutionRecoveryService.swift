import Foundation
import SwiftData

enum ExecutionRecoveryAction {
    case continueActivity
    case completeActivity
    case pauseActivity
}

@MainActor
struct ExecutionRecoveryService {
    private let executionService = ActivityExecutionService()

    func recover(
        activity: Activity,
        using action: ExecutionRecoveryAction,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        switch action {
        case .continueActivity:
            try executionService.start(activity: activity, at: date, in: context)
        case .completeActivity:
            try executionService.complete(activity: activity, at: date, in: context)
        case .pauseActivity:
            _ = closeActiveSession(for: activity, at: date)
            activity.status = .paused
            activity.actualDurationSeconds = ActivityTiming.elapsedSeconds(for: activity, at: date)
            try context.save()
        }
    }

    private func closeActiveSession(for activity: Activity, at date: Date) -> Bool {
        guard let session = activity.sessions
            .filter({ $0.endedAt == nil })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first else {
            return false
        }

        session.endedAt = max(date, session.startedAt)
        session.actualDurationSeconds = max(0, Int(session.endedAt!.timeIntervalSince(session.startedAt)))
        return true
    }
}

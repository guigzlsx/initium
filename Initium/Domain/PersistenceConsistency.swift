import Foundation

enum PersistenceConsistencyIssue: Equatable {
    case completedActivityHasActiveSession
    case inProgressActivityHasNoActiveSession
    case pausedActivityHasNoRecordedSession
    case multipleActiveTransitionSessions
    case invalidRoutineStepIndex
}

struct PersistenceConsistencyValidator {
    func issues(for activity: Activity) -> [PersistenceConsistencyIssue] {
        var issues: [PersistenceConsistencyIssue] = []
        let activeActivitySessions = activity.sessions.filter { $0.endedAt == nil }
        let activeTransitionSessions = activity.routineSessions.filter {
            $0.kind == .transition && $0.status == .active
        }

        if activity.status == .completed, !activeActivitySessions.isEmpty {
            issues.append(.completedActivityHasActiveSession)
        }

        if activity.status == .inProgress, activeActivitySessions.isEmpty {
            issues.append(.inProgressActivityHasNoActiveSession)
        }

        if activity.status == .paused,
           activity.sessions.isEmpty,
           activity.routineSessions.isEmpty {
            issues.append(.pausedActivityHasNoRecordedSession)
        }

        if activeTransitionSessions.count > 1 {
            issues.append(.multipleActiveTransitionSessions)
        }

        if let routine = activity.routine {
            let stepCount = routine.orderedSteps.count
            if activity.routineSessions.contains(where: {
                $0.currentStepIndex < 0 || $0.currentStepIndex > stepCount
            }) {
                issues.append(.invalidRoutineStepIndex)
            }
        }

        return issues
    }
}

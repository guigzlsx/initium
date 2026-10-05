import Foundation

enum TransitionState: Equatable {
    case none
    case upcoming
    case ready
    case active
    case completed
    case missed
}

struct TransitionPlan: Equatable {
    let transitionStart: Date
    let routineDurationSeconds: Int
    let transitionMarginSeconds: Int
}

struct TransitionPlanner {
    private let durationEstimator: DurationEstimator

    init(durationEstimator: DurationEstimator = DurationEstimator()) {
        self.durationEstimator = durationEstimator
    }

    /// Pure calculation kept for unit tests and for callers that already have
    /// duration samples available.
    func makePlan(
        scheduledStart: Date,
        estimatedRoutineDurationSeconds: Int,
        transitionMarginSeconds: Int,
        samples: [DurationSample]
    ) -> TransitionPlan {
        let routineDuration = durationEstimator.recommendedDuration(
            estimatedDurationSeconds: estimatedRoutineDurationSeconds,
            samples: samples
        )

        let transitionStart = scheduledStart.addingTimeInterval(
            -TimeInterval(routineDuration + max(0, transitionMarginSeconds))
        )

        return TransitionPlan(
            transitionStart: transitionStart,
            routineDurationSeconds: routineDuration,
            transitionMarginSeconds: max(0, transitionMarginSeconds)
        )
    }

    func makePlan(for activity: Activity) -> TransitionPlan? {
        guard let routine = activity.routine,
              !routine.orderedSteps.isEmpty else {
            return nil
        }

        let samples = routine.sessions
            .filter {
                $0.kind == .transition &&
                $0.status == .completed &&
                $0.actualDurationSeconds > 0
            }
            .map {
                DurationSample(
                    durationSeconds: $0.actualDurationSeconds,
                    isComplete: true
                )
            }

        return makePlan(
            scheduledStart: activity.scheduledStartAt,
            estimatedRoutineDurationSeconds: routine.estimatedDurationSeconds,
            transitionMarginSeconds: activity.transitionMarginSeconds,
            samples: samples
        )
    }

    func state(for activity: Activity, now: Date) -> TransitionState {
        guard let plan = makePlan(for: activity) else { return .none }

        let sessions = activity.routineSessions
            .filter { $0.kind == .transition }
            .sorted { $0.startedAt > $1.startedAt }

        if sessions.contains(where: { $0.status == .active }) {
            return .active
        }

        if sessions.contains(where: { $0.status == .completed }) {
            return .completed
        }

        switch activity.status {
        case .cancelled, .skipped, .postponed:
            return .none
        case .completed:
            return .none
        case .planned, .paused, .inProgress:
            if now < plan.transitionStart {
                return .upcoming
            }

            if now < activity.scheduledStartAt {
                return .ready
            }

            return .missed
        }
    }

    func isTransitionActive(for activity: Activity) -> Bool {
        activity.routineSessions.contains {
            $0.kind == .transition && $0.status == .active
        }
    }
}

import Foundation
import SwiftData

enum StopActivityResolution: Equatable {
    case complete
    case postpone
    case skip
    case cancel
}

struct ActivityCompletionSummary: Identifiable {
    let id = UUID()
    let title: String
    let estimatedDurationSeconds: Int
    let actualDurationSeconds: Int
}

struct NowStartConflict: Identifiable {
    let id = UUID()
    let pendingActivity: Activity
    let activeActivityTitle: String
}

struct TransitionCompletionSummary: Identifiable {
    let id = UUID()
    let activityID: UUID
    let title: String
    let scheduledStartAt: Date
    let actualDurationSeconds: Int
    let endedAt: Date

    var minutesDifference: Int {
        Int(scheduledStartAt.timeIntervalSince(endedAt) / 60)
    }
}

@MainActor
final class NowViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var completionSummary: ActivityCompletionSummary?
    @Published var transitionCompletionSummary: TransitionCompletionSummary?
    @Published var startConflict: NowStartConflict?

    let executionService: ActivityExecutionService
    let transitionService: TransitionExecutionService
    let transitionPlanner: TransitionPlanner

    init(
        executionService: ActivityExecutionService = ActivityExecutionService(),
        transitionService: TransitionExecutionService = TransitionExecutionService(),
        transitionPlanner: TransitionPlanner = TransitionPlanner()
    ) {
        self.executionService = executionService
        self.transitionService = transitionService
        self.transitionPlanner = transitionPlanner
    }

    func requestStart(activity: Activity, at date: Date, in context: ModelContext) {
        do {
            try executionService.start(activity: activity, at: date, in: context)
        } catch let error as ActivityExecutionError {
            if case let .anotherActivityIsActive(title) = error {
                startConflict = NowStartConflict(
                    pendingActivity: activity,
                    activeActivityTitle: title
                )
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveStartConflict(
        with resolution: StartConflictResolution,
        at date: Date,
        in context: ModelContext
    ) {
        guard let conflict = startConflict else { return }

        do {
            if let activeActivity = try executionService.activeActivity(in: context) {
                switch resolution {
                case .pauseAndStart:
                    try executionService.pause(activity: activeActivity, at: date, in: context)
                case .completeAndStart:
                    try executionService.complete(activity: activeActivity, at: date, in: context)
                }
            }

            try executionService.start(activity: conflict.pendingActivity, at: date, in: context)
            startConflict = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause(activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try executionService.pause(activity: activity, at: date, in: context)
        }
    }

    func resume(activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try executionService.resume(activity: activity, at: date, in: context)
        }
    }

    func complete(activity: Activity, at date: Date, in context: ModelContext) {
        let estimatedDuration = activity.estimatedDurationSeconds
        perform {
            try executionService.complete(activity: activity, at: date, in: context)
            LocalNotificationScheduler().remove(for: activity)
            completionSummary = ActivityCompletionSummary(
                title: activity.title,
                estimatedDurationSeconds: estimatedDuration,
                actualDurationSeconds: activity.actualDurationSeconds
            )
        }
    }

    func stop(activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try executionService.stop(activity: activity, at: date, in: context)
        }
    }

    func resolveStop(
        _ resolution: StopActivityResolution,
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) {
        guard resolution != .cancel else { return }

        perform {
            switch resolution {
            case .complete:
                let estimatedDuration = activity.estimatedDurationSeconds
                try executionService.complete(activity: activity, at: date, in: context)
                LocalNotificationScheduler().remove(for: activity)
                completionSummary = ActivityCompletionSummary(
                    title: activity.title,
                    estimatedDurationSeconds: estimatedDuration,
                    actualDurationSeconds: activity.actualDurationSeconds
                )
            case .postpone:
                try executionService.postpone(activity: activity, at: date, in: context)
                LocalNotificationScheduler().remove(for: activity)
            case .skip:
                try executionService.skip(activity: activity, at: date, in: context)
                LocalNotificationScheduler().remove(for: activity)
            case .cancel:
                break
            }
        }
    }

    func addFiveMinutes(to activity: Activity, in context: ModelContext) {
        perform {
            try executionService.addTime(to: activity, seconds: 300, in: context)
        }
    }

    func completeCurrentStep(for activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try executionService.completeCurrentRoutineStep(for: activity, at: date, in: context)
        }
    }

    func skipCurrentStep(for activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try executionService.skipCurrentRoutineStep(for: activity, at: date, in: context)
        }
    }

    func startTransition(for activity: Activity, at date: Date, in context: ModelContext) {
        perform {
            try transitionService.start(activity: activity, at: date, in: context)
        }
    }

    func completeTransitionStep(
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) {
        do {
            let didComplete = try transitionService.completeCurrentStep(
                for: activity,
                at: date,
                in: context
            )

            if didComplete {
                LocalNotificationScheduler().remove(for: activity)
                transitionCompletionSummary = makeTransitionSummary(
                    for: activity,
                    endedAt: date
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipTransitionStep(
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) {
        do {
            let didComplete = try transitionService.skipCurrentStep(
                for: activity,
                at: date,
                in: context
            )

            if didComplete {
                LocalNotificationScheduler().remove(for: activity)
                transitionCompletionSummary = makeTransitionSummary(
                    for: activity,
                    endedAt: date
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startActivityAfterTransition(
        _ activity: Activity,
        at date: Date,
        in context: ModelContext
    ) {
        perform {
            try executionService.start(activity: activity, at: date, in: context)
        }
    }

    func routineState(for activity: Activity) -> RoutineExecutionState? {
        executionService.routineState(for: activity)
    }

    func transitionState(for activity: Activity) -> RoutineExecutionState? {
        transitionService.state(for: activity)
    }

    func transitionStatus(for activity: Activity, at date: Date) -> TransitionState {
        transitionPlanner.state(for: activity, now: date)
    }

    func transitionPlan(for activity: Activity) -> TransitionPlan? {
        transitionPlanner.makePlan(for: activity)
    }

    private func makeTransitionSummary(
        for activity: Activity,
        endedAt: Date
    ) -> TransitionCompletionSummary {
        let session = activity.routineSessions
            .filter {
                $0.kind == .transition &&
                $0.status == .completed
            }
            .sorted { $0.startedAt > $1.startedAt }
            .first

        return TransitionCompletionSummary(
            activityID: activity.id,
            title: activity.title,
            scheduledStartAt: activity.scheduledStartAt,
            actualDurationSeconds: session?.actualDurationSeconds ?? 0,
            endedAt: endedAt
        )
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

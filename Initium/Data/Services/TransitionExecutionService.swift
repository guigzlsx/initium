import Foundation
import SwiftData

enum TransitionExecutionError: LocalizedError, Equatable {
    case noRoutine
    case noActiveSession
    case noStepAvailable
    case anotherTransitionIsActive(title: String)

    var errorDescription: String? {
        switch self {
        case .noRoutine:
            return InitiumLocalization.string("error.transition.no_routine")
        case .noActiveSession:
            return InitiumLocalization.string("error.transition.no_active_session")
        case .noStepAvailable:
            return InitiumLocalization.string("error.transition.no_step")
        case let .anotherTransitionIsActive(title):
            return InitiumLocalization.string("error.transition.active", title)
        }
    }
}

struct TransitionExecutionService {
    private let executionService = ActivityExecutionService()

    @MainActor
    func start(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard let routine = activity.routine,
              !routine.orderedSteps.isEmpty else {
            throw TransitionExecutionError.noRoutine
        }

        if activeSession(for: activity) != nil {
            return
        }

        if let otherActivity = try activeTransitionActivity(in: context, excluding: activity) {
            throw TransitionExecutionError.anotherTransitionIsActive(title: otherActivity.title)
        }

        let session = RoutineSession(
            startedAt: date,
            currentStepIndex: 0,
            completedStepCount: 0,
            status: .active,
            kind: .transition
        )
        session.routine = routine
        session.activity = activity
        context.insert(session)
        try context.save()
    }

    @MainActor
    func completeCurrentStep(
        for activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws -> Bool {
        try advanceCurrentStep(for: activity, at: date, in: context)
    }

    @MainActor
    func skipCurrentStep(
        for activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws -> Bool {
        try advanceCurrentStep(for: activity, at: date, in: context)
    }

    @MainActor
    func complete(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard let session = activeSession(for: activity) else {
            throw TransitionExecutionError.noActiveSession
        }

        finish(session: session, at: date)
        try context.save()
    }

    @MainActor
    func activeSession(for activity: Activity) -> RoutineSession? {
        activity.routineSessions
            .filter { $0.kind == .transition && $0.status == .active }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    func state(for activity: Activity) -> RoutineExecutionState? {
        executionService.routineState(for: activity, kind: .transition)
    }

    @MainActor
    func activeTransitionActivity(
        in context: ModelContext,
        excluding excludedActivity: Activity? = nil
    ) throws -> Activity? {
        let sessions = try context.fetch(FetchDescriptor<RoutineSession>())
        return sessions
            .filter {
                $0.kind == .transition &&
                $0.status == .active &&
                $0.activity?.id != excludedActivity?.id
            }
            .sorted { $0.startedAt < $1.startedAt }
            .first?.activity
    }

    @MainActor
    private func advanceCurrentStep(
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) throws -> Bool {
        guard let routine = activity.routine,
              let session = activeSession(for: activity) else {
            throw TransitionExecutionError.noActiveSession
        }

        let stepCount = routine.orderedSteps.count
        guard session.currentStepIndex < stepCount else {
            throw TransitionExecutionError.noStepAvailable
        }

        session.currentStepIndex += 1
        session.completedStepCount = min(session.completedStepCount + 1, stepCount)

        let didComplete = session.currentStepIndex >= stepCount
        if didComplete {
            finish(session: session, at: date)
        }

        try context.save()
        return didComplete
    }

    private func finish(session: RoutineSession, at date: Date) {
        session.status = .completed
        session.endedAt = max(date, session.startedAt)
        session.actualDurationSeconds = max(
            0,
            Int(session.endedAt!.timeIntervalSince(session.startedAt))
        )
    }
}

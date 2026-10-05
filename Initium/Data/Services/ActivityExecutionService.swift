import Foundation
import SwiftData

enum ActivityExecutionError: LocalizedError, Equatable {
    case anotherActivityIsActive(title: String)
    case noActiveSession
    case noRoutineStepAvailable

    var errorDescription: String? {
        switch self {
        case let .anotherActivityIsActive(title):
            return InitiumLocalization.string("error.activity.active", title)
        case .noActiveSession:
            return InitiumLocalization.string("error.activity.no_active_session")
        case .noRoutineStepAvailable:
            return InitiumLocalization.string("error.routine.no_step")
        }
    }
}

enum StartConflictResolution {
    case pauseAndStart
    case completeAndStart
}

struct RoutineExecutionState {
    let session: RoutineSession?
    let currentStepIndex: Int
    let completedStepCount: Int
    let totalStepCount: Int
    let currentStep: RoutineStep?
    let isFinished: Bool

    var progressText: String {
        "\(min(completedStepCount, totalStepCount)) / \(totalStepCount)"
    }
}

struct ActivityExecutionService {
    @MainActor
    func start(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard activity.status != .completed,
              activity.status != .skipped,
              activity.status != .cancelled else {
            return
        }

        if activity.status == .inProgress,
           activity.sessions.contains(where: { $0.endedAt == nil }) {
            return
        }

        if let activeActivity = try activeActivity(in: context, excluding: activity) {
            throw ActivityExecutionError.anotherActivityIsActive(title: activeActivity.title)
        }

        let session = ActivitySession(startedAt: date)
        session.activity = activity
        context.insert(session)

        activity.status = .inProgress
        activity.completedAt = nil
        preserveOriginalStartIfNeeded(for: activity)
        startOrResumeRoutine(for: activity, at: date, in: context)

        try context.save()
    }

    @MainActor
    func pause(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard activity.status == .inProgress else { return }

        guard closeActiveActivitySession(for: activity, at: date) else {
            throw ActivityExecutionError.noActiveSession
        }

        closeActiveRoutineSession(for: activity, at: date, status: .abandoned)
        activity.status = .paused
        updateCachedDuration(for: activity, at: date)
        try context.save()
    }

    @MainActor
    func resume(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard activity.status == .paused else {
            try start(activity: activity, at: date, in: context)
            return
        }

        try start(activity: activity, at: date, in: context)
    }

    @MainActor
    func complete(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        _ = closeActiveActivitySession(for: activity, at: date)
        closeActiveRoutineSession(for: activity, at: date, status: .completed)

        activity.status = .completed
        activity.completedAt = date
        updateCachedDuration(for: activity, at: date)
        try context.save()
    }

    /// Stops tracking the current segment without treating the activity as a
    /// failure. The caller can then choose to complete, postpone or skip it.
    @MainActor
    func stop(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        _ = closeActiveActivitySession(for: activity, at: date)
        closeActiveRoutineSession(for: activity, at: date, status: .abandoned)

        activity.status = .paused
        updateCachedDuration(for: activity, at: date)
        try context.save()
    }

    @MainActor
    func postpone(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        _ = closeActiveActivitySession(for: activity, at: date)
        closeActiveRoutineSession(for: activity, at: date, status: .abandoned)

        activity.status = .postponed
        updateCachedDuration(for: activity, at: date)
        try context.save()
    }

    @MainActor
    func skip(
        activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        _ = closeActiveActivitySession(for: activity, at: date)
        closeActiveRoutineSession(for: activity, at: date, status: .abandoned)

        activity.status = .skipped
        updateCachedDuration(for: activity, at: date)
        try context.save()
    }

    @MainActor
    func addTime(
        to activity: Activity,
        seconds: Int = 300,
        in context: ModelContext
    ) throws {
        activity.estimatedDurationSeconds += max(0, seconds)
        try context.save()
    }

    @MainActor
    func completeCurrentRoutineStep(
        for activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        try advanceRoutine(for: activity, at: date, in: context)
    }

    @MainActor
    func skipCurrentRoutineStep(
        for activity: Activity,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        try advanceRoutine(for: activity, at: date, in: context)
    }

    @MainActor
    func activeActivity(
        in context: ModelContext,
        excluding excludedActivity: Activity? = nil
    ) throws -> Activity? {
        let activities = try context.fetch(FetchDescriptor<Activity>())
        return activities.first {
            $0.status == .inProgress && $0.id != excludedActivity?.id
        }
    }

    func totalExecutionDuration(for activity: Activity, now: Date = .now) -> TimeInterval {
        ActivityTiming.totalExecutionDuration(for: activity, now: now)
    }

    func routineState(
        for activity: Activity,
        kind: RoutineSessionKind = .activityExecution
    ) -> RoutineExecutionState? {
        guard let routine = activity.routine else { return nil }

        let steps = routine.orderedSteps
        let session = activity.routineSessions
            .filter { $0.kind == kind }
            .sorted { $0.startedAt > $1.startedAt }
            .first
        let currentStepIndex = min(max(session?.currentStepIndex ?? 0, 0), steps.count)
        let completedStepCount = min(max(session?.completedStepCount ?? 0, 0), steps.count)

        return RoutineExecutionState(
            session: session,
            currentStepIndex: currentStepIndex,
            completedStepCount: completedStepCount,
            totalStepCount: steps.count,
            currentStep: currentStepIndex < steps.count ? steps[currentStepIndex] : nil,
            isFinished: steps.isEmpty || currentStepIndex >= steps.count
        )
    }

    @MainActor
    private func advanceRoutine(
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) throws {
        guard let routine = activity.routine,
              let session = activity.routineSessions
                .filter({ $0.status == .active && $0.kind == .activityExecution })
                .sorted(by: { $0.startedAt > $1.startedAt })
                .first else {
            throw ActivityExecutionError.noRoutineStepAvailable
        }

        let stepCount = routine.orderedSteps.count
        guard session.currentStepIndex < stepCount else {
            throw ActivityExecutionError.noRoutineStepAvailable
        }

        session.currentStepIndex += 1
        session.completedStepCount = min(session.completedStepCount + 1, stepCount)

        if session.currentStepIndex >= stepCount {
            session.status = .completed
            session.endedAt = date
            session.actualDurationSeconds = max(0, Int(date.timeIntervalSince(session.startedAt)))
        }

        try context.save()
    }

    @MainActor
    private func startOrResumeRoutine(
        for activity: Activity,
        at date: Date,
        in context: ModelContext
    ) {
        guard let routine = activity.routine,
              !routine.orderedSteps.isEmpty,
              activity.routineSessions.first(where: {
                  $0.status == .active && $0.kind == .activityExecution
              }) == nil else {
            return
        }

        let latest = activity.routineSessions
            .filter { $0.kind == .activityExecution }
            .sorted { $0.startedAt > $1.startedAt }
            .first
        let session = RoutineSession(
            startedAt: date,
            currentStepIndex: latest?.currentStepIndex ?? 0,
            completedStepCount: latest?.completedStepCount ?? 0,
            status: .active,
            kind: .activityExecution
        )
        session.routine = routine
        session.activity = activity
        context.insert(session)
    }

    @MainActor
    private func closeActiveActivitySession(for activity: Activity, at date: Date) -> Bool {
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

    @MainActor
    private func closeActiveRoutineSession(
        for activity: Activity,
        at date: Date,
        status: RoutineSessionStatus
    ) {
        guard let session = activity.routineSessions
            .filter({ $0.status == .active && $0.kind == .activityExecution })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first else {
            return
        }

        session.endedAt = max(date, session.startedAt)
        session.actualDurationSeconds = max(0, Int(session.endedAt!.timeIntervalSince(session.startedAt)))
        session.status = status
    }

    private func preserveOriginalStartIfNeeded(for activity: Activity) {
        if activity.originalScheduledStartAt == nil {
            activity.originalScheduledStartAt = activity.scheduledStartAt
        }
    }

    private func updateCachedDuration(for activity: Activity, at date: Date) {
        activity.actualDurationSeconds = Int(totalExecutionDuration(for: activity, now: date).rounded(.down))
    }
}

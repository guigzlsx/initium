import XCTest
import SwiftData
@testable import Initium

@MainActor
final class TransitionStateTests: XCTestCase {
    private let planner = TransitionPlanner()

    func testActivityWithoutRoutineHasNoTransition() throws {
        let (container, activity) = try makeActivity()
        _ = container
        activity.routine = nil

        XCTAssertEqual(planner.state(for: activity, now: .now), .none)
        XCTAssertNil(planner.makePlan(for: activity))
    }

    func testTransitionIsUpcomingBeforeComputedStart() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        _ = container

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 400)),
            .upcoming
        )
    }

    func testTransitionIsReadyBetweenTransitionAndActivityStart() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        _ = container

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 1_200)),
            .ready
        )
    }

    func testTransitionIsMissedAfterActivityStartWithoutSession() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        _ = container

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 2_001)),
            .missed
        )
    }

    func testTransitionIsActiveWhenRoutineSessionIsActive() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        let context = container.mainContext
        let session = RoutineSession(
            startedAt: Date(timeIntervalSince1970: 1_200),
            status: .active,
            kind: .transition
        )
        session.activity = activity
        session.routine = activity.routine
        context.insert(session)
        try context.save()

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 1_500)),
            .active
        )
    }

    func testTransitionIsCompletedWhenRoutineSessionIsCompleted() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        let context = container.mainContext
        let session = RoutineSession(
            startedAt: Date(timeIntervalSince1970: 1_200),
            endedAt: Date(timeIntervalSince1970: 1_800),
            actualDurationSeconds: 600,
            currentStepIndex: 1,
            completedStepCount: 1,
            status: .completed,
            kind: .transition
        )
        session.activity = activity
        session.routine = activity.routine
        context.insert(session)
        try context.save()

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 2_100)),
            .completed
        )
    }

    func testTerminalCancelledActivityHasNoTransition() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        _ = container
        activity.status = .cancelled

        XCTAssertEqual(
            planner.state(for: activity, now: Date(timeIntervalSince1970: 1_500)),
            .none
        )
    }

    func testActivityPlanUsesAverageOfAtLeastThreeTransitionSessions() throws {
        let (container, activity) = try makeActivity(start: 2_000)
        let context = container.mainContext
        let durations = [1_500, 1_200, 1_800, 1_650]

        for (index, duration) in durations.enumerated() {
            let session = RoutineSession(
                startedAt: Date(timeIntervalSince1970: TimeInterval(100 + index * 2_000)),
                endedAt: Date(timeIntervalSince1970: TimeInterval(100 + index * 2_000 + duration)),
                actualDurationSeconds: duration,
                currentStepIndex: 1,
                completedStepCount: 1,
                status: .completed,
                kind: .transition
            )
            session.activity = activity
            session.routine = activity.routine
            context.insert(session)
        }
        try context.save()

        let plan = try XCTUnwrap(planner.makePlan(for: activity))
        XCTAssertEqual(plan.routineDurationSeconds, 1_538)
        XCTAssertEqual(plan.transitionStart, Date(timeIntervalSince1970: 2_000 - 1_538 - 300))
    }

    private func makeActivity(start: TimeInterval = 2_000) throws -> (ModelContainer, Activity) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Se préparer")
        let step = RoutineStep(title: "Se préparer", estimatedDurationSeconds: 1_200, order: 0)
        step.routine = routine

        let activity = Activity(
            title: "Restaurant",
            scheduledStartAt: Date(timeIntervalSince1970: start),
            estimatedDurationSeconds: 1_800
        )
        activity.routine = routine

        context.insert(routine)
        context.insert(step)
        context.insert(activity)
        try context.save()
        return (container, activity)
    }
}

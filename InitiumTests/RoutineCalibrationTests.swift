import XCTest
import SwiftData
@testable import Initium

@MainActor
final class RoutineCalibrationTests: XCTestCase {
    func testDoesNotOfferRecommendationBeforeThreeSessions() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let routine = try makeRoutine(in: container, estimate: 20 * 60)
        try addSession(to: routine, in: container, duration: 25 * 60)
        try addSession(to: routine, in: container, duration: 30 * 60)

        let result = RoutineCalibration().result(for: routine)

        XCTAssertFalse(result.hasEnoughHistory)
        XCTAssertEqual(result.recommendedDurationSeconds, 20 * 60)
        XCTAssertEqual(result.observationCount, 2)
    }

    func testOffersAverageAfterThreeSessions() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let routine = try makeRoutine(in: container, estimate: 20 * 60)
        for duration in [25, 30, 35] {
            try addSession(to: routine, in: container, duration: duration * 60)
        }

        let result = RoutineCalibration().result(for: routine)

        XCTAssertTrue(result.hasEnoughHistory)
        XCTAssertEqual(result.recommendedDurationSeconds, 30 * 60)
        XCTAssertEqual(result.observationCount, 3)
    }

    func testTransitionPlannerUsesTheSameCalibratedDuration() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let routine = try makeRoutine(in: container, estimate: 20 * 60)
        for duration in [25, 30, 35] {
            try addSession(to: routine, in: container, duration: duration * 60)
        }

        let result = RoutineCalibration().result(for: routine)
        let start = Date(timeIntervalSince1970: 100_000)
        let plan = TransitionPlanner().makePlan(
            scheduledStart: start,
            estimatedRoutineDurationSeconds: routine.estimatedDurationSeconds,
            transitionMarginSeconds: 5 * 60,
            samples: RoutineCalibration().samples(for: routine)
        )

        XCTAssertEqual(plan.routineDurationSeconds, result.recommendedDurationSeconds)
        XCTAssertEqual(plan.transitionStart, start.addingTimeInterval(-35 * 60))
    }

    private func makeRoutine(
        in container: ModelContainer,
        estimate: Int
    ) throws -> Routine {
        let routine = Routine(name: "Se préparer")
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: estimate, order: 0)
        step.routine = routine
        container.mainContext.insert(routine)
        container.mainContext.insert(step)
        try container.mainContext.save()
        return routine
    }

    private func addSession(
        to routine: Routine,
        in container: ModelContainer,
        duration: Int
    ) throws {
        let end = Date.now
        let session = RoutineSession(
            startedAt: end.addingTimeInterval(-Double(duration)),
            endedAt: end,
            actualDurationSeconds: duration,
            currentStepIndex: 1,
            completedStepCount: 1,
            status: .completed,
            kind: .transition
        )
        session.routine = routine
        container.mainContext.insert(session)
        try container.mainContext.save()
    }
}

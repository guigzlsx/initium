import XCTest
import SwiftData
@testable import Initium

@MainActor
final class RoutineExecutionTests: XCTestCase {
    private let service = ActivityExecutionService()

    func testRoutineStartsAtFirstStep() throws {
        let (container, activity) = try makeRoutineActivity(stepCount: 3)
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)

        let state = try XCTUnwrap(service.routineState(for: activity))
        XCTAssertEqual(state.currentStepIndex, 0)
        XCTAssertEqual(state.completedStepCount, 0)
        XCTAssertEqual(state.currentStep?.title, "Étape 1")
    }

    func testCompletingRoutineStepAdvancesProgress() throws {
        let (container, activity) = try makeRoutineActivity(stepCount: 3)
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.completeCurrentRoutineStep(for: activity, at: Date(timeIntervalSince1970: 1_060), in: context)

        let state = try XCTUnwrap(service.routineState(for: activity))
        XCTAssertEqual(state.currentStepIndex, 1)
        XCTAssertEqual(state.completedStepCount, 1)
        XCTAssertEqual(state.currentStep?.title, "Étape 2")
    }

    func testSkippingRoutineStepAdvancesWithoutFailure() throws {
        let (container, activity) = try makeRoutineActivity(stepCount: 3)
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.skipCurrentRoutineStep(for: activity, at: Date(timeIntervalSince1970: 1_030), in: context)

        let state = try XCTUnwrap(service.routineState(for: activity))
        XCTAssertEqual(state.currentStepIndex, 1)
        XCTAssertEqual(state.completedStepCount, 1)
        XCTAssertFalse(state.isFinished)
    }

    func testFinalRoutineStepCompletesRoutineSession() throws {
        let (container, activity) = try makeRoutineActivity(stepCount: 2)
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_000)
        let endDate = Date(timeIntervalSince1970: 1_120)

        try service.start(activity: activity, at: startDate, in: context)
        try service.completeCurrentRoutineStep(for: activity, at: Date(timeIntervalSince1970: 1_060), in: context)
        try service.completeCurrentRoutineStep(for: activity, at: endDate, in: context)

        let state = try XCTUnwrap(service.routineState(for: activity))
        let session = try XCTUnwrap(activity.routineSessions.first)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.currentStepIndex, 2)
        XCTAssertEqual(state.completedStepCount, 2)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.actualDurationSeconds, 120)
        XCTAssertEqual(session.endedAt, endDate)
    }

    func testRoutineResumePreservesProgressAfterPause() throws {
        let (container, activity) = try makeRoutineActivity(stepCount: 3)
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_000)

        try service.start(activity: activity, at: startDate, in: context)
        try service.completeCurrentRoutineStep(for: activity, at: startDate.addingTimeInterval(60), in: context)
        try service.pause(activity: activity, at: startDate.addingTimeInterval(120), in: context)
        try service.resume(activity: activity, at: startDate.addingTimeInterval(300), in: context)

        let state = try XCTUnwrap(service.routineState(for: activity))
        XCTAssertEqual(activity.routineSessions.count, 2)
        XCTAssertEqual(state.currentStepIndex, 1)
        XCTAssertEqual(state.completedStepCount, 1)
        XCTAssertEqual(state.currentStep?.title, "Étape 2")
        XCTAssertEqual(activity.routineSessions.filter { $0.status == .active }.count, 1)
    }

    private func makeRoutineActivity(stepCount: Int) throws -> (ModelContainer, Activity) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Routine de test")
        let steps = (0..<stepCount).map {
            RoutineStep(title: "Étape \($0 + 1)", estimatedDurationSeconds: 60, order: $0)
        }
        steps.forEach { $0.routine = routine }

        let activity = Activity(
            title: "Activité avec routine",
            scheduledStartAt: Date(timeIntervalSince1970: 0),
            estimatedDurationSeconds: stepCount * 60
        )
        activity.routine = routine

        context.insert(routine)
        steps.forEach { context.insert($0) }
        context.insert(activity)
        try context.save()
        return (container, activity)
    }
}

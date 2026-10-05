import XCTest
import SwiftData
@testable import Initium

@MainActor
final class TransitionExecutionServiceTests: XCTestCase {
    private let service = TransitionExecutionService()

    func testStartCreatesTransitionSessionAtFirstStep() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_000)

        try service.start(activity: activity, at: startDate, in: context)

        let session = try XCTUnwrap(service.activeSession(for: activity))
        XCTAssertEqual(session.kind, .transition)
        XCTAssertEqual(session.currentStepIndex, 0)
        XCTAssertEqual(session.completedStepCount, 0)
        XCTAssertEqual(session.startedAt, startDate)
        XCTAssertEqual(activity.status, .planned)
    }

    func testStartDoesNotCreateDuplicateTransitionSession() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_100), in: context)

        XCTAssertEqual(activity.routineSessions.filter { $0.kind == .transition }.count, 1)
    }

    func testCompletingStepAdvancesTransition() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        let didComplete = try service.completeCurrentStep(
            for: activity,
            at: Date(timeIntervalSince1970: 1_060),
            in: context
        )

        let state = try XCTUnwrap(service.state(for: activity))
        XCTAssertFalse(didComplete)
        XCTAssertEqual(state.currentStepIndex, 1)
        XCTAssertEqual(state.completedStepCount, 1)
        XCTAssertEqual(state.currentStep?.title, "S'habiller")
    }

    func testSkippingStepAdvancesWithoutFailure() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        _ = try service.skipCurrentStep(for: activity, at: Date(timeIntervalSince1970: 1_030), in: context)

        let state = try XCTUnwrap(service.state(for: activity))
        XCTAssertEqual(state.currentStepIndex, 1)
        XCTAssertEqual(state.completedStepCount, 1)
        XCTAssertFalse(state.isFinished)
    }

    func testFinalStepCompletesTransitionAndMeasuresDuration() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_000)
        let endDate = Date(timeIntervalSince1970: 2_440)

        try service.start(activity: activity, at: startDate, in: context)
        _ = try service.completeCurrentStep(for: activity, at: Date(timeIntervalSince1970: 1_060), in: context)
        let didComplete = try service.completeCurrentStep(for: activity, at: endDate, in: context)

        let session = try XCTUnwrap(activity.routineSessions.first { $0.kind == .transition })
        XCTAssertTrue(didComplete)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.endedAt, endDate)
        XCTAssertEqual(session.actualDurationSeconds, 1_440)
    }

    func testActiveTransitionCanBeRecovered() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)

        let recovered = service.activeSession(for: activity)

        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.startedAt, Date(timeIntervalSince1970: 1_000))
    }

    func testOnlyOneTransitionCanBeActive() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let (_, first) = try makeActivity(in: container, title: "Restaurant")
        let (_, second) = try makeActivity(in: container, title: "Sport")

        try service.start(activity: first, at: Date(timeIntervalSince1970: 1_000), in: context)

        XCTAssertThrowsError(
            try service.start(activity: second, at: Date(timeIntervalSince1970: 1_100), in: context)
        ) { error in
            XCTAssertEqual(
                error as? TransitionExecutionError,
                .anotherTransitionIsActive(title: "Restaurant")
            )
        }
    }

    private func makeActivity(
        in container: ModelContainer? = nil,
        title: String = "Restaurant"
    ) throws -> (ModelContainer, Activity) {
        let resolvedContainer: ModelContainer
        if let container {
            resolvedContainer = container
        } else {
            resolvedContainer = try PersistenceController.makeContainer(inMemory: true)
        }
        let context = resolvedContainer.mainContext
        let routine = Routine(name: "Se préparer")
        let steps = [
            RoutineStep(title: "Douche", estimatedDurationSeconds: 480, order: 0),
            RoutineStep(title: "S'habiller", estimatedDurationSeconds: 420, order: 1)
        ]
        steps.forEach { $0.routine = routine }

        let activity = Activity(
            title: title,
            scheduledStartAt: Date(timeIntervalSince1970: 2_000),
            estimatedDurationSeconds: 1_800
        )
        activity.routine = routine
        context.insert(routine)
        steps.forEach { context.insert($0) }
        context.insert(activity)
        try context.save()
        return (resolvedContainer, activity)
    }
}

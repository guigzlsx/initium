import XCTest
import SwiftData
@testable import Initium

@MainActor
final class InsightsCalculatorTests: XCTestCase {
    private let calculator = InsightsCalculator()

    func testOverallCalibrationAveragesEstimatedAndActualDurations() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try makeCompletedActivity(
            in: container,
            title: "Travail",
            estimated: 20 * 60,
            actual: 25 * 60,
            completedAt: now.addingTimeInterval(-1 * 60 * 60)
        )
        _ = try makeCompletedActivity(
            in: container,
            title: "Lecture",
            estimated: 40 * 60,
            actual: 50 * 60,
            completedAt: now.addingTimeInterval(-2 * 60 * 60)
        )

        let snapshot = calculator.calculate(
            activities: try container.mainContext.fetch(FetchDescriptor<Activity>()),
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertEqual(snapshot.overallCalibration?.estimatedAverageSeconds, 30 * 60)
        XCTAssertEqual(snapshot.overallCalibration?.actualAverageSeconds, 37 * 60 + 30)
        XCTAssertEqual(snapshot.overallCalibration?.differenceSeconds, 7 * 60 + 30)
        XCTAssertEqual(snapshot.overallCalibration?.percentageDifference ?? 0, 25, accuracy: 0.1)
        XCTAssertEqual(snapshot.overallCalibration?.observationCount, 2)
        XCTAssertFalse(snapshot.overallCalibration?.isReliable ?? true)
    }

    func testRoutineAverageUsesCompletedTransitionSessions() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        let routine = try makeRoutine(in: container, name: "Se préparer", estimated: 20 * 60)
        try addRoutineSession(
            to: routine,
            in: container,
            duration: 25 * 60,
            endedAt: now.addingTimeInterval(-1 * 60 * 60)
        )
        try addRoutineSession(
            to: routine,
            in: container,
            duration: 30 * 60,
            endedAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        try addRoutineSession(
            to: routine,
            in: container,
            duration: 29 * 60,
            endedAt: now.addingTimeInterval(-3 * 60 * 60)
        )

        let snapshot = calculator.calculate(
            activities: [],
            routines: [routine],
            period: .sevenDays,
            now: now
        )

        let insight = try XCTUnwrap(snapshot.routineInsights.first)
        XCTAssertEqual(insight.estimatedDurationSeconds, 20 * 60)
        XCTAssertEqual(insight.actualAverageSeconds, 28 * 60)
        XCTAssertEqual(insight.observationCount, 3)
        XCTAssertTrue(insight.isReliable)
    }

    func testRoutineWithTwoSessionsDoesNotCreateStrongTrend() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        let routine = try makeRoutine(in: container, name: "Matin", estimated: 20 * 60)
        try addRoutineSession(to: routine, in: container, duration: 25 * 60, endedAt: now.addingTimeInterval(-1 * 60 * 60))
        try addRoutineSession(to: routine, in: container, duration: 30 * 60, endedAt: now.addingTimeInterval(-2 * 60 * 60))

        let snapshot = calculator.calculate(
            activities: [],
            routines: [routine],
            period: .sevenDays,
            now: now
        )

        XCTAssertFalse(snapshot.routineInsights[0].isReliable)
    }

    func testStartDelayAverageIncludesActivitiesStartedEarly() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        for delay in [5 * 60, 10 * 60, -4 * 60] {
            let completedAt = now.addingTimeInterval(-Double((delay + 30 * 60) + 1_000))
            _ = try makeCompletedActivity(
                in: container,
                title: "Travail",
                estimated: 30 * 60,
                actual: 30 * 60,
                scheduledStartAt: completedAt.addingTimeInterval(-30 * 60 - Double(delay)),
                completedAt: completedAt
            )
        }

        let snapshot = calculator.calculate(
            activities: try container.mainContext.fetch(FetchDescriptor<Activity>()),
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertEqual(snapshot.startDelay?.averageDelaySeconds, 220)
        XCTAssertTrue(snapshot.startDelay?.isReliable ?? false)
    }

    func testRepeatedTitleIsReportedAsUnderestimated() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        for (index, actual) in [40, 42, 44].enumerated() {
            _ = try makeCompletedActivity(
                in: container,
                title: "Courses",
                estimated: 30 * 60,
                actual: actual * 60,
                completedAt: now.addingTimeInterval(-Double(index + 1) * 60 * 60)
            )
        }

        let snapshot = calculator.calculate(
            activities: try container.mainContext.fetch(FetchDescriptor<Activity>()),
            routines: [],
            period: .sevenDays,
            now: now
        )

        let insight = try XCTUnwrap(snapshot.underestimatedActivities.first)
        XCTAssertEqual(insight.title, "Courses")
        XCTAssertEqual(insight.differenceSeconds, 12 * 60)
        XCTAssertEqual(insight.observationCount, 3)
    }

    func testRepeatedTitleCanBeWellCalibrated() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        for (index, actual) in [28, 29, 30].enumerated() {
            _ = try makeCompletedActivity(
                in: container,
                title: "Routine du matin",
                estimated: 29 * 60,
                actual: actual * 60,
                completedAt: now.addingTimeInterval(-Double(index + 1) * 60 * 60)
            )
        }

        let snapshot = calculator.calculate(
            activities: try container.mainContext.fetch(FetchDescriptor<Activity>()),
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertEqual(snapshot.wellCalibratedActivities.first?.title, "Routine du matin")
        XCTAssertTrue(snapshot.underestimatedActivities.isEmpty)
    }

    func testInvalidSessionsAreIgnored() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        let activity = Activity(
            title: "Donnée invalide",
            scheduledStartAt: now.addingTimeInterval(-2 * 60 * 60),
            estimatedDurationSeconds: 30 * 60
        )
        activity.status = .completed
        activity.completedAt = now.addingTimeInterval(-1 * 60 * 60)
        let invalid = ActivitySession(
            startedAt: now,
            endedAt: now.addingTimeInterval(-10),
            actualDurationSeconds: 0
        )
        invalid.activity = activity
        container.mainContext.insert(activity)
        container.mainContext.insert(invalid)
        try container.mainContext.save()

        let snapshot = calculator.calculate(
            activities: [activity],
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertNil(snapshot.overallCalibration)
        XCTAssertFalse(snapshot.hasObservations)
    }

    func testSevenDayPeriodExcludesOlderObservations() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try makeCompletedActivity(
            in: container,
            title: "Récent",
            estimated: 20 * 60,
            actual: 30 * 60,
            completedAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
        )
        _ = try makeCompletedActivity(
            in: container,
            title: "Ancien",
            estimated: 20 * 60,
            actual: 30 * 60,
            completedAt: now.addingTimeInterval(-10 * 24 * 60 * 60)
        )

        let activities = try container.mainContext.fetch(FetchDescriptor<Activity>())
        let sevenDays = calculator.calculate(activities: activities, routines: [], period: .sevenDays, now: now)
        let thirtyDays = calculator.calculate(activities: activities, routines: [], period: .thirtyDays, now: now)

        XCTAssertEqual(sevenDays.overallCalibration?.observationCount, 1)
        XCTAssertEqual(thirtyDays.overallCalibration?.observationCount, 2)
    }

    func testReplanSummaryCountsActivitiesAndDays() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        let first = try makeCompletedActivity(
            in: container,
            title: "Courses",
            estimated: 30 * 60,
            actual: 30 * 60,
            completedAt: now.addingTimeInterval(-1 * 60 * 60)
        )
        first.originalScheduledStartAt = first.scheduledStartAt.addingTimeInterval(-30 * 60)
        let second = try makeCompletedActivity(
            in: container,
            title: "Sport",
            estimated: 30 * 60,
            actual: 30 * 60,
            completedAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        second.originalScheduledStartAt = second.scheduledStartAt.addingTimeInterval(-30 * 60)
        try container.mainContext.save()

        let snapshot = calculator.calculate(
            activities: [first, second],
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertEqual(snapshot.replan.replannedActivityCount, 2)
        XCTAssertEqual(snapshot.replan.replannedDayCount, 1)
    }

    func testReplanOnlySnapshotStillHasUsefulContent() throws {
        let now = Date.now
        let container = try PersistenceController.makeContainer(inMemory: true)
        let activity = Activity(
            title: "Sport",
            scheduledStartAt: now.addingTimeInterval(60 * 60),
            estimatedDurationSeconds: 30 * 60
        )
        activity.originalScheduledStartAt = activity.scheduledStartAt.addingTimeInterval(-15 * 60)
        container.mainContext.insert(activity)
        try container.mainContext.save()

        let snapshot = calculator.calculate(
            activities: [activity],
            routines: [],
            period: .sevenDays,
            now: now
        )

        XCTAssertTrue(snapshot.hasObservations)
        XCTAssertEqual(snapshot.replan.replannedActivityCount, 1)
        XCTAssertNil(snapshot.overallCalibration)
    }

    func testNoDataReturnsEmptySnapshot() {
        let snapshot = calculator.calculate(
            activities: [],
            routines: [],
            period: .sevenDays,
            now: .now
        )

        XCTAssertFalse(snapshot.hasObservations)
        XCTAssertNil(snapshot.overallCalibration)
        XCTAssertNil(snapshot.startDelay)
        XCTAssertTrue(snapshot.routineInsights.isEmpty)
    }

    private func makeRoutine(
        in container: ModelContainer,
        name: String,
        estimated: Int
    ) throws -> Routine {
        let context = container.mainContext
        let routine = Routine(name: name)
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: estimated, order: 0)
        step.routine = routine
        context.insert(routine)
        context.insert(step)
        try context.save()
        return routine
    }

    private func addRoutineSession(
        to routine: Routine,
        in container: ModelContainer,
        duration: Int,
        endedAt: Date
    ) throws {
        let session = RoutineSession(
            startedAt: endedAt.addingTimeInterval(-Double(duration)),
            endedAt: endedAt,
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

    @discardableResult
    private func makeCompletedActivity(
        in container: ModelContainer,
        title: String,
        estimated: Int,
        actual: Int,
        scheduledStartAt: Date? = nil,
        completedAt: Date
    ) throws -> Activity {
        let context = container.mainContext
        let start = completedAt.addingTimeInterval(-Double(actual))
        let activity = Activity(
            title: title,
            scheduledStartAt: scheduledStartAt ?? start,
            estimatedDurationSeconds: estimated
        )
        activity.status = .completed
        activity.completedAt = completedAt
        activity.actualDurationSeconds = actual
        let session = ActivitySession(
            startedAt: start,
            endedAt: completedAt,
            actualDurationSeconds: actual
        )
        session.activity = activity
        context.insert(activity)
        context.insert(session)
        try context.save()
        return activity
    }
}

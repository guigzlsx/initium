import XCTest
import SwiftData
@testable import Initium

@MainActor
final class ActivityExecutionServiceTests: XCTestCase {
    private let service = ActivityExecutionService()

    func testStartChangesStatusAndCreatesSession() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 1_000)

        try service.start(activity: activity, at: startDate, in: context)

        XCTAssertEqual(activity.status, .inProgress)
        XCTAssertEqual(activity.sessions.count, 1)
        XCTAssertEqual(activity.sessions.first?.startedAt, startDate)
        XCTAssertNil(activity.sessions.first?.endedAt)
    }

    func testStartDoesNotCreateDuplicateSession() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.start(activity: activity, at: Date(timeIntervalSince1970: 2_000), in: context)

        XCTAssertEqual(activity.sessions.count, 1)
        XCTAssertEqual(activity.sessions.filter { $0.endedAt == nil }.count, 1)
    }

    func testPauseClosesSessionAndStoresDuration() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.pause(activity: activity, at: Date(timeIntervalSince1970: 1_600), in: context)

        XCTAssertEqual(activity.status, .paused)
        XCTAssertEqual(activity.sessions.first?.actualDurationSeconds, 600)
        XCTAssertEqual(activity.actualDurationSeconds, 600)
        XCTAssertNotNil(activity.sessions.first?.endedAt)
    }

    func testResumeCreatesNewSessionPreservingPrevious() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.pause(activity: activity, at: Date(timeIntervalSince1970: 1_600), in: context)
        try service.resume(activity: activity, at: Date(timeIntervalSince1970: 2_000), in: context)

        XCTAssertEqual(activity.status, .inProgress)
        XCTAssertEqual(activity.sessions.count, 2)
        XCTAssertEqual(activity.sessions.filter { $0.endedAt == nil }.count, 1)
        XCTAssertEqual(activity.sessions.filter { $0.endedAt != nil }.first?.actualDurationSeconds, 600)
    }

    func testCompleteClosesSessionAndStoresSummary() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let endDate = Date(timeIntervalSince1970: 1_600)

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.complete(activity: activity, at: endDate, in: context)

        XCTAssertEqual(activity.status, .completed)
        XCTAssertEqual(activity.completedAt, endDate)
        XCTAssertEqual(activity.actualDurationSeconds, 600)
        XCTAssertEqual(activity.sessions.filter { $0.endedAt == nil }.count, 0)
    }

    func testSeveralPausesSumOnlyWorkSessions() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let origin = Date(timeIntervalSince1970: 10_000)

        try service.start(activity: activity, at: origin, in: context)
        try service.pause(activity: activity, at: origin.addingTimeInterval(600), in: context)
        try service.resume(activity: activity, at: origin.addingTimeInterval(900), in: context)
        try service.pause(activity: activity, at: origin.addingTimeInterval(1_380), in: context)
        try service.resume(activity: activity, at: origin.addingTimeInterval(1_560), in: context)
        try service.complete(activity: activity, at: origin.addingTimeInterval(2_280), in: context)

        XCTAssertEqual(activity.actualDurationSeconds, 1_800)
        XCTAssertEqual(ActivityTiming.elapsedSeconds(for: activity, at: origin.addingTimeInterval(3_000)), 1_800)
    }

    func testActiveSessionCanBeMeasuredAfterRelaunch() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext
        let startDate = Date(timeIntervalSince1970: 5_000)

        try service.start(activity: activity, at: startDate, in: context)

        XCTAssertEqual(service.totalExecutionDuration(for: activity, now: startDate.addingTimeInterval(420)), 420)
    }

    func testStartingSecondActivityReportsConflict() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = Activity(title: "Première", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        let second = Activity(title: "Seconde", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        context.insert(first)
        context.insert(second)
        try context.save()

        try service.start(activity: first, at: Date(timeIntervalSince1970: 1_000), in: context)

        XCTAssertThrowsError(try service.start(activity: second, at: Date(timeIntervalSince1970: 1_100), in: context)) { error in
            XCTAssertEqual(error as? ActivityExecutionError, .anotherActivityIsActive(title: "Première"))
        }
        XCTAssertEqual(second.sessions.count, 0)
        XCTAssertEqual(first.status, .inProgress)
    }

    func testAddingFiveMinutesChangesEstimateOnly() throws {
        let (container, activity) = try makeActivity(duration: 1_800)
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.addTime(to: activity, seconds: 300, in: context)

        XCTAssertEqual(activity.estimatedDurationSeconds, 2_100)
        XCTAssertEqual(service.totalExecutionDuration(for: activity, now: Date(timeIntervalSince1970: 1_100)), 100)
        XCTAssertEqual(activity.actualDurationSeconds, 0)
    }

    func testStopLeavesActivityPausedWithoutDiscardingDuration() throws {
        let (container, activity) = try makeActivity()
        let context = container.mainContext

        try service.start(activity: activity, at: Date(timeIntervalSince1970: 1_000), in: context)
        try service.stop(activity: activity, at: Date(timeIntervalSince1970: 1_300), in: context)

        XCTAssertEqual(activity.status, .paused)
        XCTAssertEqual(activity.actualDurationSeconds, 300)
        XCTAssertEqual(activity.sessions.filter { $0.endedAt == nil }.count, 0)
    }

    private func makeActivity(duration: Int = 1_800) throws -> (ModelContainer, Activity) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let activity = Activity(
            title: "Activité de test",
            scheduledStartAt: Date(timeIntervalSince1970: 0),
            estimatedDurationSeconds: duration
        )
        container.mainContext.insert(activity)
        try container.mainContext.save()
        return (container, activity)
    }
}

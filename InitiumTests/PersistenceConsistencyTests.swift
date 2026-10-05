import XCTest
import SwiftData
@testable import Initium

@MainActor
final class PersistenceConsistencyTests: XCTestCase {
    private let validator = PersistenceConsistencyValidator()

    func testCompletedActivityWithActiveSessionIsReported() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let activity = Activity(title: "Travail", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        let session = ActivitySession(startedAt: Date(timeIntervalSince1970: 100))
        session.activity = activity
        activity.status = .completed
        context.insert(activity)
        context.insert(session)
        try context.save()

        XCTAssertTrue(validator.issues(for: activity).contains(.completedActivityHasActiveSession))
    }

    func testInProgressWithoutSessionIsRecoverable() throws {
        let activity = Activity(title: "Travail", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        activity.status = .inProgress

        XCTAssertTrue(validator.issues(for: activity).contains(.inProgressActivityHasNoActiveSession))
    }

    func testDuplicateActiveTransitionSessionsAreReported() throws {
        let routine = Routine(name: "Préparation")
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: 60, order: 0)
        step.routine = routine
        let activity = Activity(title: "Restaurant", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        activity.routine = routine
        let first = RoutineSession(kind: .transition)
        let second = RoutineSession(kind: .transition)
        first.routine = routine
        first.activity = activity
        second.routine = routine
        second.activity = activity
        routine.steps = [step]
        activity.routineSessions = [first, second]

        XCTAssertTrue(validator.issues(for: activity).contains(.multipleActiveTransitionSessions))
    }

    func testRoutineStepIndexBeyondBoundsIsReported() {
        let routine = Routine(name: "Préparation")
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: 60, order: 0)
        step.routine = routine
        let activity = Activity(title: "Restaurant", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        activity.routine = routine
        let session = RoutineSession(currentStepIndex: 2, kind: .transition)
        session.routine = routine
        session.activity = activity
        routine.steps = [step]
        activity.routineSessions = [session]

        XCTAssertTrue(validator.issues(for: activity).contains(.invalidRoutineStepIndex))
    }

    func testDataMaintenanceDeletesAllLocalModels() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Routine")
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: 60, order: 0)
        step.routine = routine
        let activity = Activity(title: "Activité", scheduledStartAt: .now, estimatedDurationSeconds: 600)
        activity.routine = routine
        let activitySession = ActivitySession()
        activitySession.activity = activity
        let routineSession = RoutineSession()
        routineSession.routine = routine
        routineSession.activity = activity
        context.insert(routine)
        context.insert(step)
        context.insert(activity)
        context.insert(activitySession)
        context.insert(routineSession)
        try context.save()

        try DataMaintenanceService().deleteAllData(in: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ActivitySession>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Routine>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RoutineStep>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RoutineSession>()).isEmpty)
    }
}

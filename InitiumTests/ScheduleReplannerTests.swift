import XCTest
import SwiftData
@testable import Initium

@MainActor
final class ScheduleReplannerTests: XCTestCase {
    private let replanner = ScheduleReplanner()

    func testFlexibleActivitiesAreShiftedFromReplanPoint() throws {
        let (container, activity) = try makeActivity(
            title: "Courses",
            start: 15 * 60 * 60,
            duration: 30 * 60
        )
        _ = container

        let proposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let change = try XCTUnwrap(proposal.changes.first)
        XCTAssertEqual(change.action, .shifted)
        XCTAssertEqual(change.proposedStart, Date(timeIntervalSince1970: 15 * 60 * 60 + 35 * 60))
    }

    func testFixedActivityRemainsUnchanged() throws {
        let (container, activity) = try makeActivity(
            title: "Restaurant",
            start: 18 * 60 * 60 + 30 * 60,
            duration: 60 * 60,
            isFixedTime: true
        )
        _ = container

        let proposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let change = try XCTUnwrap(proposal.changes.first)
        XCTAssertEqual(change.action, .unchanged)
        XCTAssertEqual(change.proposedStart, activity.scheduledStartAt)
        XCTAssertTrue(change.isFixedTime)
    }

    func testMixedActivitiesKeepTheirOrderAroundFixedActivity() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let courses = try makeActivity(
            in: container,
            title: "Courses",
            start: 15 * 60 * 60,
            duration: 30 * 60
        ).1
        let sport = try makeActivity(
            in: container,
            title: "Sport",
            start: 16 * 60 * 60,
            duration: 60 * 60
        ).1
        let restaurant = try makeActivity(
            in: container,
            title: "Restaurant",
            start: 18 * 60 * 60 + 30 * 60,
            duration: 60 * 60,
            isFixedTime: true
        ).1
        _ = context

        let proposal = replanner.makeProposal(
            activities: [restaurant, sport, courses],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let coursesChange = try XCTUnwrap(proposal.changes.first { $0.activityID == courses.id })
        let sportChange = try XCTUnwrap(proposal.changes.first { $0.activityID == sport.id })
        let restaurantChange = try XCTUnwrap(proposal.changes.first { $0.activityID == restaurant.id })

        XCTAssertEqual(coursesChange.proposedStart, Date(timeIntervalSince1970: 15 * 60 * 60 + 35 * 60))
        XCTAssertEqual(sportChange.proposedStart, Date(timeIntervalSince1970: 16 * 60 * 60 + 10 * 60))
        XCTAssertEqual(restaurantChange.proposedStart, restaurant.scheduledStartAt)
        XCTAssertLessThan(
            sportChange.proposedStart.addingTimeInterval(TimeInterval(sportChange.proposedDurationSeconds)),
            restaurant.scheduledStartAt
        )
    }

    func testCollisionBeforeFixedActivityCreatesConflict() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let longActivity = try makeActivity(
            in: container,
            title: "Sport",
            start: 15 * 60 * 60,
            duration: 2 * 60 * 60
        ).1
        let fixedActivity = try makeActivity(
            in: container,
            title: "Restaurant",
            start: 18 * 60 * 60,
            duration: 60 * 60,
            isFixedTime: true
        ).1

        let proposal = replanner.makeProposal(
            activities: [longActivity, fixedActivity],
            replanFrom: Date(timeIntervalSince1970: 16 * 60 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let conflict = try XCTUnwrap(proposal.conflicts.first)
        XCTAssertEqual(conflict.activityID, longActivity.id)
        XCTAssertEqual(conflict.fixedActivityTitle, "Restaurant")
        XCTAssertTrue(conflict.suggestedDurationsSeconds.contains(30 * 60))
    }

    func testTransitionBlockIsTreatedAsOccupiedBeforeFixedActivity() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let flexible = try makeActivity(
            in: container,
            title: "Courses",
            start: 17 * 60 * 60 + 30 * 60,
            duration: 60 * 60
        ).1
        let fixed = try makeActivity(
            in: container,
            title: "Train",
            start: 18 * 60 * 60 + 30 * 60,
            duration: 30 * 60,
            isFixedTime: true,
            routineDurations: [40 * 60]
        ).1

        let proposal = replanner.makeProposal(
            activities: [flexible, fixed],
            replanFrom: Date(timeIntervalSince1970: 17 * 60 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let conflict = try XCTUnwrap(proposal.conflicts.first)
        XCTAssertEqual(conflict.fixedActivityTitle, "Train")
        XCTAssertEqual(conflict.availableUntil, Date(timeIntervalSince1970: 18 * 60 * 60 - 15 * 60))
    }

    func testCompletedAndPostponedActivitiesAreIgnored() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let completed = try makeActivity(
            in: container,
            title: "Terminé",
            start: 14 * 60 * 60,
            duration: 30 * 60,
            status: .completed
        ).1
        let postponed = try makeActivity(
            in: container,
            title: "Reporté",
            start: 15 * 60 * 60,
            duration: 30 * 60,
            status: .postponed
        ).1

        let proposal = replanner.makeProposal(
            activities: [completed, postponed],
            replanFrom: Date(timeIntervalSince1970: 16 * 60 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        XCTAssertTrue(proposal.changes.isEmpty)
        XCTAssertTrue(proposal.conflicts.isEmpty)
    }

    func testCurrentActivityIsNeverMoved() throws {
        let (container, activity) = try makeActivity(
            title: "Travail",
            start: 14 * 60 * 60,
            duration: 60 * 60,
            status: .inProgress
        )
        _ = container

        let proposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        let change = try XCTUnwrap(proposal.changes.first)
        XCTAssertEqual(change.action, .unchanged)
        XCTAssertEqual(change.proposedStart, activity.scheduledStartAt)
    }

    func testNoChangeProposalDoesNotMoveValidPlanning() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let first = try makeActivity(
            in: container,
            title: "Lecture",
            start: 16 * 60 * 60,
            duration: 30 * 60
        ).1
        let second = try makeActivity(
            in: container,
            title: "Pause",
            start: 17 * 60 * 60,
            duration: 15 * 60
        ).1

        let proposal = replanner.makeProposal(
            activities: [first, second],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )

        XCTAssertFalse(proposal.hasChanges)
    }

    func testApplyingReplanPreservesOriginalStartAcrossSuccessiveReplans() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let activity = try makeActivity(
            in: container,
            title: "Courses",
            start: 15 * 60 * 60,
            duration: 30 * 60
        ).1
        let firstProposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )
        let service = ReplanPersistenceService()

        _ = try service.apply(proposal: firstProposal, resolutions: [:], in: container.mainContext)
        let firstNewStart = activity.scheduledStartAt
        XCTAssertEqual(activity.originalScheduledStartAt, Date(timeIntervalSince1970: 15 * 60 * 60))

        let secondProposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 16 * 60 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )
        _ = try service.apply(proposal: secondProposal, resolutions: [:], in: container.mainContext)

        XCTAssertNotEqual(activity.scheduledStartAt, firstNewStart)
        XCTAssertEqual(activity.originalScheduledStartAt, Date(timeIntervalSince1970: 15 * 60 * 60))
    }

    func testUndoRestoresThePreviousPlan() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let activity = try makeActivity(
            in: container,
            title: "Courses",
            start: 15 * 60 * 60,
            duration: 30 * 60
        ).1
        let originalStart = activity.scheduledStartAt
        let proposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 15 * 60 * 60 + 27 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )
        let service = ReplanPersistenceService()
        let snapshot = try service.apply(proposal: proposal, resolutions: [:], in: container.mainContext)

        try service.undo(snapshot: snapshot, in: container.mainContext)

        XCTAssertEqual(activity.scheduledStartAt, originalStart)
        XCTAssertNil(activity.originalScheduledStartAt)
    }

    func testMovedActivityWithRoutineGetsARecalculatedTransitionPlan() throws {
        let (container, activity) = try makeActivity(
            title: "Train",
            start: 18 * 60 * 60,
            duration: 30 * 60,
            routineDurations: [20 * 60]
        )
        let proposal = replanner.makeProposal(
            activities: [activity],
            replanFrom: Date(timeIntervalSince1970: 18 * 60 * 60 - 10 * 60),
            dayEnd: Date(timeIntervalSince1970: 86_399)
        )
        let service = ReplanPersistenceService()
        _ = try service.apply(proposal: proposal, resolutions: [:], in: container.mainContext)

        let plan = try XCTUnwrap(TransitionPlanner().makePlan(for: activity))
        XCTAssertEqual(
            plan.transitionStart,
            activity.scheduledStartAt.addingTimeInterval(-20 * 60 - 5 * 60)
        )
    }

    private func makeActivity(
        in container: ModelContainer? = nil,
        title: String,
        start: TimeInterval,
        duration: Int,
        isFixedTime: Bool = false,
        status: ActivityStatus = .planned,
        routineDurations: [Int] = []
    ) throws -> (ModelContainer, Activity) {
        let resolvedContainer = try container ?? PersistenceController.makeContainer(inMemory: true)
        let context = resolvedContainer.mainContext
        let activity = Activity(
            title: title,
            scheduledStartAt: Date(timeIntervalSince1970: start),
            estimatedDurationSeconds: duration,
            isFixedTime: isFixedTime
        )
        activity.status = status
        context.insert(activity)

        if !routineDurations.isEmpty {
            let routine = Routine(name: "Préparation")
            for (index, stepDuration) in routineDurations.enumerated() {
                let step = RoutineStep(
                    title: "Étape \(index + 1)",
                    estimatedDurationSeconds: stepDuration,
                    order: index
                )
                step.routine = routine
                context.insert(step)
            }
            activity.routine = routine
            context.insert(routine)
        }

        try context.save()
        return (resolvedContainer, activity)
    }
}

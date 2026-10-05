import XCTest
@testable import Initium

final class TransitionPlannerTests: XCTestCase {
    private let planner = TransitionPlanner()

    private var scheduledStart: Date {
        Date(timeIntervalSince1970: 100_000)
    }

    func testUsesEstimatedRoutineDurationWithoutHistory() {
        let plan = planner.makePlan(
            scheduledStart: scheduledStart,
            estimatedRoutineDurationSeconds: 20 * 60,
            transitionMarginSeconds: 5 * 60,
            samples: []
        )

        XCTAssertEqual(plan.routineDurationSeconds, 20 * 60)
        XCTAssertEqual(plan.transitionStart, scheduledStart.addingTimeInterval(-25 * 60))
    }

    func testUsesEstimateWithFewerThanThreeSessions() {
        let plan = planner.makePlan(
            scheduledStart: scheduledStart,
            estimatedRoutineDurationSeconds: 20 * 60,
            transitionMarginSeconds: 5 * 60,
            samples: [
                DurationSample(durationSeconds: 25 * 60, isComplete: true),
                DurationSample(durationSeconds: 30 * 60, isComplete: true)
            ]
        )

        XCTAssertEqual(plan.routineDurationSeconds, 20 * 60)
        XCTAssertEqual(plan.transitionStart, scheduledStart.addingTimeInterval(-25 * 60))
    }

    func testUsesAverageAfterThreeCompletedSessions() {
        let plan = planner.makePlan(
            scheduledStart: scheduledStart,
            estimatedRoutineDurationSeconds: 20 * 60,
            transitionMarginSeconds: 5 * 60,
            samples: [
                DurationSample(durationSeconds: 25 * 60, isComplete: true),
                DurationSample(durationSeconds: 30 * 60, isComplete: true),
                DurationSample(durationSeconds: 35 * 60, isComplete: true)
            ]
        )

        XCTAssertEqual(plan.routineDurationSeconds, 30 * 60)
        XCTAssertEqual(plan.transitionStart, scheduledStart.addingTimeInterval(-35 * 60))
    }

    func testAccountsForMargin() {
        let plan = planner.makePlan(
            scheduledStart: scheduledStart,
            estimatedRoutineDurationSeconds: 20 * 60,
            transitionMarginSeconds: 10 * 60,
            samples: []
        )

        XCTAssertEqual(plan.transitionStart, scheduledStart.addingTimeInterval(-30 * 60))
    }
}

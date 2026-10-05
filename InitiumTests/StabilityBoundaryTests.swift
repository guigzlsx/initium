import XCTest
@testable import Initium

final class StabilityBoundaryTests: XCTestCase {
    func testActivitySessionCanCrossMidnight() {
        let start = Date(timeIntervalSince1970: 23 * 3_600 + 50 * 60)
        let end = start.addingTimeInterval(30 * 60)
        let activity = Activity(
            title: "Fin de journée",
            scheduledStartAt: start,
            estimatedDurationSeconds: 1_800
        )
        let session = ActivitySession(startedAt: start, endedAt: end, actualDurationSeconds: 1_800)
        session.activity = activity
        activity.sessions = [session]
        activity.status = .completed

        XCTAssertEqual(ActivityTiming.elapsedSeconds(for: activity, at: end), 1_800)
    }

    func testInsightsHandleLargeLocalHistory() {
        let now = Date.now
        let activities: [Activity] = (0..<500).map { index in
            let activity = Activity(
                title: "Activité \(index % 10)",
                scheduledStartAt: now.addingTimeInterval(-Double(index % 7) * 86_400),
                estimatedDurationSeconds: 1_800
            )
            let startedAt = activity.scheduledStartAt
            let endedAt = startedAt.addingTimeInterval(2_100)
            let session = ActivitySession(startedAt: startedAt, endedAt: endedAt, actualDurationSeconds: 2_100)
            session.activity = activity
            activity.sessions = [session]
            activity.actualDurationSeconds = 2_100
            activity.completedAt = endedAt
            activity.status = .completed
            return activity
        }

        let routines: [Routine] = (0..<100).map { index in
            let routine = Routine(name: "Routine \(index)")
            let step = RoutineStep(title: "Étape", estimatedDurationSeconds: 300, order: 0)
            step.routine = routine
            routine.steps = [step]
            routine.sessions = (0..<5).map { occurrence in
                let start = now.addingTimeInterval(-Double(occurrence + 1) * 86_400)
                let session = RoutineSession(
                    startedAt: start,
                    endedAt: start.addingTimeInterval(360),
                    actualDurationSeconds: 360,
                    status: .completed,
                    kind: .transition
                )
                session.routine = routine
                return session
            }
            return routine
        }

        let snapshot = InsightsCalculator().calculate(
            activities: activities,
            routines: routines,
            period: .sevenDays,
            now: now
        )

        XCTAssertTrue(snapshot.hasObservations)
        XCTAssertFalse(snapshot.routineInsights.isEmpty)
    }
}

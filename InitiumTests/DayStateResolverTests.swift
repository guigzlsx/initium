import XCTest
@testable import Initium

final class DayStateResolverTests: XCTestCase {
    private let resolver = DayStateResolver()
    private let referenceDate = Date(timeIntervalSince1970: 100_000)

    func testInProgressActivityIsSelectedAsCurrent() {
        let planned = makeActivity("Planifiée", offset: -3_600)
        let active = makeActivity("En cours", offset: 3_600, status: .inProgress)

        let result = resolver.currentActivity(
            from: [planned, active],
            now: referenceDate
        )

        XCTAssertEqual(result?.title, "En cours")
    }

    func testArrivedPlannedActivityIsSelectedAsCurrent() {
        let activity = makeActivity("À commencer", offset: -300)

        let result = resolver.currentActivity(
            from: [activity],
            now: referenceDate
        )

        XCTAssertEqual(result?.title, "À commencer")
    }

    func testArrivedPlannedActivityRemainsCurrentAfterEstimatedEnd() {
        let activity = makeActivity("En retard de démarrage", offset: -3_600)

        let result = resolver.currentActivity(
            from: [activity],
            now: referenceDate
        )

        XCTAssertEqual(result?.title, "En retard de démarrage")
    }

    func testNextActivityIsTheEarliestFutureActivity() {
        let later = makeActivity("Plus tard", offset: 3_600)
        let sooner = makeActivity("Bientôt", offset: 1_800)

        let result = resolver.nextActivity(
            from: [later, sooner],
            now: referenceDate
        )

        XCTAssertEqual(result?.title, "Bientôt")
    }

    func testCompletedActivityIsNotCurrent() {
        let completed = makeActivity("Terminée", offset: -300, status: .completed)

        let result = resolver.currentActivity(
            from: [completed],
            now: referenceDate
        )

        XCTAssertNil(result)
    }

    func testCancelledActivityIsNotNext() {
        let cancelled = makeActivity("Annulée", offset: 1_800, status: .cancelled)

        let result = resolver.nextActivity(
            from: [cancelled],
            now: referenceDate
        )

        XCTAssertNil(result)
    }

    func testEmptyDayHasNoCurrentOrNextActivity() {
        XCTAssertNil(resolver.currentActivity(from: [], now: referenceDate))
        XCTAssertNil(resolver.nextActivity(from: [], now: referenceDate))
    }

    func testUnsortedActivitiesAreResolvedChronologically() {
        let third = makeActivity("Troisième", offset: 3_600)
        let first = makeActivity("Première", offset: 900)
        let second = makeActivity("Deuxième", offset: 1_800)

        let result = resolver.nextActivity(
            from: [third, first, second],
            now: referenceDate
        )

        XCTAssertEqual(result?.title, "Première")
    }

    private func makeActivity(
        _ title: String,
        offset: TimeInterval,
        status: ActivityStatus = .planned
    ) -> Activity {
        let activity = Activity(
            title: title,
            scheduledStartAt: referenceDate.addingTimeInterval(offset),
            estimatedDurationSeconds: 30 * 60
        )
        activity.status = status
        return activity
    }
}

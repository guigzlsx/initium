import XCTest
@testable import Initium

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {
    func testTransitionNotificationIdentifierIsStable() {
        let activity = Activity(
            title: "Restaurant",
            scheduledStartAt: Date(timeIntervalSince1970: 2_000),
            estimatedDurationSeconds: 1_800
        )

        XCTAssertEqual(
            LocalNotificationScheduler.identifier(for: activity),
            LocalNotificationScheduler.identifier(for: activity)
        )
        XCTAssertTrue(LocalNotificationScheduler.identifier(for: activity).hasPrefix("initium.transition."))
    }

    func testTransitionNotificationDescriptorContainsCalmContext() {
        let activity = Activity(
            title: "Restaurant",
            scheduledStartAt: Date(timeIntervalSince1970: 2_000),
            estimatedDurationSeconds: 1_800
        )
        let plan = TransitionPlan(
            transitionStart: Date(timeIntervalSince1970: 1_000),
            routineDurationSeconds: 1_200,
            transitionMarginSeconds: 300
        )

        let descriptor = LocalNotificationScheduler.descriptor(for: activity, plan: plan)

        XCTAssertEqual(descriptor.title, InitiumLocalization.string("notification.transition.title"))
        XCTAssertTrue(descriptor.body.contains("Restaurant"))
        XCTAssertEqual(descriptor.fireDate, plan.transitionStart)
    }

    func testDescriptorUsesStableIdentifierAndTransitionTime() {
        let activity = Activity(
            title: "Sport",
            scheduledStartAt: Date(timeIntervalSince1970: 8_000),
            estimatedDurationSeconds: 1_800
        )
        let plan = TransitionPlan(
            transitionStart: Date(timeIntervalSince1970: 7_000),
            routineDurationSeconds: 1_500,
            transitionMarginSeconds: 300
        )

        let descriptor = LocalNotificationScheduler.descriptor(for: activity, plan: plan)

        XCTAssertEqual(descriptor.identifier, LocalNotificationScheduler.identifier(for: activity))
        XCTAssertNotEqual(descriptor.fireDate, activity.scheduledStartAt)
    }
}

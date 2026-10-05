import XCTest
import SwiftData
@testable import Initium

@MainActor
final class PersistenceTests: XCTestCase {
    func testRoutineRelationsPersistInMemory() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext

        let routine = Routine(name: "Routine de test")
        let step = RoutineStep(title: "Étape", estimatedDurationSeconds: 60, order: 0)
        let activity = Activity(
            title: "Activité de test",
            scheduledStartAt: Date(timeIntervalSince1970: 100_000),
            estimatedDurationSeconds: 600
        )

        step.routine = routine
        activity.routine = routine

        context.insert(routine)
        context.insert(step)
        context.insert(activity)
        try context.save()

        let routines = try context.fetch(FetchDescriptor<Routine>())

        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines.first?.orderedSteps.first?.title, "Étape")
        XCTAssertEqual(routines.first?.activities.first?.title, "Activité de test")
    }
}

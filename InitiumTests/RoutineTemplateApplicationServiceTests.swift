import XCTest
import SwiftData
@testable import Initium

@MainActor
final class RoutineTemplateApplicationServiceTests: XCTestCase {
    func testApplyCreatesRoutineCopiesStepsAndSetsTransitionMargin() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let catalog = makeCatalog()
        let template = try XCTUnwrap(catalog.templates.first)
        let activity = Activity(
            title: "Restaurant",
            scheduledStartAt: Date(timeIntervalSince1970: 10_000),
            estimatedDurationSeconds: 1_800
        )
        context.insert(activity)

        let result = try await RoutineTemplateApplicationService(notificationScheduler: nil).apply(
            template: template,
            catalog: catalog,
            to: activity,
            in: context,
            locale: .fr
        )

        XCTAssertFalse(result.reusedExistingRoutine)
        XCTAssertEqual(activity.routine?.sourceTemplateSlug, "restaurant")
        XCTAssertEqual(activity.transitionMarginSeconds, 600)
        XCTAssertEqual(activity.routine?.orderedSteps.map(\.title), ["Douche", "Partir"])
        XCTAssertEqual(activity.routine?.estimatedDurationSeconds, 600)
        XCTAssertNotNil(result.transitionPlan)
    }

    func testApplyReusesTemplateRoutineWithoutOverwritingLocalSteps() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let catalog = makeCatalog()
        let template = try XCTUnwrap(catalog.templates.first)
        let existingRoutine = Routine(
            name: "Ma préparation calibrée",
            sourceTemplateSlug: "restaurant"
        )
        let localStep = RoutineStep(title: "Mon étape personnalisée", estimatedDurationSeconds: 900, order: 0)
        localStep.routine = existingRoutine
        context.insert(existingRoutine)
        context.insert(localStep)

        let activity = Activity(
            title: "Dîner",
            scheduledStartAt: Date(timeIntervalSince1970: 10_000),
            estimatedDurationSeconds: 1_800
        )
        context.insert(activity)
        try context.save()

        let result = try await RoutineTemplateApplicationService(notificationScheduler: nil).apply(
            template: template,
            catalog: catalog,
            to: activity,
            in: context,
            locale: .fr
        )

        XCTAssertTrue(result.reusedExistingRoutine)
        XCTAssertEqual(result.routine.id, existingRoutine.id)
        XCTAssertEqual(existingRoutine.name, "Ma préparation calibrée")
        XCTAssertEqual(existingRoutine.orderedSteps.map(\.title), ["Mon étape personnalisée"])
    }

    private func makeCatalog() -> RoutineTemplateCatalog {
        let templateID = UUID()
        return RoutineTemplateCatalog(
            categories: [],
            templates: [RoutineTemplate(
                id: templateID,
                categoryID: UUID(),
                slug: "restaurant",
                nameFR: "Se préparer pour sortir",
                nameEN: "Get ready to go out",
                descriptionFR: nil,
                descriptionEN: nil,
                icon: "figure.walk",
                defaultMarginSeconds: 600,
                sortOrder: 0,
                isActive: true
            )],
            steps: [
                RoutineTemplateStep(
                    id: UUID(), templateID: templateID, stepKey: "shower",
                    titleFR: "Douche", titleEN: "Shower", estimatedDurationSeconds: 480,
                    sortOrder: 10, isOptional: false, isActive: true
                ),
                RoutineTemplateStep(
                    id: UUID(), templateID: templateID, stepKey: "leave",
                    titleFR: "Partir", titleEN: "Leave", estimatedDurationSeconds: 120,
                    sortOrder: 20, isOptional: false, isActive: true
                )
            ],
            keywords: []
        )
    }
}

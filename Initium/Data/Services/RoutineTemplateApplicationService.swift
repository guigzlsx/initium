import Foundation
import SwiftData

struct RoutineTemplateApplicationResult {
    let routine: Routine
    let reusedExistingRoutine: Bool
    let transitionPlan: TransitionPlan?
}

enum RoutineTemplateApplicationError: LocalizedError {
    case templateHasNoSteps

    var errorDescription: String? {
        switch self {
        case .templateHasNoSteps:
            return "Cette préparation ne contient pas encore d’étapes."
        }
    }
}

@MainActor
struct RoutineTemplateApplicationService {
    private let notificationScheduler: LocalNotificationScheduler?

    init(notificationScheduler: LocalNotificationScheduler? = LocalNotificationScheduler()) {
        self.notificationScheduler = notificationScheduler
    }

    func apply(
        template: RoutineTemplate,
        catalog: RoutineTemplateCatalog,
        to activity: Activity,
        in context: ModelContext,
        locale: RoutineTemplateLocale = .current,
        now: Date = .now
    ) async throws -> RoutineTemplateApplicationResult {
        let (routine, reused) = try makeOrReuseRoutine(
            from: template,
            catalog: catalog,
            in: context,
            locale: locale
        )

        activity.routine = routine
        activity.transitionMarginSeconds = max(0, template.defaultMarginSeconds)
        routine.updatedAt = now
        try context.save()

        let plan = TransitionPlanner().makePlan(for: activity)
        if let notificationScheduler {
            guard await notificationScheduler.isAuthorized(),
                  let plan,
                  !activity.isExternallyDeleted,
                  !activity.externalIsAllDay else {
                notificationScheduler.remove(for: activity)
                return RoutineTemplateApplicationResult(
                    routine: routine,
                    reusedExistingRoutine: reused,
                    transitionPlan: plan
                )
            }

            try await notificationScheduler.schedule(for: activity, plan: plan, now: now)
        }

        return RoutineTemplateApplicationResult(
            routine: routine,
            reusedExistingRoutine: reused,
            transitionPlan: plan
        )
    }

    func makeOrReuseRoutine(
        from template: RoutineTemplate,
        catalog: RoutineTemplateCatalog,
        in context: ModelContext,
        locale: RoutineTemplateLocale = .current
    ) throws -> (routine: Routine, reused: Bool) {
        if let existing = try context.fetch(FetchDescriptor<Routine>()).first(where: {
            $0.sourceTemplateSlug == template.slug
        }) {
            return (existing, true)
        }

        let templateSteps = catalog.steps(for: template)
        guard !templateSteps.isEmpty else {
            throw RoutineTemplateApplicationError.templateHasNoSteps
        }

        let routine = Routine(
            name: template.localizedName(for: locale),
            icon: template.icon ?? "checklist",
            sourceTemplateSlug: template.slug
        )
        context.insert(routine)

        for (index, step) in templateSteps.enumerated() {
            let localStep = RoutineStep(
                title: step.localizedTitle(for: locale),
                estimatedDurationSeconds: max(1, step.estimatedDurationSeconds),
                order: index
            )
            localStep.routine = routine
            context.insert(localStep)
        }

        return (routine, false)
    }
}

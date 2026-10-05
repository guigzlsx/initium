import Foundation
import SwiftData

enum PreviewData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        let day = Date()

        let prepareRoutine = Routine(name: "Se préparer", icon: "figure.dress.line.vertical.figure")
        let prepareSteps = [
            RoutineStep(title: "Douche", estimatedDurationSeconds: 8 * 60, order: 0),
            RoutineStep(title: "S'habiller", estimatedDurationSeconds: 7 * 60, order: 1),
            RoutineStep(title: "Préparer les affaires", estimatedDurationSeconds: 3 * 60, order: 2),
            RoutineStep(title: "Chaussures", estimatedDurationSeconds: 2 * 60, order: 3)
        ]

        let workRoutine = Routine(name: "Commencer à travailler", icon: "desktopcomputer")
        let workSteps = [
            RoutineStep(title: "Préparer le bureau", estimatedDurationSeconds: 2 * 60, order: 0),
            RoutineStep(title: "Ouvrir l'ordinateur", estimatedDurationSeconds: 1 * 60, order: 1),
            RoutineStep(title: "Ouvrir le document", estimatedDurationSeconds: 1 * 60, order: 2)
        ]

        prepareSteps.forEach { $0.routine = prepareRoutine }
        workSteps.forEach { $0.routine = workRoutine }

        context.insert(prepareRoutine)
        context.insert(workRoutine)
        prepareSteps.forEach { context.insert($0) }
        workSteps.forEach { context.insert($0) }

        let activities = [
            Activity(
                title: "Travail",
                scheduledStartAt: date(day, hour: 9, minute: 0, calendar: calendar),
                estimatedDurationSeconds: 3 * 60 * 60
            ),
            Activity(
                title: "Déjeuner",
                scheduledStartAt: date(day, hour: 12, minute: 30, calendar: calendar),
                estimatedDurationSeconds: 45 * 60,
                isFixedTime: true
            ),
            Activity(
                title: "Rendez-vous",
                scheduledStartAt: date(day, hour: 14, minute: 0, calendar: calendar),
                estimatedDurationSeconds: 60 * 60,
                isFixedTime: true
            ),
            Activity(
                title: "Sport",
                scheduledStartAt: date(day, hour: 18, minute: 0, calendar: calendar),
                estimatedDurationSeconds: 60 * 60
            )
        ]

        activities[2].routine = prepareRoutine
        activities[0].routine = workRoutine

        activities.forEach { context.insert($0) }
    }

    /// Development-only data used when launching the Simulator with
    /// `--initium-ui-demo`. It is never loaded for a regular user.
    static func insertRichDemo(into context: ModelContext, activeTransition: Bool = false) {
        let calendar = Calendar.current
        let now = Date.now

        let prepareRoutine = makeRoutine(
            name: "Se préparer",
            icon: "figure.dress.line.vertical.figure",
            steps: [
                ("Douche", 8 * 60),
                ("S'habiller", 7 * 60),
                ("Préparer les affaires", 3 * 60),
                ("Chaussures", 2 * 60)
            ],
            in: context
        )
        let workRoutine = makeRoutine(
            name: "Commencer à travailler",
            icon: "desktopcomputer",
            steps: [
                ("Préparer le bureau", 2 * 60),
                ("Ouvrir l'ordinateur", 1 * 60),
                ("Ouvrir le document", 1 * 60)
            ],
            in: context
        )

        [24, 29, 26, 31, 27, 28, 25, 30].forEach {
            addRoutineSession(to: prepareRoutine, duration: $0 * 60, endedAt: now.addingTimeInterval(-Double($0 + 1) * 86_400), in: context)
        }
        [6, 7, 5, 8].forEach {
            addRoutineSession(to: workRoutine, duration: $0 * 60, endedAt: now.addingTimeInterval(-Double($0 + 2) * 86_400), in: context)
        }

        let work = Activity(
            title: "Travail profond",
            scheduledStartAt: now.addingTimeInterval(-30 * 60),
            estimatedDurationSeconds: 60 * 60
        )
        work.status = .inProgress
        work.routine = workRoutine
        let workSession = ActivitySession(
            startedAt: now.addingTimeInterval(-18 * 60),
            actualDurationSeconds: 0
        )
        workSession.activity = work
        let workRoutineSession = RoutineSession(
            startedAt: now.addingTimeInterval(-18 * 60),
            currentStepIndex: 0,
            completedStepCount: 0,
            status: .active,
            kind: .activityExecution
        )
        workRoutineSession.routine = workRoutine
        workRoutineSession.activity = work

        let lunch = Activity(
            title: "Déjeuner",
            scheduledStartAt: now.addingTimeInterval(75 * 60),
            estimatedDurationSeconds: 45 * 60,
            isFixedTime: true
        )

        let restaurant = Activity(
            title: "Restaurant",
            scheduledStartAt: now.addingTimeInterval(3 * 60 * 60),
            estimatedDurationSeconds: 60 * 60,
            isFixedTime: true
        )
        restaurant.routine = prepareRoutine
        restaurant.transitionMarginSeconds = 5 * 60

        let sport = Activity(
            title: "Sport",
            scheduledStartAt: now.addingTimeInterval(5 * 60 * 60),
            estimatedDurationSeconds: 60 * 60
        )

        [work, lunch, restaurant, sport].forEach { context.insert($0) }
        context.insert(workSession)
        context.insert(workRoutineSession)

        if activeTransition {
            let session = RoutineSession(
                startedAt: now.addingTimeInterval(-6 * 60),
                currentStepIndex: 1,
                completedStepCount: 1,
                status: .active,
                kind: .transition
            )
            session.routine = prepareRoutine
            session.activity = restaurant
            context.insert(session)
        }

        for index in 0..<4 {
            let completedAt = now.addingTimeInterval(-Double(index + 1) * 8_600)
            let activity = Activity(
                title: "Courses",
                scheduledStartAt: completedAt.addingTimeInterval(-30 * 60),
                estimatedDurationSeconds: 30 * 60
            )
            activity.status = .completed
            activity.completedAt = completedAt
            activity.actualDurationSeconds = (40 + index * 2) * 60
            let session = ActivitySession(
                startedAt: completedAt.addingTimeInterval(-Double((40 + index * 2) * 60)),
                endedAt: completedAt,
                actualDurationSeconds: (40 + index * 2) * 60
            )
            session.activity = activity
            context.insert(activity)
            context.insert(session)
        }

        // Keep the calendar reference explicit so the demo remains easy to
        // adapt when a later visual test needs fixed clock times.
        _ = calendar
        try? context.save()
    }

    private static func makeRoutine(
        name: String,
        icon: String,
        steps: [(String, Int)],
        in context: ModelContext
    ) -> Routine {
        let routine = Routine(name: name, icon: icon)
        context.insert(routine)

        for (index, step) in steps.enumerated() {
            let routineStep = RoutineStep(
                title: step.0,
                estimatedDurationSeconds: step.1,
                order: index
            )
            routineStep.routine = routine
            context.insert(routineStep)
        }

        return routine
    }

    private static func addRoutineSession(
        to routine: Routine,
        duration: Int,
        endedAt: Date,
        in context: ModelContext
    ) {
        let session = RoutineSession(
            startedAt: endedAt.addingTimeInterval(-Double(duration)),
            endedAt: endedAt,
            actualDurationSeconds: duration,
            currentStepIndex: routine.orderedSteps.count,
            completedStepCount: routine.orderedSteps.count,
            status: .completed,
            kind: .transition
        )
        session.routine = routine
        context.insert(session)
    }

    private static func date(
        _ day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

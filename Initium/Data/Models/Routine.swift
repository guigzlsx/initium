import Foundation
import SwiftData

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "checklist"
    /// Stable local provenance only. A template refresh never mutates this routine.
    var sourceTemplateSlug: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RoutineStep.routine)
    var steps: [RoutineStep] = []

    @Relationship(deleteRule: .nullify, inverse: \Activity.routine)
    var activities: [Activity] = []

    @Relationship(deleteRule: .cascade, inverse: \RoutineSession.routine)
    var sessions: [RoutineSession] = []

    var estimatedDurationSeconds: Int {
        steps.reduce(0) { total, step in
            total + step.estimatedDurationSeconds
        }
    }

    var orderedSteps: [RoutineStep] {
        steps.sorted { $0.order < $1.order }
    }

    init(name: String, icon: String = "checklist", sourceTemplateSlug: String? = nil) {
        self.name = name
        self.icon = icon
        self.sourceTemplateSlug = sourceTemplateSlug
    }
}

import Foundation
import SwiftData

@Model
final class RoutineSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var actualDurationSeconds: Int = 0
    var currentStepIndex: Int = 0
    var completedStepCount: Int = 0
    var statusRawValue: String = RoutineSessionStatus.active.rawValue
    var kindRawValue: String = RoutineSessionKind.activityExecution.rawValue

    var routine: Routine?
    var activity: Activity?

    var status: RoutineSessionStatus {
        get { RoutineSessionStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var kind: RoutineSessionKind {
        get { RoutineSessionKind(rawValue: kindRawValue) ?? .activityExecution }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        startedAt: Date = .now,
        endedAt: Date? = nil,
        actualDurationSeconds: Int = 0,
        currentStepIndex: Int = 0,
        completedStepCount: Int = 0,
        status: RoutineSessionStatus = .active,
        kind: RoutineSessionKind = .activityExecution
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.actualDurationSeconds = actualDurationSeconds
        self.currentStepIndex = currentStepIndex
        self.completedStepCount = completedStepCount
        self.statusRawValue = status.rawValue
        self.kindRawValue = kind.rawValue
    }
}

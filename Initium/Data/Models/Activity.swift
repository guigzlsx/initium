import Foundation
import SwiftData

@Model
final class Activity {
    var id: UUID = UUID()
    var title: String = ""
    var scheduledStartAt: Date = Date.now
    var originalScheduledStartAt: Date?
    var estimatedDurationSeconds: Int = 1_800
    var actualDurationSeconds: Int = 0
    var statusRawValue: String = ActivityStatus.planned.rawValue
    var isFixedTime: Bool = false
    var notes: String = ""
    var transitionMarginSeconds: Int = 300
    var createdAt: Date = Date.now
    var completedAt: Date?

    // External calendar metadata is intentionally kept separate from the
    // local execution data so EventKit remains read-only for Initium.
    var sourceTypeRawValue: String = ActivitySourceType.local.rawValue
    var externalEventIdentifier: String?
    var externalCalendarIdentifier: String?
    var externalLastModifiedAt: Date?
    var externalIsAllDay: Bool = false
    var externalLocation: String?
    var externalNotes: String?
    var isExternallyDeleted: Bool = false

    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \ActivitySession.activity)
    var sessions: [ActivitySession] = []

    @Relationship(deleteRule: .cascade, inverse: \RoutineSession.activity)
    var routineSessions: [RoutineSession] = []

    var status: ActivityStatus {
        get {
            ActivityStatus(rawValue: statusRawValue) ?? .planned
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    var sourceType: ActivitySourceType {
        get { ActivitySourceType(rawValue: sourceTypeRawValue) ?? .local }
        set { sourceTypeRawValue = newValue.rawValue }
    }

    var isCalendarActivity: Bool {
        sourceType == .calendar && !isExternallyDeleted
    }

    init(
        title: String,
        scheduledStartAt: Date,
        estimatedDurationSeconds: Int,
        isFixedTime: Bool = false,
        notes: String = "",
        sourceType: ActivitySourceType = .local
    ) {
        self.title = title
        self.scheduledStartAt = scheduledStartAt
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.isFixedTime = isFixedTime
        self.notes = notes
        self.sourceTypeRawValue = sourceType.rawValue
    }
}

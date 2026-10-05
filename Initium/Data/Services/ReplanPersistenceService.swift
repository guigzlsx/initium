import Foundation
import SwiftData

struct ReplanActivitySnapshot {
    let activityID: UUID
    let scheduledStartAt: Date
    let originalScheduledStartAt: Date?
    let estimatedDurationSeconds: Int
    let status: ActivityStatus
    let completedAt: Date?
}

struct ReplanUndoSnapshot {
    let activities: [ReplanActivitySnapshot]
}

enum ReplanPersistenceError: LocalizedError {
    case activityNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .activityNotFound:
            return InitiumLocalization.string("error.replan.activity_missing")
        }
    }
}

@MainActor
struct ReplanPersistenceService {
    func apply(
        proposal: ReplanProposal,
        resolutions: [UUID: ReplanConflictResolution],
        in context: ModelContext
    ) throws -> ReplanUndoSnapshot {
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        var snapshots: [ReplanActivitySnapshot] = []

        for change in proposal.changes {
            guard let activity = activitiesByID[change.activityID] else {
                throw ReplanPersistenceError.activityNotFound(change.activityID)
            }

            let resolution = resolutions[change.activityID]
            let shouldApplyChange = change.action != .unchanged || resolution != nil
            guard shouldApplyChange else { continue }

            snapshots.append(snapshot(for: activity))

            if let conflict = proposal.conflicts.first(where: { $0.activityID == activity.id }),
               let resolution {
                apply(
                    resolution,
                    to: activity,
                    conflict: conflict
                )
            } else {
                preserveOriginalStartIfNeeded(for: activity)
                activity.scheduledStartAt = change.proposedStart
                activity.estimatedDurationSeconds = change.proposedDurationSeconds
            }
        }

        try context.save()
        return ReplanUndoSnapshot(activities: snapshots)
    }

    func undo(
        snapshot: ReplanUndoSnapshot,
        in context: ModelContext
    ) throws {
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        for item in snapshot.activities {
            guard let activity = activitiesByID[item.activityID] else {
                throw ReplanPersistenceError.activityNotFound(item.activityID)
            }

            activity.scheduledStartAt = item.scheduledStartAt
            activity.originalScheduledStartAt = item.originalScheduledStartAt
            activity.estimatedDurationSeconds = item.estimatedDurationSeconds
            activity.status = item.status
            activity.completedAt = item.completedAt
        }

        try context.save()
    }

    private func apply(
        _ resolution: ReplanConflictResolution,
        to activity: Activity,
        conflict: ReplanConflict
    ) {
        preserveOriginalStartIfNeeded(for: activity)

        switch resolution {
        case let .postpone(date):
            activity.scheduledStartAt = date
            activity.status = .postponed
        case let .shorten(duration):
            activity.scheduledStartAt = conflict.proposedStart
            activity.estimatedDurationSeconds = max(60, duration)
        case .keep:
            activity.scheduledStartAt = conflict.originalStart
            activity.estimatedDurationSeconds = conflict.originalDurationSeconds
        }
    }

    private func snapshot(for activity: Activity) -> ReplanActivitySnapshot {
        ReplanActivitySnapshot(
            activityID: activity.id,
            scheduledStartAt: activity.scheduledStartAt,
            originalScheduledStartAt: activity.originalScheduledStartAt,
            estimatedDurationSeconds: activity.estimatedDurationSeconds,
            status: activity.status,
            completedAt: activity.completedAt
        )
    }

    private func preserveOriginalStartIfNeeded(for activity: Activity) {
        if activity.originalScheduledStartAt == nil {
            activity.originalScheduledStartAt = activity.scheduledStartAt
        }
    }
}

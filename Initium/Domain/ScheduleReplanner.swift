import Foundation

enum ReplanAction: Equatable {
    case unchanged
    case shifted
    case shortened
    case postponed
}

struct ReplanChange: Identifiable, Equatable {
    let activityID: UUID
    let title: String
    let originalStart: Date
    let proposedStart: Date
    let originalDurationSeconds: Int
    let proposedDurationSeconds: Int
    let action: ReplanAction
    let isFixedTime: Bool

    var id: UUID { activityID }
}

struct ReplanConflict: Identifiable, Equatable {
    let activityID: UUID
    let title: String
    let originalStart: Date
    let originalDurationSeconds: Int
    let proposedStart: Date
    let availableUntil: Date
    let fixedActivityTitle: String?
    let suggestedDurationsSeconds: [Int]

    var id: UUID { activityID }
}

struct ReplanProposal: Equatable {
    let generatedAt: Date
    let replanFrom: Date
    let changes: [ReplanChange]
    let conflicts: [ReplanConflict]

    var hasChanges: Bool {
        changes.contains { $0.action != .unchanged } || !conflicts.isEmpty
    }
}

enum ReplanConflictResolution: Equatable {
    case postpone(to: Date)
    case shorten(toSeconds: Int)
    case keep
}

struct ScheduleReplanner {
    let interActivityMarginSeconds: Int
    let slotSizeSeconds: Int
    private let transitionPlanner: TransitionPlanner

    init(
        interActivityMarginSeconds: Int = 5 * 60,
        slotSizeSeconds: Int = 5 * 60,
        transitionPlanner: TransitionPlanner = TransitionPlanner()
    ) {
        self.interActivityMarginSeconds = max(0, interActivityMarginSeconds)
        self.slotSizeSeconds = max(60, slotSizeSeconds)
        self.transitionPlanner = transitionPlanner
    }

    func makeProposal(
        activities: [Activity],
        replanFrom: Date,
        generatedAt: Date = .now,
        dayEnd: Date? = nil
    ) -> ReplanProposal {
        let endOfPlanningDay = dayEnd ?? Calendar.current.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: replanFrom
        ) ?? replanFrom.addingTimeInterval(24 * 60 * 60)

        let remaining = activities
            .filter { !isTerminal($0.status) }
            .sorted { lhs, rhs in
                if lhs.scheduledStartAt == rhs.scheduledStartAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.scheduledStartAt < rhs.scheduledStartAt
            }

        let futureFixedActivities = remaining.filter {
            $0.isFixedTime && $0.scheduledStartAt >= replanFrom
        }

        var cursor = replanFrom
        var changes: [ReplanChange] = []
        var conflicts: [ReplanConflict] = []

        for activity in remaining {
            let originalStart = activity.scheduledStartAt
            let originalDuration = max(60, activity.estimatedDurationSeconds)

            if activity.status == .inProgress {
                changes.append(
                    ReplanChange(
                        activityID: activity.id,
                        title: activity.title,
                        originalStart: originalStart,
                        proposedStart: originalStart,
                        originalDurationSeconds: originalDuration,
                        proposedDurationSeconds: originalDuration,
                        action: .unchanged,
                        isFixedTime: activity.isFixedTime
                    )
                )
                continue
            }

            if activity.isFixedTime {
                changes.append(
                    ReplanChange(
                        activityID: activity.id,
                        title: activity.title,
                        originalStart: originalStart,
                        proposedStart: originalStart,
                        originalDurationSeconds: originalDuration,
                        proposedDurationSeconds: originalDuration,
                        action: .unchanged,
                        isFixedTime: true
                    )
                )

                let block = fixedBlock(for: activity, replanFrom: replanFrom)
                cursor = max(cursor, block.end.addingTimeInterval(TimeInterval(interActivityMarginSeconds)))
                continue
            }

            let candidateStart = proposedStart(
                for: activity,
                cursor: cursor,
                replanFrom: replanFrom
            )
            let candidateEnd = candidateStart.addingTimeInterval(TimeInterval(originalDuration))
            let nextFixed = futureFixedActivities.first {
                $0.scheduledStartAt > originalStart
            }
            let barrier = nextFixed.map {
                fixedBlock(for: $0, replanFrom: replanFrom)
            }

            if let barrier, candidateEnd > barrier.start {
                conflicts.append(
                    makeConflict(
                        for: activity,
                        proposedStart: candidateStart,
                        availableUntil: barrier.start,
                        fixedActivityTitle: nextFixed?.title
                    )
                )
                changes.append(
                    ReplanChange(
                        activityID: activity.id,
                        title: activity.title,
                        originalStart: originalStart,
                        proposedStart: originalStart,
                        originalDurationSeconds: originalDuration,
                        proposedDurationSeconds: originalDuration,
                        action: .unchanged,
                        isFixedTime: false
                    )
                )
                cursor = max(cursor, barrier.end.addingTimeInterval(TimeInterval(interActivityMarginSeconds)))
                continue
            }

            if candidateEnd > endOfPlanningDay {
                conflicts.append(
                    makeConflict(
                        for: activity,
                        proposedStart: candidateStart,
                        availableUntil: endOfPlanningDay,
                        fixedActivityTitle: nil
                    )
                )
                changes.append(
                    ReplanChange(
                        activityID: activity.id,
                        title: activity.title,
                        originalStart: originalStart,
                        proposedStart: originalStart,
                        originalDurationSeconds: originalDuration,
                        proposedDurationSeconds: originalDuration,
                        action: .unchanged,
                        isFixedTime: false
                    )
                )
                continue
            }

            let action: ReplanAction = candidateStart == originalStart ? .unchanged : .shifted
            changes.append(
                ReplanChange(
                    activityID: activity.id,
                    title: activity.title,
                    originalStart: originalStart,
                    proposedStart: candidateStart,
                    originalDurationSeconds: originalDuration,
                    proposedDurationSeconds: originalDuration,
                    action: action,
                    isFixedTime: false
                )
            )
            cursor = candidateEnd.addingTimeInterval(TimeInterval(interActivityMarginSeconds))
        }

        return ReplanProposal(
            generatedAt: generatedAt,
            replanFrom: replanFrom,
            changes: changes,
            conflicts: conflicts
        )
    }

    private func proposedStart(
        for activity: Activity,
        cursor: Date,
        replanFrom: Date
    ) -> Date {
        var base = max(cursor, activity.scheduledStartAt)

        if activity.scheduledStartAt < replanFrom {
            base = max(base, replanFrom.addingTimeInterval(TimeInterval(interActivityMarginSeconds)))
        }

        let needsAlignment = activity.scheduledStartAt < replanFrom || base > cursor
        return needsAlignment ? alignUp(base) : base
    }

    private func makeConflict(
        for activity: Activity,
        proposedStart: Date,
        availableUntil: Date,
        fixedActivityTitle: String?
    ) -> ReplanConflict {
        let availableSeconds = max(0, Int(availableUntil.timeIntervalSince(proposedStart)))
        let suggestions = [45, 30, 15]
            .map { $0 * 60 }
            .filter { $0 < activity.estimatedDurationSeconds && $0 <= availableSeconds }

        return ReplanConflict(
            activityID: activity.id,
            title: activity.title,
            originalStart: activity.scheduledStartAt,
            originalDurationSeconds: max(60, activity.estimatedDurationSeconds),
            proposedStart: proposedStart,
            availableUntil: availableUntil,
            fixedActivityTitle: fixedActivityTitle,
            suggestedDurationsSeconds: suggestions
        )
    }

    private func fixedBlock(for activity: Activity, replanFrom: Date) -> (start: Date, end: Date) {
        let transitionStart = transitionPlanner
            .makePlan(for: activity)?
            .transitionStart ?? activity.scheduledStartAt
        let blockStart = max(replanFrom, min(transitionStart, activity.scheduledStartAt))
        let blockEnd = activity.scheduledStartAt.addingTimeInterval(
            TimeInterval(max(60, activity.estimatedDurationSeconds))
        )
        return (blockStart, blockEnd)
    }

    private func alignUp(_ date: Date) -> Date {
        let timestamp = date.timeIntervalSince1970
        let aligned = ceil(timestamp / Double(slotSizeSeconds)) * Double(slotSizeSeconds)
        return Date(timeIntervalSince1970: aligned)
    }

    private func isTerminal(_ status: ActivityStatus) -> Bool {
        switch status {
        case .completed, .skipped, .cancelled, .postponed:
            return true
        case .planned, .inProgress, .paused:
            return false
        }
    }
}

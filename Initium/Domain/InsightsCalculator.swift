import Foundation

enum InsightsPeriod: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var numberOfDays: Int {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        }
    }

    var title: String {
        switch self {
        case .sevenDays:
            return "7 jours"
        case .thirtyDays:
            return "30 jours"
        }
    }

    func interval(endingAt now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(
            byAdding: .day,
            value: -(numberOfDays - 1),
            to: today
        ) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return DateInterval(start: firstDay, end: end)
    }
}

struct CalibrationInsight: Equatable {
    let estimatedAverageSeconds: Int
    let actualAverageSeconds: Int
    let observationCount: Int

    var differenceSeconds: Int {
        actualAverageSeconds - estimatedAverageSeconds
    }

    var percentageDifference: Double? {
        guard estimatedAverageSeconds > 0 else { return nil }
        return Double(differenceSeconds) / Double(estimatedAverageSeconds) * 100
    }

    var isReliable: Bool {
        observationCount >= InsightsCalculator.minimumObservationCount
    }
}

struct RoutineInsight: Identifiable, Equatable {
    let routineID: UUID
    let name: String
    let estimatedDurationSeconds: Int
    let actualAverageSeconds: Int
    let observationCount: Int
    let recentDurationsSeconds: [Int]

    var id: UUID { routineID }

    var differenceSeconds: Int {
        actualAverageSeconds - estimatedDurationSeconds
    }

    var isReliable: Bool {
        observationCount >= InsightsCalculator.minimumObservationCount
    }

    var isWellCalibrated: Bool {
        isReliable && abs(differenceSeconds) <= InsightsCalculator.wellCalibratedToleranceSeconds
    }
}

struct StartDelayInsight: Equatable {
    let averageDelaySeconds: Int
    let observationCount: Int

    var isReliable: Bool {
        observationCount >= InsightsCalculator.minimumObservationCount
    }
}

struct ActivityCalibrationInsight: Identifiable, Equatable {
    let key: String
    let title: String
    let estimatedAverageSeconds: Int
    let actualAverageSeconds: Int
    let observationCount: Int

    var id: String { key }

    var differenceSeconds: Int {
        actualAverageSeconds - estimatedAverageSeconds
    }

    var percentageDifference: Double? {
        guard estimatedAverageSeconds > 0 else { return nil }
        return Double(differenceSeconds) / Double(estimatedAverageSeconds) * 100
    }
}

struct ReplanInsight: Equatable {
    let replannedActivityCount: Int
    let replannedDayCount: Int
}

struct InsightsSnapshot: Equatable {
    let period: InsightsPeriod
    let overallCalibration: CalibrationInsight?
    let routineInsights: [RoutineInsight]
    let startDelay: StartDelayInsight?
    let underestimatedActivities: [ActivityCalibrationInsight]
    let wellCalibratedActivities: [ActivityCalibrationInsight]
    let replan: ReplanInsight

    var hasObservations: Bool {
        overallCalibration != nil ||
            !routineInsights.isEmpty ||
            startDelay != nil ||
            replan.replannedActivityCount > 0
    }
}

struct InsightsCalculator {
    static let minimumObservationCount = 3
    static let wellCalibratedToleranceSeconds = 2 * 60
    private static let maximumValidDurationSeconds = 24 * 60 * 60

    func calculate(
        activities: [Activity],
        routines: [Routine],
        period: InsightsPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsSnapshot {
        let interval = period.interval(endingAt: now, calendar: calendar)
        let activityObservations = activities.compactMap {
            observation(for: $0, within: interval)
        }
        let routineInsights = routines.compactMap {
            routineInsight(for: $0, within: interval)
        }
        let overallCalibration = makeCalibrationInsight(from: activityObservations)
        let startDelay = makeStartDelayInsight(from: activityObservations)
        let activityGroups = Dictionary(
            grouping: activityObservations,
            by: { normalizedTitle($0.title) }
        )
        let activityInsights = activityGroups.compactMap(makeActivityInsight(from:))

        return InsightsSnapshot(
            period: period,
            overallCalibration: overallCalibration,
            routineInsights: routineInsights.sorted {
                $0.observationCount > $1.observationCount
            },
            startDelay: startDelay,
            underestimatedActivities: activityInsights
                .filter { $0.observationCount >= Self.minimumObservationCount && $0.differenceSeconds > 0 }
                .sorted { $0.differenceSeconds > $1.differenceSeconds }
                .prefix(3)
                .map { $0 },
            wellCalibratedActivities: activityInsights
                .filter {
                    $0.observationCount >= Self.minimumObservationCount &&
                    abs($0.differenceSeconds) <= Self.wellCalibratedToleranceSeconds
                }
                .sorted { $0.observationCount > $1.observationCount }
                .prefix(3)
                .map { $0 },
            replan: makeReplanInsight(from: activities, within: interval, calendar: calendar)
        )
    }

    private func observation(
        for activity: Activity,
        within interval: DateInterval
    ) -> ActivityObservation? {
        guard activity.status == .completed,
              isValidDuration(activity.estimatedDurationSeconds) else {
            return nil
        }

        let validSessions = activity.sessions.compactMap(validSession(_:))
        let lastSessionEnd = validSessions.map(\.endedAt).max()
        let completionDate = activity.completedAt ?? lastSessionEnd
        guard let completionDate, interval.contains(completionDate) else { return nil }

        let sessionDuration = validSessions.reduce(0) { $0 + $1.durationSeconds }
        let actualDuration = sessionDuration > 0
            ? sessionDuration
            : activity.actualDurationSeconds
        guard isValidDuration(actualDuration) else { return nil }

        return ActivityObservation(
            activityID: activity.id,
            title: activity.title,
            estimatedDurationSeconds: activity.estimatedDurationSeconds,
            actualDurationSeconds: actualDuration,
            scheduledStartAt: activity.scheduledStartAt,
            firstStartedAt: validSessions.map(\.startedAt).min(),
            completionDate: completionDate,
            originalScheduledStartAt: activity.originalScheduledStartAt
        )
    }

    private func routineInsight(
        for routine: Routine,
        within interval: DateInterval
    ) -> RoutineInsight? {
        guard isValidDuration(routine.estimatedDurationSeconds) else { return nil }

        let durations = routine.sessions.compactMap { session -> (date: Date, duration: Int)? in
            guard session.kind == .transition,
                  session.status == .completed,
                  let endedAt = session.endedAt,
                  interval.contains(endedAt),
                  let duration = validDuration(for: session, endedAt: endedAt) else {
                return nil
            }
            return (endedAt, duration)
        }
        guard !durations.isEmpty else { return nil }

        let sortedDurations = durations.sorted { $0.date > $1.date }.map(\.duration)
        return RoutineInsight(
            routineID: routine.id,
            name: routine.name,
            estimatedDurationSeconds: routine.estimatedDurationSeconds,
            actualAverageSeconds: average(sortedDurations),
            observationCount: sortedDurations.count,
            recentDurationsSeconds: Array(sortedDurations.prefix(5))
        )
    }

    private func makeCalibrationInsight(
        from observations: [ActivityObservation]
    ) -> CalibrationInsight? {
        guard !observations.isEmpty else { return nil }
        return CalibrationInsight(
            estimatedAverageSeconds: average(observations.map(\.estimatedDurationSeconds)),
            actualAverageSeconds: average(observations.map(\.actualDurationSeconds)),
            observationCount: observations.count
        )
    }

    private func makeStartDelayInsight(
        from observations: [ActivityObservation]
    ) -> StartDelayInsight? {
        let delays = observations.compactMap { observation -> Int? in
            guard let firstStartedAt = observation.firstStartedAt else { return nil }
            let seconds = Int(firstStartedAt.timeIntervalSince(observation.scheduledStartAt).rounded())
            guard abs(seconds) <= Self.maximumValidDurationSeconds else { return nil }
            return seconds
        }
        guard !delays.isEmpty else { return nil }
        return StartDelayInsight(
            averageDelaySeconds: average(delays),
            observationCount: delays.count
        )
    }

    private func makeActivityInsight(
        from group: (key: String, value: [ActivityObservation])
    ) -> ActivityCalibrationInsight? {
        guard group.value.count >= Self.minimumObservationCount,
              let title = group.value.first?.title else {
            return nil
        }
        return ActivityCalibrationInsight(
            key: group.key,
            title: title,
            estimatedAverageSeconds: average(group.value.map(\.estimatedDurationSeconds)),
            actualAverageSeconds: average(group.value.map(\.actualDurationSeconds)),
            observationCount: group.value.count
        )
    }

    private func makeReplanInsight(
        from activities: [Activity],
        within interval: DateInterval,
        calendar: Calendar
    ) -> ReplanInsight {
        let replanned = activities.filter { activity in
            guard let original = activity.originalScheduledStartAt,
                  original != activity.scheduledStartAt else {
                return false
            }
            return interval.contains(original) || interval.contains(activity.scheduledStartAt)
        }
        let days = Set(replanned.map {
            calendar.startOfDay(for: $0.originalScheduledStartAt ?? $0.scheduledStartAt)
        })
        return ReplanInsight(
            replannedActivityCount: replanned.count,
            replannedDayCount: days.count
        )
    }

    private func validSession(_ session: ActivitySession) -> ValidSession? {
        guard let endedAt = session.endedAt,
              endedAt >= session.startedAt else {
            return nil
        }
        let measuredDuration = Int(endedAt.timeIntervalSince(session.startedAt).rounded())
        guard isValidDuration(measuredDuration) else { return nil }
        let duration = isValidDuration(session.actualDurationSeconds)
            ? session.actualDurationSeconds
            : measuredDuration
        return ValidSession(
            startedAt: session.startedAt,
            endedAt: endedAt,
            durationSeconds: duration
        )
    }

    private func validDuration(
        for session: RoutineSession,
        endedAt: Date
    ) -> Int? {
        let measuredDuration = Int(endedAt.timeIntervalSince(session.startedAt).rounded())
        guard isValidDuration(measuredDuration) else { return nil }
        return isValidDuration(session.actualDurationSeconds)
            ? session.actualDurationSeconds
            : measuredDuration
    }

    private func isValidDuration(_ duration: Int) -> Bool {
        duration > 0 && duration <= Self.maximumValidDurationSeconds
    }

    private func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct ActivityObservation {
    let activityID: UUID
    let title: String
    let estimatedDurationSeconds: Int
    let actualDurationSeconds: Int
    let scheduledStartAt: Date
    let firstStartedAt: Date?
    let completionDate: Date
    let originalScheduledStartAt: Date?
}

private struct ValidSession {
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
}

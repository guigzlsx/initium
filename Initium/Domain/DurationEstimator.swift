import Foundation

struct DurationSample: Equatable {
    let durationSeconds: Int
    let isComplete: Bool
}

struct DurationEstimator {
    let minimumCompletedSessions = 3

    func recommendedDuration(
        estimatedDurationSeconds: Int,
        samples: [DurationSample]
    ) -> Int {
        let completedDurations = samples
            .filter { $0.isComplete && $0.durationSeconds > 0 }
            .map(\.durationSeconds)

        guard completedDurations.count >= minimumCompletedSessions else {
            return estimatedDurationSeconds
        }

        let total = completedDurations.reduce(0, +)
        return Int((Double(total) / Double(completedDurations.count)).rounded())
    }

    func recommendedDuration(
        estimatedDurationSeconds: Int,
        completedDurations: [Int]
    ) -> Int {
        let samples = completedDurations.map {
            DurationSample(durationSeconds: $0, isComplete: true)
        }

        return recommendedDuration(
            estimatedDurationSeconds: estimatedDurationSeconds,
            samples: samples
        )
    }
}

import Foundation

struct RoutineCalibrationResult: Equatable {
    let estimatedDurationSeconds: Int
    let recommendedDurationSeconds: Int
    let observationCount: Int
    let recentDurationsSeconds: [Int]

    var hasEnoughHistory: Bool {
        observationCount >= DurationEstimator().minimumCompletedSessions
    }
}

struct RoutineCalibration {
    private let estimator: DurationEstimator

    init(estimator: DurationEstimator = DurationEstimator()) {
        self.estimator = estimator
    }

    func samples(for routine: Routine) -> [DurationSample] {
        routine.sessions
            .filter {
                $0.kind == .transition &&
                $0.status == .completed &&
                $0.actualDurationSeconds > 0
            }
            .map {
                DurationSample(durationSeconds: $0.actualDurationSeconds, isComplete: true)
            }
    }

    func result(for routine: Routine) -> RoutineCalibrationResult {
        let samples = samples(for: routine)

        return RoutineCalibrationResult(
            estimatedDurationSeconds: routine.estimatedDurationSeconds,
            recommendedDurationSeconds: estimator.recommendedDuration(
                estimatedDurationSeconds: routine.estimatedDurationSeconds,
                samples: samples
            ),
            observationCount: samples.count,
            recentDurationsSeconds: Array(samples.map(\.durationSeconds).prefix(5))
        )
    }
}

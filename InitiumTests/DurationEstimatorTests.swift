import XCTest
@testable import Initium

final class DurationEstimatorTests: XCTestCase {
    private let estimator = DurationEstimator()

    func testUsesEstimateWithFewerThanThreeCompletedSessions() {
        let result = estimator.recommendedDuration(
            estimatedDurationSeconds: 1_200,
            completedDurations: [1_500, 1_800]
        )

        XCTAssertEqual(result, 1_200)
    }

    func testUsesAverageWithThreeCompletedSessions() {
        let result = estimator.recommendedDuration(
            estimatedDurationSeconds: 1_200,
            completedDurations: [1_200, 1_800, 2_400]
        )

        XCTAssertEqual(result, 1_800)
    }

    func testIgnoresIncompleteAndInvalidSamples() {
        let result = estimator.recommendedDuration(
            estimatedDurationSeconds: 1_200,
            samples: [
                DurationSample(durationSeconds: 600, isComplete: false),
                DurationSample(durationSeconds: 0, isComplete: true),
                DurationSample(durationSeconds: 1_200, isComplete: true),
                DurationSample(durationSeconds: 1_800, isComplete: true),
                DurationSample(durationSeconds: 2_400, isComplete: true)
            ]
        )

        XCTAssertEqual(result, 1_800)
    }
}

import Foundation
import SwiftData

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var period: InsightsPeriod = .sevenDays
    @Published private(set) var snapshot: InsightsSnapshot?

    private let calculator: InsightsCalculator

    init(calculator: InsightsCalculator = InsightsCalculator()) {
        self.calculator = calculator
    }

    func refresh(
        activities: [Activity],
        routines: [Routine],
        now: Date = .now
    ) {
        snapshot = calculator.calculate(
            activities: activities,
            routines: routines,
            period: period,
            now: now
        )
    }
}

import Foundation
import SwiftData

@Model
final class RoutineStep {
    var id: UUID = UUID()
    var title: String = ""
    var estimatedDurationSeconds: Int = 300
    var order: Int = 0

    var routine: Routine?

    init(title: String, estimatedDurationSeconds: Int, order: Int) {
        self.title = title
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.order = order
    }
}

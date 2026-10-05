import Foundation
import SwiftData

@Model
final class ActivitySession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var actualDurationSeconds: Int = 0

    var activity: Activity?

    init(startedAt: Date = .now, endedAt: Date? = nil, actualDurationSeconds: Int = 0) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.actualDurationSeconds = actualDurationSeconds
    }
}

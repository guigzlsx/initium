import Foundation

enum ActivityStatus: String, Codable {
    case planned
    case inProgress
    case paused
    case completed
    case skipped
    case postponed
    case cancelled
}

import Foundation

struct OnboardingPreferences: Codable, Equatable {
    var primaryDifficulty: PrimaryDifficulty?
    var commonPattern: CommonPattern?
    var guidanceStyle: GuidanceStyle?
    var mainGoal: MainGoal?
}

enum PrimaryDifficulty: String, Codable, CaseIterable, Identifiable {
    case startingTask
    case changingActivities
    case estimatingTime
    case followingPlans
    case aBitOfEverything

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .startingTask: "onboarding.difficulty.start"
        case .changingActivities: "onboarding.difficulty.transition"
        case .estimatingTime: "onboarding.difficulty.time"
        case .followingPlans: "onboarding.difficulty.planning"
        case .aBitOfEverything: "onboarding.difficulty.everything"
        }
    }
}

enum CommonPattern: String, Codable, CaseIterable, Identifiable {
    case underestimateTime
    case lastMinute
    case stuckInActivity
    case plansDrift
    case overwhelmed

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .underestimateTime: "onboarding.pattern.underestimate"
        case .lastMinute: "onboarding.pattern.last_minute"
        case .stuckInActivity: "onboarding.pattern.stuck"
        case .plansDrift: "onboarding.pattern.drift"
        case .overwhelmed: "onboarding.pattern.overwhelmed"
        }
    }
}

enum GuidanceStyle: String, Codable, CaseIterable, Identifiable {
    case simple
    case gentleReminders
    case moreStructure

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .simple: "onboarding.guidance.simple"
        case .gentleReminders: "onboarding.guidance.reminders"
        case .moreStructure: "onboarding.guidance.structure"
        }
    }
}

enum MainGoal: String, Codable, CaseIterable, Identifiable {
    case startEasier
    case beReadyOnTime
    case estimateTime
    case recoverFromChanges
    case understandRhythm

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .startEasier: "onboarding.goal.start"
        case .beReadyOnTime: "onboarding.goal.ready"
        case .estimateTime: "onboarding.goal.estimate"
        case .recoverFromChanges: "onboarding.goal.recover"
        case .understandRhythm: "onboarding.goal.rhythm"
        }
    }
}

import Foundation
import SwiftUI

@MainActor
final class EntryFlowViewModel: ObservableObject {
    @Published private(set) var state: AppFlowState = .restoring
    @Published private(set) var onboardingStep = 0
    @Published private(set) var onboardingPreferences: OnboardingPreferences

    let totalOnboardingSteps = 4

    private let defaults: UserDefaults

    private enum Key {
        static let hasSeenWelcome = "initium.entry.hasSeenWelcome"
        static let onboardingCompleted = "initium.entry.onboardingCompleted"
        static let paywallSeen = "initium.entry.paywallSeen"
        static let onboardingStep = "initium.entry.onboardingStep"
        static let onboardingPreferences = "initium.entry.onboardingPreferences"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.onboardingPreferences = Self.loadPreferences(from: defaults)
        self.onboardingStep = min(
            max(defaults.integer(forKey: Key.onboardingStep), 0),
            3
        )
        restore()
    }

    var isCurrentQuestionAnswered: Bool {
        switch onboardingStep {
        case 0: onboardingPreferences.primaryDifficulty != nil
        case 1: onboardingPreferences.commonPattern != nil
        case 2: onboardingPreferences.guidanceStyle != nil
        case 3: onboardingPreferences.mainGoal != nil
        default: false
        }
    }

    var progressLabel: String {
        "\(onboardingStep + 1) / \(totalOnboardingSteps)"
    }

    func completeWelcome() {
        defaults.set(true, forKey: Key.hasSeenWelcome)
        state = .onboarding
    }

    func select(_ value: PrimaryDifficulty) {
        onboardingPreferences.primaryDifficulty = value
        persistPreferences()
    }

    func select(_ value: CommonPattern) {
        onboardingPreferences.commonPattern = value
        persistPreferences()
    }

    func select(_ value: GuidanceStyle) {
        onboardingPreferences.guidanceStyle = value
        persistPreferences()
    }

    func select(_ value: MainGoal) {
        onboardingPreferences.mainGoal = value
        persistPreferences()
    }

    func continueOnboarding() {
        guard isCurrentQuestionAnswered else { return }

        if onboardingStep < totalOnboardingSteps - 1 {
            onboardingStep += 1
            persistStep()
        } else {
            defaults.set(true, forKey: Key.onboardingCompleted)
            state = .valueSummary
        }
    }

    func goBackInOnboarding() {
        if onboardingStep > 0 {
            onboardingStep -= 1
            persistStep()
        } else {
            state = .welcome
        }
    }

    func continueFromValueSummary() {
        state = .paywall
    }

    func continueFromPaywall() {
        defaults.set(true, forKey: Key.paywallSeen)
        state = .accountCreation
    }

    #if DEBUG
    func resetForDevelopment() {
        defaults.removeObject(forKey: Key.hasSeenWelcome)
        defaults.removeObject(forKey: Key.onboardingCompleted)
        defaults.removeObject(forKey: Key.paywallSeen)
        defaults.removeObject(forKey: Key.onboardingStep)
        defaults.removeObject(forKey: Key.onboardingPreferences)
        onboardingStep = 0
        onboardingPreferences = OnboardingPreferences()
        state = .welcome
    }
    #endif

    private func restore() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let demoMode = arguments.contains(where: { $0.hasPrefix("--initium-") })
        if demoMode {
            state = .mainApp
            return
        }
        #endif

        if defaults.bool(forKey: Key.paywallSeen) {
            state = .accountCreation
        } else if defaults.bool(forKey: Key.onboardingCompleted) {
            state = .valueSummary
        } else if defaults.bool(forKey: Key.hasSeenWelcome) {
            state = .onboarding
        } else {
            state = .welcome
        }
    }

    private func persistStep() {
        defaults.set(onboardingStep, forKey: Key.onboardingStep)
    }

    private func persistPreferences() {
        guard let data = try? JSONEncoder().encode(onboardingPreferences) else { return }
        defaults.set(data, forKey: Key.onboardingPreferences)
    }

    private static func loadPreferences(from defaults: UserDefaults) -> OnboardingPreferences {
        guard
            let data = defaults.data(forKey: Key.onboardingPreferences),
            let preferences = try? JSONDecoder().decode(OnboardingPreferences.self, from: data)
        else {
            return OnboardingPreferences()
        }
        return preferences
    }
}

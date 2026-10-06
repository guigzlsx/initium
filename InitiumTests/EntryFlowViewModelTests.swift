import XCTest
@testable import Initium

@MainActor
final class EntryFlowViewModelTests: XCTestCase {
    func testNewUserStartsAtWelcome() {
        let viewModel = EntryFlowViewModel(defaults: makeDefaults())

        XCTAssertEqual(viewModel.state, .welcome)
        XCTAssertEqual(viewModel.onboardingStep, 0)
    }

    func testWelcomeLeadsToOnboarding() {
        let viewModel = EntryFlowViewModel(defaults: makeDefaults())

        viewModel.completeWelcome()

        XCTAssertEqual(viewModel.state, .onboarding)
    }

    func testIncompleteOnboardingResumesAtSavedStep() {
        let defaults = makeDefaults()
        let firstLaunch = EntryFlowViewModel(defaults: defaults)
        firstLaunch.completeWelcome()
        firstLaunch.select(.startingTask)
        firstLaunch.continueOnboarding()

        let relaunch = EntryFlowViewModel(defaults: defaults)

        XCTAssertEqual(relaunch.state, .onboarding)
        XCTAssertEqual(relaunch.onboardingStep, 1)
        XCTAssertEqual(relaunch.onboardingPreferences.primaryDifficulty, .startingTask)
    }

    func testBackNavigationReturnsToPreviousQuestionAndWelcome() {
        let viewModel = EntryFlowViewModel(defaults: makeDefaults())
        viewModel.completeWelcome()
        viewModel.select(.startingTask)
        viewModel.continueOnboarding()

        viewModel.goBackInOnboarding()
        XCTAssertEqual(viewModel.onboardingStep, 0)

        viewModel.goBackInOnboarding()
        XCTAssertEqual(viewModel.state, .welcome)
    }

    func testPreferencesPersistAcrossRelaunch() {
        let defaults = makeDefaults()
        let viewModel = EntryFlowViewModel(defaults: defaults)
        viewModel.completeWelcome()
        viewModel.select(.changingActivities)
        viewModel.continueOnboarding()
        viewModel.select(.plansDrift)
        viewModel.continueOnboarding()
        viewModel.select(.gentleReminders)
        viewModel.continueOnboarding()
        viewModel.select(.recoverFromChanges)

        let relaunch = EntryFlowViewModel(defaults: defaults)

        XCTAssertEqual(
            relaunch.onboardingPreferences,
            OnboardingPreferences(
                primaryDifficulty: .changingActivities,
                commonPattern: .plansDrift,
                guidanceStyle: .gentleReminders,
                mainGoal: .recoverFromChanges
            )
        )
    }

    func testCompleteFlowReachesMainAppAndSurvivesRelaunch() {
        let defaults = makeDefaults()
        let viewModel = EntryFlowViewModel(defaults: defaults)
        completeOnboarding(viewModel)

        XCTAssertEqual(viewModel.state, .valueSummary)

        viewModel.continueFromValueSummary()
        XCTAssertEqual(viewModel.state, .paywall)

        viewModel.continueFromPaywall()
        XCTAssertEqual(viewModel.state, .accountCreation)

        viewModel.completeAccountPlaceholder()
        XCTAssertEqual(viewModel.state, .mainApp)

        let relaunch = EntryFlowViewModel(defaults: defaults)
        XCTAssertEqual(relaunch.state, .mainApp)
    }

    func testPaywallAndAccountProgressPersistIndependently() {
        let defaults = makeDefaults()
        let viewModel = EntryFlowViewModel(defaults: defaults)
        completeOnboarding(viewModel)
        viewModel.continueFromValueSummary()
        viewModel.continueFromPaywall()

        let relaunch = EntryFlowViewModel(defaults: defaults)

        XCTAssertEqual(relaunch.state, .accountCreation)
    }

    #if DEBUG
    func testDebugResetReturnsToWelcomeAndClearsPreferences() {
        let defaults = makeDefaults()
        let viewModel = EntryFlowViewModel(defaults: defaults)
        completeOnboarding(viewModel)

        viewModel.resetForDevelopment()

        XCTAssertEqual(viewModel.state, .welcome)
        XCTAssertEqual(viewModel.onboardingPreferences, OnboardingPreferences())
        XCTAssertEqual(viewModel.onboardingStep, 0)
    }
    #endif

    private func completeOnboarding(_ viewModel: EntryFlowViewModel) {
        viewModel.completeWelcome()
        viewModel.select(.startingTask)
        viewModel.continueOnboarding()
        viewModel.select(.underestimateTime)
        viewModel.continueOnboarding()
        viewModel.select(.simple)
        viewModel.continueOnboarding()
        viewModel.select(.startEasier)
        viewModel.continueOnboarding()
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InitiumTests.EntryFlow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

import SwiftUI

struct EntryFlowView: View {
    @ObservedObject var viewModel: EntryFlowViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .restoring:
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .initiumScreen()
            case .welcome:
                WelcomeView {
                    viewModel.completeWelcome()
                }
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .valueSummary:
                ValueSummaryView(viewModel: viewModel) {
                    viewModel.continueFromValueSummary()
                }
            case .paywall:
                PaywallPlaceholderView {
                    viewModel.continueFromPaywall()
                }
            case .accountCreation:
                AccountPlaceholderView {
                    viewModel.completeAccountPlaceholder()
                }
            case .mainApp:
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }
}

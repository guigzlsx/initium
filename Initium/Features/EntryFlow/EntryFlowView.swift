import SwiftUI

struct EntryFlowView: View {
    @ObservedObject var viewModel: EntryFlowViewModel

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch viewModel.state {
                case .restoring:
                    ProgressView()
                        .tint(AppTheme.accent)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }
}
